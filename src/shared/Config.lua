--!strict
-- Global tuning constants. Everything numeric that designers may want to change lives here
-- or in the per-domain config modules (Creatures, Machines, Research, Prestige, Quests).

local Config = {}

Config.GameName = "ECLIPSE: INFINITE EMPIRE"
Config.DataVersion = 1

-- All stored/produced values are clamped here so they stay exactly representable
-- (doubles are integer-exact up to ~9e15) and ordered datastores can hold them.
Config.MaxValue = 1e15

Config.Resources = {
	{ id = "cash", name = "Cash", icon = "$", color = Color3.fromRGB(120, 230, 140) },
	{ id = "biomass", name = "Biomass", icon = "B", color = Color3.fromRGB(150, 220, 90) },
	{ id = "cores", name = "Cores", icon = "C", color = Color3.fromRGB(90, 190, 255) },
	{ id = "echoes", name = "Echoes", icon = "E", color = Color3.fromRGB(190, 120, 255) },
}

Config.Rarities = {
	{ id = "Common", color = Color3.fromRGB(190, 195, 205) },
	{ id = "Uncommon", color = Color3.fromRGB(110, 220, 120) },
	{ id = "Rare", color = Color3.fromRGB(80, 160, 255) },
	{ id = "Epic", color = Color3.fromRGB(180, 100, 255) },
	{ id = "Legendary", color = Color3.fromRGB(255, 180, 50) },
	{ id = "Mythic", color = Color3.fromRGB(255, 80, 120) },
}

Config.Elements = {
	ember = { name = "Ember", color = Color3.fromRGB(255, 120, 60) },
	stone = { name = "Stone", color = Color3.fromRGB(170, 150, 120) },
	bio = { name = "Bio", color = Color3.fromRGB(120, 220, 90) },
	arc = { name = "Arc", color = Color3.fromRGB(90, 200, 255) },
	void = { name = "Void", color = Color3.fromRGB(160, 90, 255) },
}

-- Machine scaling -------------------------------------------------------------
Config.MachineMaxLevel = 250
Config.MachineLevelStep = 0.25 -- +25% of base per level (additive part)
Config.MachineMilestones = { 25, 50, 100, 200 } -- each doubles output
Config.MachineSlotLevels = { 1, 10, 30, 75 } -- levels at which slots 1..4 unlock

-- Creature scaling ------------------------------------------------------------
Config.CreatureMaxLevel = 50
Config.CreatureLevelStep = 0.12
Config.CreatureLevelCostBase = 5 -- biomass
Config.CreatureLevelCostGrowth = 1.22
Config.IncompatibleEfficiency = 0.35 -- power multiplier when element != machine element
Config.BaseInventory = 60
Config.GamepassInventoryBonus = 60

-- Hatching ----------------------------------------------------------------------
Config.PityThreshold = 30 -- hatches without Rare+ before the next hatch is guaranteed Rare+
Config.PityMinRarity = 3 -- index into Rarities (3 = Rare)

-- Misc economy ------------------------------------------------------------------
Config.StartCash = 25
Config.BaseOfflineHours = 1
Config.OfflineEfficiency = 0.5
Config.MaxUpgradeDiscount = 0.6
Config.EchoPassiveBonus = 0.01 -- +1% cash per echo ever earned
Config.RebirthEchoDivisor = 1e7

Config.Rebirth = {
	baseRequirement = 5e7, -- run cash required for the first rebirth
	requirementGrowth = 3, -- per completed rebirth
	minZone = 3,
}

-- Server behaviour ------------------------------------------------------------
Config.TickSeconds = 1
Config.AutoSaveSeconds = 60
Config.LeaderboardWriteSeconds = 120
Config.LeaderboardReadSeconds = 120
Config.LeaderboardSize = 15

-- Remote rate limit: token bucket per player.
Config.RateLimit = { capacity = 20, refillPerSecond = 8 }
-- Per-action stricter costs (tokens consumed). Default is 1.
Config.ActionCost = {
	buyEgg = 2,
	fuse = 2,
	rebirth = 10,
	autoAssign = 4,
	visit = 5,
}

return Config
