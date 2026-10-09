--!nonstrict
-- Persistence: session-locked DataStore profiles with retries, autosave and shutdown saving.
-- Profile shape lives in Logic/Engine.lua (newProfile / migrate). Keys starting with "_" are runtime-only.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Logic.Shared).Config
local Engine = require(script.Parent.Parent.Logic.Engine)

local STORE_NAME = "EclipseEmpire_Profiles_v1"
local LOCK_TIMEOUT = 150 -- seconds before an abandoned session lock is considered dead
-- fail fast in Studio (API access is often off there); retry patiently in live servers
local MAX_LOAD_ATTEMPTS = if RunService:IsStudio() then 2 else 8


local DataService = {}

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles: { [Player]: any } = {}
local saving: { [Player]: boolean } = {}
local ephemeral: { [Player]: boolean } = {} -- Studio fallback when DataStores are unavailable

local function keyFor(userId: number): string
	return "P_" .. userId
end

--- Deep copy without runtime-only ("_"-prefixed) keys, safe for DataStore serialisation.
local function serialize(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		if not (type(k) == "string" and k:sub(1, 1) == "_") then
			out[k] = serialize(x)
		end
	end
	return out
end
DataService.serialize = serialize

local function backoff(attempt: number)
	task.wait(math.min(2 ^ attempt, 12))
end

--- Loads (and session-locks) a player's profile. Returns profile or nil + reason.
function DataService.load(player: Player): (any?, string?)
	local key = keyFor(player.UserId)
	local lastErr = "unknown"
	for attempt = 1, MAX_LOAD_ATTEMPTS do
		if player.Parent == nil then
			return nil, "left"
		end
		local lockedByOther = false
		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(old: any)
				local now = os.time()
				old = old or {}
				local lock = old.lock
				if lock and lock.job ~= game.JobId and now - lock.t < LOCK_TIMEOUT then
					lockedByOther = true
					return nil -- cancel: another live server owns this profile
				end
				old.lock = { job = game.JobId, t = now }
				return old
			end)
		end)
		if ok and result and result.lock and result.lock.job == game.JobId then
			local now = os.time()
			local p
			if result.data then
				p = Engine.migrate(result.data, now)
			else
				p = Engine.newProfile(now)
			end
			profiles[player] = p
			return p, nil
		elseif ok and lockedByOther then
			lastErr = "locked"
		else
			lastErr = tostring(result)
		end
		backoff(attempt)
	end

	if RunService:IsStudio() and lastErr ~= "locked" then
		warn("[DataService] DataStore unavailable in Studio (" .. lastErr .. "). Using a temporary profile - progress will NOT be saved.")
		local p = Engine.newProfile(os.time())
		profiles[player] = p
		ephemeral[player] = true
		return p, nil
	end
	return nil, lastErr
end

function DataService.get(player: Player): any?
	return profiles[player]
end

function DataService.all(): { [Player]: any }
	return profiles
end

--- Saves a profile. release=true also drops the session lock. Returns success.
function DataService.save(player: Player, release: boolean?): boolean
	local p = profiles[player]
	if not p or ephemeral[player] then
		return ephemeral[player] == true
	end
	if saving[player] then
		return false -- a save is already in flight for this player
	end
	saving[player] = true
	p.lastSeen = os.time()
	local snapshot = serialize(p)
	local success = false
	for attempt = 1, 4 do
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player.UserId), function(old: any)
				old = old or {}
				if old.lock and old.lock.job ~= game.JobId and os.time() - old.lock.t < LOCK_TIMEOUT then
					error("session lock lost") -- never overwrite a profile another server owns
				end
				old.data = snapshot
				old.savedAt = os.time()
				old.lock = if release then nil else { job = game.JobId, t = os.time() }
				return old
			end)
		end)
		if ok then
			success = true
			break
		end
		warn(string.format("[DataService] save attempt %d failed for %s: %s", attempt, player.Name, tostring(err)))
		if tostring(err):find("session lock lost") then
			break
		end
		backoff(attempt)
	end
	saving[player] = nil
	return success
end

--- Saves, then forgets the player's profile (call on PlayerRemoving).
function DataService.release(player: Player)
	DataService.save(player, true)
	profiles[player] = nil
	ephemeral[player] = nil
end

function DataService.start()
	-- autosave, staggered so requests don't burst
	task.spawn(function()
		while true do
			task.wait(Config.AutoSaveSeconds)
			local list = {}
			for player in pairs(profiles) do
				table.insert(list, player)
			end
			for _, player in ipairs(list) do
				if profiles[player] then
					task.spawn(DataService.save, player, false)
				end
				task.wait(math.min(2, Config.AutoSaveSeconds / math.max(#list, 1)))
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(0.2)
		end
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				DataService.save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
