--!nonstrict
-- Rebirth upgrades bought with Echoes. level scaling: cost = base * growth^level.
-- kind drives how Stats/Engine interpret `perLevel`.

local Prestige = {}

Prestige.upgrades = {
	{ id = "r_cash", name = "Echo Engine", kind = "cashMult", perLevel = 0.25, max = 25, base = 1, growth = 1.5, desc = "+25% cash per level." },
	{ id = "r_start", name = "Seed Capital", kind = "startCash", perLevel = 500, max = 15, base = 1, growth = 1.45, desc = "Start each run with 500 x level² cash." },
	{ id = "r_luck", name = "Mutagen Memory", kind = "mutationLuck", perLevel = 0.10, max = 10, base = 2, growth = 1.6, desc = "+10% mutation luck per level." },
	{ id = "r_cores", name = "Core Memory", kind = "coreMult", perLevel = 0.20, max = 15, base = 2, growth = 1.5, desc = "+20% cores per level." },
	{ id = "r_slots", name = "Residual Slots", kind = "slotBonus", perLevel = 1, max = 2, base = 12, growth = 4, desc = "+1 creature slot on every machine per level." },
	{ id = "r_zone", name = "Keep Foundations", kind = "startZone", perLevel = 1, max = 2, base = 6, growth = 5, desc = "Rebirth keeps your factory floors: start on zone 2, then zone 3." },
}

Prestige.byId = {} :: { [string]: any }
for _, u in ipairs(Prestige.upgrades) do
	Prestige.byId[u.id] = u
end

return Prestige
