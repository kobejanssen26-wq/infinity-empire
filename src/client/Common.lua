--!nonstrict
-- Shared client helpers: formatting, toasts, modals and server-action wrappers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Creatures = require(Shared:WaitForChild("Creatures"))
local Format = require(Shared:WaitForChild("Format"))

local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)

local Common = {}

Common.layer = nil -- ScreenGui root frame, assigned by Main
Common.toastHost = nil

local resInfo = {}
for _, r in ipairs(Config.Resources) do
	resInfo[r.id] = r
end
Common.resInfo = resInfo

function Common.money(res, amount)
	local info = resInfo[res]
	return string.format("<font color='#%s'>%s %s</font>", info.color:ToHex(), Format.number(amount), info.name)
end

--- Cost text coloured green if affordable, red if not.
function Common.cost(res, amount)
	local have = State.value(res)
	local col = if have >= amount then Theme.good else Theme.bad
	return string.format("<font color='#%s'>%s %s</font>", col:ToHex(), Format.number(amount), resInfo[res].name)
end

--- Plain cost for use inside buttons (the button's own enabled/disabled colour shows affordability).
function Common.costPlain(res, amount)
	return string.format("%s %s", Format.number(amount), resInfo[res].name)
end

function Common.rewardText(reward)
	local parts = {}
	for _, r in ipairs(Config.Resources) do
		if reward[r.id] and reward[r.id] > 0 then
			table.insert(parts, Common.money(r.id, reward[r.id]))
		end
	end
	return table.concat(parts, "  ")
end

function Common.creatureName(c)
	local def = Creatures.byId[c.sp]
	local mut = Creatures.mutations[Creatures.mutationIndex[c.mut] or 1]
	local col = Theme.rarity(def.rarity)
	local prefix = if c.mut ~= "normal" then string.format("<font color='#%s'>%s</font> ", mut.color:ToHex(), mut.name) else ""
	return string.format("%s<font color='#%s'>%s</font>", prefix, col:ToHex(), def.name)
end

----------------------------------------------------------------------------------------------------
-- Toasts
----------------------------------------------------------------------------------------------------

function Common.toast(text, kind, duration)
	local host = Common.toastHost
	if not host then
		return
	end
	local color = if kind == "good" then Theme.good elseif kind == "bad" then Theme.bad elseif kind == "gold" then Theme.accent else Theme.info
	local t = UI.card(host, { BackgroundColor3 = Theme.panel, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	UI.stroke(t, color, 2)
	UI.padding(t, 8)
	UI.label(t, text, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left })
	task.delay(duration or 3.5, function()
		if t.Parent then
			t:Destroy()
		end
	end)
	-- keep the stack short
	local kids = {}
	for _, c in ipairs(host:GetChildren()) do
		if c:IsA("Frame") then table.insert(kids, c) end
	end
	while #kids > 5 do
		table.remove(kids, 1):Destroy()
	end
end

--- Server action with toast feedback. onDone(ok, msg, data) optional.
function Common.act(action, args, onDone, silentSuccess)
	task.spawn(function()
		local ok, msg, data = State.request(action, args)
		if not ok then
			Common.toast(msg or "Failed", "bad")
		elseif not silentSuccess and msg and msg ~= "" then
			Common.toast(msg, "good", 2)
		end
		if onDone then
			onDone(ok, msg, data)
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Modals
----------------------------------------------------------------------------------------------------

function Common.modal(title, bodyText, buttons, width)
	local overlay = UI.frame(Common.layer, {
		Name = "Modal", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1), ZIndex = 50, Active = true,
	})
	local box = UI.card(overlay, {
		BackgroundColor3 = Theme.panel, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, width or 460, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 51,
	})
	UI.stroke(box, Theme.accent, 2)
	UI.padding(box, 16)
	local list = UI.listLayout(box, 10)
	UI.label(box, title, { Size = UDim2.new(1, 0, 0, 28), TextSize = Theme.size.title, Font = Theme.fontBold, ZIndex = 52 })
	UI.label(box, bodyText, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 52 })
	local row = UI.frame(box, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), ZIndex = 52 })
	UI.listLayout(row, 8, Enum.FillDirection.Horizontal)
	row.ChildAdded:Connect(function() end)
	for _, b in ipairs(buttons) do
		UI.button(row, b.text, function()
			overlay:Destroy()
			if b.onClick then b.onClick() end
		end, { color = b.color or Theme.accent, Size = UDim2.fromOffset(b.width or 130, 34), ZIndex = 53 })
	end
	return overlay
