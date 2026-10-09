--!strict
-- Machine templates. Add a table to `list` to add a machine; nothing else needs to change.
-- produces: resource id. baseRate: units/sec at level 1. upgrade cost = upBase * upGrowth^level (cash).
-- unlockCost: cash to build. zone: factory zone required. pos: layout offset (studs) from plot center.

local Machines = {}

Machines.list = {
	{
		id = "forge", name = "Ember Forge", produces = "cash", baseRate = 1, unlockCost = 0, zone = 1,
		upBase = 12, upGrowth = 1.19, element = "ember", color = Color3.fromRGB(255, 120, 60), pos = { -14, -10 },
		desc = "Smelts scrap into cash. Your starting machine.",
	},
	{
		id = "press", name = "Hydraulic Press", produces = "cash", baseRate = 7, unlockCost = 350, zone = 1,
		upBase = 250, upGrowth = 1.19, element = "stone", color = Color3.fromRGB(170, 150, 120), pos = { 14, -10 },
		desc = "Slow, heavy and profitable.",
	},
	{
		id = "biolab", name = "Bio-Lab", produces = "biomass", baseRate = 0.4, unlockCost = 4000, zone = 2,
		upBase = 1800, upGrowth = 1.20, element = "bio", color = Color3.fromRGB(120, 220, 90), pos = { -14, 14 },
		desc = "Grows Biomass for creature levels and fusion.",
	},
	{
		id = "reactor", name = "Core Reactor", produces = "cores", baseRate = 0.03, unlockCost = 15000, zone = 2,
		upBase = 12000, upGrowth = 1.20, element = "arc", color = Color3.fromRGB(90, 200, 255), pos = { 14, 14 },
		desc = "Condenses Cores used by the Research tree.",
	},
	{
		id = "chamber", name = "Mutation Chamber", produces = "biomass", baseRate = 1.5, unlockCost = 400000, zone = 3,
		upBase = 150000, upGrowth = 1.20, element = "void", color = Color3.fromRGB(160, 90, 255), pos = { -34, 2 },
		luckPerLevel = 0.01, luckCap = 1.0,
		desc = "Produces Biomass and raises mutation luck with every level.",
	},
	{
		id = "quantum", name = "Quantum Assembler", produces = "cash", baseRate = 900, unlockCost = 40000000, zone = 4,
		upBase = 15000000, upGrowth = 1.21, element = "arc", color = Color3.fromRGB(255, 255, 255), pos = { 34, 2 },
		desc = "Assembles cash out of probability.",
	},
}

Machines.byId = {} :: { [string]: any }
for _, m in ipairs(Machines.list) do
	Machines.byId[m.id] = m
end

-- Factory zones (expandable floors). Zone 1 is free and owned from the start.
Machines.zones = {
	{ id = 1, name = "Starter Floor", cost = 0, size = { 56, 40 } },
	{ id = 2, name = "Mezzanine Wing", cost = 5000, size = { 56, 66 } },
	{ id = 3, name = "Genetics Annex", cost = 300000, size = { 96, 66 } },
	{ id = 4, name = "Sky Deck", cost = 25000000, size = { 96, 66 } },
}

return Machines
