--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Prestige = require(Shared:WaitForChild("Prestige"))
local Machines = require(Shared:WaitForChild("Machines"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Format = require(Shared:WaitForChild("Format"))

local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Common = require(script.Parent.Parent.Common)

local Page = { id = "rebirth", title = "Rebirth" }

local function bullets(parent, heading, color, lines, order)
	local box = UI.card(parent, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order })
	UI.padding(box, 10)
	UI.listLayout(box, 2)
	UI.label(box, string.format("<font color='#%s'><b>%s</b></font>", color:ToHex(), heading), { Size = UDim2.new(1, 0, 0, 20), TextSize = 16 })
	for _, l in ipairs(lines) do
		UI.label(box, "- " .. l, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 13 })
	end
end

local function lostLines(d)
	local keepZone = (d.prestige.r_zone or 0)
	return {
		"All Cash and Biomass",
		"Every machine's level, and machines beyond the Ember Forge (you rebuild them)",
		keepZone > 0 and string.format("Factory floors above zone %d (Keep Foundations keeps the rest)", 1 + keepZone) or "Factory expansions (back to the Starter Floor)",
		"Creature levels and machine assignments (the creatures themselves are kept)",
		"Egg price inflation resets (a perk, not a loss)",
	}
end

local function keptLines()
	return {
		"All creatures, your Collection Index and discoveries",
		"All Research and all Cores",
		"Echoes, Echo upgrades, achievements and quest progress",
		"Cosmetics, themes and purchases",
	}
end

function Page.render(content)
	local d = State.data
	local pv = d.preview
	local scroll = UI.scroll(content, { Name = "Scroll" })

	local head = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 128), LayoutOrder = 1 })
	UI.padding(head, 12)
	UI.label(head, string.format("<b>Rebirth #%d</b>", d.rebirths + 1), { Size = UDim2.new(1, -220, 0, 24), TextSize = 20 })
	UI.label(head, string.format("Cash earned this run: %s / %s required   |   Factory zone: %d / %d required",
		Format.number(pv.runCash), Format.number(pv.requirement), d.zone, Config.Rebirth.minZone), { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, -220, 0, 20), TextSize = 13, TextColor3 = Theme.textDim, TextWrapped = false })
	local bar = UI.progress(head, pv.runCash / pv.requirement, Theme.accent)
	bar.Position = UDim2.fromOffset(0, 54)
	bar.Size = UDim2.new(1, -220, 0, 12)
	UI.label(head, string.format("You would gain: %s  (and +%d%% cash per Echo earned, permanently)", Common.money("echoes", pv.gain), Config.EchoPassiveBonus * 100), { Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, -220, 0, 40), TextSize = 14 })
	local b = UI.button(head, "Rebirth...", function()
		local lost = table.concat(lostLines(d), "\n- ")
		local kept = table.concat(keptLines(), "\n- ")
		Common.confirm("Confirm Rebirth", string.format("<b>You will gain:</b> %d Echoes\n\n<b>You will lose:</b>\n- %s\n\n<b>You keep:</b>\n- %s\n\nThis cannot be undone.", pv.gain, lost, kept), "Rebirth now", function()
			Common.act("rebirth", { confirm = true })
		end)
	end, { Position = UDim2.new(1, -200, 0.5, -26), Size = UDim2.fromOffset(190, 52), color = Theme.bad, textColor = Color3.new(1, 1, 1) })
	UI.setDisabled(b, not pv.can, if pv.can then nil else (pv.reason or "Not yet"))
	if pv.can then b.TextColor3 = Color3.new(1, 1, 1) end

	bullets(scroll, "You will lose", Theme.bad, lostLines(d), 2)
	bullets(scroll, "You keep", Theme.good, keptLines(), 3)

	UI.label(scroll, string.format("<b>Echo Upgrades</b>   Echoes: %s", Common.money("echoes", d.echoes)), { Size = UDim2.new(1, -8, 0, 28), TextSize = 18, LayoutOrder = 10 })
	for i, u in ipairs(Prestige.upgrades) do
		local lvl = d.prestige[u.id] or 0
		local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 58), LayoutOrder = 10 + i })
		UI.label(card, string.format("<b>%s</b>  Lv %d/%d", u.name, lvl, u.max), { Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -170, 0, 20), TextSize = 15, TextWrapped = false })
		UI.label(card, u.desc, { Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -170, 0, 28), TextSize = 12, TextColor3 = Theme.textDim })
		local btn = UI.button(card, "", function() Common.act("buyPrestige", { id = u.id }) end, { Position = UDim2.new(1, -150, 0.5, -20), Size = UDim2.fromOffset(140, 40) })
		if lvl >= u.max then
			btn.Text = "MAX"
			UI.setDisabled(btn, true)
		else
			local cost = Formulas.prestigeCost(u, lvl)
			btn.Text = cost .. " Echoes"
			UI.setDisabled(btn, d.echoes < cost)
		end
	end
	UI.label(scroll, "<i>Advanced Prestige and Dimensions are designed as future layers on top of this system and are not part of this release.</i>", {
		Size = UDim2.new(1, -8, 0, 36), TextSize = 12, TextColor3 = Theme.textDim, LayoutOrder = 100,
	})
end

return Page
