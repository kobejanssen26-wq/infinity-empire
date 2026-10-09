--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Creatures = require(Shared:WaitForChild("Creatures"))

local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Common = require(script.Parent.Parent.Common)

local Page = { id = "index", title = "Index" }

local function sources(sp)
	local out = {}
	local def = Creatures.byId[sp]
	for _, e in ipairs(Creatures.eggs) do
		if (e.weights[def.rarity] or 0) > 0 then table.insert(out, e.name) end
	end
	for _, r in ipairs(Creatures.recipes) do
		if r.result == sp then table.insert(out, "Fusion") break end
	end
	return table.concat(out, ", ")
end

function Page.render(content)
	local d = State.data
	local total = #Creatures.list * #Creatures.mutations
	local found = 0
	for _ in pairs(d.discovered) do found += 1 end
	UI.label(content, string.format("Discovered <b>%d / %d</b> variants. Each first discovery pays a one-time bonus; mutated discoveries pay %dx.", found, total, Creatures.MutationDiscoveryMult), {
		Size = UDim2.new(1, 0, 0, 22), TextSize = 14,
	})
	local scroll = UI.scroll(content, { Name = "Scroll", Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26) })
	for i, def in ipairs(Creatures.list) do
		local seenAny = false
		for _, m in ipairs(Creatures.mutations) do
			if d.discovered[def.id .. ":" .. m.id] then seenAny = true end
		end
		local rcol = Theme.rarity(def.rarity)
		local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 62), LayoutOrder = i })
		local bar = UI.frame(card, { BackgroundColor3 = if seenAny then rcol else Theme.disabled, Size = UDim2.new(0, 6, 1, -12), Position = UDim2.fromOffset(6, 6) })
		UI.corner(bar, 3)
		local el = Config.Elements[def.element]
		UI.label(card, if seenAny then string.format("<b><font color='#%s'>%s</font></b>  <font color='#%s'>%s - %s</font>", rcol:ToHex(), def.name, Theme.textDim:ToHex(), Config.Rarities[def.rarity].id, el.name) else "<b>???</b>", {
			Position = UDim2.fromOffset(20, 6), Size = UDim2.new(0.5, -20, 0, 20), TextSize = 15, TextWrapped = false,
		})
		UI.label(card, if seenAny then ("Found in: " .. sources(def.id)) else "Undiscovered. Found in: " .. sources(def.id), {
			Position = UDim2.fromOffset(20, 30), Size = UDim2.new(0.5, -20, 0, 28), TextSize = 12, TextColor3 = Theme.textDim,
		})
		local chips = UI.frame(card, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(250, 44) })
		UI.listLayout(chips, 4, Enum.FillDirection.Horizontal)
		for _, m in ipairs(Creatures.mutations) do
			local has = d.discovered[def.id .. ":" .. m.id]
			local c = UI.frame(chips, { BackgroundColor3 = if has then m.color else Theme.bg, Size = UDim2.fromOffset(46, 44) })
			UI.corner(c, 6)
			UI.label(c, if has then m.name:sub(1, 4) else "?", {
				Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11,
				TextColor3 = if has then Color3.fromRGB(20, 20, 30) else Theme.textDim, Font = Theme.fontBold, TextWrapped = false,
			})
		end
	end
end

return Page