end

function Common.confirm(title, body, yesText, onYes)
	Common.modal(title, body, {
		{ text = yesText or "Confirm", color = Theme.bad, onClick = onYes, width = 170 },
		{ text = "Cancel", color = Theme.cardHi },
	}, 520)
end

--- Egg / fusion reveal card.
function Common.reveal(d)
	local def = Creatures.byId[d.sp]
	local rcol = Theme.rarity(def.rarity)
	local mut = Creatures.mutations[Creatures.mutationIndex[d.mut] or 1]
	local trait = Creatures.traitById[d.trait]
	local card = UI.card(Common.layer, {
		BackgroundColor3 = Theme.panel, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(280, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 40,
	})
	UI.stroke(card, rcol, 3)
	UI.padding(card, 14)
	UI.listLayout(card, 4)
	local holder = UI.frame(card, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 90), ZIndex = 41, LayoutOrder = 1 })
	local orb = UI.frame(holder, {
		BackgroundColor3 = if d.mut ~= "normal" then mut.color else rcol, Size = UDim2.fromOffset(72, 72), ZIndex = 41,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	})
	UI.corner(orb, 36)
	local center = Enum.TextXAlignment.Center
	UI.label(card, Common.creatureName({ sp = d.sp, mut = d.mut }), { Size = UDim2.new(1, 0, 0, 26), TextSize = Theme.size.title, Font = Theme.fontBold, TextXAlignment = center, ZIndex = 41, LayoutOrder = 2 })
	UI.label(card, string.format("%s  |  %s%s", Config.Rarities[def.rarity].id, def.element:sub(1, 1):upper() .. def.element:sub(2), (trait and trait.id ~= "none") and ("  |  " .. trait.name) or ""), { Size = UDim2.new(1, 0, 0, 20), TextColor3 = Theme.textDim, TextXAlignment = center, ZIndex = 41, LayoutOrder = 3 })
	if d.isNew then
		UI.label(card, "NEW DISCOVERY!", { Size = UDim2.new(1, 0, 0, 22), TextColor3 = Theme.accent, Font = Theme.fontBold, TextXAlignment = center, ZIndex = 41, LayoutOrder = 4 })
	end
	UI.tween(orb, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(84, 84) })
	task.delay(2.6, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

--- Popup menu anchored near a button.
function Common.menu(anchor, options)
	local overlay = UI.new("TextButton", {
		Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60, AutoButtonColor = false,
	}, Common.layer)
	local box = UI.card(overlay, { BackgroundColor3 = Theme.panel, Size = UDim2.fromOffset(200, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 61 })
	UI.padding(box, 6)
	UI.listLayout(box, 4)
	local layerAbs = Common.layer.AbsolutePosition
	local scale = Common.scale or 1
	local abs = anchor.AbsolutePosition
	local x = (abs.X - layerAbs.X) / scale - 100 + (anchor.AbsoluteSize.X / scale) / 2
	local y = (abs.Y - layerAbs.Y) / scale + anchor.AbsoluteSize.Y / scale + 4
	box.Position = UDim2.fromOffset(math.max(8, x), y)
	for _, o in ipairs(options) do
		local b = UI.button(box, o.text, function()
			overlay:Destroy()
			o.onClick()
		end, { Size = UDim2.new(1, 0, 0, 30), color = Theme.cardHi, TextColor3 = Theme.text, ZIndex = 62 })
		b.TextColor3 = Theme.text
		b:SetAttribute("TextOn", Theme.text)
		if o.disabled then UI.setDisabled(b, true) end
	end
	overlay.Activated:Connect(function()
		overlay:Destroy()
	end)
end

return Common
