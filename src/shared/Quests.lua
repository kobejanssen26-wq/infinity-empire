--!strict
-- Quest / achievement / event framework data. Progress is derived from profile stats:
--   Quests.getStat(profile, statName)  -> number
-- kinds: tutorial (ordered, absolute), daily (rolled per UTC day, delta), repeat (delta, resets on claim),
--        milestone (absolute, one-time claim). Achievements auto-grant when `stat >= target`.
-- Rewards deliberately span resources that need different parts of the game (cores, biomass, echoes).

local Creatures = require(script.Parent.Creatures)

local Quests = {}

Quests.tutorial = {
	{ id = "t1", name = "Power Up", desc = "Upgrade the Ember Forge 3 times.", stat = "machineUpgrades", target = 3, reward = { cash = 100 }, hint = "Open Factory (F) and press Upgrade, or walk to the forge and use its prompt." },
	{ id = "t2", name = "Hatch Your First Egg", desc = "Buy and hatch a Scrap Egg.", stat = "hatched", target = 1, reward = { cash = 150 }, hint = "Open Eggs and buy a Scrap Egg." },
	{ id = "t3", name = "Put Them To Work", desc = "Assign a creature to a machine.", stat = "assignments", target = 1, reward = { cash = 250 }, hint = "Open Creatures, pick a creature and press Assign. Matching elements work at full power." },
	{ id = "t4", name = "Expand Your Business", desc = "Build the Hydraulic Press.", stat = "machinesBuilt", target = 2, reward = { cash = 500 }, hint = "Open Factory and build the Hydraulic Press." },
	{ id = "t5", name = "Grow Your Collection", desc = "Discover 4 creature variants.", stat = "discoveries", target = 4, reward = { cash = 1000 }, hint = "Hatch more eggs. Open the Index to see what's undiscovered." },
	{ id = "t6", name = "Open the Mezzanine", desc = "Expand the factory to zone 2.", stat = "zone", target = 2, reward = { biomass = 40 }, hint = "Open Factory and expand to the Mezzanine Wing." },
	{ id = "t7", name = "Fuse Something New", desc = "Perform a fusion.", stat = "fused", target = 1, reward = { biomass = 40, cores = 2 }, hint = "Open Eggs > Fusion. Three of the same common creature fuse into an Uncommon." },
	{ id = "t8", name = "Think Ahead", desc = "Buy your first research.", stat = "researchBought", target = 1, reward = { cores = 5 }, hint = "Build the Core Reactor to produce Cores, then open Research." },
	{ id = "t9", name = "The Big Reset", desc = "Complete a rebirth.", stat = "rebirths", target = 1, reward = { echoes = 2 }, hint = "Open Rebirth to see requirements. Resets are explained before you confirm." },
}

Quests.daily = {
	{ id = "d_hatch", name = "Egg Day", desc = "Hatch 8 eggs.", stat = "hatched", target = 8, reward = { cash = 2500, biomass = 20 } },
	{ id = "d_upgrade", name = "Maintenance Crew", desc = "Upgrade machines 15 times.", stat = "machineUpgrades", target = 15, reward = { cash = 3000, cores = 1 } },
	{ id = "d_fuse", name = "Mad Scientist", desc = "Perform 2 fusions.", stat = "fused", target = 2, reward = { biomass = 40, cores = 2 } },
	{ id = "d_level", name = "Training Day", desc = "Level up creatures 10 times.", stat = "creatureLevels", target = 10, reward = { cash = 2000, biomass = 30 } },
	{ id = "d_cash", name = "Cash Flow", desc = "Earn 50,000 cash.", stat = "cashEarned", target = 50000, reward = { cores = 2, biomass = 25 } },
	{ id = "d_research", name = "Lab Work", desc = "Buy 1 research node.", stat = "researchBought", target = 1, reward = { cash = 5000, cores = 2 } },
	{ id = "d_discover", name = "Field Notes", desc = "Discover 1 new creature variant.", stat = "discoveries", target = 1, reward = { cash = 4000, cores = 2 } },
}
Quests.DailyCount = 3

Quests.repeatable = {
	{ id = "r_hatch", name = "Hatchery Regular", desc = "Hatch 25 eggs.", stat = "hatched", target = 25, reward = { cash = 10000, biomass = 50 } },
	{ id = "r_upgrade", name = "Never Stop Upgrading", desc = "Upgrade machines 50 times.", stat = "machineUpgrades", target = 50, reward = { cash = 15000, cores = 3 } },
}

Quests.milestones = {
	{ id = "m_zone3", name = "Genetics Annex", desc = "Reach factory zone 3.", stat = "zone", target = 3, reward = { cores = 10 } },
	{ id = "m_zone4", name = "Sky High", desc = "Reach factory zone 4.", stat = "zone", target = 4, reward = { cores = 40 } },
	{ id = "m_disc10", name = "Naturalist", desc = "Discover 10 variants.", stat = "discoveries", target = 10, reward = { cash = 25000, cores = 5 } },
	{ id = "m_disc25", name = "Taxonomist", desc = "Discover 25 variants.", stat = "discoveries", target = 25, reward = { cash = 500000, cores = 20 } },
	{ id = "m_machine50", name = "Fully Loaded", desc = "Get any machine to level 50.", stat = "maxMachineLevel", target = 50, reward = { cash = 100000, biomass = 200 } },
	{ id = "m_reb3", name = "Cycle of Rebirth", desc = "Rebirth 3 times.", stat = "rebirths", target = 3, reward = { echoes = 5 } },
	{ id = "m_research10", name = "Researcher", desc = "Buy 10 research nodes.", stat = "researchBought", target = 10, reward = { cores = 25 } },
}

