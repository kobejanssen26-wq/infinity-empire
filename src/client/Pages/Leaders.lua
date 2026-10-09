--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared:WaitForChild("Quests"))
local Format = require(Shared:WaitForChild("Format"))

local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Common = require(script.Parent.Parent.Common)

local Page = { id = "leaders", title = "Ranks" }
local boardId = "cash"
local requestedAt = -1000

local function statsCard(scroll, d)
	local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 })
	UI.padding(card, 10)
	UI.listLayout(card, 3)
	UI.label(card, "<b>Your statistics</b>", { Size = UDim2.new(1, 0, 0, 22), TextSize = 17 })
	local achievements = 0
	for _ in pairs(d.achievements) do achievements += 1 end
	local lines = {
		{ "Lifetime cash", Format.number(d.lifetimeCash) }, { "Cash this run", Format.number(d.runCash) },
		{ "Rebirths", tostring(d.rebirths) }, { "Eggs hatched", Format.number(d.stats.hatched) },
		{ "Fusions", Format.number(d.stats.fused) }, { "Machine upgrades", Format.number(d.stats.machineUpgrades) },
		{ "Variants discovered", tostring(Quests.getStat(d, "discoveries")) }, { "Achievements", tostring(achievements) .. " / " .. #Quests.achievements },
		{ "Research bought", tostring(d.stats.researchBought) }, { "Echoes earned (lifetime)", Format.number(d.echoesEarned) },
	}
	local grid = UI.frame(card, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	local g = UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 20), CellPadding = UDim2.fromOffset(6, 2) }, grid)
	for _, l in ipairs(lines) do
		UI.label(grid, string.format("%s: <b>%s</b>", l[1], l[2]), { TextSize = 13, TextWrapped = false })
	end
end

function Page.render(content)
	local d = State.data
	if os.clock() - requestedAt > 45 then
		requestedAt = os.clock()
		Common.act("leaderboards", {}, nil, true)
	end
	local scroll = UI.scroll(content, { Name = "Scroll" })
	statsCard(scroll, d)

	-- tabs
	local tabs = UI.frame(scroll, { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 34), LayoutOrder = 2 })
	UI.listLayout(tabs, 6, Enum.FillDirection.Horizontal)
	local boards = State.leaderboards
	if #boards == 0 then
		UI.label(scroll, "Loading global rankings...", { Size = UDim2.new(1, -8, 0, 24), LayoutOrder = 3, TextColor3 = Theme.textDim })
	end
	for _, b in ipairs(boards) do
		UI.button(tabs, b.name, function() boardId = b.id Common.refresh() end, {
			Size = UDim2.fromOffset(140, 30), color = if boardId == b.id then Theme.accent else Theme.cardHi, textColor = if boardId == b.id then nil else Theme.text,
		})
	end
	local online = {}
	for _, plr in ipairs(Players:GetPlayers()) do online[plr.UserId] = plr end
	for _, b in ipairs(boards) do
		if b.id == boardId then
			for rank, row in ipairs(b.rows) do
				local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 36), LayoutOrder = 10 + rank, BackgroundColor3 = if row.userId == Players.LocalPlayer.UserId then Theme.cardHi else Theme.card })
				UI.label(card, "#" .. rank, { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(44, 36), Font = Theme.fontBold, TextColor3 = if rank <= 3 then Theme.accent else Theme.textDim, TextWrapped = false })
				UI.label(card, row.name, { Position = UDim2.fromOffset(56, 0), Size = UDim2.new(0.5, -60, 1, 0), TextWrapped = false })
				UI.label(card, Format.number(row.value), { Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.25, 0, 1, 0), Font = Theme.fontBold, TextWrapped = false })
			end
		end
	end

	-- players in this server -> visit
	UI.label(scroll, "<b>Players in this server</b> (visiting is view-only)", { Size = UDim2.new(1, -8, 0, 26), TextSize = 17, LayoutOrder = 100 })
	local n = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		n += 1
		local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 100 + n })
		UI.label(card, plr.DisplayName .. (plr == Players.LocalPlayer and " (you)" or ""), { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -150, 1, 0), TextWrapped = false })
		if plr == Players.LocalPlayer then
			UI.button(card, "Go home", function() Common.act("home") end, { Position = UDim2.new(1, -120, 0.5, -15), Size = UDim2.fromOffset(110, 30), color = Theme.good })
		else
			UI.button(card, "Visit", function() Common.act("visit", { userId = plr.UserId }) end, { Position = UDim2.new(1, -120, 0.5, -15), Size = UDim2.fromOffset(110, 30), color = Theme.info })
		end
	end
end

return Page
