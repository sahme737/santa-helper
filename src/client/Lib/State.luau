--!strict
-- Latest state snapshot from the server, plus a change signal.

local Net = require(script.Parent.Net)

local State = {}

State.data = nil :: any
State.loaded = false
-- Offset between server os.time() and local os.time(), for countdowns.
State.timeOffset = 0

local listeners: { (any) -> () } = {}

function State.onChanged(fn: (any) -> ())
	table.insert(listeners, fn)
	if State.data then
		task.spawn(fn, State.data)
	end
end

function State.now(): number
	return os.time() + State.timeOffset
end

function State.profile(): any
	return State.data and State.data.profile
end

Net.on("State", function(snapshot)
	State.data = snapshot
	State.loaded = true
	State.timeOffset = snapshot.serverTime - os.time()
	for _, fn in listeners do
		task.spawn(fn, snapshot)
	end
end)

return State
