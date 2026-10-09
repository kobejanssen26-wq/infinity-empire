--!nonstrict
-- Visual system: one palette, one type scale, rarity colours from shared Config.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Theme = {}

Theme.bg = Color3.fromRGB(14, 17, 27)
Theme.panel = Color3.fromRGB(22, 27, 42)
Theme.card = Color3.fromRGB(31, 38, 58)
Theme.cardHi = Color3.fromRGB(41, 50, 76)
Theme.stroke = Color3.fromRGB(58, 70, 104)
Theme.text = Color3.fromRGB(235, 240, 255)
Theme.textDim = Color3.fromRGB(150, 160, 190)
Theme.accent = Color3.fromRGB(255, 176, 56)
Theme.good = Color3.fromRGB(74, 205, 120)
Theme.bad = Color3.fromRGB(235, 90, 90)
Theme.info = Color3.fromRGB(80, 160, 255)
Theme.disabled = Color3.fromRGB(58, 64, 82)

Theme.font = Enum.Font.GothamMedium
Theme.fontBold = Enum.Font.GothamBold

Theme.size = { small = 13, body = 15, title = 20, huge = 26 }

function Theme.rarity(i: number): Color3
	return Config.Rarities[i].color
end

return Theme
