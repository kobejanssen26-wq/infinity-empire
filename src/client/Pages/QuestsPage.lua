--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared:WaitForChild("Quests"))
local Format = require(Shared:WaitForChild("Format"))

local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Common = require(script.Parent.Parent.Common)

local Page = { id = "quests", title = "Quests" }

local order = 0
local function questRow(scroll, q, progress, claimed, canClaim, claimable)
	order += 1
	local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 66), LayoutOrder = order })
	local frac = math.clamp(progress / q.target, 0, 1)
	UI.label(card, "<b>" .. q.name .. "</b>  -  " .. q.desc, { Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -150, 0, 20), TextSize = 14, TextWrapped = false })
	local bar = UI.progress(card, frac, if frac >= 1 then Theme.good else Theme.info)
	bar.Position = UDim2.fromOffset(12, 30)
	bar.Size = UDim2.new(1, -170, 0, 8)
	UI.label(card, string.format("%s / %s   |   Reward: %s", Format.number(math.min(progress, q.target)), Format.number(q.target), Common.rewardText(q.reward)), {
		Position = UDim2.fromOffset(12, 42), Size = UDim2.new(1, -150, 0, 18), TextSize = 12, TextColor3 = Theme.textDim, TextWrapped = false,
	})
	if claimable then
		local b = UI.button(card, claimed and "Claimed" or "Claim", function() Common.act("claimQuest", { id = q.id }, nil, true) end, {
			Position = UDim2.new(1, -120, 0.5, -16), Size = UDim2.fromOffset(110, 32), color = Theme.good,
		})
		UI.setDisabled(b, claimed or not canClaim)
	end
end

local function heading(scroll, text)
	order += 1
	UI.label(scroll, "<b>" .. text .. "</b>", { Size = UDim2.new(1, -8, 0, 26), TextSize = 18, LayoutOrder = order })
end

function Page.render(content)
	local d = State.data
	order = 0
	local scroll = UI.scroll(content, { Name = "Scroll" })

	local step = Quests.tutorial[d.tutorial]
	if step then
		heading(scroll, string.format("Tutorial (step %d of %d)", d.tutorial, #Quests.tutorial))
		local cur = Quests.getStat(d, step.stat)
		questRow(scroll, step, cur, false, cur >= step.target, true)
	end

	heading(scroll, "Daily Quests")
	local dq = d.quests.daily
	for _, id in ipairs(dq.ids) do
		local q = Quests.byId[id]
		local cur = Quests.getStat(d, q.stat) - (dq.base[id] or 0)
		questRow(scroll, q, cur, dq.claimed[id] == true, cur >= q.target, true)
	end
	UI.label(scroll, "Daily quests refresh at 00:00 UTC. Different quests reward different resources - mix up how you play.", { Size = UDim2.new(1, -8, 0, 18), TextSize = 12, TextColor3 = Theme.textDim, LayoutOrder = order + 1 })
	order += 1

	heading(scroll, "Repeatable")
	for _, q in ipairs(Quests.repeatable) do
		local cur = Quests.getStat(d, q.stat) - (d.quests.repeatBase[q.id] or 0)
		questRow(scroll, q, cur, false, cur >= q.target, true)
	end

	heading(scroll, "Milestones")
	for _, q in ipairs(Quests.milestones) do
		local cur = Quests.getStat(d, q.stat)
		local claimed = d.quests.claimed[q.id] == true
		questRow(scroll, q, claimed and q.target or cur, claimed, cur >= q.target, true)
	end

	heading(scroll, "Achievements (rewards are granted automatically)")
	for _, a in ipairs(Quests.achievements) do
		local done = d.achievements[a.id] == true
		questRow(scroll, a, done and a.target or Quests.getStat(d, a.stat), done, false, false)
	end
end

return Page
