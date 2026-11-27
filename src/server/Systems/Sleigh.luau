--!strict
-- Sleigh Delivery: the finale activity. The player flies a sleigh over the
-- snowy town and drops presents down chimneys before the night runs out.
-- The client steers (its character is network-owned by it); the server
-- decides every hit using the replicated position, a plausibility check on
-- speed, a per-run "already delivered" set, and run time limits.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Build = require(Shared.Util.Build)
local ReindeerModel = require(Shared.Models.ReindeerModel)

local Net = require(script.Parent.Parent.Lib.Net)
local PlayerData = require(script.Parent.PlayerData)
local PlayerState = require(script.Parent.PlayerState)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Workshop = require(script.Parent.Workshop)
local Events = require(script.Parent.Events)

local Sleigh = {}

type Run = {
	id: number,
	route: Config.RouteDef,
	houses: { [number]: string }, -- chimney index -> "gift" | "gold" | "coal"
	targets: number,
	startedAt: number,
	endsAt: number,
	delivered: { [number]: boolean },
	count: number,
	coins: number,
	snowflakes: number,
	combo: number,
	bestCombo: number,
	lastDropAt: number,
	lastPos: Vector3,
	lastPosAt: number,
	speed: number,
	radius: number,
	suspendedUntil: number, -- drops ignored after an impossible movement
	sampleAt: number,
	model: Model?,
	connections: { RBXScriptConnection },
}

local runs: { [Player]: Run } = {}
local cooldownUntil: { [Player]: number } = {}
local runCounter = 0

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function attachSleigh(player: Player, root: BasePart, reindeer: number): Model
	local character = player.Character :: Model
	local sleigh = WorldBuilder.sleighModel(1.1, true)
	sleigh.Name = "DeliverySleigh"
	-- Reindeer team, two abreast, in front of the sleigh.
	for i = 1, reindeer do
		local row = math.ceil(i / 2)
		local side = if i % 2 == 1 then -1 else 1
		local deer = ReindeerModel.build(if i <= 2 then "Starlight" else "Cocoa", false, 1.0)
		deer:PivotTo(CFrame.new(side * 2.2, 1.0, -8 - row * 5.5))
		deer:SetAttribute("Row", row)
		ReindeerModel.rig(deer)
		CollectionService:AddTag(deer, "SleighDeer")
		deer.Parent = sleigh
		-- Glowing reins
		Build.deco({
			Size = Vector3.new(0.15, 0.15, 5.5 * row),
			CFrame = CFrame.new(side * 1.2, 2.6, -5 - row * 2.75),
			Color = Color3.fromRGB(255, 210, 80),
			Material = Enum.Material.Neon,
			Parent = sleigh,
		})
	end
	local primary = sleigh.PrimaryPart :: BasePart
	-- Place the sleigh so the player stands in it, facing the same way.
	sleigh:PivotTo(root.CFrame * CFrame.new(0, -3.4, 0.8))
	for _, d in sleigh:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			local deer = d:FindFirstAncestorOfClass("Model")
			if deer and deer ~= sleigh and deer:GetAttribute("Rigged") then
				-- Rigged reindeer hang off their own Root; the Root rides on a
				-- weld the client bobs up and down.
				if d == deer.PrimaryPart then
					local bob = Instance.new("Weld")
					bob.Name = "Bob"
					bob.Part0 = primary
					bob.Part1 = d
					bob.C0 = primary.CFrame:ToObjectSpace(d.CFrame)
					bob.Parent = d
				end
			elseif d ~= primary then
				local w = Instance.new("WeldConstraint")
				w.Part0 = primary
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = primary
	weld.Parent = primary
	sleigh.Parent = character
	return sleigh
end

-- A flying helper passes through everything, so bumping a rooftop, a tall
-- tree or another sleigh can never knock the sleigh off course.
local FLY_GROUP = "FlyingSleigh"

local function setFlying(character: Model?, flying: boolean)
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = if flying then FLY_GROUP else "Default"
		end
	end
end

function Sleigh.isFlying(player: Player): boolean
	return runs[player] ~= nil
end

