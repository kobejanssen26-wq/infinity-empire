--!nonstrict
-- Pure, Roblox-service-free game rules. Every state change a player can cause goes through here.
-- Functions take the player profile `p` and a ctx = { now: number, rng: Random-like, notify: ((string, any) -> ())? }
-- and return (ok: boolean, message: string, data: any?).
-- Being pure, this module is unit-tested outside Roblox (see tests/).

local S = require(script.Parent.Shared)
local Config, Creatures, Machines, Research, Prestige, Quests, Formulas, Stats =
	S.Config, S.Creatures, S.Machines, S.Research, S.Prestige, S.Quests, S.Formulas, S.Stats

local Engine = {}

export type Ctx = { now: number, rng: any, notify: ((string, any) -> ())? }

local RESOURCES = { cash = true, biomass = true, cores = true, echoes = true }

local function notify(ctx: Ctx, kind: string, data: any)
	if ctx.notify then
		ctx.notify(kind, data)
	end
end

local function fail(msg: string): (boolean, string, any?)
	return false, msg, nil
end

----------------------------------------------------------------------------------------------------
-- Profile lifecycle
----------------------------------------------------------------------------------------------------

function Engine.newProfile(now: number): any
	local p = {
		version = Config.DataVersion,
		cash = Config.StartCash, biomass = 0, cores = 0, echoes = 0, echoesEarned = 0,
		runCash = 0, lifetimeCash = 0,
		zone = 1,
		machines = { forge = { level = 1 } },
		creatures = {},
		nextUid = 1,
		discovered = {},
		research = {},
		prestige = {},
		rebirths = 0,
		stats = {
			hatched = 0, fused = 0, machineUpgrades = 0, machinesBuilt = 1, assignments = 0,
			creatureLevels = 0, researchBought = 0, cashEarned = 0, mythics = 0,
		},
		tutorial = 1,
		quests = { claimed = {}, repeatBase = {}, daily = { day = 0, ids = {}, base = {}, claimed = {} } },
		achievements = {},
		settings = { autoUpgrade = false, notifications = true },
		pity = 0,
		eggsRun = 0,
		lastSeen = now,
		receipts = {},
		owned = {},
		theme = "default",
	}
	-- starter creature (assigned to the starter forge)
	local ctx: Ctx = { now = now, rng = Random.new(1) }
	local uid = Engine._addCreature(p, Creatures.StarterCreature, "normal", "none", ctx, true)
	p.creatures[uid].mach = "forge"
	return p
end

--- Fills any missing fields so old saves keep loading as the schema grows.
function Engine.migrate(p: any, now: number): any
	local fresh = Engine.newProfile(now)
	local function fill(dst: any, src: any)
		for k, v in pairs(src) do
			if dst[k] == nil then
				dst[k] = if type(v) == "table" then table.clone(v) else v
			elseif type(v) == "table" and type(dst[k]) == "table" and k ~= "creatures" and k ~= "discovered" then
				fill(dst[k], v)
			end
		end
	end
	if p.creatures == nil then
		p.creatures = {}
	end
	fill(p, fresh)
	-- drop references to content that no longer exists
	for uid, c in pairs(p.creatures) do
		if not Creatures.byId[c.sp] then
			p.creatures[uid] = nil
		else
			if not Creatures.mutationIndex[c.mut] then c.mut = "normal" end
			if not Creatures.traitById[c.trait] then c.trait = "none" end
			c.lvl = math.clamp(math.floor(c.lvl or 1), 1, Config.CreatureMaxLevel)
			if c.mach and not Machines.byId[c.mach] then c.mach = nil end
		end
	end
	for id in pairs(p.machines) do
		if not Machines.byId[id] then
			p.machines[id] = nil
		end
	end
	if p.machines.forge == nil then
		p.machines.forge = { level = 1 }
	end
	for _, res in ipairs({ "cash", "biomass", "cores", "echoes", "echoesEarned", "runCash", "lifetimeCash" }) do
		local v = p[res]
		if type(v) ~= "number" or v ~= v then
			p[res] = 0
		end
		p[res] = math.clamp(p[res], 0, Config.MaxValue)
	end
	p.version = Config.DataVersion
	return p
end

----------------------------------------------------------------------------------------------------
-- Stats cache
----------------------------------------------------------------------------------------------------

