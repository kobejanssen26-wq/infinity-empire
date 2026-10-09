--!nonstrict
-- Integration run: boots the REAL server + client scripts on the mocked runtime and plays through the game.
local M = require("./mock_roblox")
local bundle = require("./bundle")

local passed, failed = 0, 0
local function check(cond, name)
	if cond then passed += 1 else failed += 1 print("FAIL: " .. name) end
end
local function section(n) print("== " .. n) end

M.boot(bundle)
local Players = M.service("Players")
local RS = M.service("ReplicatedStorage")

-- 1. boot server
M.isServer = true
M.run(M.serverMain)
local remotes = RS:WaitForChild("Remotes")
check(remotes:FindFirstChild("Request") ~= nil, "remotes created")

local SS = M.serverMain.Parent
local DataService = M.requireModule(SS:WaitForChild("Services"):WaitForChild("DataService"))
local Engine = M.requireModule(SS:WaitForChild("Logic"):WaitForChild("Engine"))

-- 2. player 1 joins (with client attached)
local p1 = M.newPlayer(1001, "Alice")
rawset(Players, "LocalPlayer", p1)
M.localPlayer = p1
M.clientAttached = true
M.isServer = false
M.run(M.clientMain)
M.dsFailures = 2 -- first two DataStore calls fail: load must retry
Players.PlayerAdded:Fire(p1)
M.advance(10)

section("join & load")
local prof = DataService.get(p1)
check(prof ~= nil, "profile loaded after DataStore retries")
check(M.service("Workspace"):FindFirstChild("Plots") ~= nil, "plots folder exists")
local plot = M.service("Workspace").Plots:FindFirstChild("Plot_1001")
check(plot ~= nil, "plot created for player")
check(plot and plot:FindFirstChild("M_forge") ~= nil, "starter forge model built")
check(plot and plot:FindFirstChild("Structure") ~= nil, "plot structure built")
check(p1:FindFirstChild("leaderstats") ~= nil, "leaderstats created")

local PG = p1:WaitForChild("PlayerGui")
local function button(text)
	return M.find(PG, function(n) return rawget(n, "ClassName") == "TextButton" and rawget(n, "Text") == text end)
end
local function buttonMatch(pat)
	return M.find(PG, function(n) return rawget(n, "ClassName") == "TextButton" and type(rawget(n, "Text")) == "string" and rawget(n, "Text"):find(pat) ~= nil end)
end
local function click(b)
	assert(b, "button not found")
	if b:GetAttribute("Disabled") then return false end
	b.Activated:Fire()
	return true
end
local function settle(t) M.advance(t or 1.2) end
local function poke(plr) remotes.Request.OnServerInvoke(plr, "setSetting", { key = "notifications", value = true }) end

section("UI pages render")
for _, title in ipairs({ "Factory", "Creatures", "Eggs", "Research", "Rebirth", "Quests", "Index", "Ranks", "Settings" }) do
	local nav = button(title)
	check(nav ~= nil, "nav button " .. title)
	if nav then
		click(nav) settle(0.5)
		local panel = M.find(PG, function(n) return rawget(n, "Name") == "Panel" end)
		check(panel and panel.Visible == true, title .. " opens panel")
		local content = panel and M.find(panel, function(n) return rawget(n, "Name") == "Scroll" end)
		check(content ~= nil, title .. " rendered a scroll body")
	end
end
local renderFails = 0
for _, l in ipairs(M.logs) do if l:find("page render failed") then renderFails += 1 print("  " .. l) end end
check(renderFails == 0, "no page render errors")

section("gameplay via UI")
local before = prof.cash
settle(5)
check(prof.cash > before, "cash grows over time (server tick)")
prof.cash = 1e6
settle(1.5) -- let the 1 Hz Tick carry the new balance to the client
click(button("Factory")) click(button("Factory")) -- toggle closed/open
settle(0.3)
local up = buttonMatch("^Upgrade x1")
check(up ~= nil, "factory shows upgrade button")
local lvl0 = prof.machines.forge.level
if up then click(up) end
settle(0.3)
check(prof.machines.forge.level == lvl0 + 1, "UI upgrade increased forge level on server")
local build = buttonMatch("^Build")
check(build ~= nil and click(build), "build press via UI")
settle(0.3)
check(prof.machines.press ~= nil, "press built")