local function endRun(player: Player, reason: string)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	for _, c in run.connections do
		c:Disconnect()
	end
	if run.model then
		run.model:Destroy()
	end
	setFlying(player.Character, false)
	local def = run.route
	local stars = Economy.starsFor(def, run.count)
	local perfect = run.count >= run.targets
	local newStars = 0
	local previousBest = 0
	local unlocked: string? = nil
	local xp = 0
	local profile = PlayerData.get(player)
	if profile then
		local key = tostring(def.id)
		local record = profile.routes[key]
		if not record then
			record = { stars = 0, best = 0 }
			profile.routes[key] = record
		end
		previousBest = record.best
		record.best = math.max(record.best, run.count)
		if stars > record.stars then
			newStars = stars - record.stars
			local firstClear = record.stars == 0
			record.stars = stars
			profile.stars = Economy.totalStars(profile)
			run.snowflakes += PlayerState.addSnowflakes(
				player,
				profile,
				newStars * Config.ROUTE.STAR_SNOWFLAKES * def.id,
				true
			)
			xp += newStars * Config.ROUTE.XP_PER_STAR * def.id
			local nextDef = Config.ROUTES[def.id + 1]
			if firstClear and nextDef then
				unlocked = nextDef.name
			end
			if stars == 3 then
				Net.toastAll(`⭐⭐⭐ {player.DisplayName} got 3 stars on {def.name}!`, "event")
			end
		end
		xp += run.count * Config.ROUTE.XP_PER_PRESENT * def.id
		PlayerState.addXp(player, profile, xp)
		if newStars > 0 then
			PlayerState.emit("rank", player)
		end
	end
	cooldownUntil[player] = os.clock() + Config.SLEIGH.COOLDOWN
	PlayerState.setExtra(player, "flying", false)
	PlayerState.setExtra(player, "sleighCooldownUntil", os.time() + Config.SLEIGH.COOLDOWN)
	Net.push(player, "SleighEnd", {
		reason = reason,
		route = def.id,
		count = run.count,
		targets = run.targets,
		coins = run.coins,
		snowflakes = run.snowflakes,
		bestCombo = run.bestCombo,
		perfect = perfect,
		stars = stars,
		newStars = newStars,
		previousBest = previousBest,
		unlocked = unlocked,
		xp = xp,
	})
	if player.Parent == Players and reason ~= "died" then
		task.delay(0.1, function()
			local root = rootOf(player)
			if root then
				root.AssemblyLinearVelocity = Vector3.zero
			end
			Workshop.sendHome(player)
		end)
	end
end

