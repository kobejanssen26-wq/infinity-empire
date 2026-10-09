--!nonstrict
-- The single client->server entry point. Every request is: rate-limited, resolved to a whitelisted
-- action, argument-validated, executed by the pure Engine (which re-validates all game rules),
-- then followed by an achievement check and a batched state sync.

local Players = game:GetService("Players")

local Shared = require(script.Parent.Parent.Logic.Shared)
local Engine = require(script.Parent.Parent.Logic.Engine)
local Config = Shared.Config
local DataService = require(script.Parent.DataService)
local Session = require(script.Parent.Session)
local PlotService = require(script.Parent.PlotService)
local PurchaseService = require(script.Parent.PurchaseService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local Router = {}

type Result = { ok: boolean, msg: string, data: any? }
type Handler = (Player, any, any, any) -> (boolean, string, any?)

local buckets: { [Player]: { tokens: number, last: number } } = {}
local serverHatched = 0
local GOAL_STEP = 200

local function takeToken(player: Player, cost: number): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = Config.RateLimit.capacity, last = now }
		buckets[player] = b
	end
	b.tokens = math.min(Config.RateLimit.capacity, b.tokens + (now - b.last) * Config.RateLimit.refillPerSecond)
	b.last = now
	if b.tokens < cost then
		return false
	end
	b.tokens -= cost
	return true
end

local function str(v: any, maxLen: number?): string?
	if type(v) == "string" and #v <= (maxLen or 40) then
		return v
	end
	return nil
end

local actions: { [string]: Handler } = {
	buyMachine = function(_, p, a, ctx) return Engine.buyMachine(p, str(a.id), ctx) end,
	upgradeMachine = function(_, p, a, ctx)
		return Engine.upgradeMachine(p, str(a.id), if type(a.count) == "number" then a.count else 1, ctx)
	end,
	expandZone = function(_, p, _, ctx) return Engine.expandZone(p, ctx) end,
	buyEgg = function(_, p, a, ctx)
		local ok, msg, data = Engine.buyEgg(p, str(a.id), ctx)
		if ok then
			serverHatched += 1
			if serverHatched % GOAL_STEP == 0 then
				-- server-wide cooperative goal hook: everyone in the server benefits
				for plr, prof in pairs(DataService.all()) do
					Engine.grantReward(prof, { cores = 3, biomass = 50 }, Session.ctx(plr))
					Session.dirty(plr)
				end
				Session.announceServer(string.format("Server goal reached: %d eggs hatched! Everyone receives 3 Cores and 50 Biomass.", serverHatched))
			end
		end
		return ok, msg, data
	end,
	levelCreature = function(_, p, a, ctx) return Engine.levelCreature(p, str(a.uid), ctx) end,
	assign = function(_, p, a, ctx)
		local m = a.machine
		if m ~= nil and str(m) == nil then return false, "Bad request" end
		return Engine.assign(p, str(a.uid), m, ctx)
	end,
	autoAssign = function(_, p, _, ctx) return Engine.autoAssign(p, ctx) end,
	release = function(_, p, a, ctx) return Engine.release(p, str(a.uid), ctx) end,
	fuse = function(_, p, a, ctx)
		local uids = nil
		if a.uids ~= nil then
			if type(a.uids) ~= "table" or #a.uids > 10 then return false, "Bad request" end
			uids = {}
			for _, u in ipairs(a.uids) do
				table.insert(uids, str(u) or "")
			end
		end
		return Engine.fuse(p, str(a.recipe), uids, ctx)
	end,
	buyResearch = function(_, p, a, ctx) return Engine.buyResearch(p, str(a.id), ctx) end,
	rebirth = function(_, p, a, ctx) return Engine.rebirth(p, a.confirm, ctx) end,
	buyPrestige = function(_, p, a, ctx) return Engine.buyPrestige(p, str(a.id), ctx) end,
	claimQuest = function(_, p, a, ctx) return Engine.claimQuest(p, str(a.id), ctx) end,
	setSetting = function(_, p, a, ctx) return Engine.setSetting(p, str(a.key), a.value, ctx) end,
	setTheme = function(_, p, a, ctx) return Engine.setTheme(p, str(a.theme), ctx) end,
	buyPass = function(player, _, a) return PurchaseService.prompt(player, "pass", str(a.key)) end,
	buyProduct = function(player, _, a) return PurchaseService.prompt(player, "product", str(a.key)) end,
	visit = function(player, _, a)
		local uid = a.userId
		if type(uid) ~= "number" or uid ~= uid then return false, "Bad request" end
		local target = Players:GetPlayerByUserId(uid)
		if not target or target == player then return false, "Player not found" end
		local cf = PlotService.visitorCFrame(target)
		if not cf then return false, "Factory not ready" end
		PlotService.moveCharacter(player, cf)
		return true, "Visiting " .. target.DisplayName
	end,
	home = function(player)
		PlotService.moveCharacter(player, PlotService.spawnCFrame(player))
		return true, "Welcome home"
	end,
	leaderboards = function(player)
		Session.notify(player, "leaderboards", LeaderboardService.snapshot())
		return true, "ok"
	end,
}

-- actions that change nothing and need no state sync
local READONLY = { leaderboards = true, visit = true, home = true, buyPass = true, buyProduct = true }

function Router.init(remotes: { [string]: any })
	remotes.Request.OnServerInvoke = function(player: Player, action: any, args: any): Result
		if type(action) ~= "string" then
			return { ok = false, msg = "Bad request" }
		end
		local handler = actions[action]
		if not handler then
			return { ok = false, msg = "Unknown action" }
		end
		if type(args) ~= "table" then
			args = {}
		end
		if not takeToken(player, Config.ActionCost[action] or 1) then
			return { ok = false, msg = "Slow down!" }
		end
		local p = DataService.get(player)
		if not p then
			return { ok = false, msg = "Still loading your data" }
		end
		local ctx = Session.ctx(player)
		local ok, success, msg, data = pcall(handler, player, p, args, ctx)
		if not ok then
			warn(string.format("[Router] %s by %s errored: %s", action, player.Name, tostring(success)))
			return { ok = false, msg = "Server error" }
		end
		if not READONLY[action] then
			Engine.checkAchievements(p, ctx)
			Session.dirty(player)
		end
		return { ok = success, msg = msg, data = data }
	end
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

--- Plot prompts (walk-up Build / Upgrade) go through the same Engine validation.
function Router.onPrompt(player: Player, machineId: string)
	if not takeToken(player, 1) then return end
	local p = DataService.get(player)
	if not p then return end
	local ctx = Session.ctx(player)
	if p.machines[machineId] then
		Engine.upgradeMachine(p, machineId, 1, ctx)
	else
		local ok, msg = Engine.buyMachine(p, machineId, ctx)
		if not ok then Session.notify(player, "toast", { text = msg, kind = "bad" }) end
	end
	Engine.checkAchievements(p, ctx)
	Session.dirty(player)
end

return Router