-- eggs
click(button("Eggs")) settle(0.5)
local hatch = buttonMatch("^Hatch")
check(hatch ~= nil and click(hatch), "hatch via UI")
settle(0.3)
check(prof.stats.hatched == 1, "egg hatched")

-- 3. raw remote hardening
section("remote hardening")
local R = remotes.Request
local function call(action, args) return R.OnServerInvoke(p1, action, args) end
check(call(123, {}).ok == false, "non-string action rejected")
check(call("giveCash", { amount = 1e9 }).ok == false, "unknown action rejected")
check(call("buyEgg", { id = {} }).ok == false, "table arg rejected")
check(call("buyMachine", "str").ok == false, "non-table args tolerated")
check(call("assign", { uid = "c1", machine = 5 }).ok == false, "bad machine type rejected")
check(call("fuse", { recipe = "f_magmaroo", uids = { 1, 2, 3 } }).ok == false, "bad fuse uids rejected")
check(call("visit", { userId = 0 / 0 }).ok == false, "NaN userId rejected")
check(call("rebirth", { confirm = false }).ok == false, "rebirth needs confirm")
check(call("rebirth", { confirm = true }).ok == false, "rebirth blocked when requirements unmet")
local cash = prof.cash
call("setSetting", { key = "cash", value = true })
check(prof.cash == cash, "cannot set arbitrary profile fields")
check(call("buyPass", { key = "invPlus" }).ok == false, "unconfigured pass refuses")
local limited = false
for i = 1, 200 do
	if call("leaderboards", {}).msg == "Slow down!" then limited = true break end
end
check(limited, "rate limiter engages on spam")
M.advance(2)

section("persistence")
prof.cash = 12345
prof.research.ind1 = true
Engine.invalidate(prof)
local discovered = 0
for _ in pairs(prof.discovered) do discovered += 1 end
Players.PlayerRemoving:Fire(p1)
p1.Parent = nil
M.advance(2)
check(DataService.get(p1) == nil, "profile dropped on leave")
local store = M.stores["EclipseEmpire_Profiles_v1"]
local saved = store["P_1001"]
check(saved and saved.data and saved.data.cash == 12345, "cash saved")
check(saved and saved.lock == nil, "session lock released on leave")
check(saved and saved.data._stats == nil, "runtime keys not persisted")
check(M.service("Workspace").Plots:FindFirstChild("Plot_1001") == nil, "plot cleaned up")

local p1b = M.newPlayer(1001, "Alice")
M.localPlayer = p1b
Players.PlayerAdded:Fire(p1b)
M.advance(3)
local prof2 = DataService.get(p1b)
check(prof2 and prof2.research.ind1 == true and prof2.machines.press ~= nil, "state restored on rejoin")
local d2 = 0
for _ in pairs(prof2.discovered) do d2 += 1 end
check(d2 == discovered, "collection restored")

section("session lock")
store["P_2002"] = { data = Engine.newProfile(os.time()), lock = { job = "other-server", t = os.time() } }
local p2 = M.newPlayer(2002, "Bob")
local kicked = false
rawset(p2, "Kick", function() kicked = true end)
Players.PlayerAdded:Fire(p2)
M.advance(400)
check(DataService.get(p2) == nil, "locked profile is not loaded by a second server")
check(kicked, "player kicked when profile locked elsewhere")

section("multiple players")
local p3 = M.newPlayer(3003, "Carol")
local p4 = M.newPlayer(4004, "Dan")
Players.PlayerAdded:Fire(p3)
Players.PlayerAdded:Fire(p4)
M.advance(3)
check(DataService.get(p3) and DataService.get(p4), "two more players loaded")
local plots = M.service("Workspace").Plots
check(plots:FindFirstChild("Plot_3003") and plots:FindFirstChild("Plot_4004") and plots:FindFirstChild("Plot_1001"), "separate plots per player")
DataService.get(p3).cash = 5e6
check(R.OnServerInvoke(p3, "upgradeMachine", { id = "forge", count = 5 }).ok, "player 3 upgrades")
check(DataService.get(p4).machines.forge.level == 1, "player 4 unaffected by player 3")
check(R.OnServerInvoke(p4, "visit", { userId = 3003 }).ok, "visit another factory")
check(not R.OnServerInvoke(p4, "visit", { userId = 99999 }).ok, "visit unknown player fails")

