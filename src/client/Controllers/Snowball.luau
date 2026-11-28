--!strict
-- Snowball fight! Inside the arena the player clicks or taps to throw.
-- Elf bots run about, hide, throw back and fall flat on their backs when
-- hit, so there is always someone to play with. When nobody is in the arena
-- the bots keep pelting each other. Everything here is for fun only: no
-- currency is earned, so bots and throws are simulated on each client and
-- only hits on real players go through the server.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local ElfModel = require(Shared.Models.ElfModel)

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local State = require(Lib.State)
local Bus = require(Lib.Bus)

local Snowball = {}

local T = UI.Theme
local player = Players.LocalPlayer
local ARENA = Config.SNOWBALL
local CENTER = ARENA.CENTER
local ACTIVE_RANGE = 260 -- bots only move when the camera is this close
local HIT_RADIUS = 2.7
local SNOW = Color3.fromRGB(245, 250, 255)
local GOLD = Color3.fromRGB(255, 205, 70)

type Bot = {
	model: Model,
	stars: BillboardGui,
	at: Vector3,
	target: Vector3,
	facing: number,
	wait: number,
	throwIn: number,
	windup: number,
	aim: Vector3?,
	down: number, -- seconds left lying in the snow (0 = up)
	offset: number,
}
type Ball = {
	part: BasePart,
	pos: Vector3,
	vel: Vector3,
	owner: "me" | "bot" | "other",
	bot: Bot?,
	life: number,
}

local folder: Folder
local screen: ScreenGui
local chip: Frame
local chipLabel: TextLabel
local splat: Frame
local bots: { Bot } = {}
local balls: { Ball } = {}
local inArena = false
local flying = false
local hits = 0
local lastThrow = 0
local knockedUntil = 0
local rayParams = RaycastParams.new()

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function arenaPoint(maxRadius: number): Vector3
	local a = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * maxRadius
	return Vector3.new(CENTER.X + math.cos(a) * r, CENTER.Y, CENTER.Z + math.sin(a) * r)
end

--------------------------------------------------------------------------------
-- Effects
--------------------------------------------------------------------------------

local function snowPuff(at: Vector3, amount: number)
	local holder = Build.deco({
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(at),
		Transparency = 1,
		Parent = folder,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(SNOW)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Size = NumberSequence.new(1, 3)
	emitter.Lifetime = NumberRange.new(0.3, 0.7)
	emitter.Speed = NumberRange.new(6, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(amount)
	task.delay(1, function()
		holder:Destroy()
	end)
end

-- Snow splattered over the screen when the player takes one in the face.
local function screenSplat()
	for _ = 1, 7 do
		local size = 0.12 + math.random() * 0.2
		local blob: Frame = UI.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.15 + math.random() * 0.7, 0.15 + math.random() * 0.6),
			Size = UDim2.fromScale(size, size),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.1,
			Parent = splat,
		})
		UI.make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = blob })
		UI.corner(blob, 200)
		UI.pop(blob, 0.3)
		UI.tween(blob, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
			Position = blob.Position + UDim2.fromScale(0, 0.12),
		})
		task.delay(1.7, function()
			blob:Destroy()
		end)
	end
end

local function updateChip()
	chipLabel.Text = if UserInputService.TouchEnabled
		then `❄ Tap to throw!   Hits: {hits}`
		else `❄ Click to throw!   Hits: {hits}`
end

--------------------------------------------------------------------------------
-- Snowballs
--------------------------------------------------------------------------------

local function launch(
	origin: Vector3,
	velocity: Vector3,
	owner: "me" | "bot" | "other",
	bot: Bot?,
	gold: boolean?
)
	local part = Build.ball(
		folder,
		CFrame.new(origin),
		1.3,
		if gold then GOLD else SNOW,
		if gold then Enum.Material.Neon else Enum.Material.Snow
	)
	part.CastShadow = false
	if gold then
		-- Golden Snowballs pass: glitter only, it hits just the same.
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = GOLD
		sparkles.Parent = part
	end
	table.insert(
		balls,
		{ part = part, pos = origin, vel = velocity, owner = owner, bot = bot, life = 4 }
	)
