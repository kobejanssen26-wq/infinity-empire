--!nonstrict
-- Derives every multiplier and production rate from a profile. Pure: the server uses it for
-- authoritative production; the client uses the same function to display exact rates.

local Config = require(script.Parent.Config)
local Creatures = require(script.Parent.Creatures)
local Machines = require(script.Parent.Machines)
local Research = require(script.Parent.Research)
local Prestige = require(script.Parent.Prestige)
local Formulas = require(script.Parent.Formulas)

local Stats = {}

--- Effective power of one creature instance (before compatibility).
function Stats.creaturePower(c: any, creaturePowerBonus: number): number
	local def = Creatures.byId[c.sp]
	local mut = Creatures.mutations[Creatures.mutationIndex[c.mut] or 1]
	local trait = Creatures.traitById[c.trait] or Creatures.traitById.none
	return def.power * Formulas.creatureLevelMult(c.lvl) * mut.mult * trait.powerMult * (1 + creaturePowerBonus)
end

function Stats.compute(p: any, event: any?): any
	local s = {
		cashMult = 1,
		biomassMult = 1,
		coreMult = 1,
		mutationLuck = 0,
		upgradeDiscount = 0,
		fusionDiscount = 0,
		creaturePower = 0,
		echoMult = 0,
		offlineHours = Config.BaseOfflineHours,
		slotBonus = 0,
		machineMult = {} :: { [string]: number },
		flags = { autoUpgrade = false, autoAssign = false },
		machines = {} :: { [string]: any },
		rates = { cash = 0, biomass = 0, cores = 0 },
	}

	local function addEffect(key: string, value: any)
		if type(value) == "boolean" then
			s.flags[key] = value or s.flags[key]
		elseif key:sub(1, 12) == "machineMult." then
			local id = key:sub(13)
			s.machineMult[id] = (s.machineMult[id] or 0) + value
		elseif key == "cashMult" or key == "biomassMult" or key == "coreMult" or key == "mutationLuck"
			or key == "upgradeDiscount" or key == "fusionDiscount" or key == "creaturePower"
			or key == "echoMult" or key == "offlineHours" or key == "slotBonus" then
			s[key] += value
		end
	end

	for id in pairs(p.research) do
		local node = Research.byId[id]
		if node then
			for k, v in pairs(node.effects) do
				addEffect(k, v)
			end
		end
	end
	for id, lvl in pairs(p.prestige) do
		local u = Prestige.byId[id]
		if u and lvl > 0 then
			if u.kind == "cashMult" or u.kind == "mutationLuck" or u.kind == "coreMult" or u.kind == "slotBonus" then
				addEffect(u.kind, u.perLevel * lvl)
			end
		end
	end
	s.cashMult += p.echoesEarned * Config.EchoPassiveBonus
	if event then
		for k, v in pairs(event.effects) do
			addEffect(k, v)
		end
	end

	-- assigned creatures: group per machine in stable uid order
	local perMachine: { [string]: { string } } = {}
	for uid, c in pairs(p.creatures) do
		if c.mach then
			local list = perMachine[c.mach]
			if not list then
				list = {}
				perMachine[c.mach] = list
			end
			table.insert(list, uid)
		end
	end

	local passiveCash, passiveBio, passiveCore = 0, 0, 0
	local discountFromCreatures = 0
	for _, def in ipairs(Machines.list) do
		local m = p.machines[def.id]
		if m then
			local slots = Formulas.baseSlots(m.level) + s.slotBonus
			local uids = perMachine[def.id] or {}
			table.sort(uids)
			local power = 0
			local used = {}
			for i, uid in ipairs(uids) do
				if i > slots then
					break
				end
				local c = p.creatures[uid]
				local cdef = Creatures.byId[c.sp]
				local compat = if cdef.element == def.element then 1 else Config.IncompatibleEfficiency
				power += Stats.creaturePower(c, s.creaturePower) * compat
				table.insert(used, uid)
				local trait = Creatures.traitById[c.trait]
				if trait then
					s.mutationLuck += trait.luck
				end
				if cdef.passive then
					for k, v in pairs(cdef.passive) do
						if k == "cashMult" then
							passiveCash += v
						elseif k == "biomassMult" then
							passiveBio += v
						elseif k == "coreMult" then
							passiveCore += v
						elseif k == "mutationLuck" then
							s.mutationLuck += v
						elseif k == "upgradeDiscount" then
							discountFromCreatures += v
						end
					end
				end
			end
			if def.luckPerLevel then
				s.mutationLuck += math.min(def.luckCap or 1, def.luckPerLevel * m.level)
			end
			s.machines[def.id] = { slots = slots, power = power, assigned = used, level = m.level }
		end
	end
	s.cashMult += passiveCash
	s.biomassMult += passiveBio
	s.coreMult += passiveCore
	s.upgradeDiscount = math.min(Config.MaxUpgradeDiscount, s.upgradeDiscount + discountFromCreatures)
	s.fusionDiscount = math.min(0.8, s.fusionDiscount)

	local globalMult = { cash = s.cashMult, biomass = s.biomassMult, cores = s.coreMult }
	for _, def in ipairs(Machines.list) do
		local info = s.machines[def.id]
		if info then
			local rate = def.baseRate * Formulas.machineLevelMult(info.level) * (1 + info.power)
				* (1 + (s.machineMult[def.id] or 0)) * (globalMult[def.produces] or 1)
			info.rate = rate
			s.rates[def.produces] += rate
		end
	end

	s.invCap = Config.BaseInventory + (if p.owned and p.owned.invPlus then Config.GamepassInventoryBonus else 0)
	return s
end

return Stats
