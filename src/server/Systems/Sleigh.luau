--!strict
-- Sleigh Delivery: the finale activity. The player flies a sleigh over the
-- snowy town and drops presents down chimneys before the night runs out.
-- The client steers (its character is network-owned by it); the server
-- decides every hit using the replicated position, a plausibility check on
-- speed, a per-run "already delivered" set, and run time limits.

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
			if d ~= primary then
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
	local profile = PlayerData.get(player)
	if profile and run.count >= #WorldBuilder.chimneys then
		local got = PlayerState.addSnowflakes(player, profile, 15, true)
		run.snowflakes += got
	end
	cooldownUntil[player] = os.clock() + Config.SLEIGH.COOLDOWN
	PlayerState.setExtra(player, "flying", false)
	PlayerState.setExtra(player, "sleighCooldownUntil", os.time() + Config.SLEIGH.COOLDOWN)
	Net.push(player, "SleighEnd", {
		reason = reason,
		count = run.count,
		coins = run.coins,
		snowflakes = run.snowflakes,
		bestCombo = run.bestCombo,
		perfect = run.count >= #WorldBuilder.chimneys,
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

function Sleigh.beginRun(player: Player): (boolean, any)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	if runs[player] then
		return false, "Already flying!"
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
	runCounter += 1
	local startCF = WorldBuilder.townStart()
	character:PivotTo(startCF)
	root.AssemblyLinearVelocity = Vector3.zero
	local model = attachSleigh(player, root, stats.reindeer)

	local nowTime = os.clock()
	local run: Run = {
		id = runCounter,
		startedAt = nowTime,
		endsAt = nowTime + stats.duration,
		delivered = {},
		count = 0,
		coins = 0,
		snowflakes = 0,
		combo = 0,
		bestCombo = 0,
		lastDropAt = 0,
		lastPos = startCF.Position,
		lastPosAt = nowTime,
		speed = stats.speed,
		radius = stats.radius,
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
	task.delay(stats.duration + 0.5, function()
		if runs[player] == run then
			endRun(player, "time")
		end
	end)

	PlayerState.setExtra(player, "flying", true)
	return true,
		{
			duration = stats.duration,
			speed = stats.speed,
			radius = stats.radius,
			altitude = Config.SLEIGH.ALTITUDE,
			townOrigin = WorldBuilder.TOWN_ORIGIN.Position,
			chimneys = #WorldBuilder.chimneys,
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

	local best: number? = nil
	local bestDist = run.radius + Config.SLEIGH.LATENCY_SLACK
	for index, chimney in WorldBuilder.chimneys do
		if not run.delivered[index] then
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
	run.count += 1
	run.combo = if now - run.lastDropAt <= Config.SLEIGH.COMBO_WINDOW then run.combo + 1 else 1
	run.bestCombo = math.max(run.bestCombo, run.combo)
	run.lastDropAt = now

	local reward = Economy.presentReward(profile, PlayerState.ctx(player), run.combo)
	PlayerState.addCoins(player, profile, reward)
	run.coins += reward
	profile.delivered += 1
	local snow = 0
	if run.count % Config.SLEIGH.SNOWFLAKE_EVERY == 0 then
		snow = PlayerState.addSnowflakes(player, profile, 1, true)
		run.snowflakes += snow
	end
	Events.addCommunityPresents(1)
	PlayerState.dirty(player)

	if run.count >= #WorldBuilder.chimneys then
		task.defer(endRun, player, "perfect")
	end
	return true,
		{ index = best, reward = reward, combo = run.combo, count = run.count, snowflakes = snow }
end

-- Server-side movement sampling: a client that teleports between chimneys
-- (instead of flying) gets its drops suspended.
local function sampleRuns()
	local now = os.clock()
	for player, run in runs do
		if now - run.sampleAt >= 0.2 then
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
	game:GetService("RunService").Heartbeat:Connect(sampleRuns)
	Net.handle("StartDelivery", 0.5, 2, function(player)
		return Sleigh.beginRun(player)
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