end

-- Velocity that lobs a ball from `from` so it lands on `to`.
local function lob(from: Vector3, to: Vector3, speed: number): Vector3
	local delta = to - from
	local distance = math.max(1, flat(delta).Magnitude)
	local time = distance / speed
	local horizontal = flat(delta) / time
	local vertical = delta.Y / time + ARENA.GRAVITY * time / 2
	return Vector3.new(horizontal.X, vertical, horizontal.Z)
end

local function knockPlayer()
	local now = os.clock()
	if now < knockedUntil then
		return
	end
	knockedUntil = now + 2.5
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	screenSplat()
	UI.sound("Pop", 0.6, 0.7)
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
		task.delay(1.2, function()
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end
end

local function knockBot(bot: Bot, byPlayer: boolean)
	if bot.down > 0 then
		return
	end
	bot.down = 2.6
	bot.windup = 0
	bot.aim = nil
	bot.stars.Enabled = true
	snowPuff(bot.at + Vector3.new(0, 3, 0), 16)
	if byPlayer then
		hits += 1
		updateChip()
		UI.pop(chip, 1.2)
		UI.sound("Pop", 0.55, 1.15)
		UI.sound("Coin", 0.35, 1 + math.min(hits, 12) * 0.04)
		if hits == 5 or hits == 10 or hits % 25 == 0 then
			Bus.fire("Announce", `❄ {hits} hits! ❄`, Color3.fromRGB(170, 220, 255))
		end
	end
end

local function stepBalls(dt: number)
	for i = #balls, 1, -1 do
		local ball = balls[i]
		ball.life -= dt
		ball.vel -= Vector3.new(0, ARENA.GRAVITY * dt, 0)
		local step = ball.vel * dt
		local nextPos = ball.pos + step
		local done = ball.life <= 0
		local splatAt: Vector3? = nil

		-- Elf bots (their parts do not take raycasts, so check by distance).
		for _, bot in bots do
			if bot ~= ball.bot and bot.down <= 0 and ball.owner ~= "other" then
				local body = bot.at + Vector3.new(0, 2.6, 0)
				if (nextPos - body).Magnitude < HIT_RADIUS then
					knockBot(bot, ball.owner == "me")
					splatAt = nextPos
					break
				end
			end
		end

		if not splatAt and step.Magnitude > 0 then
			local character = player.Character
			rayParams.FilterDescendantsInstances = if ball.owner == "me" and character
				then { character }
				else {}
			local result = workspace:Raycast(ball.pos, step, rayParams)
			if result then
				splatAt = result.Position
				local model = result.Instance:FindFirstAncestorOfClass("Model")
				local victim = model and Players:GetPlayerFromCharacter(model)
				if victim == player and ball.owner == "bot" then
					knockPlayer()
				elseif victim and victim ~= player and ball.owner == "me" then
					hits += 1
					updateChip()
					UI.sound("Pop", 0.55, 1.15)
					task.spawn(Net.request, "SnowballHit", victim.UserId)
				end
			end
		end

		if splatAt then
			snowPuff(splatAt, 10)
			done = true
		end
		if done then
			ball.part:Destroy()
			table.remove(balls, i)
		else
			ball.pos = nextPos
			ball.part.CFrame = CFrame.new(nextPos)
		end
	end
end

local function throwAt(screenPoint: Vector2)
	local now = os.clock()
	local root = rootPart()
	local camera = workspace.CurrentCamera
	if
		not inArena
		or flying
		or not root
		or not camera
		or now - lastThrow < ARENA.COOLDOWN
		or now < knockedUntil - 1.3
		or UI.anyPanelOpen()
	then
		return
	end
	lastThrow = now
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	local character = player.Character
	rayParams.FilterDescendantsInstances = if character then { character } else {}
	local result = workspace:Raycast(ray.Origin, ray.Direction * 400, rayParams)
	local aim = if result then result.Position else ray.Origin + ray.Direction * 120
	-- Bots do not take raycasts, so snap the aim to one the click passes over.
	for _, bot in bots do
		local body = bot.at + Vector3.new(0, 2.6, 0)
		local along = (body - ray.Origin):Dot(ray.Direction)
		if along > 0 and (ray.Origin + ray.Direction * along - body).Magnitude < 3.5 then
			if not result or along < (result.Position - ray.Origin).Magnitude then
				aim = body
			end
		end
	end
	local origin = root.Position + Vector3.new(0, 2, 0)
	local toward = flat(aim - origin)
	if toward.Magnitude > 0.1 then
		origin += toward.Unit * 1.6
	end
	local velocity = lob(origin, aim, ARENA.SPEED)
	local data = State.data
	launch(origin, velocity, "me", nil, data and data.passes.GoldenSnowballs == true)
	UI.sound("Whoosh", 0.3, 1.3)
	task.spawn(Net.request, "SnowballThrow", origin, velocity)
end

--------------------------------------------------------------------------------
-- Bots
--------------------------------------------------------------------------------

local function makeBot(index: number): Bot
	local model = ElfModel.build(index, 1.1)
	model.Name = "SnowballElf"
	model.Parent = folder
	local stars: BillboardGui = UI.make("BillboardGui", {
		Size = UDim2.fromScale(5, 2.2),
		StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0),
		LightInfluence = 0,
		MaxDistance = 200,
		Enabled = false,
		Adornee = model.PrimaryPart,
		Parent = model,
	})
	UI.text({ Text = "💫😵💫", MaxTextSize = 80, Parent = stars })
	local at = arenaPoint(ARENA.RADIUS - 6)
	return {
		model = model,
		stars = stars,
		at = at,
		target = at,
		facing = 0,
		wait = index * 0.4,
		throwIn = 1.5 + index * 0.7,
		windup = 0,
		aim = nil,
		down = 0,
		offset = index * 1.3,
	}
