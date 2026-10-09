--!nonstrict
-- Small immediate-style UI toolkit on top of Roblox GuiObjects (no external deps).

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local UI = {}

UI.pressing = false
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		UI.pressing = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		UI.pressing = false
	end
end)

function UI.new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

function UI.corner(inst, radius)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, inst)
end

function UI.stroke(inst, color, thickness)
	return UI.new("UIStroke", { Color = color or Theme.stroke, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
end

function UI.padding(inst, px)
	return UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
	}, inst)
end

function UI.listLayout(inst, gap, direction)
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, gap or 6),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, inst)
end

function UI.frame(parent, props)
	local p = { BackgroundColor3 = Theme.card, BorderSizePixel = 0 }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return UI.new("Frame", p, parent)
end

function UI.card(parent, props)
	local f = UI.frame(parent, props)
	UI.corner(f, 10)
	UI.stroke(f)
	return f
end

function UI.label(parent, text, props)
	local p = {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Theme.text,
		Font = Theme.font,
		TextSize = Theme.size.body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return UI.new("TextLabel", p, parent)
end

function UI.setDisabled(btn, disabled, reason)
	btn:SetAttribute("Disabled", disabled)
	local base = btn:GetAttribute("BaseColor") or Theme.accent
	btn.BackgroundColor3 = if disabled then Theme.disabled else base
	btn.TextColor3 = if disabled then Theme.textDim else (btn:GetAttribute("TextOn") or Color3.fromRGB(25, 20, 10))
	if reason then
		btn.Text = reason
	end
end

--- onClick runs only when not disabled. props.color changes the base colour.
function UI.button(parent, text, onClick, props)
	local color = props and props.color or Theme.accent
	local textOn = props and props.textColor or Color3.fromRGB(25, 20, 10)
	local p = {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Text = text,
		TextColor3 = textOn,
		Font = Theme.fontBold,
		TextSize = Theme.size.body,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(100, 32),
		TextWrapped = true,
	}
	for k, v in pairs(props or {}) do
		if k ~= "color" and k ~= "textColor" then
			p[k] = v
		end
	end
	local btn = UI.new("TextButton", p, parent)
	btn:SetAttribute("BaseColor", color)
	btn:SetAttribute("TextOn", textOn)
	UI.corner(btn, 8)
	btn.MouseEnter:Connect(function()
		if not btn:GetAttribute("Disabled") then
			btn.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.18)
		end
	end)
	btn.MouseLeave:Connect(function()
		if not btn:GetAttribute("Disabled") then
			btn.BackgroundColor3 = color
		end
	end)
	btn.Activated:Connect(function()
		if btn:GetAttribute("Disabled") then
			return
		end
		onClick()
	end)
	return btn
end

function UI.scroll(parent, props)
	local p = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local s = UI.new("ScrollingFrame", p, parent)
	UI.listLayout(s, 8)
	return s
end

function UI.progress(parent, frac, color, props)
	local bar = UI.frame(parent, { BackgroundColor3 = Theme.bg, Size = UDim2.new(1, 0, 0, 10) })
	for k, v in pairs(props or {}) do
		bar[k] = v
	end
	UI.corner(bar, 5)
	local fill = UI.frame(bar, { BackgroundColor3 = color or Theme.good, Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1) })
	UI.corner(fill, 5)
	return bar
end

function UI.tween(inst, info, goal)
	local t = TweenService:Create(inst, info, goal)
	t:Play()
	return t
end

--- A tag/pill label.
function UI.pill(parent, text, color, props)
	local l = UI.label(parent, text, {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 0.7,
		BackgroundColor3 = color,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5),
		Font = Theme.fontBold,
		TextSize = Theme.size.small,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(0, 20),
	})
	if props then
		for k, v in pairs(props) do l[k] = v end
	end
	l.Parent = parent
	UI.corner(l, 10)
	UI.padding(l, 5)
	return l
end

function UI.hex(c)
	return c:ToHex()
end

return UI
