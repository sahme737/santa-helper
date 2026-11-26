--!strict
-- Date helpers for daily rewards and the holiday event. Everything is UTC so
-- every server agrees on what "today" is.

local Config = require(script.Parent.Config)

local Calendar = {}

function Calendar.dayNumber(now: number): number
	return math.floor(now / 86400)
end

function Calendar.secondsUntilNextDay(now: number): number
	return 86400 - (now % 86400)
end

function Calendar.eventActive(now: number): boolean
	return now <= Config.EVENT.END_TIME
end

function Calendar.eventSecondsLeft(now: number): number
	return math.max(0, Config.EVENT.END_TIME - now)
end

-- Returns the advent day (1-25) that is open right now, or nil.
function Calendar.adventDay(now: number): number?
	local t = os.date("!*t", now)
	if
		t.year == Config.EVENT.YEAR
		and t.month == Config.EVENT.ADVENT_MONTH
		and t.day <= Config.EVENT.ADVENT_LAST_DAY
	then
		return t.day
	end
	return nil
end

-- Days until advent starts (0 when it has started or is over).
function Calendar.daysUntilAdvent(now: number): number
	return math.max(0, math.ceil((Config.EVENT.ADVENT_START - now) / 86400))
end

return Calendar
