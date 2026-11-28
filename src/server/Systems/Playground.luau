--!strict
-- Christmas Playground: teleports to the attractions and ticket sales for
-- the rides. The rides themselves are drawn on each client; the server only
-- checks the player is at the ride and takes the Cheer for the ticket.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Net = require(script.Parent.Parent.Lib.Net)
local PlayerData = require(script.Parent.PlayerData)
local PlayerState = require(script.Parent.PlayerState)

local Playground = {}

local PLAY = Config.PLAYGROUND

local function ringPoint(angleDeg: number, radius: number): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
end

-- A spot `distance` studs from `centre` on the side facing the plaza.
local function plazaSide(centre: Vector3, distance: number): Vector3
	local flat = Vector3.new(centre.X, 0, centre.Z)
	return flat - flat.Unit * distance
end

local STATION = ringPoint(PLAY.TRAIN.STATION_ANGLE, PLAY.TRAIN.RADIUS + 13)

-- Where each attraction drops you, and what to face.
local PLACES: { [string]: { at: Vector3, look: Vector3 } } = {
	Snowball = {
		at = Config.SNOWBALL.CENTER + Vector3.new(0, 0, -(Config.SNOWBALL.RADIUS - 8)),
		look = Config.SNOWBALL.CENTER,
	},
	Train = { at = STATION + Vector3.new(0, 1.2, 0), look = Vector3.zero },
	Carousel = {
		at = plazaSide(PLAY.CAROUSEL.CENTER, PLAY.CAROUSEL.RADIUS + 7),
		look = PLAY.CAROUSEL.CENTER,
	},
	Rink = { at = plazaSide(PLAY.RINK.CENTER, PLAY.RINK.RADIUS - 6), look = PLAY.RINK.CENTER },
}

local RIDES: { [string]: { cost: number, at: Vector3, reach: number } } = {
	Train = { cost = PLAY.TRAIN.COST, at = STATION, reach = 45 },
	Carousel = { cost = PLAY.CAROUSEL.COST, at = PLAY.CAROUSEL.CENTER, reach = 45 },
}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function Playground.start()
	Net.handle("GoPlace", 0.5, 2, function(player, place: unknown)
		if typeof(place) ~= "string" then
			return false, nil
		end
		local spot = PLACES[place]
		local character = player.Character
		if not spot or not character then
			return false, nil
		end
		if character:FindFirstChild("DeliverySleigh") then
			return false, "Finish your delivery first"
		end
		local at = spot.at + Vector3.new(0, 3.5, 0)
		character:PivotTo(CFrame.lookAt(at, Vector3.new(spot.look.X, at.Y, spot.look.Z)))
		return true, nil
	end)

	Net.handle("RideTicket", 1, 2, function(player, ride: unknown)
		if typeof(ride) ~= "string" then
			return false, nil
		end
		local info = RIDES[ride]
		local profile = PlayerData.get(player)
		local root = rootOf(player)
		if not info or not profile or not root then
			return false, nil
		end
		local away = Vector3.new(root.Position.X - info.at.X, 0, root.Position.Z - info.at.Z)
		if away.Magnitude > info.reach then
			return false, "Come closer to the ride"
		end
		if not PlayerState.trySpend(player, profile, "coins", info.cost) then
			return false, `A ticket costs {info.cost} Cheer. Wrap a present to earn some!`
		end
		return true, info.cost
	end)
end

return Playground