end

local function faceTo(from: Vector3, to: Vector3): number
	local d = flat(to - from)
	return math.atan2(-d.X, -d.Z)
end

-- Who a bot throws at: the player when they are in the arena (most of the
-- time), otherwise another bot that is still standing.
local function pickAim(bot: Bot): Vector3?
	local root = rootPart()
	if inArena and root and os.clock() > knockedUntil and math.random() < 0.7 then
		-- Bots are not great shots.
		local miss = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 9
		return root.Position + root.AssemblyLinearVelocity * 0.35 + miss
	end
	local others: { Bot } = {}
	for _, other in bots do
		if other ~= bot and other.down <= 0 then
			table.insert(others, other)
		end
	end
	if #others == 0 then
		return nil
	end
	local other = others[math.random(1, #others)]
	local miss = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 7
	return other.at + Vector3.new(0, 2.6, 0) + miss
end

local function stepBot(bot: Bot, t: number, dt: number)
	local cf: CFrame
	local pose: ElfModel.Pose = "idle"
	local stride = 0
	if bot.down > 0 then
		-- Flat on its back in the snow, legs kicking, then hops back up.
		bot.down -= dt
		local total = 2.6
		local elapsed = total - bot.down
		local tilt = if elapsed < 0.3
			then elapsed / 0.3
			elseif bot.down < 0.35 then math.max(0, bot.down / 0.35)
			else 1
		local bounce = if elapsed < 0.6
			then math.abs(math.sin(elapsed * 10)) * (0.6 - elapsed)
			else 0
		cf = CFrame.new(bot.at + Vector3.new(0, tilt * 0.7 + bounce, 0))
			* CFrame.Angles(0, bot.facing, 0)
			* CFrame.Angles(math.rad(88) * tilt, 0, 0)
		pose = "walk"
		stride = 0.9
		if bot.down <= 0 then
			bot.stars.Enabled = false
			bot.target = arenaPoint(ARENA.RADIUS - 6)
			bot.throwIn = 1 + math.random() * 1.5
		end
	elseif bot.windup > 0 then
		-- Arm up, then let fly.
		bot.windup -= dt
		local aim = bot.aim
		if aim then
			bot.facing = faceTo(bot.at, aim)
		end
		pose = "wave"
		cf = CFrame.new(bot.at) * CFrame.Angles(0, bot.facing, 0)
		if bot.windup <= 0 and aim then
			local origin = bot.at + Vector3.new(0, 3.2, 0)
			launch(origin, lob(origin, aim, ARENA.BOT_SPEED), "bot", bot)
			bot.aim = nil
		end
	else
		local toTarget = flat(bot.target - bot.at)
		local distance = toTarget.Magnitude
		if bot.wait > 0 then
			bot.wait -= dt
			if bot.wait <= 0 then
				bot.target = arenaPoint(ARENA.RADIUS - 6)
			end
		elseif distance < 0.8 then
			bot.wait = 0.3 + math.random() * 1.2
		else
			bot.at += toTarget.Unit * math.min(distance, 10 * dt)
			bot.facing = faceTo(bot.at, bot.target)
			pose = "walk"
			stride = 0.8
		end
		bot.throwIn -= dt
		if bot.throwIn <= 0 then
			bot.throwIn = 1.8 + math.random() * 2.4
			bot.aim = pickAim(bot)
			if bot.aim then
				bot.windup = 0.45
			end
		end
		local bob = if stride > 0 then math.abs(math.sin((t + bot.offset) * 9)) * 0.2 else 0
		cf = CFrame.new(bot.at + Vector3.new(0, bob, 0)) * CFrame.Angles(0, bot.facing, 0)
	end
	ElfModel.place(bot.model, cf)
	ElfModel.step(bot.model, t + bot.offset, stride, pose)
end

--------------------------------------------------------------------------------

function Snowball.init()
	screen = UI.screen("Snowball", 4)
	screen.IgnoreGuiInset = true
	splat = UI.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	chip = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.3, 0.055),
		BackgroundColor3 = Color3.fromRGB(25, 45, 80),
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = screen,
	})
	UI.make(
		"UISizeConstraint",
		{ MinSize = Vector2.new(240, 34), MaxSize = Vector2.new(440, 50), Parent = chip }
	)
	UI.corner(chip, 14)
	UI.stroke(chip, Color3.fromRGB(170, 220, 255), 1.5)
	chipLabel = UI.text({
		Text = "",
		Size = UDim2.fromScale(0.94, 0.76),
		Position = UDim2.fromScale(0.03, 0.12),
		MaxTextSize = 22,
		Parent = chip,
	})
	UI.textStroke(chipLabel, T.Ink, 1.5)
	updateChip()
	Bus.on("Flying", function(value: boolean)
		flying = value
	end)
