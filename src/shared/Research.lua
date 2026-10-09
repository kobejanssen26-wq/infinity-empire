--!nonstrict
-- Research tree. Cost in cores. requires = all of; anyOf = at least one of; exclusive = locks out these nodes.
-- effects keys (additive unless noted): cashMult biomassMult coreMult creaturePower mutationLuck
--   upgradeDiscount fusionDiscount echoMult slotBonus offlineHours machineMult.<id>
--   flags: autoUpgrade autoAssign (booleans)

local Research = {}

Research.branches = {
	{ id = "industrial", name = "Industrial Production", color = Color3.fromRGB(255, 150, 70) },
	{ id = "evolution", name = "Creature Evolution", color = Color3.fromRGB(190, 110, 255) },
	{ id = "automation", name = "Automation", color = Color3.fromRGB(90, 200, 255) },
	{ id = "efficiency", name = "Resource Efficiency", color = Color3.fromRGB(120, 220, 120) },
	{ id = "dimensional", name = "Dimensional Technology", color = Color3.fromRGB(255, 110, 180) },
}

Research.nodes = {
	-- Industrial
	{ id = "ind1", branch = "industrial", name = "Better Bearings", cost = 5, desc = "+10% cash from all sources.", effects = { cashMult = 0.10 } },
	{ id = "ind2", branch = "industrial", name = "Overclocked Forges", cost = 20, requires = { "ind1" }, desc = "Ember Forge output +50%.", effects = { ["machineMult.forge"] = 0.5 } },
	{ id = "ind3a", branch = "industrial", name = "Mass Production", cost = 80, requires = { "ind2" }, exclusive = { "ind3b" }, desc = "+35% cash. Excludes Precision Engineering.", effects = { cashMult = 0.35 } },
	{ id = "ind3b", branch = "industrial", name = "Precision Engineering", cost = 80, requires = { "ind2" }, exclusive = { "ind3a" }, desc = "+15% cash and -8% upgrade costs. Excludes Mass Production.", effects = { cashMult = 0.15, upgradeDiscount = 0.08 } },
	{ id = "ind4", branch = "industrial", name = "Quantum Foundry", cost = 400, anyOf = { "ind3a", "ind3b" }, desc = "Hydraulic Press output +100%.", effects = { ["machineMult.press"] = 1.0 } },
	{ id = "ind5", branch = "industrial", name = "Industrial Singularity", cost = 2000, requires = { "ind4" }, desc = "+75% cash.", effects = { cashMult = 0.75 } },
	-- Evolution
	{ id = "evo1", branch = "evolution", name = "Gene Splicing", cost = 8, desc = "+25% mutation luck.", effects = { mutationLuck = 0.25 } },
	{ id = "evo2", branch = "evolution", name = "Efficient Fusion", cost = 30, requires = { "evo1" }, desc = "-25% fusion Biomass cost.", effects = { fusionDiscount = 0.25 } },
	{ id = "evo3a", branch = "evolution", name = "Hardy Lineages", cost = 100, requires = { "evo2" }, exclusive = { "evo3b" }, desc = "+20% creature power. Excludes Wild Genes.", effects = { creaturePower = 0.20 } },
	{ id = "evo3b", branch = "evolution", name = "Wild Genes", cost = 100, requires = { "evo2" }, exclusive = { "evo3a" }, desc = "+60% mutation luck. Excludes Hardy Lineages.", effects = { mutationLuck = 0.60 } },
	{ id = "evo4", branch = "evolution", name = "Apex Breeding", cost = 500, anyOf = { "evo3a", "evo3b" }, desc = "+30% creature power.", effects = { creaturePower = 0.30 } },
	-- Automation
	{ id = "aut1", branch = "automation", name = "Night Shift", cost = 15, desc = "+2 hours of offline production.", effects = { offlineHours = 2 } },
	{ id = "aut2", branch = "automation", name = "Auto-Upgrader", cost = 60, requires = { "aut1" }, desc = "Unlocks a toggle that automatically buys the cheapest machine upgrade.", effects = { autoUpgrade = true } },
	{ id = "aut3", branch = "automation", name = "Smart Assignment", cost = 200, requires = { "aut2" }, desc = "Unlocks one-click 'Optimize Assignments'.", effects = { autoAssign = true } },
	{ id = "aut4", branch = "automation", name = "Deep Storage", cost = 600, requires = { "aut3" }, desc = "+6 hours of offline production.", effects = { offlineHours = 6 } },
	-- Efficiency
	{ id = "eff1", branch = "efficiency", name = "Resource Recycling", cost = 10, desc = "+25% Biomass.", effects = { biomassMult = 0.25 } },
	{ id = "eff2", branch = "efficiency", name = "Core Compression", cost = 40, requires = { "eff1" }, desc = "+25% Cores.", effects = { coreMult = 0.25 } },
	{ id = "eff3", branch = "efficiency", name = "Bulk Contracts", cost = 120, requires = { "eff1" }, desc = "-7% upgrade costs.", effects = { upgradeDiscount = 0.07 } },
	{ id = "eff4", branch = "efficiency", name = "Extra Bays", cost = 250, requires = { "eff2", "eff3" }, desc = "+1 creature slot on every machine.", effects = { slotBonus = 1 } },
	{ id = "eff5", branch = "efficiency", name = "Lean Manufacturing", cost = 900, requires = { "eff4" }, desc = "-10% upgrade costs.", effects = { upgradeDiscount = 0.10 } },
	-- Dimensional
	{ id = "dim1", branch = "dimensional", name = "Echo Tuning", cost = 50, requires = { "ind1" }, desc = "+15% Echoes from rebirth.", effects = { echoMult = 0.15 } },
	{ id = "dim2", branch = "dimensional", name = "Resonant Rebirth", cost = 300, requires = { "dim1" }, desc = "+25% Echoes from rebirth.", effects = { echoMult = 0.25 } },
	{ id = "dim3", branch = "dimensional", name = "Rift Mapping", cost = 1500, requires = { "dim2" }, desc = "Unlocks Rift Eggs. Foundation for future Dimensions.", effects = { cashMult = 0.25 } },
}

-- Global multiplier on every node cost, to retune pacing in one place.
Research.costScale = 6

Research.byId = {} :: { [string]: any }
for _, n in ipairs(Research.nodes) do
	n.cost = n.cost * Research.costScale
	Research.byId[n.id] = n
end

return Research
