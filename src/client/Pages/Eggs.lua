--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Machines = require(Shared:WaitForChild("Machines"))
local Creatures = require(Shared:WaitForChild("Creatures"))
local Research = require(Shared:WaitForChild("Research"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Monetization = require(Shared:WaitForChild("Monetization"))

local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Common = require(script.Parent.Parent.Common)

local Page = { id = "eggs", title = "Eggs" }
local tab = "eggs"

local function tabs(content)
	local row = UI.frame(content, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36) })
	UI.listLayout(row, 8, Enum.FillDirection.Horizontal)
	for _, t in ipairs({ { "eggs", "Eggs" }, { "fusion", "Fusion Lab" }, { "store", "Store" } }) do
		UI.button(row, t[2], function() tab = t[1] Common.refresh() end, {
			Size = UDim2.fromOffset(130, 32), color = if tab == t[1] then Theme.accent else Theme.cardHi,
			textColor = if tab == t[1] then nil else Theme.text,
		})
	end
end

local function eggsTab(area)
	local d = State.data
	local scroll = UI.scroll(area, { Name = "Scroll" })
	local pityLeft = math.max(1, Config.PityThreshold - d.pity)
	UI.label(scroll, string.format("Rare-or-better is guaranteed within <b>%d</b> hatches (pity). Mutation luck: <b>+%d%%</b>", pityLeft, State.stats.mutationLuck * 100 + 0.5), {
		Size = UDim2.new(1, -8, 0, 20), TextSize = 13, TextColor3 = Theme.textDim, LayoutOrder = 0,
	})
	for i, egg in ipairs(Creatures.eggs) do
		local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 108), LayoutOrder = i })
		local orb = UI.frame(card, { BackgroundColor3 = egg.color, Size = UDim2.fromOffset(54, 66), Position = UDim2.fromOffset(12, 20) })
		UI.corner(orb, 27)
		UI.label(card, "<b>" .. egg.name .. "</b>", { Position = UDim2.fromOffset(80, 8), Size = UDim2.new(1, -300, 0, 22), TextSize = 17, TextWrapped = false })
		local total = 0
		for _, w in ipairs(egg.weights) do total += w end
		local odds = {}
		for r, w in ipairs(egg.weights) do
			if w > 0 then
				table.insert(odds, string.format("<font color='#%s'>%s %s%%</font>", Theme.rarity(r):ToHex(), Config.Rarities[r].id, tostring(math.floor(w / total * 1000 + 0.5) / 10)))
			end
		end
		UI.label(card, table.concat(odds, "   "), { Position = UDim2.fromOffset(80, 32), Size = UDim2.new(1, -300, 0, 40), TextSize = 13 })
		local req = nil
		if d.zone < egg.zone then
			req = "Requires " .. Machines.zones[egg.zone].name
		elseif egg.requiresResearch and not d.research[egg.requiresResearch] then
			req = "Research: " .. Research.byId[egg.requiresResearch].name
		end
		local price = Formulas.eggCost(egg, d.eggsRun or 0)
		UI.label(card, req or ("Price rises slightly with each egg bought this run (resets on rebirth)."), {
			Position = UDim2.fromOffset(80, 76), Size = UDim2.new(1, -300, 0, 28), TextSize = 12, TextColor3 = if req then Theme.bad else Theme.textDim,
		})
		local b = UI.button(card, "Hatch\n" .. Common.costPlain(egg.currency, price), function()
			Common.act("buyEgg", { id = egg.id }, function(ok, _, data) if ok and data then Common.reveal(data) end end, true)
		end, { Position = UDim2.new(1, -200, 0.5, -28), Size = UDim2.fromOffset(190, 56) })
		UI.setDisabled(b, req ~= nil or State.value(egg.currency) < price)
	end
end