--- Returns cached derived stats, recomputing when invalidated or when the live event changed.
function Engine.stats(p: any, now: number): any
	local ev = Quests.activeEvent(now)
	local evId = if ev then ev.id else ""
	if p._stats == nil or p._statsEvent ~= evId then
		p._stats = Stats.compute(p, ev)
		p._statsEvent = evId
		p._event = ev
	end
	return p._stats
end

function Engine.invalidate(p: any)
	p._stats = nil
end

local function stats(p: any, ctx: Ctx): any
	return Engine.stats(p, ctx.now)
end

----------------------------------------------------------------------------------------------------
-- Resources
----------------------------------------------------------------------------------------------------

function Engine.add(p: any, res: string, amount: number)
	assert(RESOURCES[res], "unknown resource")
	p[res] = math.clamp(p[res] + amount, 0, Config.MaxValue)
end

local function spend(p: any, res: string, amount: number): boolean
	if amount ~= amount or amount < 0 or not (p[res] >= amount) then
		return false
	end
	p[res] -= amount
	return true
end

function Engine.grantReward(p: any, reward: { [string]: number }, ctx: Ctx)
	for res, amt in pairs(reward) do
		if RESOURCES[res] then
			Engine.add(p, res, amt)
			if res == "echoes" then
				p.echoesEarned += amt
			end
		end
	end
	Engine.invalidate(p)
	notify(ctx, "reward", reward)
end

--- Advances production by dt seconds. Returns gains.
function Engine.tick(p: any, dt: number, ctx: Ctx): { [string]: number }
	local st = stats(p, ctx)
	local gains = { cash = st.rates.cash * dt, biomass = st.rates.biomass * dt, cores = st.rates.cores * dt }
	local before = p.cash
	Engine.add(p, "cash", gains.cash)
	Engine.add(p, "biomass", gains.biomass)
	Engine.add(p, "cores", gains.cores)
	local cashGained = p.cash - before
	if cashGained > 0 then
		p.runCash = math.min(Config.MaxValue, p.runCash + gains.cash)
		p.lifetimeCash = math.min(Config.MaxValue, p.lifetimeCash + gains.cash)
		p.stats.cashEarned = math.min(Config.MaxValue, p.stats.cashEarned + gains.cash)
	end
	return gains
end

--- Offline progress on join. Returns summary or nil.
function Engine.applyOffline(p: any, ctx: Ctx): any?
	local st = stats(p, ctx)
	local away = ctx.now - (p.lastSeen or ctx.now)
	local cap = st.offlineHours * 3600
	local sec = math.min(away, cap)
	if sec < 120 then
		return nil
	end
	local eff = Config.OfflineEfficiency
	local gains = Engine.tick(p, sec * eff, ctx)
	return { seconds = sec, gains = gains, capped = away > cap }
end

----------------------------------------------------------------------------------------------------
-- Machines & factory
----------------------------------------------------------------------------------------------------

function Engine.buyMachine(p: any, id: any, ctx: Ctx): (boolean, string, any?)
	local def = if type(id) == "string" then Machines.byId[id] else nil
	if not def then return fail("Unknown machine") end
	if p.machines[def.id] then return fail("Already built") end
	if p.zone < def.zone then return fail("Requires " .. Machines.zones[def.zone].name) end
	if not spend(p, "cash", def.unlockCost) then return fail("Not enough cash") end
	p.machines[def.id] = { level = 1 }
	p.stats.machinesBuilt += 1
	Engine.invalidate(p)
	notify(ctx, "toast", { text = def.name .. " built!", kind = "good" })
	return true, "Built " .. def.name
end

function Engine.upgradeMachine(p: any, id: any, count: any, ctx: Ctx): (boolean, string, any?)
	local m = if type(id) == "string" then p.machines[id] else nil
	if not m then return fail("Machine not built") end
	local n = if type(count) == "number" then math.clamp(math.floor(count), 1, 100) else 1
	if m.level >= Config.MachineMaxLevel then return fail("Max level") end
	local st = stats(p, ctx)
	local total, bought = Formulas.upgradeBulk(id, m.level, st.upgradeDiscount, p.cash, n)
	if bought == 0 then return fail("Not enough cash") end
	if not spend(p, "cash", total) then return fail("Not enough cash") end
	m.level += bought
	p.stats.machineUpgrades += bought
	Engine.invalidate(p)
	return true, string.format("%s +%d", Machines.byId[id].name, bought), { bought = bought }
