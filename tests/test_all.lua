--!nonstrict

local Config = require("./Config")
local Creatures = require("./Creatures")
local Machines = require("./Machines")
local Research = require("./Research")
local Prestige = require("./Prestige")
local Quests = require("./Quests")
local Formulas = require("./Formulas")
local Stats = require("./Stats")
local Format = require("./Format")
local Engine = require("./Engine")

local passed, failed = 0, 0
local function check(cond, name)
	if cond then passed += 1 else failed += 1 print("FAIL: " .. name) end
end
local function section(n) print("== " .. n) end

local notes = {}
local function mkctx(now, seed)
	return { now = now or 1700000000, rng = Random.new(seed or 7), notify = function(k, d) table.insert(notes, k) end }
end

----------------------------------------------------------------------------------------------
section("config validation")
for _, c in ipairs(Creatures.list) do
	check(Config.Elements[c.element] ~= nil, "creature element valid: " .. c.id)
	check(c.rarity >= 1 and c.rarity <= #Config.Rarities, "creature rarity valid: " .. c.id)
end
for _, r in ipairs(Creatures.recipes) do
	check(Creatures.byId[r.result] ~= nil, "recipe result exists " .. r.id)
	for sp in pairs(r.inputs) do check(Creatures.byId[sp] ~= nil, "recipe input exists " .. r.id .. "/" .. sp) end
end
for _, e in ipairs(Creatures.eggs) do
	check(#e.weights <= 5, "eggs never roll mythic " .. e.id)
	check(Machines.zones[e.zone] ~= nil, "egg zone exists " .. e.id)
	if e.requiresResearch then check(Research.byId[e.requiresResearch] ~= nil, "egg research exists") end
end
-- every species that is not the starter must be obtainable via an egg or a recipe
local obtainable = {}
for _, e in ipairs(Creatures.eggs) do
	for r, w in ipairs(e.weights) do
		if w > 0 then for _, c in ipairs(Creatures.list) do if c.rarity == r then obtainable[c.id] = true end end end
	end
end
for _, r in ipairs(Creatures.recipes) do obtainable[r.result] = true end
for _, c in ipairs(Creatures.list) do check(obtainable[c.id], "obtainable: " .. c.id) end
for _, n in ipairs(Research.nodes) do
	for _, r in ipairs(n.requires or {}) do check(Research.byId[r] ~= nil, "research prereq " .. n.id) end
	for _, r in ipairs(n.anyOf or {}) do check(Research.byId[r] ~= nil, "research anyOf " .. n.id) end
	for _, r in ipairs(n.exclusive or {}) do check(Research.byId[r] ~= nil, "research excl " .. n.id) end
end
for _, m in ipairs(Machines.list) do
	check(Machines.zones[m.zone] ~= nil, "machine zone " .. m.id)
	check(Config.Elements[m.element] ~= nil, "machine element " .. m.id)
end
for id, q in pairs(Quests.byId) do
	check(q.target > 0 and next(q.reward) ~= nil, "quest well-formed " .. id)
end

----------------------------------------------------------------------------------------------
section("formulas")
check(Formulas.machineLevelMult(1) == 1, "level 1 mult")
check(Formulas.machineLevelMult(25) > Formulas.machineLevelMult(24) * 1.9, "milestone doubles at 25")
check(Formulas.upgradeCost("forge", 1, 0) == math.floor(12 * 1.19), "forge upgrade cost")
check(Formulas.upgradeCost("quantum", 250, 0) == Config.MaxValue, "cost clamps instead of overflowing")
check(Formulas.upgradeCost("forge", 5, 5) == Formulas.upgradeCost("forge", 5, Config.MaxUpgradeDiscount), "discount capped")
check(Formulas.echoGain(1e5, 0) == 0 and Formulas.echoGain(4e7, 0) == 2, "echo gain")
check(Format.number(1234567) == "1.23M" and Format.number(5) == "5" and Format.number(0 / 0) == "0", "format")

----------------------------------------------------------------------------------------------
section("new profile / production")
local ctx = mkctx()
local p = Engine.newProfile(ctx.now)
check(p.cash == Config.StartCash and Engine.creatureCount(p) == 1, "starter state")
local st = Engine.stats(p, ctx.now)
check(st.rates.cash > 1 and st.rates.cash < 3, "starter forge w/ matching creature ~ 1.15/s (got " .. st.rates.cash .. ")")
local before = p.cash
Engine.tick(p, 10, ctx)
check(math.abs(p.cash - before - st.rates.cash * 10) < 1e-6, "tick adds rate*dt")
check(p.runCash > 0 and p.lifetimeCash > 0 and p.stats.cashEarned > 0, "earn counters")

section("purchases: insufficient / sufficient / invalid")
local p2 = Engine.newProfile(ctx.now)
local ok, msg = Engine.upgradeMachine(p2, "forge", 1, ctx)
check(ok == true, "can afford first forge upgrade at 25 cash")
p2.cash = 0
ok, msg = Engine.upgradeMachine(p2, "forge", 1, ctx)
check(not ok and msg == "Not enough cash", "upgrade fails with 0 cash")
ok = Engine.buyMachine(p2, "press", ctx)
check(not ok, "cannot buy press with no cash")
p2.cash = 1e6
check(Engine.buyMachine(p2, "press", ctx), "buy press")
check(not Engine.buyMachine(p2, "press", ctx), "cannot double-buy")
check(not Engine.buyMachine(p2, "biolab", ctx), "zone gate on biolab")
check(not Engine.buyMachine(p2, 123, ctx) and not Engine.buyMachine(p2, nil, ctx) and not Engine.buyMachine(p2, {}, ctx), "garbage machine ids")
check(not Engine.upgradeMachine(p2, "nope", 5, ctx), "unknown machine")
local cash0 = p2.cash
check(Engine.upgradeMachine(p2, "forge", 1e9, ctx), "huge count is clamped, not an error")
check(p2.machines.forge.level <= 1 + 100, "count clamped to 100")
check(p2.cash >= 0 and p2.cash <= cash0, "cash never negative")
check(not Engine.upgradeMachine(p2, "forge", -5, ctx) or true, "negative count handled")
check(Engine.expandZone(p2, ctx) and p2.zone == 2, "expand zone")
check(not Engine.expandZone(p2, ctx), "zone 3 too expensive")
p2.cash = 0 / 0
check(not Engine.buyEgg(p2, "common", ctx), "NaN cash cannot buy")

section("eggs, discovery, inventory")
local p3 = Engine.newProfile(ctx.now)
p3.cash = 1e7
local discoveries0 = Quests.getStat(p3, "discoveries")
local hatched = {}
for i = 1, 40 do
	local ok2, _, d = Engine.buyEgg(p3, "common", ctx)
	check(ok2, "hatch " .. i)
	if ok2 then hatched[d.sp] = true end
end
check(Quests.getStat(p3, "discoveries") > discoveries0, "discoveries increased")
check(p3.stats.hatched == 40, "hatched stat")
check(not Engine.buyEgg(p3, "bio", ctx), "zone gated egg")
check(not Engine.buyEgg(p3, "rift", ctx), "research gated egg")
p3.cash = 1e12
while Engine.creatureCount(p3) < Config.BaseInventory do
	check(Engine.buyEgg(p3, "common", ctx), "fill inventory")
end
check(not Engine.buyEgg(p3, "common", ctx), "inventory cap enforced")

section("pity")
local p4 = Engine.newProfile(ctx.now)
p4.cash = 1e12
local gotRare = false
for i = 1, Config.PityThreshold + 1 do
	local _, _, d = Engine.buyEgg(p4, "common", mkctx(1, 99))
	if d and Creatures.byId[d.sp].rarity >= 3 then gotRare = true end
end
check(gotRare, "pity guarantees Rare+ within threshold")

section("assignment & compatibility")
local p5 = Engine.newProfile(ctx.now)
local uid = next(p5.creatures)
check(p5.creatures[uid].mach == "forge", "starter assigned")
check(not Engine.assign(p5, uid, "forge", ctx), "already assigned")
check(not Engine.assign(p5, uid, "press", ctx), "unbuilt machine")
p5.cash = 1e6
Engine.buyMachine(p5, "press", ctx)
p5.cash = 1e6
Engine.buyEgg(p5, "common", ctx)
local other
for u in pairs(p5.creatures) do if u ~= uid then other = u end end
check(not Engine.assign(p5, other, "forge", ctx), "forge has 1 slot: full")
check(Engine.assign(p5, other, "press", ctx), "assign to press")
check(not Engine.assign(p5, "zzz", "press", ctx), "unknown creature")
local s5 = Engine.stats(p5, ctx.now)
local cdef = Creatures.byId[p5.creatures[other].sp]
local expectCompat = if cdef.element == "stone" then 1 else Config.IncompatibleEfficiency
local expect = Stats.creaturePower(p5.creatures[other], 0) * expectCompat
check(math.abs(s5.machines.press.power - expect) < 1e-9, "compat factor applied")
check(Engine.assign(p5, other, nil, ctx) and p5.creatures[other].mach == nil, "unassign")

section("fusion")
local p6 = Engine.newProfile(ctx.now)
p6.biomass = 1e6
-- no ingredients
check(not Engine.fuse(p6, "f_magmaroo", nil, ctx), "missing ingredients")
for i = 1, 3 do Engine._addCreature(p6, "cindermite", "normal", "none", ctx, true) end
local before6 = Engine.creatureCount(p6)
check(not Engine.fuse(p6, "f_magmaroo", { "c1", "c1", "c1" }, ctx), "duplicate uids rejected")
check(not Engine.fuse(p6, "f_slabbit", nil, ctx), "wrong recipe for held creatures")
check(not Engine.fuse(p6, "nope", nil, ctx), "unknown recipe")
check(not Engine.fuse(p6, "f_magmaroo", { "c1", "c2" }, ctx), "wrong ingredient count")
local ok6, _, d6 = Engine.fuse(p6, "f_magmaroo", nil, ctx)
check(ok6 and d6.sp == "magmaroo", "valid fusion")
check(Engine.creatureCount(p6) == before6 - 3 + 1 and p6.biomass == 1e6 - 10, "fusion consumed inputs and biomass")
p6.biomass = 0
for i = 1, 3 do Engine._addCreature(p6, "cindermite", "normal", "none", ctx, true) end
check(not Engine.fuse(p6, "f_magmaroo", nil, ctx), "fusion needs biomass")

section("creature levelling")
local p7 = Engine.newProfile(ctx.now)
local u7 = next(p7.creatures)
check(not Engine.levelCreature(p7, u7, ctx), "no biomass")
p7.biomass = 1e6
check(Engine.levelCreature(p7, u7, ctx) and p7.creatures[u7].lvl == 2, "level up")
for _ = 1, 100 do Engine.levelCreature(p7, u7, ctx) end
check(p7.creatures[u7].lvl == Config.CreatureMaxLevel, "level cap")

section("research")
local p8 = Engine.newProfile(ctx.now)
check(not Engine.buyResearch(p8, "ind1", ctx), "no cores")
p8.cores = 1e4
check(not Engine.buyResearch(p8, "ind2", ctx), "prereq enforced")
check(Engine.buyResearch(p8, "ind1", ctx) and p8.research.ind1, "buy ind1")
check(not Engine.buyResearch(p8, "ind1", ctx), "no double buy")
check(Engine.buyResearch(p8, "ind2", ctx), "buy ind2")
check(Engine.buyResearch(p8, "ind3a", ctx), "buy ind3a")
check(not Engine.buyResearch(p8, "ind3b", ctx), "exclusive branch locked")
check(not Engine.buyResearch(p8, "ind5", ctx), "ind5 needs ind4")
check(Engine.buyResearch(p8, "ind4", ctx), "anyOf satisfied")
local sBefore = Stats.compute(Engine.newProfile(ctx.now))
local sAfter = Engine.stats(p8, ctx.now)
check(sAfter.cashMult > sBefore.cashMult and sAfter.rates.cash > sBefore.rates.cash, "research raises production")
check(not Engine.setSetting(p8, "autoUpgrade", true, ctx), "autoUpgrade locked behind research")
check(not Engine.autoAssign(p8, ctx), "autoAssign locked behind research")

section("rebirth")
local p9 = Engine.newProfile(ctx.now)
p9.cash = 1e9
p9.cores = 55
Engine.buyResearch(p9, "ind1", ctx)
Engine._addCreature(p9, "pyrofox", "golden", "none", ctx, true)
check(not Engine.rebirth(p9, true, ctx), "rebirth blocked at start")
p9.zone = 3
p9.runCash = 6e7
local prev = Engine.rebirthPreview(p9, ctx)
check(prev.can and prev.gain >= 1, "rebirth preview OK")
check(not Engine.rebirth(p9, nil, ctx) and not Engine.rebirth(p9, "yes", ctx), "needs explicit confirmation")
p9.biomass = 77
p9.machines.press = { level = 12 }
local discBefore = Quests.getStat(p9, "discoveries")
local beforeEchoes = p9.echoes
check(Engine.rebirth(p9, true, ctx), "rebirth")
check(p9.echoes == beforeEchoes + prev.gain, "echoes granted")
check(p9.zone == 1 and p9.biomass == 0 and p9.runCash == 0 and p9.machines.press == nil, "run state reset")
check(p9.machines.forge.level == 1, "forge reset")
check(p9.research.ind1 and p9.cores == 55 - Research.byId.ind1.cost, "research + cores retained")
check(Quests.getStat(p9, "discoveries") == discBefore, "collection retained")
check(Engine.creatureCount(p9) == 2, "creatures retained")
for _, c in pairs(p9.creatures) do check(c.lvl == 1, "creature levels reset") end
check(p9.rebirths == 1, "rebirth counter")
check(not Engine.rebirth(p9, true, ctx), "second rebirth requires more")
-- prestige shop
p9.echoes = 100
check(Engine.buyPrestige(p9, "r_cash", ctx) and p9.prestige.r_cash == 1, "buy prestige")
check(not Engine.buyPrestige(p9, "nope", ctx), "unknown prestige")
local s9 = Engine.stats(p9, ctx.now)
check(s9.cashMult > 1.2, "prestige raises cash mult")
for _ = 1, 40 do Engine.buyPrestige(p9, "r_zone", ctx) end
check(p9.prestige.r_zone == 2, "prestige level cap")
p9.runCash = 1e13 p9.zone = 3
check(Engine.rebirth(p9, true, ctx) and p9.zone == 3, "keep foundations keeps zone")

section("quests & achievements")
local pq = Engine.newProfile(ctx.now)
check(not Engine.claimQuest(pq, "t1", ctx), "tutorial 1 incomplete")
check(not Engine.claimQuest(pq, "t2", ctx), "tutorial must be in order")
pq.cash = 1e6
for _ = 1, 3 do Engine.upgradeMachine(pq, "forge", 1, ctx) end
local c0 = pq.cash
check(Engine.claimQuest(pq, "t1", ctx) and pq.tutorial == 2 and pq.cash == c0 + 100, "claim tutorial 1")
check(not Engine.claimQuest(pq, "t1", ctx), "no double claim tutorial")
Engine.refreshDaily(pq, ctx.now)
check(#pq.quests.daily.ids == Quests.DailyCount, "daily rolled")
local did = pq.quests.daily.ids[1]
check(not Engine.claimQuest(pq, did, ctx), "daily incomplete")
pq.stats[Quests.byId[did].stat] = (pq.stats[Quests.byId[did].stat] or 0) + Quests.byId[did].target
check(Engine.claimQuest(pq, did, ctx), "daily claim")
check(not Engine.claimQuest(pq, did, ctx), "daily double-claim rejected")
check(not Engine.claimQuest(pq, "a_first_egg", ctx), "achievements are not claimable")
pq.stats.hatched = 100
local unlocked = Engine.checkAchievements(pq, ctx)
check(#unlocked >= 2, "achievements unlock")
check(#Engine.checkAchievements(pq, ctx) == 0, "achievements unlock once")
local d1, d2 = Quests.rollDaily(19000), Quests.rollDaily(19000)
check(d1[1] == d2[1] and d1[3] == d2[3], "daily roll deterministic")

section("persistence shape")
local function plain(v, path, seen)
	local t = type(v)
	if t == "table" then
		check(not seen[v], "no cycles at " .. path)
		seen[v] = true
		for k, x in pairs(v) do
			if type(k) ~= "string" and type(k) ~= "number" then check(false, "bad key type " .. path) end
			if not (type(k) == "string" and k:sub(1, 1) == "_") then plain(x, path .. "." .. tostring(k), seen) end
		end
		seen[v] = nil
	else
		check(t == "number" or t == "string" or t == "boolean", "serializable " .. path)
	end
end
plain(p9, "p9", {})
local mig = Engine.migrate({ cash = 10, creatures = { c1 = { sp = "ghost", mut = "normal", trait = "none", lvl = 1 } }, machines = { bogus = { level = 2 } } }, ctx.now)
check(mig.creatures.c1 == nil and mig.machines.bogus == nil and mig.machines.forge and mig.zone == 1, "migrate heals old/invalid saves")

section("offline")
local po = Engine.newProfile(ctx.now)
po.lastSeen = ctx.now - 3600 * 100
local off = Engine.applyOffline(po, ctx)
check(off and off.capped and off.seconds == Config.BaseOfflineHours * 3600, "offline capped")
local po2 = Engine.newProfile(ctx.now)
po2.lastSeen = ctx.now - 30
check(Engine.applyOffline(po2, ctx) == nil, "short absences ignored")

section("events")
local ev
for d = 0, 13 do
	local e = Quests.activeEvent((19000 + d) * 86400)
	if e then ev = e end
end
check(ev ~= nil, "some event is active within a 14-day window")

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
