--!strict
-- Client networking: request actions from the server and listen to pushes.
-- The client never decides outcomes; it asks and renders the answer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction
local push = remotes:WaitForChild("Push") :: RemoteEvent

local Net = {}

local listeners: { [string]: { (any) -> () } } = {}

-- Returns (ok, data). Never throws.
function Net.request(action: string, ...: any): (boolean, any)
	local args = table.pack(...)
	local ok, success, data = pcall(function()
		return request:InvokeServer(action, table.unpack(args, 1, args.n))
	end)
	if not ok then
		return false, "Connection hiccup, try again"
	end
	return success == true, data
end

function Net.on(topic: string, fn: (any) -> ())
	local list = listeners[topic]
	if not list then
		list = {}
		listeners[topic] = list
	end
	table.insert(list, fn)
end

push.OnClientEvent:Connect(function(topic: string, payload: any)
	local list = listeners[topic]
	if list then
		for _, fn in list do
			task.spawn(fn, payload)
		end
	end
end)

return Net
