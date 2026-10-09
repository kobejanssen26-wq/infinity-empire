--!nonstrict
-- Robux purchases. Grants happen ONLY here, on the server, from Roblox's own receipt / pass events.
-- Items whose id is 0 in Shared/Monetization.lua are treated as "not configured" and cannot be bought.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = require(script.Parent.Parent.Logic.Shared)
local Engine = require(script.Parent.Parent.Logic.Engine)
local Monetization = Shared.Monetization
local DataService = require(script.Parent.DataService)
local Session = require(script.Parent.Session)

local PurchaseService = {}

local function passByKey(key: any): any?
	for _, g in ipairs(Monetization.gamepasses) do
		if g.key == key then return g end
	end
	return nil
end

local function productByKey(key: any): any?
	for _, g in ipairs(Monetization.products) do
		if g.key == key then return g end
	end
	return nil
end

--- Refreshes pass ownership from Roblox (called on join). Safe when ids are unconfigured.
function PurchaseService.refreshOwnership(player: Player, p: any)
	for _, g in ipairs(Monetization.gamepasses) do
		if g.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, g.id)
			end)
			if ok and owns then
				p.owned[g.key] = true
			end
		end
	end
	Engine.invalidate(p)
end

--- Called from the validated "buyPass"/"buyProduct" remote actions. Opens Roblox's purchase prompt only.
function PurchaseService.prompt(player: Player, kind: string, key: any): (boolean, string)
	if kind == "pass" then
		local g = passByKey(key)
		if not g then return false, "Unknown item" end
		if g.id == 0 then return false, "Not available yet" end
		MarketplaceService:PromptGamePassPurchase(player, g.id)
		return true, "Opening purchase..."
	end
	local prod = productByKey(key)
	if not prod then return false, "Unknown item" end
	if prod.id == 0 then return false, "Not available yet" end
	MarketplaceService:PromptProductPurchase(player, prod.id)
	return true, "Opening purchase..."
end

function PurchaseService.start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, wasPurchased: boolean)
		if not wasPurchased then return end
		local p = DataService.get(player)
		if not p then return end
		for _, g in ipairs(Monetization.gamepasses) do
			if g.id ~= 0 and g.id == passId then
				p.owned[g.key] = true
				Engine.invalidate(p)
				Session.dirty(player)
				Session.notify(player, "toast", { text = g.name .. " unlocked. Thank you!", kind = "good" })
				task.spawn(DataService.save, player, false)
			end
		end
	end)

	MarketplaceService.ProcessReceipt = function(info: any)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local p = DataService.get(player)
		if not p then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local receiptKey = tostring(info.PurchaseId)
		if p.receipts[receiptKey] then
			return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted: idempotent
		end
		local prod
		for _, g in ipairs(Monetization.products) do
			if g.id ~= 0 and g.id == info.ProductId then prod = g end
		end
		if not prod then
			warn("[Purchase] unknown product " .. tostring(info.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		p.receipts[receiptKey] = true
		if prod.grant then
			Engine.grantReward(p, prod.grant, Session.ctx(player))
		end
		if prod.flag then
			p.owned[prod.flag] = true
		end
		Engine.invalidate(p)
		Session.dirty(player)
		-- only confirm the receipt once the grant is durably saved
		if DataService.save(player, false) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		-- keep the receipt marked: the grant is in memory, so a retry must not grant twice
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return PurchaseService
