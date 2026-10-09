--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Machines = require(Shared:WaitForChild("Machines"))
local Creatures = require(Shared:WaitForChild("Creatures"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Format = require(Shared:WaitForChild("Format"))

local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Common = require(script.Parent.Parent.Common)

local Page = { id = "factory", title = "Factory" }

function Page.render(content)
	local d, st = State.data, State.stats
	local scroll = UI.scroll(content, { Name = "Scroll" })

	-- zone / expansion card
	local zoneCard = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 74), LayoutOrder = 0 })
	UI.padding(zoneCard, 10)
	local zone = Machines.zones[d.zone]
	local nextZone = Machines.zones[d.zone + 1]
	UI.label(zoneCard, string.format("<b>%s</b>  (Zone %d/%d)", zone.name, d.zone, #Machines.zones), { Size = UDim2.new(1, -190, 0, 22), TextSize = Theme.size.title - 2 })
	if nextZone then
		local unlocks = {}
		for _, m in ipairs(Machines.list) do
			if m.zone == nextZone.id then table.insert(unlocks, m.name) end
		end
		for _, e in ipairs(Creatures.eggs) do
			if e.zone == nextZone.id then table.insert(unlocks, e.name) end
		end
		UI.label(zoneCard, "Next: " .. nextZone.name .. " - unlocks " .. (#unlocks > 0 and table.concat(unlocks, ", ") or "more space"), {
			Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -190, 0, 34), TextColor3 = Theme.textDim, TextSize = 13,
		})
		local b = UI.button(zoneCard, "Expand", function() Common.act("expandZone") end, {
			Position = UDim2.new(1, -170, 0, 4), Size = UDim2.fromOffset(170, 52),
		})
		b.Text = "Expand\n" .. Common.costPlain("cash", nextZone.cost)
		UI.setDisabled(b, State.value("cash") < nextZone.cost)
	else
		UI.label(zoneCard, "Your factory is fully expanded. Rebirth to grow stronger!", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 24), TextColor3 = Theme.textDim })
	end

	for i, def in ipairs(Machines.list) do
		local m = d.machines[def.id]
		local el = Config.Elements[def.element]
		local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 104), LayoutOrder = i })
		local bar = UI.frame(card, { BackgroundColor3 = def.color, Size = UDim2.new(0, 6, 1, -12), Position = UDim2.fromOffset(6, 6) })
		UI.corner(bar, 3)
		local title = UI.label(card, string.format("<b>%s</b>", def.name), { Position = UDim2.fromOffset(20, 6), Size = UDim2.new(1, -300, 0, 22), TextSize = 17, TextWrapped = false })
		UI.label(card, string.format("<font color='#%s'>%s element</font>  |  makes %s", el.color:ToHex(), el.name, Common.resInfo[def.produces].name), {
			Position = UDim2.fromOffset(20, 28), Size = UDim2.new(1, -300, 0, 18), TextSize = 12, TextColor3 = Theme.textDim, TextWrapped = false,
		})
		if m then
			local info = st.machines[def.id]
			local mult = Formulas.machineLevelMult(m.level)
			local nextMult = Formulas.machineLevelMult(math.min(m.level + 1, Config.MachineMaxLevel))
			local nextRate = if mult > 0 then info.rate * nextMult / mult else info.rate
			UI.label(card, string.format("Lv <b>%d</b>  |  <font color='#%s'>+%s/s</font>  |  next level: +%s/s", m.level, Common.resInfo[def.produces].color:ToHex(), Format.rate(info.rate), Format.rate(nextRate - info.rate)), {
				Position = UDim2.fromOffset(20, 48), Size = UDim2.new(1, -300, 0, 18), TextSize = 13, TextWrapped = false,
			})
			local names = {}
			for _, uid in ipairs(info.assigned) do table.insert(names, Common.creatureName(d.creatures[uid])) end
			UI.label(card, string.format("Creatures %d/%d: %s", #info.assigned, info.slots, #names > 0 and table.concat(names, ", ") or "<i>none (assign in Creatures)</i>"), {
				Position = UDim2.fromOffset(20, 68), Size = UDim2.new(1, -300, 0, 32), TextSize = 12, TextColor3 = Theme.textDim,
			})
			local btnArea = UI.frame(card, { BackgroundTransparency = 1, Position = UDim2.new(1, -270, 0, 8), Size = UDim2.fromOffset(260, 88) })
			UI.listLayout(btnArea, 6)
			local function upgradeBtn(label, count)
				local total, n = Formulas.upgradeBulk(def.id, m.level, st.upgradeDiscount, State.value("cash"), count)
				local want = math.min(count, Config.MachineMaxLevel - m.level)
				local shownCost = total
				if n < want or n == 0 then
					shownCost = 0
					for k = 0, math.min(count, Config.MachineMaxLevel - m.level) - 1 do shownCost += Formulas.upgradeCost(def.id, m.level + k, st.upgradeDiscount) end
				end
				local b = UI.button(btnArea, "", function() Common.act("upgradeMachine", { id = def.id, count = count }, nil, true) end, { Size = UDim2.new(1, 0, 0, 40) })
				if m.level >= Config.MachineMaxLevel then
					b.Text = "MAX LEVEL"
					UI.setDisabled(b, true)
				else
					b.Text = string.format("%s: %s", label, Common.costPlain("cash", shownCost))
					UI.setDisabled(b, n < want)
				end
				return b
			end
			upgradeBtn("Upgrade x1", 1)
			upgradeBtn("Upgrade x10", 10)
		else
			local locked = d.zone < def.zone
			UI.label(card, def.desc, { Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -300, 0, 40), TextSize = 13, TextColor3 = Theme.textDim })
			local b = UI.button(card, "", function() Common.act("buyMachine", { id = def.id }) end, {
				Position = UDim2.new(1, -230, 0.5, -24), Size = UDim2.fromOffset(220, 48),
			})
			if locked then
				b.Text = "Requires " .. Machines.zones[def.zone].name
				UI.setDisabled(b, true)
			else
				b.Text = "Build\n" .. Common.costPlain("cash", def.unlockCost)
				UI.setDisabled(b, State.value("cash") < def.unlockCost)
			end
		end
	end
end

return Page