end

function Snowball.start()
	folder = Instance.new("Folder")
	folder.Name = "SnowballFight"
	folder.Parent = workspace
	for i = 1, ARENA.BOTS do
		table.insert(bots, makeBot(i))
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local at = UserInputService:GetMouseLocation()
			throwAt(Vector2.new(at.X, at.Y))
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			local camera = workspace.CurrentCamera
			if camera then
				throwAt(camera.ViewportSize / 2)
			end
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if not processed then
			throwAt(position)
		end
	end)

	-- Another player's throw, shown here.
	Net.on("Snowball", function(payload)
		if typeof(payload.origin) == "Vector3" and typeof(payload.velocity) == "Vector3" then
			launch(payload.origin, payload.velocity, "other", nil, payload.gold == true)
		end
	end)
	Net.on("Snowballed", function(payload)
		knockPlayer()
		Bus.fire("Toast", `❄ {payload.by} got you!`, "info")
	end)

	RunService.Heartbeat:Connect(function(dt)
		local root = rootPart()
		local nowIn = root ~= nil
			and flat(root.Position - CENTER).Magnitude <= ARENA.RADIUS + 1
			and math.abs(root.Position.Y - CENTER.Y) < 30
		if nowIn ~= inArena then
			inArena = nowIn
			if nowIn then
				UI.pop(chip, 1.15)
			end
		end
		chip.Visible = inArena and not flying and not UI.anyPanelOpen()

		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - CENTER).Magnitude < ACTIVE_RANGE then
			local t = os.clock()
			for _, bot in bots do
				stepBot(bot, t, dt)
			end
		end
		stepBalls(dt)
	end)
end

return Snowball
