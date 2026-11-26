--!strict
-- Number and time formatting for UI.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }

function Format.short(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = tostring(math.floor(n))
		return if negative then "-" .. s else s
	end
	local tier = math.min(#SUFFIXES, math.floor(math.log10(n) / 3) + 1)
	local scaled = n / 10 ^ ((tier - 1) * 3)
	local text
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		text = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		text = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "%.?0+$", "")
	end
	return (if negative then "-" else "") .. text .. SUFFIXES[tier]
end

function Format.commas(n: number): string
	local s = tostring(math.floor(n))
	local result = string.reverse(s)
	result = string.gsub(result, "(%d%d%d)", "%1,")
	result = string.reverse(result)
	if string.sub(result, 1, 1) == "," then
		result = string.sub(result, 2)
	end
	return result
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d = math.floor(seconds / 86400)
	local h = math.floor(seconds % 86400 / 3600)
	local m = math.floor(seconds % 3600 / 60)
	local s = seconds % 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%d:%02d", m, s)
end

function Format.percent(fraction: number): string
	return string.format("+%d%%", math.floor(fraction * 100 + 0.5))
end

return Format
