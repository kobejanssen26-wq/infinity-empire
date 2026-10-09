--!nonstrict
-- Minimal stand-ins for the Roblox globals used by pure modules, so they run under the luau CLI.
local Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end }

-- xorshift-based deterministic RNG with the same surface as Roblox's Random.
local RandomImpl = {}
RandomImpl.__index = RandomImpl
function RandomImpl:NextNumber()
	local x = self.s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.s = x
	return (x % 1000003) / 1000003
end
function RandomImpl:NextInteger(a, b)
	return a + math.floor(self:NextNumber() * (b - a + 1))
end
local Random = { new = function(seed) return setmetatable({ s = (seed * 2654435761 + 12345) % 4294967296 + 1 }, RandomImpl) end }
return { Color3 = Color3, Random = Random }
