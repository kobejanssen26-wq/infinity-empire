--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Machines = require(Shared:WaitForChild("Machines"))
local Creatures = require(Shared:WaitForChild("Creatures"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local Stats = require(Shared:WaitForChild("Stats"))
local Format = require(Shared:WaitForChild("Format"))

local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Common = require(script.Parent.Parent.Common)

local Page = { id = "creatures", title = "Creatures" }

local filterFree = false
local releaseArmed = {} -- uid -> expiry clock (two-step release)

local function passiveText(def)
	if not def.passive then return "" end
	local parts = {}
	local names = {
		cashMult = "cash", biomassMult = "biomass", coreMult = "cores", mutationLuck = "mutation luck",
		upgradeDiscount = "upgrade discount",
	}
	for k, v in pairs(def.passive) do
		table.insert(parts, string.format("+%d%% %s", v * 100 + 0.5, names[k] or k))
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

function Page.render(content)
	local d, st = State.data, State.stats
	local list = {}
	local count = 0
	for uid, c in pairs(d.creatures) do
		count += 1
		if not (filterFree and c.mach) then
			table.insert(list, { uid = uid, c = c, def = Creatures.byId[c.sp] })
		end
	end
	table.sort(list, function(a, b)
		if a.def.rarity ~= b.def.rarity then return a.def.rarity > b.def.rarity end
		local ma, mb = Creatures.mutationIndex[a.c.mut], Creatures.mutationIndex[b.c.mut]
		if ma ~= mb then return ma > mb end
		if a.c.lvl ~= b.c.lvl then return a.c.lvl > b.c.lvl end
		return a.uid < b.uid
	end)

	local top = UI.frame(content, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36) })
	local capColor = if count >= st.invCap then Theme.bad else Theme.textDim
	UI.label(top, string.format("Inventory <font color='#%s'>%d / %d</font>   |   Biomass: %s", capColor:ToHex(), count, st.invCap, Common.money("biomass", State.value("biomass"))), {
		Size = UDim2.new(1, -280, 1, 0), TextWrapped = false, TextSize = 14,
	})
	UI.button(top, filterFree and "Showing: free" or "Showing: all", function() filterFree = not filterFree Common.refresh() end, {
		Position = UDim2.new(1, -270, 0, 2), Size = UDim2.fromOffset(120, 30), color = Theme.cardHi, textColor = Theme.text,
	})
	local opt = UI.button(top, "Optimize", function() Common.act("autoAssign") end, {
		Position = UDim2.new(1, -140, 0, 2), Size = UDim2.fromOffset(130, 30), color = Theme.good,
	})
	if not st.flags.autoAssign then
		UI.setDisabled(opt, true, "Optimize (locked)")
	end

	local scroll = UI.scroll(content, { Name = "Scroll", Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40) })
	for i, e in ipairs(list) do
		local c, def, uid = e.c, e.def, e.uid
		local rcol = Theme.rarity(def.rarity)
		local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 72), LayoutOrder = i })
		local bar = UI.frame(card, { BackgroundColor3 = rcol, Size = UDim2.new(0, 6, 1, -12), Position = UDim2.fromOffset(6, 6) })
		UI.corner(bar, 3)
		UI.label(card, string.format("<b>%s</b>  <font color='#%s'>%s</font>", Common.creatureName(c), Theme.textDim:ToHex(), Config.Rarities[def.rarity].id), {
			Position = UDim2.fromOffset(20, 6), Size = UDim2.new(1, -340, 0, 20), TextSize = 16, TextWrapped = false,
		})
		local trait = Creatures.traitById[c.trait]
		local el = Config.Elements[def.element]
		local power = Stats.creaturePower(c, st.creaturePower)
		UI.label(card, string.format("Lv %d  |  <font color='#%s'>%s</font>  |  power %s%s%s", c.lvl, el.color:ToHex(), el.name, Format.rate(power),
			(trait and trait.id ~= "none") and ("  |  " .. trait.name) or "", def.passive and ("  |  " .. passiveText(def)) or ""), {
			Position = UDim2.fromOffset(20, 28), Size = UDim2.new(1, -340, 0, 18), TextSize = 12, TextColor3 = Theme.textDim, TextWrapped = false,
		})
		local where = if c.mach then ("Working at " .. Machines.byId[c.mach].name) else "Idle"
		UI.label(card, where, { Position = UDim2.fromOffset(20, 48), Size = UDim2.new(1, -340, 0, 18), TextSize = 12, TextColor3 = if c.mach then Theme.good else Theme.accent, TextWrapped = false })

		local btns = UI.frame(card, { BackgroundTransparency = 1, Position = UDim2.new(1, -324, 0, 8), Size = UDim2.fromOffset(316, 56) })
		UI.listLayout(btns, 6, Enum.FillDirection.Horizontal)
		local assignBtn
		assignBtn = UI.button(btns, c.mach and "Move" or "Assign", function()
			local opts = {}
			for _, m in ipairs(Machines.list) do
				local info = st.machines[m.id]
				if info then
					local used = #info.assigned
					local compat = if m.element == def.element then "full power" else string.format("%d%%", Config.IncompatibleEfficiency * 100)
					table.insert(opts, {
						text = string.format("%s (%d/%d) - %s", m.name, used, info.slots, compat),
						disabled = used >= info.slots and c.mach ~= m.id,
						onClick = function() Common.act("assign", { uid = uid, machine = m.id }, nil, true) end,
					})
				end
			end
			if c.mach then
				table.insert(opts, { text = "Unassign", onClick = function() Common.act("assign", { uid = uid }, nil, true) end })
			end
			Common.menu(assignBtn, opts)
		end, { Size = UDim2.fromOffset(94, 56), color = Theme.info })
		local lvlBtn = UI.button(btns, "", function() Common.act("levelCreature", { uid = uid }, nil, true) end, { Size = UDim2.fromOffset(110, 56) })
		if c.lvl >= Config.CreatureMaxLevel then
			lvlBtn.Text = "MAX"
			UI.setDisabled(lvlBtn, true)
		else
			local cost = Formulas.creatureLevelCost(def.rarity, c.lvl)
			lvlBtn.Text = "Level up\n" .. Common.costPlain("biomass", cost)
			UI.setDisabled(lvlBtn, State.value("biomass") < cost)
		end
		local armed = releaseArmed[uid] and releaseArmed[uid] > os.clock()
		UI.button(btns, armed and "Sure?" or "Release", function()
			if releaseArmed[uid] and releaseArmed[uid] > os.clock() then
				releaseArmed[uid] = nil
				Common.act("release", { uid = uid })
			else
				releaseArmed[uid] = os.clock() + 4
				Common.refresh()
			end
		end, { Size = UDim2.fromOffset(84, 56), color = if armed then Theme.bad else Theme.cardHi, textColor = Theme.text })
	end
	if #list == 0 then
		UI.label(scroll, "Nothing to show. Hatch some eggs in the Eggs tab!", { Size = UDim2.new(1, 0, 0, 40), TextColor3 = Theme.textDim })
	end
end

return Page
