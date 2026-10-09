--!strict
-- Optional Robux items. IDs of 0 are "not configured": the shop hides them and purchases are refused.
-- Fill in real IDs from the Creator Dashboard. Nothing here sells raw progression power:
--   * gamepasses are convenience (inventory) or cosmetic (themes)
--   * the Supporter pack gives cosmetics + a flat cash gift that is small relative to a few minutes of play.

local Monetization = {}

Monetization.gamepasses = {
	{ key = "invPlus", id = 0, name = "Roomy Barn", desc = "+60 creature inventory slots.", kind = "convenience" },
	{ key = "theme_neon", id = 0, name = "Neon Factory Theme", desc = "Cosmetic: neon trim on your plot.", kind = "cosmetic" },
	{ key = "theme_gold", id = 0, name = "Gilded Factory Theme", desc = "Cosmetic: gold plating on your plot.", kind = "cosmetic" },
}

Monetization.products = {
	{ key = "supporter", id = 0, name = "Supporter Pack", desc = "Cosmetic Sparkle Aura on your creatures + 5 Cores. Thank you!", grant = { cores = 5 }, flag = "fx_sparkle" },
}

Monetization.themes = {
	default = { name = "Classic Steel", trim = Color3.fromRGB(70, 80, 95), accent = Color3.fromRGB(255, 190, 70), material = "Metal", requires = nil },
	neon = { name = "Neon", trim = Color3.fromRGB(20, 20, 40), accent = Color3.fromRGB(0, 255, 220), material = "Neon", requires = "theme_neon" },
	gold = { name = "Gilded", trim = Color3.fromRGB(215, 170, 50), accent = Color3.fromRGB(255, 240, 160), material = "Foil", requires = "theme_gold" },
}

return Monetization
