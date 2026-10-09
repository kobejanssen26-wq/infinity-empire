--!nonstrict
-- ECLIPSE: INFINITE EMPIRE - server bootstrap and main loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Config = require(Shared:WaitForChild("Config"))
local Quests = require(Shared:WaitForChild("Quests"))

local Services = script.Parent:WaitForChild("Services")
local Engine = require(script.Parent:WaitForChild("Logic"):WaitForChild("Engine"))
local DataService = require(Services:WaitForChild("DataService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local Session = require(Services:WaitForChild("Session"))
local Router = require(Services:WaitForChild("Router"))
local PurchaseService = require(Services:WaitForChild("PurchaseService"))
local LeaderboardService = require(Services:WaitForChild("LeaderboardService"))

local remotes = Remotes.get()
Session.init(remotes)
PlotService.init()
PlotService.setPromptHandler(Router.onPrompt)
Router.init(remotes)
DataService.start()
PurchaseService.start()

local lastTick: { [Player]: number } = {}
local loading: { [Player]: boolean } = {}

local function placeCharacter(player: Player)
	local cf = PlotService.spawnCFrame(player)
	local char = player.Character
	if cf and char then
		char:WaitForChild("HumanoidRootPart", 10)
		char:PivotTo(cf)
	end
end

local function onPlayerAdded(player: Player)
	if loading[player] then
		return
	end
	loading[player] = true
	PlotService.assign(player)
	player.CharacterAdded:Connect(function()
		task.defer(placeCharacter, player)
	end)

	local p, err = DataService.load(player)
	if not p then
		if player.Parent then
			player:Kick("We couldn't load your save safely (" .. tostring(err) .. "). Please rejoin in a minute - your progress is protected.")
		end
		loading[player] = nil
		return
	end
	if player.Parent == nil then
		DataService.release(player)
		return
	end

	local ctx = Session.ctx(player)
	Engine.refreshDaily(p, ctx.now)
	PurchaseService.refreshOwnership(player, p)
	local off = Engine.applyOffline(p, ctx)
	lastTick[player] = os.clock()
	Engine.checkAchievements(p, ctx)
	Session.sync(player)
	Session.updateLeaderstats(player, p)
	if off then
		Session.notify(player, "offline", off)
	end
	if player.Character then
		task.defer(placeCharacter, player)
	end
	loading[player] = nil
end

local function onPlayerRemoving(player: Player)
	local p = DataService.get(player)
	if p then
		LeaderboardService.forget(player)
		LeaderboardService.write(player, p)
	end
	DataService.release(player)
	PlotService.release(player)
	Session.forget(player)
	lastTick[player] = nil
	loading[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, plr)
end

-- Main production loop: ONE heartbeat accumulator for all players (no per-player/per-machine loops).
local accum = 0
local flushAccum = 0
local autoAccum = 0
local lastEventId = ""
RunService.Heartbeat:Connect(function(dt)
	accum += dt
	flushAccum += dt
	if flushAccum >= 0.1 then
		flushAccum = 0
		Session.flush()
	end
	if accum < Config.TickSeconds then
		return
	end
	local step = accum
	accum = 0
	autoAccum += 1
	local autoStep = autoAccum % 2 == 0

	for player, p in pairs(DataService.all()) do
		local ctx = Session.ctx(player)
		local elapsed = math.min(os.clock() - (lastTick[player] or os.clock()), 10)
		lastTick[player] = os.clock()
		Engine.tick(p, math.max(elapsed, step), ctx)
		if autoStep and Engine.autoUpgradeStep(p, ctx) then
			Session.dirty(player)
		end
		if autoAccum % 5 == 0 then
			if #Engine.checkAchievements(p, ctx) > 0 then
				Session.dirty(player)
			end
			Session.updateLeaderstats(player, p)
		end
		remotes.Tick:FireClient(player, { cash = p.cash, biomass = p.biomass, cores = p.cores, echoes = p.echoes, runCash = p.runCash })
	end

	-- live-event transitions
	if autoAccum % 10 == 0 then
		local ev = Quests.activeEvent(os.time())
		local id = if ev then ev.id else ""
		if id ~= lastEventId then
			lastEventId = id
			if ev then
				Session.announceServer("EVENT: " .. ev.name .. " - " .. ev.desc, "event")
			end
			for player in pairs(DataService.all()) do
				Session.dirty(player)
			end
		end
	end
end)

-- Leaderboards: write own scores / refresh the cached top lists on a slow timer.
task.spawn(function()
	LeaderboardService.refresh()
	while true do
		task.wait(Config.LeaderboardReadSeconds)
		for player, p in pairs(DataService.all()) do
			LeaderboardService.write(player, p)
		end
		LeaderboardService.refresh()
	end
end)
