--!nonstrict
local Format = {}

local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.number(n: number): string
	if n ~= n then
		return "0"
	end
	if n < 1000 then
		if n >= 100 or n == math.floor(n) then
			return string.format("%d", math.floor(n))
		end
		return string.format("%.1f", n)
	end
	local i = 1
	while n >= 1000 and i < #suffixes do
		n /= 1000
		i += 1
	end
	if n >= 100 then
		return string.format("%d%s", math.floor(n), suffixes[i])
	elseif n >= 10 then
		return string.format("%.1f%s", n, suffixes[i])
	end
	return string.format("%.2f%s", n, suffixes[i])
end

--- Rates: keeps one decimal below 10 so 0.08/s stays readable.
function Format.rate(n: number): string
	if n < 10 then
		return string.format("%.2f", n)
	end
	return Format.number(n)
end

function Format.percent(f: number): string
	return string.format("%d%%", math.floor(f * 100 + 0.5))
end

function Format.duration(sec: number): string
	sec = math.max(0, math.floor(sec))
	local h = sec // 3600
	local m = (sec % 3600) // 60
	local s = sec % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

return Format
