--!nonstrict
-- A permissive fake of the Roblox runtime, good enough to EXECUTE the real server and client scripts
-- (Instances, services, signals, tasks, DataStores). It cannot validate rendering or true engine behaviour;
-- it catches runtime errors, nil-index typos, bad logic flow and persistence round-trips.
local M = {}

M.errors = {}
M.logs = {}
M.isServer = true
local function logError(where, err)
	table.insert(M.errors, where .. ": " .. tostring(err))
end

----------------------------------------------------------------------------------------------------
-- "Any": a value that tolerates everything (used for unmodelled engine types)
----------------------------------------------------------------------------------------------------
local Any
do
	local mt = {}
	mt.__index = function() return Any end
	mt.__call = function() return Any end
	mt.__newindex = function() end
	for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__unm", "__idiv", "__pow" }) do
		mt[op] = function() return Any end
	end
	mt.__concat = function(a, b) return tostring(a) .. tostring(b) end
	mt.__lt = function() return false end
	mt.__le = function() return false end
	mt.__len = function() return 0 end
	mt.__tostring = function() return "<any>" end
	Any = setmetatable({}, mt)
end
M.Any = Any

----------------------------------------------------------------------------------------------------
-- virtual time + task library
----------------------------------------------------------------------------------------------------
local now = 0
local sleepers = {}
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		logError("task", debug.traceback(co, tostring(err)))
	end
end
local task = {}
function task.spawn(f, ...)
	local co = coroutine.create(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local args = table.pack(...)
	table.insert(sleepers, { t = now, co = coroutine.create(function() f(table.unpack(args, 1, args.n)) end) })
end
function task.delay(t, f, ...)
	local args = table.pack(...)
	table.insert(sleepers, { t = now + t, co = coroutine.create(function() f(table.unpack(args, 1, args.n)) end) })
end
function task.wait(t)
	local co, isMain = coroutine.running()
	if isMain then error("task.wait called from main thread in harness") end
	table.insert(sleepers, { t = now + (t or 0.03), co = co })
	coroutine.yield()
	return t or 0.03
end
M.task = task

----------------------------------------------------------------------------------------------------
-- signals
----------------------------------------------------------------------------------------------------
local function newSignal()
	local s = { cbs = {} }
	function s:Connect(f)
		table.insert(self.cbs, f)
		return { Disconnect = function() end }
	end
	s.Once = s.Connect
	function s:Wait() return end
	function s:Fire(...)
		for _, f in ipairs(self.cbs) do
			task.spawn(f, ...)
		end
	end
	return s
end
M.newSignal = newSignal

local signalNames = {}
for _, n in ipairs({
	"PlayerAdded", "PlayerRemoving", "CharacterAdded", "Heartbeat", "RenderStepped", "Triggered", "Activated", "MouseEnter",
	"MouseLeave", "OnClientEvent", "InputBegan", "InputEnded", "PromptGamePassPurchaseFinished", "ChildAdded",
	"Changed", "Touched", "MouseButton1Click", "FocusLost", "Destroying", "Died",
}) do signalNames[n] = true end

----------------------------------------------------------------------------------------------------
-- datatypes
----------------------------------------------------------------------------------------------------
local Vector3MT = {}
Vector3MT.__index = Vector3MT
local function v3(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, Vector3MT) end
Vector3MT.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3MT.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3MT.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end

local Color3MT = {}
Color3MT.__index = Color3MT
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b }, Color3MT) end
function Color3MT:ToHex()
	local function h(v) return string.format("%02x", math.clamp(math.floor(v * 255 + 0.5), 0, 255)) end
	return h(self.R) .. h(self.G) .. h(self.B)
end
function Color3MT:Lerp(o, a) return c3(self.R + (o.R - self.R) * a, self.G + (o.G - self.G) * a, self.B + (o.B - self.B) * a) end

local function randomObj(seed)
	local state = (seed or 12345) % 2147483647
	if state <= 0 then state += 2147483646 end
	local r = {}
	local function nextf()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	function r:NextNumber() return nextf() end
	function r:NextInteger(a, b) return a + math.floor(nextf() * (b - a + 1)) end
	return r
end

----------------------------------------------------------------------------------------------------
-- instances
----------------------------------------------------------------------------------------------------
local basePartClasses = { Part = true, SpawnLocation = true, MeshPart = true }
local methods = {}
local InstMT = {}

