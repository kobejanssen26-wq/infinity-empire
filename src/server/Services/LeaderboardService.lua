--!nonstrict
-- Global leaderboards via OrderedDataStores. Writes are throttled; reads are cached and broadcast.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = require(script.Parent.Parent.Logic.Shared)
local Config, Quests = Shared.Config, Shared.Quests

local LeaderboardService = {}

LeaderboardService.boards = {
	{ id = "cash", name = "Lifetime Cash", store = "LB_LifetimeCash_v1", value = function(p: any): number return math.floor(p.lifetimeCash) end },
	{ id = "rebirths", name = "Rebirths", store = "LB_Rebirths_v1", value = function(p: any): number return p.rebirths end },
	{ id = "collection", name = "Collection", store = "LB_Collection_v1", value = function(p: any): number return Quests.getStat(p, "discoveries") end },
}

local stores: { [string]: OrderedDataStore } = {}
for _, b in ipairs(LeaderboardService.boards) do
	stores[b.id] = DataStoreService:GetOrderedDataStore(b.store)
end

local cache: { [string]: { { name: string, userId: number, value: number } } } = {}
local nameCache: { [number]: string } = {}
local lastWrite: { [Player]: number } = {}

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok then name else ("User " .. userId)
	return nameCache[userId]
end

function LeaderboardService.write(player: Player, p: any)
	local last = lastWrite[player]
	if last and os.clock() - last < Config.LeaderboardWriteSeconds * 0.9 then
		return
	end
	lastWrite[player] = os.clock()
	for _, b in ipairs(LeaderboardService.boards) do
		local v = math.clamp(b.value(p), 0, Config.MaxValue)
		if v > 0 then
			local ok, err = pcall(function()
				stores[b.id]:SetAsync(tostring(player.UserId), v)
			end)
			if not ok then
				warn("[Leaderboard] write failed: " .. tostring(err))
			end
		end
	end
end

function LeaderboardService.forget(player: Player)
	lastWrite[player] = nil
end

function LeaderboardService.refresh()
	for _, b in ipairs(LeaderboardService.boards) do
		local ok, pages = pcall(function()
			return stores[b.id]:GetSortedAsync(false, Config.LeaderboardSize)
		end)
		if ok then
			local rows = {}
			for _, entry in ipairs(pages:GetCurrentPage()) do
				local userId = tonumber(entry.key)
				if userId then
					table.insert(rows, { name = nameFor(userId), userId = userId, value = entry.value })
				end
			end
			cache[b.id] = rows
		else
			warn("[Leaderboard] read failed: " .. tostring(pages))
		end
	end
end

function LeaderboardService.snapshot(): any
	local out = {}
	for _, b in ipairs(LeaderboardService.boards) do
		table.insert(out, { id = b.id, name = b.name, rows = cache[b.id] or {} })
	end
	return out
end

return LeaderboardService