Quests.achievements = {
	{ id = "a_first_egg", name = "Cracked It", desc = "Hatch your first egg.", stat = "hatched", target = 1, reward = { cash = 100 } },
	{ id = "a_eggs100", name = "Egg Enthusiast", desc = "Hatch 100 eggs.", stat = "hatched", target = 100, reward = { cash = 50000, biomass = 100 } },
	{ id = "a_eggs1000", name = "Omelette Maker", desc = "Hatch 1,000 eggs.", stat = "hatched", target = 1000, reward = { cores = 100 } },
	{ id = "a_rich", name = "Millionaire", desc = "Earn 1,000,000 cash in total.", stat = "cashEarned", target = 1e6, reward = { cores = 5 } },
	{ id = "a_rich2", name = "Billionaire", desc = "Earn 1e9 cash in total.", stat = "cashEarned", target = 1e9, reward = { cores = 50 } },
	{ id = "a_fuse10", name = "Splice Master", desc = "Perform 10 fusions.", stat = "fused", target = 10, reward = { biomass = 300 } },
	{ id = "a_mutant", name = "Mutant!", desc = "Own a creature with a Golden or better mutation.", stat = "bestMutation", target = 3, reward = { cores = 10 } },
	{ id = "a_mythic", name = "Eclipse Rising", desc = "Fuse an Eclipse Leviathan.", stat = "mythics", target = 1, reward = { echoes = 10 } },
	{ id = "a_reb1", name = "Reborn", desc = "Rebirth once.", stat = "rebirths", target = 1, reward = { cores = 5 } },
	{ id = "a_reb10", name = "Eternal", desc = "Rebirth 10 times.", stat = "rebirths", target = 10, reward = { echoes = 25 } },
}

Quests.byId = {} :: { [string]: any }
for _, group in ipairs({ Quests.tutorial, Quests.daily, Quests.repeatable, Quests.milestones, Quests.achievements }) do
	for _, q in ipairs(group) do
		Quests.byId[q.id] = q
	end
end

-- Limited-duration events: active when (day since epoch) % cycleDays falls in [startDay, startDay+durationDays).
-- effects: mutationLuck / cashMult / biomassMult / coreMult additive bonuses while active.
Quests.events = {
	{ id = "mutation_surge", name = "Mutation Surge", desc = "Mutation luck +100% while the Surge lasts!", cycleDays = 7, startDay = 2, durationDays = 1, effects = { mutationLuck = 1.0 } },
	{ id = "gold_rush", name = "Gold Rush", desc = "All cash production +50%!", cycleDays = 7, startDay = 5, durationDays = 1, effects = { cashMult = 0.5 } },
	{ id = "bio_bloom", name = "Bio Bloom", desc = "Biomass +50% and Cores +25%!", cycleDays = 14, startDay = 9, durationDays = 2, effects = { biomassMult = 0.5, coreMult = 0.25 } },
}

--- Active event for a unix time (or nil).
function Quests.activeEvent(now: number): any?
	local day = math.floor(now / 86400)
	for _, e in ipairs(Quests.events) do
		local pos = (day - e.startDay) % e.cycleDays
		if pos < e.durationDays then
			local endsAt = (day - pos + e.durationDays) * 86400
			return { id = e.id, name = e.name, desc = e.desc, effects = e.effects, endsAt = endsAt }
		end
	end
	return nil
end

--- Reads a numeric progress stat from a profile (derived stats computed on demand).
function Quests.getStat(p: any, stat: string): number
	if stat == "zone" then
		return p.zone
	elseif stat == "discoveries" then
		local n = 0
		for _ in pairs(p.discovered) do
			n += 1
		end
		return n
	elseif stat == "maxMachineLevel" then
		local best = 0
		for _, m in pairs(p.machines) do
			if m.level > best then
				best = m.level
			end
		end
		return best
	elseif stat == "bestMutation" then
		local best = 1
		for _, c in pairs(p.creatures) do
			local idx = Creatures.mutationIndex[c.mut] or 1
			if idx > best then
				best = idx
			end
		end
		return best
	elseif stat == "rebirths" then
		return p.rebirths
	end
	return p.stats[stat] or 0
end

--- Picks the daily quest ids for a given UTC day number (deterministic, shared by all players).
function Quests.rollDaily(dayNumber: number): { string }
	local pool = {}
	for i, q in ipairs(Quests.daily) do
		pool[i] = q.id
	end
	local rng = Random.new(dayNumber * 7919 + 13)
	local picked = {}
	for _ = 1, math.min(Quests.DailyCount, #pool) do
		local i = rng:NextInteger(1, #pool)
		table.insert(picked, table.remove(pool, i))
	end
	return picked
end

return Quests