local function newInstance(class, name)
	local inst = setmetatable({}, InstMT)
	rawset(inst, "ClassName", class)
	rawset(inst, "Name", name or class)
	rawset(inst, "_children", {})
	rawset(inst, "_attrs", {})
	rawset(inst, "AbsolutePosition", setmetatable({ X = 0, Y = 0 }, { __index = function() return 0 end }))
	rawset(inst, "AbsoluteSize", setmetatable({ X = 0, Y = 0 }, { __index = function() return 0 end }))
	return inst
end

InstMT.__index = function(t, k)
	local m = methods[k]
	if m then return m end
	if k == "Parent" then return rawget(t, "_parent") end
	if k == "Character" or k == "Adornee" or k == "OnServerInvoke" or k == "ProcessReceipt" then return nil end
	local sigs = rawget(t, "_sigs")
	if signalNames[k] or tostring(k):match("Changed$") then
		if not sigs then sigs = {} rawset(t, "_sigs", sigs) end
		if not sigs[k] then sigs[k] = newSignal() end
		return sigs[k]
	end
	for _, c in ipairs(rawget(t, "_children")) do
		if c.Name == k then return c end
	end
	return Any
end

InstMT.__newindex = function(t, k, v)
	if k == "Parent" then
		local old = rawget(t, "_parent")
		if old then
			for i, c in ipairs(rawget(old, "_children")) do
				if c == t then table.remove(rawget(old, "_children"), i) break end
			end
		end
		rawset(t, "_parent", v)
		if v then
			table.insert(rawget(v, "_children"), t)
			local sigs = rawget(v, "_sigs")
			if sigs and sigs.ChildAdded then sigs.ChildAdded:Fire(t) end
		end
	else
		rawset(t, k, v)
	end
end

function methods.WaitForChild(self, name)
	for _, c in ipairs(rawget(self, "_children")) do
		if c.Name == name then return c end
	end
	error("WaitForChild would hang: " .. rawget(self, "Name") .. "." .. tostring(name), 2)
end
function methods.FindFirstChild(self, name)
	for _, c in ipairs(rawget(self, "_children")) do
		if c.Name == name then return c end
	end
	return nil
end
function methods.FindFirstChildOfClass(self, cls)
	for _, c in ipairs(rawget(self, "_children")) do
		if c.ClassName == cls then return c end
	end
	return nil
end
function methods.GetChildren(self) return table.clone(rawget(self, "_children")) end
function methods.GetDescendants(self)
	local out = {}
	local function walk(n)
		for _, c in ipairs(rawget(n, "_children")) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods.IsA(self, cls)
	local c = rawget(self, "ClassName")
	if c == cls or cls == "Instance" then return true end
	if cls == "BasePart" then return basePartClasses[c] == true end
	if cls == "GuiObject" then return c == "Frame" or c == "TextLabel" or c == "TextButton" or c == "ScrollingFrame" end
	if cls == "ValueBase" then return c:match("Value$") ~= nil end
	return false
end
function methods.Destroy(self)
	local p = rawget(self, "_parent")
	if p then
		for i, c in ipairs(rawget(p, "_children")) do
			if c == self then table.remove(rawget(p, "_children"), i) break end
		end
	end
	rawset(self, "_parent", nil)
	rawset(self, "_destroyed", true)
	for _, c in ipairs(table.clone(rawget(self, "_children"))) do methods.Destroy(c) end
end
function methods.ClearAllChildren(self)
	for _, c in ipairs(table.clone(rawget(self, "_children"))) do methods.Destroy(c) end
end
function methods.SetAttribute(self, k, v) rawget(self, "_attrs")[k] = v end
function methods.GetAttribute(self, k) return rawget(self, "_attrs")[k] end
function methods.GetPropertyChangedSignal(self, k) return newSignal() end
function methods.PivotTo(self, cf) rawset(self, "_pivot", cf) end
function methods.GetService(self, name) return M.service(name) end
function methods.GetPlayers(self)
	local out = {}
	for _, c in ipairs(rawget(self, "_children")) do
		if c.ClassName == "Player" then table.insert(out, c) end
	end
	return out
end
function methods.GetPlayerByUserId(self, id)
	for _, c in ipairs(rawget(self, "_children")) do
		if c.ClassName == "Player" and c.UserId == id then return c end
	end
	return nil