function Sleigh.beginRun(player: Player, routeId: unknown): (boolean, any)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	if runs[player] then
		return false, "Already flying!"
	end
	local def = if typeof(routeId) == "number" then Config.ROUTES[routeId] else nil
	if not def then
		return false, "Pick a route"
	end
	if not Economy.routeUnlocked(profile, def.id) then
		return false, "Earn a star on the route before it first"
	end
	local now = os.clock()
	local cd = cooldownUntil[player]
	if cd and now < cd then
		return false, `The reindeer are resting ({math.ceil(cd - now)}s)`
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(player)
	if not character or not humanoid or humanoid.Health <= 0 or not root then
		return false, "Respawn first"
	end

	local stats = Economy.sleighStats(profile)
	local duration = def.time + (stats.duration - Config.SLEIGH.BASE_TIME)
	local radius = stats.radius * def.radius
	local houses = Economy.routeHouses(def, #WorldBuilder.chimneys)
	local targets = 0
	local houseKeys: { [string]: string } = {}
	for index, kind in houses do
		houseKeys[tostring(index)] = kind
		if kind ~= "coal" then
			targets += 1
		end
	end

	runCounter += 1
	local startCF = WorldBuilder.townStart()
	character:PivotTo(startCF)
	root.AssemblyLinearVelocity = Vector3.zero
	local model = attachSleigh(player, root, stats.reindeer)
	setFlying(character, true)

	local nowTime = os.clock()
	local run: Run = {
		id = runCounter,
		route = def,
		houses = houses,
		targets = targets,
		startedAt = nowTime,
		endsAt = nowTime + duration,
		delivered = {},
		count = 0,
		coins = 0,
		snowflakes = 0,
		combo = 0,
		bestCombo = 0,
		lastDropAt = 0,
		lastPos = startCF.Position,
		lastPosAt = nowTime,
		speed = stats.speed + def.wind,
		radius = radius,
		suspendedUntil = nowTime + 0.5,
		sampleAt = nowTime,
		model = model,
		connections = {},
	}
	runs[player] = run
	table.insert(
		run.connections,
		humanoid.Died:Connect(function()
			endRun(player, "died")
		end)
	)
	table.insert(
		run.connections,
		player.CharacterRemoving:Connect(function()
			endRun(player, "died")
		end)
	)

	PlayerState.setExtra(player, "flying", true)
	return true,
		{
			route = def.id,
			duration = duration,
			speed = stats.speed,
			radius = radius,
			altitude = Config.SLEIGH.ALTITUDE,
			townOrigin = WorldBuilder.TOWN_ORIGIN.Position,
			houses = houseKeys,
			targets = targets,
		}
end

function Sleigh.drop(player: Player): (boolean, any)
	local run = runs[player]
	if not run then
		return false, "Not flying"
	end
	local now = os.clock()
	if now > run.endsAt + 0.5 then
		return false, "Night is over"
	end
	local profile = PlayerData.get(player)
	local root = rootOf(player)
	if not profile or not root then
		return false, "Not flying"
	end

	-- Movement is sampled every frame on the server (see start()); after an
	-- impossible jump, drops are ignored for a moment.
	if now < run.suspendedUntil then
		return false, "Whoa, too fast!"
	end
	local pos = root.Position
	local altitude = pos.Y - WorldBuilder.TOWN_ORIGIN.Position.Y
	if math.abs(altitude - Config.SLEIGH.ALTITUDE) > 30 then
		return false, "miss"
	end

	-- Nearest house on this route that hasn't been used yet. Naughty houses
	-- count, so a careless drop near one lands on it.
	local best: number? = nil
	local bestDist = run.radius + Config.SLEIGH.LATENCY_SLACK
	for index, _ in run.houses do
		local chimney = WorldBuilder.chimneys[index]
		if chimney and not run.delivered[index] then
			local flat = Vector3.new(pos.X - chimney.X, 0, pos.Z - chimney.Z).Magnitude
			local height = pos.Y - chimney.Y
			if flat <= bestDist and height > -5 and height < 120 then
				best = index
				bestDist = flat
			end
		end
	end
	if not best then
		run.combo = 0
		return false, "miss"
	end

	run.delivered[best] = true
	local kind = run.houses[best]
	if kind == "coal" then
		run.combo = 0
		run.endsAt -= Config.ROUTE.COAL_TIME_PENALTY
		return true, { index = best, coal = true, remaining = math.max(0, run.endsAt - now) }
	end

	run.count += 1
	run.combo = if now - run.lastDropAt <= Config.SLEIGH.COMBO_WINDOW then run.combo + 1 else 1
	run.bestCombo = math.max(run.bestCombo, run.combo)
	run.lastDropAt = now

	local golden = kind == "gold"
	local reward = Economy.presentReward(
		profile,
		PlayerState.ctx(player),
		run.combo,
		run.route.reward * (if golden then Config.ROUTE.GOLDEN_MULTIPLIER else 1)
	)
	PlayerState.addCoins(player, profile, reward)
	run.coins += reward
	profile.delivered += 1
	local snow = 0
	if golden or run.count % Config.SLEIGH.SNOWFLAKE_EVERY == 0 then
		snow = PlayerState.addSnowflakes(player, profile, 1, true)
		run.snowflakes += snow
	end
	Events.addCommunityPresents(1)
	PlayerState.dirty(player)

	if run.count >= run.targets then
		task.defer(endRun, player, "perfect")
	end
	return true,
		{
			index = best,
			reward = reward,
			combo = run.combo,
			count = run.count,
			snowflakes = snow,
			golden = golden,
			stars = Economy.starsFor(run.route, run.count),
		}
end

-- Server-side movement sampling: a client that teleports between chimneys
-- (instead of flying) gets its drops suspended.
local function sampleRuns()
	local now = os.clock()
	for player, run in runs do
		if now > run.endsAt then
			task.defer(endRun, player, "time")
		elseif now - run.sampleAt >= 0.2 then
			local root = rootOf(player)
			if root then
				local pos = root.Position
				local dt = now - run.lastPosAt
				local flat = Vector3.new(pos.X - run.lastPos.X, 0, pos.Z - run.lastPos.Z).Magnitude
				if flat > run.speed * 1.4 * dt * 1.6 + 15 then
					run.suspendedUntil = now + 1.5
				end
				run.lastPos = pos
				run.lastPosAt = now
				run.sampleAt = now
			end
		end
	end
end

function Sleigh.start()
	PhysicsService:RegisterCollisionGroup(FLY_GROUP)
	PhysicsService:CollisionGroupSetCollidable(FLY_GROUP, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(FLY_GROUP, FLY_GROUP, false)
	game:GetService("RunService").Heartbeat:Connect(sampleRuns)
	Net.handle("StartDelivery", 0.5, 2, function(player, routeId: unknown)
		return Sleigh.beginRun(player, routeId)
	end)
	Net.handle("DropPresent", 5, 6, function(player)
		return Sleigh.drop(player)
	end)
	Net.handle("EndDelivery", 1, 2, function(player)
		if runs[player] then
			endRun(player, "quit")
			return true, nil
		end
		return false, nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		local run = runs[player]
		if run then
			runs[player] = nil
			for _, c in run.connections do
				c:Disconnect()
			end
		end
		cooldownUntil[player] = nil
	end)
end

return Sleigh