end

function Engine.expandZone(p: any, ctx: Ctx): (boolean, string, any?)
	local nextZone = p.zone + 1
	local z = Machines.zones[nextZone]
	if not z then return fail("Factory fully expanded") end
	if not spend(p, "cash", z.cost) then return fail("Not enough cash") end
	p.zone = nextZone
	Engine.invalidate(p)
	notify(ctx, "toast", { text = "Unlocked " .. z.name .. "!", kind = "good" })
	return true, "Expanded: " .. z.name
end

--- Cheapest affordable upgrade step, used by the Auto-Upgrader research.
function Engine.autoUpgradeStep(p: any, ctx: Ctx): boolean
	local st = stats(p, ctx)
	if not (p.settings.autoUpgrade and st.flags.autoUpgrade) then return false end
	local bestId, bestCost
	for id, m in pairs(p.machines) do
		if m.level < Config.MachineMaxLevel then
			local c = Formulas.upgradeCost(id, m.level, st.upgradeDiscount)
			if c <= p.cash and (bestCost == nil or c < bestCost) then
				bestId, bestCost = id, c
			end
		end
	end
	if bestId then
		return (Engine.upgradeMachine(p, bestId, 1, ctx))
	end
	return false
end

----------------------------------------------------------------------------------------------------
-- Creatures
----------------------------------------------------------------------------------------------------

local function creatureCount(p: any): number
	local n = 0
	for _ in pairs(p.creatures) do n += 1 end
	return n
end
Engine.creatureCount = creatureCount

local function rollMutation(luck: number, rng: any): string
	for i = #Creatures.mutations, 2, -1 do
		local m = Creatures.mutations[i]
		if rng:NextNumber() < math.min(0.5, m.chance * (1 + luck)) then
			return m.id
		end
	end
	return "normal"
end

local function rollTrait(rng: any): string
	local total = 0
	for _, t in ipairs(Creatures.traits) do total += t.weight end
	local r = rng:NextNumber() * total
	for _, t in ipairs(Creatures.traits) do
		r -= t.weight
		if r <= 0 then return t.id end
	end
	return "none"
end

--- Inserts a creature, records discovery, grants the discovery reward. Returns uid, isNew.
function Engine._addCreature(p: any, sp: string, mut: string, trait: string, ctx: Ctx, silent: boolean?): (string, boolean)
	local uid = "c" .. p.nextUid
	p.nextUid += 1
	p.creatures[uid] = { sp = sp, mut = mut, trait = trait, lvl = 1 }
	local key = sp .. ":" .. mut
	local isNew = not p.discovered[key]
	if isNew then
		p.discovered[key] = true
		local def = Creatures.byId[sp]
		local mult = if mut ~= "normal" then Creatures.MutationDiscoveryMult else 1
		local reward = {
			cash = Creatures.DiscoveryReward.cash[def.rarity] * mult,
			cores = Creatures.DiscoveryReward.cores[def.rarity] * mult,
		}
		if not silent then
			Engine.grantReward(p, reward, ctx)
			notify(ctx, "discovery", { sp = sp, mut = mut, reward = reward })
			local mi = Creatures.mutationIndex[mut]
			if def.rarity >= 5 or mi >= 4 then
				notify(ctx, "announce", { sp = sp, mut = mut })
			end
		end
	end
	if Creatures.byId[sp].rarity == 6 then
		p.stats.mythics += 1
	end
	Engine.invalidate(p)
	return uid, isNew
end

local function rollRarity(egg: any, p: any, rng: any): number
	local total = 0
	for _, w in ipairs(egg.weights) do total += w end
	local r = rng:NextNumber() * total
	local rarity = #egg.weights
	for i, w in ipairs(egg.weights) do
		r -= w
		if r <= 0 and w > 0 then
			rarity = i
			break
		end
	end
	-- pity: guarantee at least Rare once the counter fills, if this egg can produce it
	if p.pity >= Config.PityThreshold - 1 and rarity < Config.PityMinRarity and #egg.weights >= Config.PityMinRarity then
		local pool = {}
		for i = Config.PityMinRarity, #egg.weights do
			if egg.weights[i] > 0 then table.insert(pool, i) end
		end
		if #pool > 0 then rarity = pool[1] end
	end
	return rarity
