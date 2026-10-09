--!strict
-- Creature, mutation, trait, egg and fusion data. Pure data: add rows to extend the game.

local Creatures = {}

-- power: contribution to machine output multiplier at level 1 (see Stats).
-- passive: { kind = value } applied while ASSIGNED to a machine.
--   cashMult / biomassMult / coreMult / mutationLuck / upgradeDiscount (fractions)
Creatures.list = {
	-- Common
	{ id = "cindermite", name = "Cindermite", rarity = 1, element = "ember", power = 0.15, desc = "A restless ember bug." },
	{ id = "pebblet", name = "Pebblet", rarity = 1, element = "stone", power = 0.15, desc = "Rolls into things." },
	{ id = "mossling", name = "Mossling", rarity = 1, element = "bio", power = 0.15, desc = "Smells of rain." },
	{ id = "zapling", name = "Zapling", rarity = 1, element = "arc", power = 0.15, desc = "Static with legs." },
	-- Uncommon
	{ id = "magmaroo", name = "Magmaroo", rarity = 2, element = "ember", power = 0.5, passive = { cashMult = 0.02 }, desc = "Hops on hot coals." },
	{ id = "slabbit", name = "Slabbit", rarity = 2, element = "stone", power = 0.5, passive = { cashMult = 0.02 }, desc = "Heavy for a rabbit." },
	{ id = "sporeling", name = "Sporeling", rarity = 2, element = "bio", power = 0.5, passive = { biomassMult = 0.04 }, desc = "Sneezes spores." },
	{ id = "arcmoth", name = "Arcmoth", rarity = 2, element = "arc", power = 0.5, passive = { coreMult = 0.04 }, desc = "Drawn to reactor light." },
	-- Rare
	{ id = "pyrofox", name = "Pyrofox", rarity = 3, element = "ember", power = 1.5, passive = { cashMult = 0.04 }, desc = "Three tails, all on fire." },
	{ id = "geodrake", name = "Geodrake", rarity = 3, element = "stone", power = 1.5, passive = { upgradeDiscount = 0.01 }, desc = "Hoards crystals, haggles hard." },
	{ id = "bloomhound", name = "Bloomhound", rarity = 3, element = "bio", power = 1.5, passive = { biomassMult = 0.06 }, desc = "Flowers grow where it naps." },
	{ id = "voltwisp", name = "Voltwisp", rarity = 3, element = "arc", power = 1.5, passive = { coreMult = 0.06 }, desc = "A thought made of lightning." },
	-- Epic
	{ id = "infernowyrm", name = "Infernowyrm", rarity = 4, element = "ember", power = 4, passive = { cashMult = 0.06 }, desc = "Coiled around the forge chimney." },
	{ id = "hivemind", name = "Hivemind", rarity = 4, element = "bio", power = 4, passive = { biomassMult = 0.10 }, desc = "Many bodies, one opinion." },
	{ id = "riftcat", name = "Riftcat", rarity = 4, element = "void", power = 4, passive = { mutationLuck = 0.10 }, desc = "Was never entirely here." },
	-- Legendary
	{ id = "solarphoenix", name = "Solar Phoenix", rarity = 5, element = "ember", power = 12, passive = { cashMult = 0.12 }, desc = "Rebirth is its hobby." },
	{ id = "chronogolem", name = "Chrono Golem", rarity = 5, element = "stone", power = 12, passive = { upgradeDiscount = 0.03 }, desc = "Time bends around it." },
	-- Mythic (fusion only)
	{ id = "eclipseleviathan", name = "Eclipse Leviathan", rarity = 6, element = "void", power = 40, passive = { cashMult = 0.25, mutationLuck = 0.15 }, desc = "The reason the sun goes out." },
}

Creatures.byId = {} :: { [string]: any }
for _, c in ipairs(Creatures.list) do
	Creatures.byId[c.id] = c
end

Creatures.StarterCreature = "cindermite"

-- Mutation variants. chance is the base roll (before luck) for non-normal tiers, checked rarest first.
Creatures.mutations = {
	{ id = "normal", name = "Normal", mult = 1, chance = 1, color = Color3.fromRGB(255, 255, 255) },
	{ id = "shiny", name = "Shiny", mult = 1.5, chance = 0.06, color = Color3.fromRGB(255, 240, 150) },
	{ id = "golden", name = "Golden", mult = 2.5, chance = 0.015, color = Color3.fromRGB(255, 200, 40) },
	{ id = "prismatic", name = "Prismatic", mult = 5, chance = 0.003, color = Color3.fromRGB(255, 120, 255) },
	{ id = "eclipse", name = "Eclipse", mult = 12, chance = 0.0004, color = Color3.fromRGB(120, 40, 200) },
}
Creatures.mutationIndex = {} :: { [string]: number }
for i, m in ipairs(Creatures.mutations) do
	Creatures.mutationIndex[m.id] = i
