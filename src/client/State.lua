--!nonstrict
-- Client-side mirror of the server profile. Read-only: all changes happen by asking the server.
-- Rates are derived with the SAME shared Stats module the server uses, so displayed numbers match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Stats = require(Shared:WaitForChild("Stats"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local State = {}

State.data = nil
State.stats = nil
State.ready = false
State.leaderboards = {}

local listeners = {}
local tickListeners = {}
local base = { cash = 0, biomass = 0, cores = 0, echoes = 0, runCash = 0 }
local baseClock = os.clock()
local remotes = Remotes.get()
State.remotes = remotes

function State.onChange(fn)
	table.insert(listeners, fn)
end

function State.onTick(fn)
	table.insert(tickListeners, fn)
end

local function fire(list)
	for _, fn in ipairs(list) do
		task.spawn(fn)
	end
end

remotes.Sync.OnClientEvent:Connect(function(snap)
	State.data = snap
	State.stats = Stats.compute(snap, snap.event)
	for k in pairs(base) do
		base[k] = snap[k]
	end
	baseClock = os.clock()
	State.ready = true
	fire(listeners)
end)

remotes.Tick.OnClientEvent:Connect(function(t)
	if not State.data then
		return
	end
	for k, v in pairs(t) do
		base[k] = v
		State.data[k] = v
	end
	baseClock = os.clock()
	fire(tickListeners)
end)

--- Smoothly interpolated resource value (server remains authoritative).
function State.value(res)
	local v = base[res] or 0
	local rate = State.stats and State.stats.rates[res]
	if rate then
		v += rate * math.min(os.clock() - baseClock, 2)
	end
	return v
end

function State.rate(res)
	return State.stats and State.stats.rates[res] or 0
end

--- Asks the server to do something. Returns ok, message, data.
function State.request(action, args)
	local ok, res = pcall(function()
		return remotes.Request:InvokeServer(action, args or {})
	end)
	if not ok or type(res) ~= "table" then
		return false, "Connection problem", nil
	end
	return res.ok, res.msg, res.data
end

return State