local function fusionTab(area)
	local d, st = State.data, State.stats
	local have = {}
	for _, c in pairs(d.creatures) do have[c.sp] = (have[c.sp] or 0) + 1 end
	local scroll = UI.scroll(area, { Name = "Scroll" })
	UI.label(scroll, "Fusing consumes your lowest-level, least-mutated copies first. The result may inherit the best mutation among the ingredients, and fusion has boosted mutation luck. Mythic creatures can only be fused!", {
		Size = UDim2.new(1, -8, 0, 40), TextSize = 13, TextColor3 = Theme.textDim, LayoutOrder = 0,
	})
	for i, r in ipairs(Creatures.recipes) do
		local res = Creatures.byId[r.result]
		local ok = true
		local parts = {}
		for sp, n in pairs(r.inputs) do
			local def = Creatures.byId[sp]
			local h = have[sp] or 0
			if h < n then ok = false end
			table.insert(parts, string.format("%dx <font color='#%s'>%s</font> <font color='#%s'>(have %d)</font>", n, Theme.rarity(def.rarity):ToHex(), def.name, (h >= n and Theme.good or Theme.bad):ToHex(), h))
		end
		table.sort(parts)
		local cost = math.ceil(r.cost * (1 - st.fusionDiscount))
		local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 64), LayoutOrder = i })
		UI.label(card, table.concat(parts, "  +  "), { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -230, 0, 26), TextSize = 13 })
		UI.label(card, string.format("=> <b><font color='#%s'>%s</font></b> (%s)", Theme.rarity(res.rarity):ToHex(), res.name, Config.Rarities[res.rarity].id), {
			Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -230, 0, 22), TextSize = 15, TextWrapped = false,
		})
		local b = UI.button(card, "Fuse\n" .. Common.costPlain("biomass", cost), function()
			Common.act("fuse", { recipe = r.id }, function(success, _, data) if success and data then Common.reveal(data) end end, true)
		end, { Position = UDim2.new(1, -150, 0.5, -24), Size = UDim2.fromOffset(140, 48) })
		UI.setDisabled(b, not ok or State.value("biomass") < cost)
	end
end

local function storeTab(area)
	local d = State.data
	local scroll = UI.scroll(area, { Name = "Scroll" })
	UI.label(scroll, "Everything here is optional. Core progression never requires Robux; passes are convenience or cosmetic only.", {
		Size = UDim2.new(1, -8, 0, 22), TextSize = 13, TextColor3 = Theme.textDim, LayoutOrder = 0,
	})
	local order = 1
	local function item(kind, it)
		local owned = kind == "pass" and d.owned[it.key]
		local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 62), LayoutOrder = order })
		order += 1
		UI.label(card, "<b>" .. it.name .. "</b>", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 22), TextSize = 16, TextWrapped = false })
		UI.label(card, it.desc, { Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -170, 0, 28), TextSize = 12, TextColor3 = Theme.textDim })
		local label = if owned then "Owned" elseif it.id == 0 then "Coming soon" else "Buy (R$)"
		local b = UI.button(card, label, function()
			Common.act(kind == "pass" and "buyPass" or "buyProduct", { key = it.key })
		end, { Position = UDim2.new(1, -150, 0.5, -16), Size = UDim2.fromOffset(140, 32), color = Theme.info })
		UI.setDisabled(b, owned or it.id == 0)
	end
	for _, g in ipairs(Monetization.gamepasses) do item("pass", g) end
	for _, g in ipairs(Monetization.products) do item("product", g) end

	UI.label(scroll, "<b>Factory theme</b> (cosmetic)", { Size = UDim2.new(1, -8, 0, 24), LayoutOrder = order + 1, TextSize = 16 })
	local row = UI.frame(scroll, { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 40), LayoutOrder = order + 2 })
	UI.listLayout(row, 8, Enum.FillDirection.Horizontal)
	for id, th in pairs(Monetization.themes) do
		local unlocked = th.requires == nil or d.owned[th.requires]
		local b = UI.button(row, th.name .. (d.theme == id and " (active)" or ""), function() Common.act("setTheme", { theme = id }) end, {
			Size = UDim2.fromOffset(170, 34), color = th.accent,
		})
		UI.setDisabled(b, not unlocked or d.theme == id, if not unlocked then th.name .. " (locked)" else nil)
	end
end

function Page.render(content)
	tabs(content)
	local area = UI.frame(content, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42) })
	if tab == "eggs" then eggsTab(area) elseif tab == "fusion" then fusionTab(area) else storeTab(area) end
end

return Page