end

-- Genetic traits: rolled once at birth. powerMult multiplies power; luck adds to mutation luck while assigned.
Creatures.traits = {
	{ id = "none", name = "Plain", weight = 70, powerMult = 1, luck = 0 },
	{ id = "swift", name = "Swift", weight = 12, powerMult = 1.15, luck = 0, desc = "+15% power" },
	{ id = "hardy", name = "Hardy", weight = 10, powerMult = 1.10, luck = 0, desc = "+10% power" },
	{ id = "fertile", name = "Fertile", weight = 8, powerMult = 1, luck = 0.05, desc = "+5% mutation luck" },
}
Creatures.traitById = {} :: { [string]: any }
for _, t in ipairs(Creatures.traits) do
	Creatures.traitById[t.id] = t
end

-- Eggs: weights per rarity index. cost in `currency`. Mythic (6) is never in eggs.
Creatures.eggs = {
	{ id = "common", name = "Scrap Egg", currency = "cash", cost = 120, zone = 1, weights = { 80, 18, 2 }, color = Color3.fromRGB(200, 200, 210) },
	{ id = "hatchery", name = "Hatchery Egg", currency = "cash", cost = 6000, zone = 2, weights = { 0, 62, 34, 4 }, color = Color3.fromRGB(110, 220, 120) },
	{ id = "bio", name = "Biomass Egg", currency = "biomass", cost = 150, zone = 3, weights = { 0, 0, 72, 25, 3 }, color = Color3.fromRGB(150, 220, 90) },
	{ id = "rift", name = "Rift Egg", currency = "cores", cost = 120, zone = 4, requiresResearch = "dim3", weights = { 0, 0, 40, 48, 12 }, color = Color3.fromRGB(190, 120, 255) },
}
Creatures.eggById = {} :: { [string]: any }
for _, e in ipairs(Creatures.eggs) do
	Creatures.eggById[e.id] = e
end

-- Fusion recipes: inputs = species counts, validated server-side. cost in biomass.
Creatures.recipes = {
	{ id = "f_magmaroo", inputs = { cindermite = 3 }, result = "magmaroo", cost = 10 },
	{ id = "f_slabbit", inputs = { pebblet = 3 }, result = "slabbit", cost = 10 },
	{ id = "f_sporeling", inputs = { mossling = 3 }, result = "sporeling", cost = 10 },
	{ id = "f_arcmoth", inputs = { zapling = 3 }, result = "arcmoth", cost = 10 },
	{ id = "f_pyrofox", inputs = { magmaroo = 3 }, result = "pyrofox", cost = 80 },
	{ id = "f_geodrake", inputs = { slabbit = 3 }, result = "geodrake", cost = 80 },
	{ id = "f_bloomhound", inputs = { sporeling = 3 }, result = "bloomhound", cost = 80 },
	{ id = "f_voltwisp", inputs = { arcmoth = 3 }, result = "voltwisp", cost = 80 },
	{ id = "f_infernowyrm", inputs = { pyrofox = 3 }, result = "infernowyrm", cost = 600 },
	{ id = "f_hivemind", inputs = { bloomhound = 3 }, result = "hivemind", cost = 600 },
	{ id = "f_riftcat", inputs = { voltwisp = 1, bloomhound = 1, geodrake = 1 }, result = "riftcat", cost = 700 },
	{ id = "f_solarphoenix", inputs = { infernowyrm = 2, geodrake = 1 }, result = "solarphoenix", cost = 5000 },
	{ id = "f_chronogolem", inputs = { hivemind = 2, geodrake = 1 }, result = "chronogolem", cost = 5000 },
	{ id = "f_eclipseleviathan", inputs = { solarphoenix = 1, chronogolem = 1, riftcat = 1 }, result = "eclipseleviathan", cost = 60000 },
}
Creatures.recipeById = {} :: { [string]: any }
for _, r in ipairs(Creatures.recipes) do
	Creatures.recipeById[r.id] = r
end

Creatures.DiscoveryReward = {
	-- by rarity index: first time a species/mutation combo is owned
	cash = { 50, 200, 1000, 5000, 25000, 100000 },
	cores = { 0, 0, 1, 3, 8, 20 },
}
-- extra multiplier for non-normal mutation discoveries
Creatures.MutationDiscoveryMult = 3

return Creatures
