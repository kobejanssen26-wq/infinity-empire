--!nonstrict
-- ECLIPSE: INFINITE EMPIRE - client bootstrap: HUD, navigation, page manager, server notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Quests = require(Shared:WaitForChild("Quests"))
local Format = require(Shared:WaitForChild("Format"))
local Creatures = require(Shared:WaitForChild("Creatures"))

local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Common = require(script.Parent.Common)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local pageModules = {
	require(script.Parent.Pages.Factory),
	require(script.Parent.Pages.Creatures),
	require(script.Parent.Pages.Eggs),
	require(script.Parent.Pages.Research),
	require(script.Parent.Pages.Rebirth),
	require(script.Parent.Pages.QuestsPage),
	require(script.Parent.Pages.Index),
	require(script.Parent.Pages.Leaders),
	require(script.Parent.Pages.Settings),
}

----------------------------------------------------------------------------------------------------
-- Root + responsive scale
----------------------------------------------------------------------------------------------------

local gui = UI.new("ScreenGui", {
	Name = "EclipseUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
}, playerGui)
local root = UI.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
local uiScale = UI.new("UIScale", { Scale = 1 }, root)
Common.layer = root

local function rescale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	local s = math.clamp(math.min(vp.X / 1100, vp.Y / 650), 0.5, 1.15)
	uiScale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
	Common.scale = s
end
rescale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

----------------------------------------------------------------------------------------------------
-- Top bar: resource chips
----------------------------------------------------------------------------------------------------

local topBar = UI.frame(root, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48) })
local topList = UI.listLayout(topBar, 8, Enum.FillDirection.Horizontal)
topList.HorizontalAlignment = Enum.HorizontalAlignment.Center
topList.VerticalAlignment = Enum.VerticalAlignment.Center

local chips = {}
for _, r in ipairs(Config.Resources) do
	local chip = UI.card(topBar, { BackgroundColor3 = Theme.panel, Size = UDim2.fromOffset(168, 40) })
	UI.stroke(chip, r.color, 1.5)
	local icon = UI.frame(chip, { BackgroundColor3 = r.color, Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(7, 7) })
	UI.corner(icon, 13)
	UI.label(icon, r.icon, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(20, 20, 30), Font = Theme.fontBold, TextWrapped = false })
	local value = UI.label(chip, "0", { Position = UDim2.fromOffset(40, 2), Size = UDim2.new(1, -44, 0, 22), Font = Theme.fontBold, TextSize = 18, TextWrapped = false })
	local rate = UI.label(chip, "", { Position = UDim2.fromOffset(40, 22), Size = UDim2.new(1, -44, 0, 16), TextSize = 12, TextColor3 = Theme.textDim, TextWrapped = false })
	chips[r.id] = { value = value, rate = rate }
end

task.spawn(function()
	while true do
		if State.ready then
			for id, c in pairs(chips) do
				c.value.Text = Format.number(State.value(id))
				local r = State.rate(id)
				c.rate.Text = if id == "echoes" then string.format("+%d%% cash", State.data.echoesEarned * Config.EchoPassiveBonus * 100 + 0.5) elseif r > 0 then ("+" .. Format.rate(r) .. "/s") else ""
			end
		end
		task.wait(0.1)
	end
end)

----------------------------------------------------------------------------------------------------
-- Event chip, announcement banner, toasts
----------------------------------------------------------------------------------------------------

local eventChip = UI.card(root, {
	BackgroundColor3 = Theme.panel, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8),
	Size = UDim2.fromOffset(250, 40), Visible = false,
})
UI.stroke(eventChip, Theme.accent, 2)
local eventLabel = UI.label(eventChip, "", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 13 })

local banner = UI.card(root, {
	BackgroundColor3 = Theme.panel, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 54),
	Size = UDim2.fromOffset(560, 34), Visible = false, ZIndex = 30,
})
local bannerLabel = UI.label(banner, "", { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 31, TextSize = 14 })
local bannerToken = 0

local function showBanner(text, kind)
	bannerToken += 1
	local mine = bannerToken
	banner.Visible = true
	local c = if kind == "global" then Theme.accent elseif kind == "event" then Theme.info else Theme.good
	banner:FindFirstChildOfClass("UIStroke").Color = c
	bannerLabel.Text = text
	task.delay(7, function()
		if mine == bannerToken then banner.Visible = false end
	end)
end

