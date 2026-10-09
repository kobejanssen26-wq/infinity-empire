--!nonstrict
-- Per-player runtime glue: engine context, state replication (batched), notifications and announcements.

local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")

local Shared = require(script.Parent.Parent.Logic.Shared)
local Engine = require(script.Parent.Parent.Logic.Engine)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local Creatures, Config, Format = Shared.Creatures, Shared.Config, Shared.Format

local Session = {}

local remotes: { [string]: any }
local dirtyPlayers: { [Player]: boolean } = {}
local TOPIC = "EclipseDiscoveries"

function Session.init(r: { [string]: any })
	remotes = r
	-- cross-server discovery announcements (best effort; disabled silently when MessagingService is unavailable)
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(msg)
				local d = msg.Data
				if type(d) == "table" and d.job ~= game.JobId and type(d.text) == "string" then
					remotes.Announce:FireAllClients({ text = d.text, kind = "global" })
				end
			end)
		end)
		if not ok and not RunService:IsStudio() then
			warn("[Session] MessagingService subscribe failed: " .. tostring(err))
		end
	end)
end

function Session.announceServer(text: string, kind: string?)
	remotes.Announce:FireAllClients({ text = text, kind = kind or "server" })
end

function Session.announceGlobal(text: string)
	Session.announceServer(text, "global")
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(TOPIC, { job = game.JobId, text = text })
		end)
	end)
end

function Session.notify(player: Player, kind: string, data: any)
	remotes.Notify:FireClient(player, kind, data)
end

--- Builds the Engine context for a player. notify() routes engine events to the client / server.
function Session.ctx(player: Player): any
	return {
		now = os.time(),
		rng = Random.new(),
		notify = function(kind: string, data: any)
			if kind == "announce" then
				local def = Creatures.byId[data.sp]
				local mut = Creatures.mutations[Creatures.mutationIndex[data.mut]]
				local label = (if data.mut ~= "normal" then mut.name .. " " else "") .. def.name
				Session.announceGlobal(string.format("%s discovered a %s %s!", player.DisplayName, Config.Rarities[def.rarity].id, label))
			else
				Session.notify(player, kind, data)
			end
		end,
	}
end

function Session.dirty(player: Player)
	dirtyPlayers[player] = true
end

function Session.snapshot(player: Player, p: any): any
	local ctx = Session.ctx(player)
	Engine.refreshDaily(p, ctx.now)
	local snap = DataService.serialize(p)
	Engine.stats(p, ctx.now)
	snap.preview = Engine.rebirthPreview(p, ctx)
	local ev = p._event
	snap.event = if ev then { id = ev.id, name = ev.name, desc = ev.desc, effects = ev.effects, endsAt = ev.endsAt } else nil
	snap.serverTime = ctx.now
	snap.receipts = nil -- internal bookkeeping, not for clients
	return snap
end

function Session.sync(player: Player)
	local p = DataService.get(player)
	if not p then
		return
	end
	dirtyPlayers[player] = nil
	remotes.Sync:FireClient(player, Session.snapshot(player, p))
	PlotService.update(player, p, Engine.stats(p, os.time()))
end

--- Flushes pending syncs; called ~10x/s so bursts of actions coalesce into one packet.
function Session.flush()
	for player in pairs(dirtyPlayers) do
		if player.Parent then
			Session.sync(player)
		else
			dirtyPlayers[player] = nil
		end
	end
end

function Session.forget(player: Player)
	dirtyPlayers[player] = nil
end

--- leaderstats for the default Roblox player list.
function Session.updateLeaderstats(player: Player, p: any)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local c = Instance.new("StringValue")
		c.Name = "Cash"
		c.Parent = ls
		local r = Instance.new("IntValue")
		r.Name = "Rebirths"
		r.Parent = ls
		ls.Parent = player
	end
	local c = (ls :: Instance):FindFirstChild("Cash") :: StringValue
	local r = (ls :: Instance):FindFirstChild("Rebirths") :: IntValue
	local txt = Format.number(p.cash)
	if c.Value ~= txt then c.Value = txt end
	if r.Value ~= p.rebirths then r.Value = p.rebirths end
end

return Session