end
function methods.GetNameFromUserIdAsync(self, id) return "User" .. id end
function methods.IsStudio() return M.studio == true end
function methods.IsServer() return M.isServer end
function methods.Create(self, inst, info, goal) return { Play = function() end } end
function methods.UserOwnsGamePassAsync() return M.ownsPass or false end
function methods.PromptGamePassPurchase(self, plr, id) M.prompted = { "pass", id } end
function methods.PromptProductPurchase(self, plr, id) M.prompted = { "product", id } end
function methods.SubscribeAsync() end
function methods.PublishAsync() end
function methods.JSONEncode(self, v) return "{}" end

-- remotes
function methods.FireClient(self, plr, ...)
	if plr == M.localPlayer and M.clientAttached then
		self.OnClientEvent:Fire(...)
	end
end
function methods.FireAllClients(self, ...)
	if M.clientAttached then self.OnClientEvent:Fire(...) end
end
function methods.FireServer(self, ...) end
function methods.InvokeServer(self, ...)
	local f = rawget(self, "OnServerInvoke")
	assert(f, "no OnServerInvoke")
	return f(M.localPlayer, ...)
end

----------------------------------------------------------------------------------------------------
-- fake DataStores
----------------------------------------------------------------------------------------------------
M.stores = {}
M.dsFailures = 0
local function deepcopy(v)
	if type(v) ~= "table" then return v end
	local o = {}
	for k, x in pairs(v) do o[k] = deepcopy(x) end
	return o
end
local function validateSerializable(v, path)
	local t = type(v)
	if t == "table" then
		if getmetatable(v) ~= nil then error("DataStore value has metatable at " .. path) end
		local strKeys, numKeys, n = 0, 0, 0
		for k, x in pairs(v) do
			n += 1
			if type(k) == "string" then strKeys += 1 elseif type(k) == "number" then numKeys += 1 else error("bad key type at " .. path) end
			validateSerializable(x, path .. "." .. tostring(k))
		end
		if strKeys > 0 and numKeys > 0 then error("mixed keys at " .. path) end
		if numKeys > 0 then
			for i = 1, n do if v[i] == nil then error("sparse array at " .. path) end end
		end
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then error("non-finite number at " .. path) end
	elseif t ~= "string" and t ~= "boolean" then
		error("unserializable " .. t .. " at " .. path)
	end
end
local function newStore(name)
	local data = {}
	M.stores[name] = data
	local s = {}
	function s:UpdateAsync(key, fn)
		if M.dsFailures > 0 then M.dsFailures -= 1 error("DataStore request failed (injected)") end
		local old = deepcopy(data[key])
		local new = fn(old)
		if new == nil then return old end
		validateSerializable(new, name .. "/" .. key)
		data[key] = deepcopy(new)
		return deepcopy(new)
	end
	function s:SetAsync(key, v)
		validateSerializable(v, name .. "/" .. key)
		data[key] = v
	end
	function s:GetSortedAsync(asc, n)
		local rows = {}
		for k, v in pairs(data) do table.insert(rows, { key = k, value = v }) end
		table.sort(rows, function(a, b) if asc then return a.value < b.value end return a.value > b.value end)
		return { GetCurrentPage = function() return rows end }
	end
	return s
end

local services = {}
function M.service(name)
	if services[name] then return services[name] end
	local s = newInstance(name)
	services[name] = s
	if name == "DataStoreService" then
		rawset(s, "GetDataStore", function(_, n) return newStore(n) end)
		rawset(s, "GetOrderedDataStore", function(_, n) return newStore(n) end)
	elseif name == "Workspace" then
		rawset(s, "CurrentCamera", setmetatable({ ViewportSize = { X = 1920, Y = 1080 } }, { __index = function(_, k) if k == "GetPropertyChangedSignal" then return methods.GetPropertyChangedSignal end return Any end }))
	end
	return s
end

----------------------------------------------------------------------------------------------------
-- environment + require
----------------------------------------------------------------------------------------------------
local G
local moduleCache = {}

local function buildTree(spec, parent)
	local inst = newInstance(spec.class, spec.name)
	if spec.source then rawset(inst, "Source", spec.source) end
	inst.Parent = parent
	for _, c in ipairs(spec.children or {}) do buildTree(c, inst) end
	return inst
end