end

function Engine.buyEgg(p: any, eggId: any, ctx: Ctx): (boolean, string, any?)
	local egg = if type(eggId) == "string" then Creatures.eggById[eggId] else nil
	if not egg then return fail("Unknown egg") end
	if p.zone < egg.zone then return fail("Requires " .. Machines.zones[egg.zone].name) end
	if egg.requiresResearch and not p.research[egg.requiresResearch] then
		return fail("Requires research: " .. Research.byId[egg.requiresResearch].name)
	end
	local st = stats(p, ctx)
	if creatureCount(p) >= st.invCap then return fail("Inventory full - fuse or release creatures") end
	if not spend(p, egg.currency, Formulas.eggCost(egg, p.eggsRun)) then return fail("Not enough " .. egg.currency) end

	local rarity = rollRarity(egg, p, ctx.rng)
	if rarity >= Config.PityMinRarity then p.pity = 0 else p.pity += 1 end
	local pool = {}
	for _, c in ipairs(Creatures.list) do
		if c.rarity == rarity then table.insert(pool, c) end
	end
	local species = pool[ctx.rng:NextInteger(1, #pool)]
	local mut = rollMutation(st.mutationLuck, ctx.rng)
	local trait = rollTrait(ctx.rng)
	local uid, isNew = Engine._addCreature(p, species.id, mut, trait, ctx)
	p.stats.hatched += 1
	p.eggsRun += 1
	return true, "Hatched " .. species.name, { uid = uid, sp = species.id, mut = mut, trait = trait, isNew = isNew }
end

function Engine.levelCreature(p: any, uid: any, ctx: Ctx): (boolean, string, any?)
	local c = if type(uid) == "string" then p.creatures[uid] else nil
	if not c then return fail("Unknown creature") end
	if c.lvl >= Config.CreatureMaxLevel then return fail("Max level") end
	local cost = Formulas.creatureLevelCost(Creatures.byId[c.sp].rarity, c.lvl)
	if not spend(p, "biomass", cost) then return fail("Not enough biomass") end
	c.lvl += 1
	p.stats.creatureLevels += 1
	Engine.invalidate(p)
	return true, "Leveled up"
end

function Engine.assign(p: any, uid: any, machineId: any, ctx: Ctx): (boolean, string, any?)
	local c = if type(uid) == "string" then p.creatures[uid] else nil
	if not c then return fail("Unknown creature") end
	if machineId == nil or machineId == "" then
		c.mach = nil
		Engine.invalidate(p)
		return true, "Unassigned"
	end
	local m = if type(machineId) == "string" then p.machines[machineId] else nil
	if not m then return fail("Machine not built") end
	if c.mach == machineId then return fail("Already assigned there") end
	local st = stats(p, ctx)
	local slots = Formulas.baseSlots(m.level) + st.slotBonus
	local used = 0
	for _, o in pairs(p.creatures) do
		if o.mach == machineId then used += 1 end
	end
	if used >= slots then return fail("No free slots (level up the machine for more)") end
	c.mach = machineId
	p.stats.assignments += 1
	Engine.invalidate(p)
	return true, "Assigned"
end

local RESOURCE_WEIGHT = { cash = 1, biomass = 3, cores = 40 }

--- One-click assignment optimiser (unlocked by research).
function Engine.autoAssign(p: any, ctx: Ctx): (boolean, string, any?)
	local st = stats(p, ctx)
	if not st.flags.autoAssign then return fail("Research Smart Assignment first") end
	for _, c in pairs(p.creatures) do c.mach = nil end
	local pairsList = {}
	for mid, m in pairs(p.machines) do
		local def = Machines.byId[mid]
		local importance = def.baseRate * Formulas.machineLevelMult(m.level) * (RESOURCE_WEIGHT[def.produces] or 1)
		for uid, c in pairs(p.creatures) do
			local cdef = Creatures.byId[c.sp]
			local compat = if cdef.element == def.element then 1 else Config.IncompatibleEfficiency
			table.insert(pairsList, { uid = uid, mid = mid, v = importance * Stats.creaturePower(c, st.creaturePower) * compat })
		end
	end
	table.sort(pairsList, function(a, b)
		if a.v ~= b.v then return a.v > b.v end
		if a.uid ~= b.uid then return a.uid < b.uid end
		return a.mid < b.mid
	end)
	local free: { [string]: number } = {}
	for mid, m in pairs(p.machines) do
		free[mid] = Formulas.baseSlots(m.level) + st.slotBonus
	end
	local placed = 0
	for _, e in ipairs(pairsList) do
		if free[e.mid] > 0 and p.creatures[e.uid].mach == nil then
			p.creatures[e.uid].mach = e.mid
			free[e.mid] -= 1
			placed += 1
		end
	end
	Engine.invalidate(p)
	return true, "Assigned " .. placed .. " creatures"
end

function Engine.release(p: any, uid: any, ctx: Ctx): (boolean, string, any?)
	local c = if type(uid) == "string" then p.creatures[uid] else nil
	if not c then return fail("Unknown creature") end
	if creatureCount(p) <= 1 then return fail("Keep at least one creature") end
	local rarity = Creatures.byId[c.sp].rarity
	local gain = 10 * 4 ^ (rarity - 1) * c.lvl
	p.creatures[uid] = nil
	Engine.add(p, "cash", gain)
	Engine.invalidate(p)
	return true, "Released for $" .. gain, { cash = gain }
end

----------------------------------------------------------------------------------------------------
-- Fusion
----------------------------------------------------------------------------------------------------

-- cheapest-first: unassigned, lowest level, lowest mutation
local function inputScore(c: any): number
	return (if c.mach then 1e6 else 0) + c.lvl * 1000 + (Creatures.mutationIndex[c.mut] or 1) * 10
end

--- Chooses creatures to feed a recipe (lowest value first). Returns uid list or nil.
function Engine.pickFusionInputs(p: any, recipe: any): { string }?
	local picked = {}
	for sp, need in pairs(recipe.inputs) do
		local cands = {}
		for uid, c in pairs(p.creatures) do
			if c.sp == sp then table.insert(cands, uid) end
		end
		if #cands < need then return nil end
		table.sort(cands, function(a, b)
			local sa, sb = inputScore(p.creatures[a]), inputScore(p.creatures[b])
			if sa ~= sb then return sa < sb end
			return a < b
		end)
		for i = 1, need do table.insert(picked, cands[i]) end
	end
	return picked
end

function Engine.fuse(p: any, recipeId: any, uids: any, ctx: Ctx): (boolean, string, any?)
	local recipe = if type(recipeId) == "string" then Creatures.recipeById[recipeId] else nil
	if not recipe then return fail("Unknown recipe") end
	local list
	if uids == nil then
		list = Engine.pickFusionInputs(p, recipe)
		if not list then return fail("Missing ingredients") end
	else
		if type(uids) ~= "table" then return fail("Bad request") end
		list = uids
	end
	-- validate: exact multiset, distinct, owned
	local need = {}
	local totalNeed = 0
	for sp, n in pairs(recipe.inputs) do need[sp] = n totalNeed += n end
	if #list ~= totalNeed then return fail("Wrong number of ingredients") end
	local seen = {}
	local bestMut = 1
	for _, uid in ipairs(list) do
		if type(uid) ~= "string" or seen[uid] then return fail("Invalid ingredients") end
		seen[uid] = true
		local c = p.creatures[uid]
		if not c then return fail("Unknown creature in ingredients") end
		if not need[c.sp] or need[c.sp] <= 0 then return fail("Ingredients do not match recipe") end
		need[c.sp] -= 1
		bestMut = math.max(bestMut, Creatures.mutationIndex[c.mut])
	end
	local st = stats(p, ctx)
	local cost = math.ceil(recipe.cost * (1 - st.fusionDiscount))
	if not spend(p, "biomass", cost) then return fail("Not enough biomass (" .. cost .. ")") end
	for _, uid in ipairs(list) do p.creatures[uid] = nil end

	-- 50% to inherit the best input mutation, otherwise roll normally (fusion has double luck)
	local mut = rollMutation(st.mutationLuck * 2 + 0.5, ctx.rng)
	if ctx.rng:NextNumber() < 0.5 and bestMut > (Creatures.mutationIndex[mut] or 1) then
		mut = Creatures.mutations[bestMut].id
	end
	local trait = rollTrait(ctx.rng)
	Engine.invalidate(p)
	local uid, isNew = Engine._addCreature(p, recipe.result, mut, trait, ctx)
	p.stats.fused += 1
	return true, "Fused " .. Creatures.byId[recipe.result].name, { uid = uid, sp = recipe.result, mut = mut, trait = trait, isNew = isNew }
end

----------------------------------------------------------------------------------------------------
-- Research
----------------------------------------------------------------------------------------------------

--- Returns (available, reason).
function Engine.researchStatus(p: any, id: string): (boolean, string?)
	local node = Research.byId[id]
	if not node then return false, "Unknown" end
	if p.research[id] then return false, "Owned" end
	for _, ex in ipairs(node.exclusive or {}) do
		if p.research[ex] then return false, "Locked out by " .. Research.byId[ex].name end
	end
	for _, r in ipairs(node.requires or {}) do
		if not p.research[r] then return false, "Requires " .. Research.byId[r].name end
	end
	if node.anyOf then
		local any = false
		for _, r in ipairs(node.anyOf) do
			if p.research[r] then any = true end
		end
		if not any then return false, "Requires one of: " .. Research.byId[node.anyOf[1]].name .. " / " .. Research.byId[node.anyOf[2]].name end
	end
	return true, nil
end

function Engine.buyResearch(p: any, id: any, ctx: Ctx): (boolean, string, any?)
	if type(id) ~= "string" then return fail("Bad request") end
	local node = Research.byId[id]
	if not node then return fail("Unknown research") end
	local ok, why = Engine.researchStatus(p, id)
	if not ok then return fail(why or "Unavailable") end
	if not spend(p, "cores", node.cost) then return fail("Not enough cores") end
	p.research[id] = true
	p.stats.researchBought += 1
	Engine.invalidate(p)
	notify(ctx, "toast", { text = "Researched " .. node.name, kind = "good" })
	return true, "Researched " .. node.name
end

----------------------------------------------------------------------------------------------------
-- Rebirth
----------------------------------------------------------------------------------------------------

function Engine.prestigeLevel(p: any, id: string): number
	return p.prestige[id] or 0
end

function Engine.rebirthPreview(p: any, ctx: Ctx): any
	local st = stats(p, ctx)
	local req = Formulas.rebirthRequirement(p.rebirths)
	local gain = Formulas.echoGain(p.runCash, st.echoMult)
	local can, reason = true, nil
	if p.zone < Config.Rebirth.minZone then
		can, reason = false, "Expand to " .. Machines.zones[Config.Rebirth.minZone].name .. " first"
	elseif p.runCash < req then
		can, reason = false, "Earn more cash this run"
	elseif gain < 1 then
		can, reason = false, "Would not grant any Echoes yet"
	end
	return { can = can, reason = reason, requirement = req, runCash = p.runCash, gain = gain, rebirths = p.rebirths }
end

function Engine.rebirth(p: any, confirm: any, ctx: Ctx): (boolean, string, any?)
	if confirm ~= true then return fail("Confirmation required") end
	local prev = Engine.rebirthPreview(p, ctx)
	if not prev.can then return fail(prev.reason or "Cannot rebirth yet") end

	local startCashLvl = Engine.prestigeLevel(p, "r_start")
	local startZoneLvl = Engine.prestigeLevel(p, "r_zone")
	p.echoes += prev.gain
	p.echoesEarned += prev.gain
	p.rebirths += 1
	p.cash = Config.StartCash + Prestige.byId.r_start.perLevel * startCashLvl * startCashLvl
	p.biomass = 0
	p.runCash = 0
	p.zone = 1 + startZoneLvl
	p.machines = { forge = { level = 1 } }
	p.stats.machinesBuilt = 1
	p.pity = 0
	p.eggsRun = 0
	for _, c in pairs(p.creatures) do
		c.lvl = 1
		c.mach = nil
	end
	-- re-seat the best matching creature on the forge so a new run is never stalled
	local bestUid, bestV
	for uid, c in pairs(p.creatures) do
		local v = Stats.creaturePower(c, 0) * (if Creatures.byId[c.sp].element == "ember" then 1 else Config.IncompatibleEfficiency)
		if bestV == nil or v > bestV then bestUid, bestV = uid, v end
	end
	if bestUid then p.creatures[bestUid].mach = "forge" end
	Engine.invalidate(p)
	notify(ctx, "toast", { text = "Rebirth complete! +" .. prev.gain .. " Echoes", kind = "good" })
	return true, "Reborn", { gain = prev.gain }
end

function Engine.buyPrestige(p: any, id: any, ctx: Ctx): (boolean, string, any?)
	local u = if type(id) == "string" then Prestige.byId[id] else nil
	if not u then return fail("Unknown upgrade") end
	local lvl = Engine.prestigeLevel(p, id)
	if lvl >= u.max then return fail("Max level") end
	if not spend(p, "echoes", Formulas.prestigeCost(u, lvl)) then return fail("Not enough echoes") end
	p.prestige[id] = lvl + 1
	Engine.invalidate(p)
	return true, u.name .. " " .. (lvl + 1)
end

----------------------------------------------------------------------------------------------------
-- Quests & achievements
----------------------------------------------------------------------------------------------------

function Engine.refreshDaily(p: any, now: number)
	local day = math.floor(now / 86400)
	local d = p.quests.daily
	if d.day ~= day then
		d.day = day
		d.ids = Quests.rollDaily(day)
		d.base = {}
		d.claimed = {}
		for _, id in ipairs(d.ids) do
			d.base[id] = Quests.getStat(p, Quests.byId[id].stat)
		end
	end
end

function Engine.claimQuest(p: any, id: any, ctx: Ctx): (boolean, string, any?)
	local q = if type(id) == "string" then Quests.byId[id] else nil
	if not q then return fail("Unknown quest") end
	Engine.refreshDaily(p, ctx.now)
	local cur = Quests.getStat(p, q.stat)
	local qs = p.quests
	local function done(base: number): boolean
		return cur - base >= q.target
	end
	local kindOk = false
	if Quests.tutorial[p.tutorial] and Quests.tutorial[p.tutorial].id == id then
		if cur < q.target then return fail("Not complete yet") end
		p.tutorial += 1
		kindOk = true
	elseif table.find(qs.daily.ids, id) then
		if qs.daily.claimed[id] then return fail("Already claimed") end
		if not done(qs.daily.base[id] or 0) then return fail("Not complete yet") end
		qs.daily.claimed[id] = true
		kindOk = true
	elseif table.find(Quests.repeatable, q) then
		local base = qs.repeatBase[id] or 0
		if not done(base) then return fail("Not complete yet") end
		qs.repeatBase[id] = base + q.target
		kindOk = true
	elseif table.find(Quests.milestones, q) then
		if qs.claimed[id] then return fail("Already claimed") end
		if cur < q.target then return fail("Not complete yet") end
		qs.claimed[id] = true
		kindOk = true
	end
	if not kindOk then return fail("Quest not available") end
	Engine.grantReward(p, q.reward, ctx)
	return true, "Claimed " .. q.name, { reward = q.reward }
end

--- Auto-grants any newly met achievements. Returns list of unlocked ids.
function Engine.checkAchievements(p: any, ctx: Ctx): { string }
	local unlocked = {}
	for _, a in ipairs(Quests.achievements) do
		if not p.achievements[a.id] and Quests.getStat(p, a.stat) >= a.target then
			p.achievements[a.id] = true
			table.insert(unlocked, a.id)
			Engine.grantReward(p, a.reward, ctx)
			notify(ctx, "achievement", { id = a.id, name = a.name, reward = a.reward })
		end
	end
	return unlocked
end

----------------------------------------------------------------------------------------------------
-- Settings / cosmetics
----------------------------------------------------------------------------------------------------

function Engine.setSetting(p: any, key: any, value: any, ctx: Ctx): (boolean, string, any?)
	if type(value) ~= "boolean" then return fail("Bad value") end
	if key ~= "autoUpgrade" and key ~= "notifications" then return fail("Unknown setting") end
	if key == "autoUpgrade" and value and not stats(p, ctx).flags.autoUpgrade then
		return fail("Research Auto-Upgrader first")
	end
	p.settings[key] = value
	return true, "Saved"
end

function Engine.setTheme(p: any, theme: any, ctx: Ctx): (boolean, string, any?)
	local def = if type(theme) == "string" then S.Monetization.themes[theme] else nil
	if not def then return fail("Unknown theme") end
	if def.requires and not p.owned[def.requires] then return fail("Theme not owned") end
	p.theme = theme
	return true, "Theme set"
end

return Engine
