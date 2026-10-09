--!nonstrict
-- Pure cost / scaling formulas. Shared by client (display) and server (authority).

local Config = require(script.Parent.Config)
local Machines = require(script.Parent.Machines)

local Formulas = {}

function Formulas.clamp(n: number): number
	if n ~= n then
		return 0
	end
	return math.clamp(n, 0, Config.MaxValue)
end

--- Output multiplier of a machine level (additive growth, doubling at milestones).
function Formulas.machineLevelMult(level: number): number
	local m = 1 + Config.MachineLevelStep * (level - 1)
	for _, ms in ipairs(Config.MachineMilestones) do
		if level >= ms then
			m *= 2
		end
	end
	return m
end

--- Slots a machine has at `level` (before research/prestige slot bonuses).
function Formulas.baseSlots(level: number): number
	local n = 0
	for _, l in ipairs(Config.MachineSlotLevels) do
		if level >= l then
			n += 1
		end
	end
	return n
end

--- Cash cost to raise machine `id` from `level` to level+1.
function Formulas.upgradeCost(id: string, level: number, discount: number): number
	local m = Machines.byId[id]
	local d = math.clamp(discount, 0, Config.MaxUpgradeDiscount)
	return Formulas.clamp(math.floor(m.upBase * m.upGrowth ^ level * (1 - d)))
end

--- Total cost of n consecutive upgrades and how many are affordable with `budget` (<= n).
function Formulas.upgradeBulk(id: string, level: number, discount: number, budget: number, maxCount: number): (number, number)
	local total, count = 0, 0
	local limit = math.min(maxCount, Config.MachineMaxLevel - level)
	for i = 0, limit - 1 do
		local c = Formulas.upgradeCost(id, level + i, discount)
		if total + c > budget then
			break
		end
		total += c
		count += 1
	end
	return total, count
end

function Formulas.creatureLevelMult(level: number): number
	return 1 + Config.CreatureLevelStep * (level - 1)
end

--- Biomass cost to raise a creature from `level` to level+1.
function Formulas.creatureLevelCost(rarity: number, level: number): number
	local base = Config.CreatureLevelCostBase * Config.CreatureLevelCostGrowth ^ (level - 1)
	return Formulas.clamp(math.floor(base * (1 + (rarity - 1) * 1.5)))
end

function Formulas.rebirthRequirement(rebirths: number): number
	return Formulas.clamp(math.floor(Config.Rebirth.baseRequirement * Config.Rebirth.requirementGrowth ^ rebirths))
end

function Formulas.echoGain(runCash: number, echoMult: number): number
	if runCash < Config.RebirthEchoDivisor then
		return 0
	end
	return math.floor(math.sqrt(runCash / Config.RebirthEchoDivisor) * (1 + echoMult))
end

function Formulas.prestigeCost(upgrade: any, level: number): number
	return Formulas.clamp(math.ceil(upgrade.base * upgrade.growth ^ level))
end

--- Egg price rises with eggs bought this run (resets on rebirth), softly capped at 12x.
function Formulas.eggCost(egg: any, eggsThisRun: number): number
	return Formulas.clamp(math.ceil(egg.cost * math.min(12, 1 + eggsThisRun * 0.02)))
end

function Formulas.zoneCost(zone: number): number
	return Machines.zones[zone].cost
end

return Formulas
