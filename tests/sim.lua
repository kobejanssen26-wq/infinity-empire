--!nonstrict
-- Greedy-bot pacing simulation: prints how long a reasonably active player needs for key milestones.
local Creatures = require("./Creatures")
local Machines = require("./Machines")
local Research = require("./Research")
local Formulas = require("./Formulas")
local Engine = require("./Engine")
local Shim = require("./shim")

local ctx = { now = 1700000000, rng = Shim.Random.new(42) }
local p = Engine.newProfile(ctx.now)
local t = 0
local marks = {}
local function mark(name) if not marks[name] then marks[name] = t print(string.format("%7.1f min  %s", t / 60, name)) end end

local function step()
	Engine.tick(p, 1, ctx)
	ctx.now += 1
	t += 1
	local st = Engine.stats(p, ctx.now)
	-- zone / machines
	local nz = Machines.zones[p.zone + 1]
	if nz and p.cash >= nz.cost then Engine.expandZone(p, ctx) mark("zone " .. p.zone) end
	for _, m in ipairs(Machines.list) do
		if not p.machines[m.id] and p.zone >= m.zone and p.cash >= m.unlockCost then
			Engine.buyMachine(p, m.id, ctx) mark("built " .. m.id)
		end
	end
	local saving = false
	if nz and p.cash >= nz.cost * 0.2 then saving = true end
	for _, m in ipairs(Machines.list) do
		if not p.machines[m.id] and p.zone >= m.zone and p.cash >= m.unlockCost * 0.2 then saving = true end
	end
	-- research cheapest affordable
	for _, n in ipairs(Research.nodes) do
		if p.cores >= n.cost and Engine.researchStatus(p, n.id) then
			if Engine.buyResearch(p, n.id, ctx) then mark("research " .. n.id) end
		end
	end
	-- eggs: best affordable egg
	for i = #Creatures.eggs, 1, -1 do
		if saving then break end
		local e = Creatures.eggs[i]
		if p.zone >= e.zone and p[e.currency] >= e.cost * 8 and (not e.requiresResearch or p.research[e.requiresResearch]) then
			if Engine.creatureCount(p) < st.invCap then Engine.buyEgg(p, e.id, ctx) end
			break
		end
	end
	-- fuse whatever is fusable (cheapest recipes first)
	if t % 30 == 0 then
		for _, r in ipairs(Creatures.recipes) do
			if p.biomass >= r.cost * 3 and Engine.pickFusionInputs(p, r) then
				if Engine.fuse(p, r.id, nil, ctx) then mark("fused " .. r.result) end
			end
		end
		-- level assigned creatures
		for uid, c in pairs(p.creatures) do
			if c.mach and p.biomass > 200 then Engine.levelCreature(p, uid, ctx) end
		end
		-- free creatures: release junk when full
		if Engine.creatureCount(p) >= st.invCap - 2 then
			for uid, c in pairs(p.creatures) do
				if not c.mach and Creatures.byId[c.sp].rarity <= 2 then Engine.release(p, uid, ctx) end
			end
		end
	end
	-- spend on upgrades (best marginal rate per cost), keep 30% for eggs
	for _ = 1, (saving and 0 or 3) do
		local bestId, bestScore
		for id, m in pairs(p.machines) do
			local c = Formulas.upgradeCost(id, m.level, st.upgradeDiscount)
			if c <= p.cash * 0.7 then
				local def = Machines.byId[id]
				local gain = def.baseRate * (Formulas.machineLevelMult(m.level + 1) - Formulas.machineLevelMult(m.level))
				local w = ({ cash = 1, biomass = 3, cores = 25 })[def.produces]
				local score = gain * w / c
				if not bestScore or score > bestScore then bestId, bestScore = id, score end
			end
		end
		if bestId then Engine.upgradeMachine(p, bestId, 1, ctx) else break end
	end
	-- assign: auto when available, else greedily top up slots
	if t % 10 == 0 then
		if st.flags.autoAssign then Engine.autoAssign(p, ctx)
		else
			for uid, c in pairs(p.creatures) do
				if not c.mach then
					local def = Creatures.byId[c.sp]
					for mid in pairs(p.machines) do
						if Machines.byId[mid].element == def.element and Engine.assign(p, uid, mid, ctx) then break end
					end
				end
			end
			for uid, c in pairs(p.creatures) do
				if not c.mach then
					for mid in pairs(p.machines) do if Engine.assign(p, uid, mid, ctx) then break end end
				end
			end
		end
	end
end

local limit = 10 * 3600
while t < limit do
	step()
	local prev = Engine.rebirthPreview(p, ctx)
	if prev.can then mark("rebirth available (gain " .. prev.gain .. " echoes, cash/s " .. string.format("%.0f", Engine.stats(p, ctx.now).rates.cash) .. ")") break end
end
print(string.format("end t=%.1f min cash=%.0f runCash=%.0f cores=%.0f creatures=%d zone=%d research=%d", t / 60, p.cash, p.runCash, p.cores, Engine.creatureCount(p), p.zone, p.stats.researchBought))