local toastHost = UI.frame(root, {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -8),
	Size = UDim2.fromOffset(300, 300), ZIndex = 20,
})
local toastList = UI.listLayout(toastHost, 6)
toastList.VerticalAlignment = Enum.VerticalAlignment.Bottom
Common.toastHost = toastHost

----------------------------------------------------------------------------------------------------
-- Page panel + navigation
----------------------------------------------------------------------------------------------------

local panel = UI.card(root, {
	Name = "Panel", BackgroundColor3 = Theme.panel, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 56, 0, 56),
	Size = UDim2.new(1, -124, 1, -128), Visible = false, ZIndex = 5,
})
UI.new("UISizeConstraint", { MaxSize = Vector2.new(980, 900), MinSize = Vector2.new(300, 200) }, panel)
local header = UI.frame(panel, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), ZIndex = 6 })
local titleLabel = UI.label(header, "", { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -70, 1, 0), TextSize = Theme.size.title, Font = Theme.fontBold, ZIndex = 6, TextWrapped = false })
local content = UI.frame(panel, { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -24, 1, -56), ZIndex = 6, ClipsDescendants = true })

local currentPage = nil
local navButtons = {}

local renderRequested = false
local function renderNow()
	if not currentPage or not State.ready then return end
	-- remember scroll offsets so periodic refreshes do not jump
	local saved = {}
	for _, d in ipairs(content:GetDescendants()) do
		if d:IsA("ScrollingFrame") then
			saved[d.Name] = d.CanvasPosition
		end
	end
	for _, c in ipairs(content:GetChildren()) do
		c:Destroy()
	end
	local ok, err = pcall(currentPage.render, content)
	if not ok then
		warn("[UI] page render failed: " .. tostring(err))
		UI.label(content, "Something went wrong drawing this page.", { Size = UDim2.new(1, 0, 0, 30) })
	end
	task.defer(function()
		for _, d in ipairs(content:GetDescendants()) do
			if d:IsA("ScrollingFrame") and saved[d.Name] then
				d.CanvasPosition = saved[d.Name]
			end
		end
	end)
end

local function requestRender()
	renderRequested = true
end
Common.refresh = requestRender

local function setPage(mod)
	if currentPage == mod then
		currentPage = nil
		panel.Visible = false
	else
		currentPage = mod
		panel.Visible = true
		titleLabel.Text = mod.title
		for _, c in ipairs(content:GetChildren()) do c:Destroy() end
		renderNow()
	end
	for m, b in pairs(navButtons) do
		b.BackgroundColor3 = if m == currentPage then Theme.accent else Theme.panel
		b.TextColor3 = if m == currentPage then Color3.fromRGB(25, 20, 10) else Theme.text
	end
end
Common.openPage = function(id)
	for _, m in ipairs(pageModules) do
		if m.id == id and currentPage ~= m then setPage(m) end
	end
end

UI.button(header, "X", function() if currentPage then setPage(currentPage) end end, {
	Position = UDim2.new(1, -44, 0, 6), Size = UDim2.fromOffset(34, 32), color = Theme.cardHi, ZIndex = 7, textColor = Theme.text,
})

local nav = UI.card(root, { BackgroundColor3 = Theme.bg, Position = UDim2.fromOffset(8, 56), Size = UDim2.new(0, 100, 1, -128) })
local navScroll = UI.scroll(nav, { Size = UDim2.new(1, 0, 1, 0), ScrollBarThickness = 3 })
UI.padding(navScroll, 5)
for i, mod in ipairs(pageModules) do
	local b = UI.button(navScroll, mod.title, function() setPage(mod) end, {
		Size = UDim2.new(1, -6, 0, 38), color = Theme.panel, LayoutOrder = i, TextSize = 14,
	})
	b.TextColor3 = Theme.text
	b:SetAttribute("TextOn", Theme.text)
	navButtons[mod] = b
end

task.spawn(function()
	local sinceRender = 0
	while true do
		task.wait(0.1)
		sinceRender += 0.1
		if currentPage and State.ready and not UI.pressing and (renderRequested or sinceRender >= 1) then
			renderRequested = false
			sinceRender = 0
			renderNow()
		end
	end
end)
State.onChange(requestRender)

----------------------------------------------------------------------------------------------------
-- Objective tracker (tutorial -> next milestone)
----------------------------------------------------------------------------------------------------