local function envFor(inst)
	local env = setmetatable({ script = inst }, { __index = G })
	env.require = function(m)
		if moduleCache[m] ~= nil then return moduleCache[m].value end
		local src = rawget(m, "Source")
		assert(src, "require of non-module " .. tostring(rawget(m, "Name")))
		local fn, err = loadstring(src, "=" .. rawget(m, "Name"))
		if not fn then error("syntax error in " .. rawget(m, "Name") .. ": " .. tostring(err)) end
		setfenv(fn, envFor(m))
		moduleCache[m] = { value = nil }
		local value = fn()
		moduleCache[m].value = value
		return value
	end
	return env
end

function M.run(scriptInst)
	local fn, err = loadstring(rawget(scriptInst, "Source"), "=" .. rawget(scriptInst, "Name"))
	if not fn then error("syntax error: " .. tostring(err)) end
	setfenv(fn, envFor(scriptInst))
	local co = coroutine.create(fn)
	resume(co)
end

function M.boot(bundle)
	local game = newInstance("DataModel", "game")
	rawset(game, "JobId", "job-A")
	rawset(game, "PlaceId", 1)
	G = {
		game = game, Instance = { new = function(cls) return newInstance(cls) end },
		Enum = Any, Vector3 = { new = v3 }, Vector2 = { new = function(x, y) return { X = x, Y = y } end },
		Color3 = { new = c3, fromRGB = function(r, g, b) return c3(r / 255, g / 255, b / 255) end },
		CFrame = Any, UDim2 = Any, UDim = Any, TweenInfo = Any, Rect = Any, NumberRange = Any, Font = Any,
		ColorSequence = Any, NumberSequence = Any, Random = { new = randomObj },
		task = task, warn = function(...) table.insert(M.logs, table.concat({ ... }, " ")) end,
		typeof = type, tick = os.clock,
		print = print, assert = assert, error = error, pcall = pcall, xpcall = xpcall, select = select, next = next,
		pairs = pairs, ipairs = ipairs, tostring = tostring, tonumber = tonumber, type = type, unpack = unpack,
		setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget, rawset = rawset, rawequal = rawequal,
		string = string, table = table, math = math, os = os, coroutine = coroutine, bit32 = bit32, utf8 = utf8, buffer = buffer,
		debug = debug,
	}
	G.Instance.new = function(cls) return newInstance(cls) end
	local ws = M.service("Workspace")
	G.workspace = ws
	rawset(game, "Workspace", ws)
	rawset(game, "_children", rawget(game, "_children"))

	local RS = M.service("ReplicatedStorage")
	buildTree(bundle.shared, RS)
	local SSS = M.service("ServerScriptService")
	buildTree(bundle.server, SSS)
	local playerScripts = newInstance("Folder", "StarterPlayerScripts")
	buildTree(bundle.client, playerScripts)
	M.serverMain = SSS:WaitForChild("Server"):WaitForChild("Main")
	M.clientMain = playerScripts:WaitForChild("Client"):WaitForChild("Main")
	return game
end

function M.requireModule(inst)
	return envFor(inst).require(inst)
end

function M.newPlayer(userId, name)
	local p = newInstance("Player", name)
	rawset(p, "UserId", userId)
	rawset(p, "DisplayName", name)
	local gui = newInstance("PlayerGui", "PlayerGui")
	gui.Parent = p
	p.Parent = M.service("Players")
	return p
end

--- Advances virtual time, firing Heartbeat at 10 Hz and waking sleeping tasks.
function M.advance(seconds)
	local target = now + seconds
	while now < target do
		now += 0.1
		local hb = M.service("RunService").Heartbeat
		hb:Fire(0.1)
		local due, rest = {}, {}
		for _, s in ipairs(sleepers) do
			if s.t <= now then table.insert(due, s) else table.insert(rest, s) end
		end
		sleepers = rest
		for _, s in ipairs(due) do resume(s.co) end
	end
end

function M.find(root, pred)
	local function walk(n)
		if pred(n) then return n end
		for _, c in ipairs(rawget(n, "_children")) do
			local r = walk(c)
			if r then return r end
		end
		return nil
	end
	return walk(root)
end

function M.findAll(root, pred)
	local out = {}
	for _, d in ipairs(methods.GetDescendants(root)) do
		if pred(d) then table.insert(out, d) end
	end
	return out
end

function M.uniqueRoot() return M.service("Players") end

return M
