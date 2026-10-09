--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Common = require(script.Parent.Parent.Common)

local Page = { id = "settings", title = "Settings" }

local function toggle(scroll, order, title, desc, key, value, locked)
	local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 58), LayoutOrder = order })
	UI.label(card, "<b>" .. title .. "</b>", { Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -170, 0, 20), TextSize = 15, TextWrapped = false })
	UI.label(card, desc, { Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -170, 0, 28), TextSize = 12, TextColor3 = Theme.textDim })
	local b = UI.button(card, if locked then "Locked" elseif value then "ON" else "OFF", function()
		Common.act("setSetting", { key = key, value = not value }, nil, true)
	end, { Position = UDim2.new(1, -140, 0.5, -16), Size = UDim2.fromOffset(130, 32), color = if value then Theme.good else Theme.cardHi, textColor = if value then nil else Theme.text })
	UI.setDisabled(b, locked)
end

function Page.render(content)
	local d, st = State.data, State.stats
	local scroll = UI.scroll(content, { Name = "Scroll" })
	toggle(scroll, 1, "Notifications", "Reward and unlock toasts. Errors are always shown.", "notifications", d.settings.notifications ~= false, false)
	toggle(scroll, 2, "Auto-Upgrader", st.flags.autoUpgrade and "Automatically buys the cheapest affordable machine upgrade." or "Research 'Auto-Upgrader' (Automation branch) to unlock.", "autoUpgrade", d.settings.autoUpgrade == true, not st.flags.autoUpgrade)
	local home = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 58), LayoutOrder = 3 })
	UI.label(home, "<b>Teleport to my factory</b>", { Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -170, 0, 20), TextSize = 15 })
	UI.label(home, "Lost? Jump back to your plot.", { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -170, 0, 20), TextSize = 12, TextColor3 = Theme.textDim })
	UI.button(home, "Go home", function() Common.act("home") end, { Position = UDim2.new(1, -140, 0.5, -16), Size = UDim2.fromOffset(130, 32), color = Theme.info })
	UI.label(scroll, string.format("<b>%s</b>\nTips: walk up to a machine in your factory and press E to build or upgrade it. Matching a creature's element to its machine gives full power; mismatches work at %d%%. Your progress autosaves every %ds and when you leave.",
		Config.GameName, Config.IncompatibleEfficiency * 100, Config.AutoSaveSeconds), {
		Size = UDim2.new(1, -8, 0, 80), LayoutOrder = 4, TextSize = 13, TextColor3 = Theme.textDim,
	})
end

return Page
