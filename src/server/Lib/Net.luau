--!strict
-- Server networking. Creates the only two remotes in the game:
--   Request (RemoteFunction)  client -> server action requests, returns (ok, data)
--   Push    (RemoteEvent)     server -> client topics (state, toasts, effects)
-- Every handler is rate limited per player and receives raw, untrusted args.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimiter = require(script.Parent.RateLimiter)

local Net = {}

type Handler = (player: Player, ...any) -> (boolean, any)
type Entry = { fn: Handler, rate: number, burst: number }

local handlers: { [string]: Entry } = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"
local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = folder
local push = Instance.new("RemoteEvent")
push.Name = "Push"
push.Parent = folder
folder.Parent = ReplicatedStorage

-- Register a handler. `rate` = tokens per second, `burst` = bucket size.
function Net.handle(name: string, rate: number, burst: number, fn: Handler)
	assert(handlers[name] == nil, `duplicate handler {name}`)
	handlers[name] = { fn = fn, rate = rate, burst = burst }
end

request.OnServerInvoke = function(player: Player, action: unknown, ...: any): (boolean, any)
	if typeof(action) ~= "string" then
		return false, "bad request"
	end
	local entry = handlers[action]
	if not entry then
		return false, "unknown action"
	end
	if not RateLimiter.allow(player, action, entry.rate, entry.burst) then
		return false, "Slow down!"
	end
	local ok, success, data = pcall(entry.fn, player, ...)
	if not ok then
		warn(`[Net] handler {action} errored for {player.UserId}: {success}`)
		return false, "Something went wrong"
	end
	return success == true, data
end

function Net.push(player: Player, topic: string, payload: any)
	if player.Parent == Players then
		push:FireClient(player, topic, payload)
	end
end

function Net.pushAll(topic: string, payload: any)
	push:FireAllClients(topic, payload)
end

-- Convenience toast.
function Net.toast(player: Player, text: string, kind: string?)
	Net.push(player, "Toast", { text = text, kind = kind or "info" })
end

function Net.toastAll(text: string, kind: string?)
	Net.pushAll("Toast", { text = text, kind = kind or "info" })
end

return Net
