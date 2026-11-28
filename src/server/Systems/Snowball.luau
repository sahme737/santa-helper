--!strict
-- Snowball fight arena. Bots and the player's own throws are simulated on
-- each client (they are only for fun and earn nothing). The server only
-- teleports players to the arena and relays throws and hits between real
-- players, after checking that both are really there.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Net = require(script.Parent.Parent.Lib.Net)

local Snowball = {}

local ARENA = Config.SNOWBALL
local lastHit: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function inArena(player: Player, slack: number): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	local flat = Vector3.new(root.Position.X - ARENA.CENTER.X, 0, root.Position.Z - ARENA.CENTER.Z)
	return flat.Magnitude <= ARENA.RADIUS + slack
		and math.abs(root.Position.Y - ARENA.CENTER.Y) < 40
end

local function finite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6
end

function Snowball.start()
	Net.handle("GoArena", 0.5, 2, function(player)
		local character = player.Character
		if not character or character:FindFirstChild("DeliverySleigh") then
			return false, "Finish your delivery first"
		end
		local at = ARENA.CENTER + Vector3.new(0, 3.5, -(ARENA.RADIUS - 8))
		character:PivotTo(CFrame.lookAt(at, Vector3.new(ARENA.CENTER.X, at.Y, ARENA.CENTER.Z)))
		return true, nil
	end)

	-- Show my throw to the other players nearby.
	Net.handle("SnowballThrow", 3, 4, function(player, origin: unknown, velocity: unknown)
		if typeof(origin) ~= "Vector3" or typeof(velocity) ~= "Vector3" then
			return false, nil
		end
		local root = rootOf(player)
		if not root or not finite(origin) or not finite(velocity) or not inArena(player, 12) then
			return false, nil
		end
		if (origin - root.Position).Magnitude > 12 or velocity.Magnitude > ARENA.SPEED * 1.6 then
			return false, nil
		end
		for _, other in Players:GetPlayers() do
			if other ~= player and inArena(other, 120) then
				Net.push(
					other,
					"Snowball",
					{ from = player.UserId, origin = origin, velocity = velocity }
				)
			end
		end
		return true, nil
	end)

	-- My snowball hit another player: knock them over.
	Net.handle("SnowballHit", 3, 4, function(player, targetId: unknown)
		if typeof(targetId) ~= "number" then
			return false, nil
		end
		local target = Players:GetPlayerByUserId(targetId)
		if not target or target == player then
			return false, nil
		end
		if not inArena(player, 12) or not inArena(target, 6) then
			return false, nil
		end
		local now = os.clock()
		if now - (lastHit[target] or 0) < 2 then
			return false, nil
		end
		lastHit[target] = now
		Net.push(target, "Snowballed", { by = player.DisplayName })
		return true, nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
	end)
end

return Snowball
