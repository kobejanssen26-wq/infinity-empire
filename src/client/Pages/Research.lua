--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Research = require(Shared:WaitForChild("Research"))
local Format = require(Shared:WaitForChild("Format"))

local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Common = require(script.Parent.Parent.Common)

local Page = { id = "research", title = "Research" }

-- Mirrors Engine.researchStatus for display only; the server re-validates every purchase.
local function status(d, node)
	if d.research[node.id] then return "owned" end
	for _, ex in ipairs(node.exclusive or {}) do
		if d.research[ex] then return "excluded", "Locked out by " .. Research.byId[ex].name end
	end
	for _, r in ipairs(node.requires or {}) do
		if not d.research[r] then return "locked", "Requires " .. Research.byId[r].name end
	end
	if node.anyOf then
		local any = false
		for _, r in ipairs(node.anyOf) do if d.research[r] then any = true end end
		if not any then return "locked", "Requires " .. Research.byId[node.anyOf[1]].name .. " or " .. Research.byId[node.anyOf[2]].name end
	end
	return "available"
end

function Page.render(content)
	local d = State.data
	UI.label(content, string.format("Cores: %s   |   Research persists through rebirth. Some nodes are <b>exclusive</b> - choose your specialization!", Common.money("cores", State.value("cores"))), {
		Size = UDim2.new(1, 0, 0, 22), TextSize = 13,
	})
	local scroll = UI.scroll(content, { Name = "Scroll", Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26) })
	for bi, branch in ipairs(Research.branches) do
		local head = UI.label(scroll, string.format("<font color='#%s'><b>%s</b></font>", branch.color:ToHex(), branch.name), { Size = UDim2.new(1, -8, 0, 26), TextSize = 18, LayoutOrder = bi * 100 })
		local n = 0
		for _, node in ipairs(Research.nodes) do
			if node.branch == branch.id then
				n += 1
				local s, why = status(d, node)
				local card = UI.card(scroll, { Size = UDim2.new(1, -8, 0, 62), LayoutOrder = bi * 100 + n, BackgroundColor3 = if s == "owned" then Color3.fromRGB(28, 56, 44) else Theme.card })
				if s == "owned" or s == "available" then UI.stroke(card, branch.color, 1.5) end
				UI.label(card, "<b>" .. node.name .. "</b>" .. (s == "owned" and "  (researched)" or ""), { Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -170, 0, 20), TextSize = 15, TextWrapped = false })
				UI.label(card, node.desc, { Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -170, 0, 32), TextSize = 12, TextColor3 = Theme.textDim })
				if s ~= "owned" then
					local b = UI.button(card, "", function() Common.act("buyResearch", { id = node.id }) end, { Position = UDim2.new(1, -150, 0.5, -22), Size = UDim2.fromOffset(140, 44) })
					if s == "available" then
						b.Text = Format.number(node.cost) .. " Cores"
						UI.setDisabled(b, State.value("cores") < node.cost)
					else
						b.Text = why
						b.TextSize = 11
						UI.setDisabled(b, true)
					end
				end
			end
		end
	end
end

return Page
