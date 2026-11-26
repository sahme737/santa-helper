--!strict
-- Argument validation helpers for remote handlers. Every value from a client
-- is `unknown` until one of these narrows it.

local Guard = {}

function Guard.string(value: unknown, maxLen: number): string?
	if typeof(value) ~= "string" then
		return nil
	end
	if #value == 0 or #value > maxLen then
		return nil
	end
	return value
end

function Guard.int(value: unknown, min: number, max: number): number?
	if typeof(value) ~= "number" then
		return nil
	end
	if value ~= value or value ~= math.floor(value) then
		return nil
	end
	if value < min or value > max then
		return nil
	end
	return value
end

function Guard.boolean(value: unknown): boolean?
	if typeof(value) ~= "boolean" then
		return nil
	end
	return value
end

-- Returns value only if it is a key of `set`.
function Guard.oneOf<T>(value: unknown, set: { [string]: T }): string?
	if typeof(value) ~= "string" or #value > 64 then
		return nil
	end
	if set[value] == nil then
		return nil
	end
	return value
end

return Guard