section("full loop through the UI")
local pr = prof2
pr.zone = 3
pr.runCash = 6e7
pr.cash = 5e6
pr.biomass = 500
pr.cores = 5000
for _ = 1, 3 do Engine._addCreature(pr, "cindermite", "normal", "none", { now = os.time(), rng = { NextNumber = function() return 0.5 end, NextInteger = function(_, a) return a end } }, true) end
Engine.invalidate(pr)
poke(p1b)
settle(1.5)

-- research
click(button("Research")) settle(0.5)
local rbtn = M.find(PG, function(n) return rawget(n, "ClassName") == "TextButton" and (rawget(n, "Text") or ""):find("Cores$") and not n:GetAttribute("Disabled") end)
check(rbtn ~= nil, "an affordable research node is clickable")
local rs0 = pr.stats.researchBought
if rbtn then click(rbtn) end
settle(0.5)
check(pr.stats.researchBought == rs0 + 1, "research purchased through UI")

-- fusion
click(button("Eggs")) settle(0.3)
click(button("Fusion Lab")) settle(0.5)
local fuseBtn = M.find(PG, function(n) return rawget(n, "ClassName") == "TextButton" and (rawget(n, "Text") or ""):find("^Fuse") and not n:GetAttribute("Disabled") end)
check(fuseBtn ~= nil, "fuse button enabled with 3 cindermite")
local f0 = pr.stats.fused
if fuseBtn then click(fuseBtn) end
settle(0.5)
check(pr.stats.fused == f0 + 1, "fusion performed through UI")

-- tutorial claim via tracker
pr.stats.machineUpgrades = 5
pr.tutorial = 1
poke(p1b)
settle(1.5)
local claim = M.find(PG, function(n) return rawget(n, "ClassName") == "TextButton" and rawget(n, "Text") == "Claim" and not n:GetAttribute("Disabled") end)
check(claim ~= nil, "tutorial claim enabled when objective complete")
local c0 = pr.cash
if claim then click(claim) end
settle(0.5)
check(pr.tutorial == 2, "tutorial advanced via UI claim")

-- rebirth with confirmation modal
pr.runCash = 6e7 pr.zone = 3
poke(p1b)
settle(1.5)
click(button("Rebirth")) settle(0.5)
local rb = M.find(PG, function(n) return rawget(n, "ClassName") == "TextButton" and rawget(n, "Text") == "Rebirth..." end)
check(rb ~= nil and not rb:GetAttribute("Disabled"), "rebirth button enabled when requirements met")
local echoes0 = pr.echoes
if rb then click(rb) end
settle(0.3)
check(pr.rebirths == 0, "opening the dialog does not rebirth")
local modalYes = button("Rebirth now")
check(modalYes ~= nil, "confirmation modal shows")
if modalYes then click(modalYes) end
settle(0.5)
check(pr.rebirths == 1 and pr.echoes > echoes0 and pr.zone == 1, "rebirth executed after confirmation")
check(pr.research.ind1 or pr.stats.researchBought >= 1, "research survives rebirth")

local renderFails2 = 0
for _, l in ipairs(M.logs) do if l:find("page render failed") then renderFails2 += 1 print("  " .. l) end end
check(renderFails2 == 0, "no page render errors during full loop")

section("runtime errors")
for _, e in ipairs(M.errors) do print("  ERROR " .. e) end
check(#M.errors == 0, "no runtime errors in any task")
for _, l in ipairs(M.logs) do
	if not l:find("Studio") and not l:find("save attempt") and not l:find("DataStore") then print("  warn: " .. l) end
end

print(string.format("\nmock run: %d passed, %d failed", passed, failed))
if failed > 0 then error("mock run failed") end