local tracker = UI.card(root, {
	BackgroundColor3 = Theme.panel, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 56, 1, -8),
	Size = UDim2.fromOffset(560, 56), Visible = false, ZIndex = 4,
})
UI.stroke(tracker, Theme.accent, 1.5)
local trackTitle = UI.label(tracker, "", { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -130, 0, 20), Font = Theme.fontBold, TextWrapped = false })
local trackHint = UI.label(tracker, "", { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -130, 0, 30), TextSize = 12, TextColor3 = Theme.textDim })
local trackBtn = UI.button(tracker, "Claim", function() end, { Position = UDim2.new(1, -114, 0.5, -16), Size = UDim2.fromOffset(104, 32), color = Theme.good })
local trackQuest = nil
trackBtn.Activated:Connect(function()
	if trackQuest and not trackBtn:GetAttribute("Disabled") then
		Common.act("claimQuest", { id = trackQuest.id })
	end
end)

local function refreshTracker()
	if not State.ready then return end
	local d = State.data
	local q = Quests.tutorial[d.tutorial]
	trackQuest = q
	if not q then
		-- tutorial finished: suggest the next unclaimed milestone
		local next
		for _, m in ipairs(Quests.milestones) do
			if not d.quests.claimed[m.id] then next = m break end
		end
		if next then
			tracker.Visible = true
			local cur = Quests.getStat(d, next.stat)
			trackTitle.Text = "Goal: " .. next.name
			trackHint.Text = string.format("%s (%s / %s)", next.desc, Format.number(math.min(cur, next.target)), Format.number(next.target))
			trackQuest = next
			UI.setDisabled(trackBtn, cur < next.target, if cur < next.target then "In progress" else "Claim")
			trackBtn.Text = if cur < next.target then "In progress" else "Claim"
		else
			tracker.Visible = false
		end
		return
	end
	tracker.Visible = true
	local cur = Quests.getStat(d, q.stat)
	trackTitle.Text = string.format("Step %d/%d: %s  (%s/%s)", d.tutorial, #Quests.tutorial, q.name, Format.number(math.min(cur, q.target)), Format.number(q.target))
	trackHint.Text = if cur >= q.target then "Complete! " .. Common.rewardText(q.reward) else q.hint
	trackBtn.Text = if cur >= q.target then "Claim" else "..."
	UI.setDisabled(trackBtn, cur < q.target)
end
State.onChange(refreshTracker)
State.onTick(refreshTracker)

-- event banner chip
local function refreshEvent()
	local ev = State.data and State.data.event
	if ev then
		eventChip.Visible = true
		eventLabel.Text = string.format("<b>%s</b>\n%s", ev.name, ev.desc)
	else
		eventChip.Visible = false
	end
end
State.onChange(refreshEvent)

----------------------------------------------------------------------------------------------------
-- Server -> client notifications
----------------------------------------------------------------------------------------------------

local remotes = State.remotes
remotes.Notify.OnClientEvent:Connect(function(kind, data)
	local notifOn = not (State.data and State.data.settings and State.data.settings.notifications == false)
	if kind == "toast" then
		if notifOn or data.kind == "bad" then Common.toast(data.text, data.kind) end
	elseif kind == "reward" then
		if notifOn then Common.toast("Reward: " .. Common.rewardText(data), "gold", 3) end
	elseif kind == "discovery" then
		local def = Creatures.byId[data.sp]
		Common.toast(string.format("New discovery: %s!\nBonus: %s", Common.creatureName({ sp = data.sp, mut = data.mut }), Common.rewardText(data.reward)), "gold", 5)
	elseif kind == "achievement" then
		Common.toast(string.format("Achievement: %s\n%s", data.name, Common.rewardText(data.reward)), "gold", 5)
	elseif kind == "leaderboards" then
		State.leaderboards = data
		requestRender()
	elseif kind == "offline" then
		local gains = Common.rewardText(data.gains)
		Common.modal("Welcome back!", string.format("Your factory kept working for %s%s.\n\n%s", Format.duration(data.seconds), data.capped and " (offline cap reached - research Night Shift / Deep Storage to extend it)" or "", gains), {
			{ text = "Nice!", width = 120 },
		})
	end
end)

remotes.Announce.OnClientEvent:Connect(function(data)
	showBanner(data.text, data.kind)
end)

task.spawn(function()
	-- wait for the first state sync, then greet and open the factory
	while not State.ready do
		task.wait(0.2)
	end
	State.syncClock = os.clock()
	refreshTracker()
	refreshEvent()
end)

State.onChange(function() State.syncClock = os.clock() end)

