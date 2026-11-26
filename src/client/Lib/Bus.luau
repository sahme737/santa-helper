--!strict
-- Tiny in-client event bus so controllers can talk without requiring each other.

local Bus = {}

local handlers: { [string]: { (...any) -> () } } = {}

function Bus.on(name: string, fn: (...any) -> ())
	local list = handlers[name]
	if not list then
		list = {}
		handlers[name] = list
	end
	table.insert(list, fn)
end

function Bus.fire(name: string, ...: any)
	local list = handlers[name]
	if list then
		for _, fn in list do
			task.spawn(fn, ...)
		end
	end
end

return Bus
