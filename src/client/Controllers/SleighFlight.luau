--!strict
-- Sleigh Delivery flight: steering, drop button, chimney guides, run HUD
-- and the end-of-night summary. The server validates every drop.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Format = require(Shared.Util.Format)
local ToyModels = require(Shared.Models.ToyModels)

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local Bus = require(Lib.Bus)

local SleighFlight = {}

local T = UI.Theme
local player = Players.LocalPlayer

type Flight = {
	root: BasePart,
	humanoid: Humanoid,
	attachment: Attachment,
	velocity: LinearVelocity,
	align: AlignOrientation,
	yaw: number,
	bank: number,
	speed: number,
	radius: number,
	altitude: number,
	townOrigin: Vector3,
	endsAt: number,
	duration: number,
	delivered: { [number]: boolean },
	count: number,
	markers: { [number]: { part: BasePart, gui: BillboardGui } },
	conn: RBXScriptConnection?,
	lastDrop: number,
}

local flight: Flight? = nil
local controls: any = nil
local screen: ScreenGui
local hud: Frame
local timerFill: Frame
local timerLabel: TextLabel
local countLabel: TextLabel
local comboLabel: TextLabel
local summary: Frame

local function getControls(): any
	if controls then
		return controls
	end
	local ok, result = pcall(function()
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		return (require(module :: ModuleScript) :: any):GetControls()
	end)
	if ok then
		controls = result
	end
	return controls
end

local function moveVector(): Vector3
	local c = getControls()
	if c then
		local ok, v = pcall(function()
			return c:GetMoveVector()
		end)
		if ok and typeof(v) == "Vector3" then
			return v
		end
	end
	return Vector3.zero
end

local function chimneyIndex(part: Instance): number
	return tonumber(part:GetAttribute("Index")) or 0
end

local function makeMarkers(f: Flight)
	for _, part in CollectionService:GetTagged("Chimney") do
		if part:IsA("BasePart") then
			local index = chimneyIndex(part)
			local ring = Build.deco({
				Name = "ChimneyGuide",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, f.radius * 2, f.radius * 2),
				CFrame = CFrame.new(part.Position + Vector3.new(0, 0.5, 0))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = T.Gold,
				Material = Enum.Material.Neon,
				Transparency = 0.6,
				CastShadow = false,
				Parent = workspace,
			})
			local gui = Build.billboard(
				ring,
				"🎁",
				UDim2.fromOffset(46, 46),
				Vector3.new(0, 10, 0),
				Color3.new(1, 1, 1),
				900
			)
			gui.AlwaysOnTop = true
			f.markers[index] = { part = ring, gui = gui }
		end
	end
end

local function clearMarkers(f: Flight)
	for _, m in f.markers do
		m.part:Destroy()
	end
	table.clear(f.markers)
end

local function dropVisual(from: Vector3, to: Vector3, hit: boolean)
	local present = ToyModels.present(2.2, math.random(1, 5))
	local root = present.PrimaryPart :: BasePart
	Build.weldModel(present, root)
	for _, d in present:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
		end
	end
	root.Anchored = true
	present:PivotTo(CFrame.new(from))
	present.Parent = workspace
	local fall = math.max(0.35, (from.Y - to.Y) / 90)
	UI.tween(root, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(to) * CFrame.Angles(math.rad(180), math.rad(90), 0),
	})
	task.delay(fall, function()
		if hit then
			local burst = Build.deco({
				Size = Vector3.new(1, 1, 1),
				CFrame = CFrame.new(to),
				Transparency = 1,
				Parent = workspace,
			})
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkle.Color = ColorSequence.new(T.Gold, Color3.new(1, 1, 1))
			sparkle.LightEmission = 1
			sparkle.Size = NumberSequence.new(1.6, 0)
			sparkle.Lifetime = NumberRange.new(0.5, 1)
			sparkle.Speed = NumberRange.new(8, 16)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Rate = 0
			sparkle.Parent = burst
			sparkle:Emit(40)
			task.delay(1.5, function()
				burst:Destroy()
			end)
		end
		present:Destroy()
	end)
end

local function stopFlight()
	local f = flight
	if not f then
		return
	end
	flight = nil
	if f.conn then
		f.conn:Disconnect()
	end
	ContextActionService:UnbindAction("SleighDrop")
	clearMarkers(f)
	f.velocity:Destroy()
	f.align:Destroy()
	f.attachment:Destroy()
	if f.humanoid.Parent then
		f.humanoid.PlatformStand = false
		f.humanoid.AutoRotate = true
	end
	hud.Visible = false
end

local function tryDrop()
	local f = flight
	if not f then
		return
	end
	local now = os.clock()
	if now - f.lastDrop < 0.25 then
		return
	end
	f.lastDrop = now
	local from = f.root.Position - Vector3.new(0, 4, 0)
	task.spawn(function()
		local ok, data = Net.request("DropPresent")
		if not flight then
			return
		end
		if ok and typeof(data) == "table" then
			f.delivered[data.index] = true
			f.count = data.count
			local marker = f.markers[data.index]
			local target = if marker then marker.part.Position else from - Vector3.new(0, 40, 0)
			if marker then
				marker.part.Color = T.Green
				marker.part.Transparency = 0.85
				marker.gui.Enabled = false
			end
			dropVisual(from, target, true)
			UI.sound("Coin", 0.55, 1 + math.min(data.combo, 10) * 0.05)
			Bus.fire("FloatGain", `+{Format.short(data.reward)}`, T.Gold)
			countLabel.Text = `🎁 {data.count} delivered`
			if data.combo >= 2 then
				comboLabel.Text = `COMBO x{data.combo}!`
				comboLabel.Visible = true
				UI.pop(comboLabel, 1.5)
			end
		else
			local ground = f.townOrigin.Y
			dropVisual(from, Vector3.new(from.X, ground + 1, from.Z), false)
			if data == "miss" then
				comboLabel.Text = "Miss!"
				comboLabel.Visible = true
				UI.pop(comboLabel, 1.2)
			elseif typeof(data) == "string" then
				Bus.fire("Toast", data, "error")
			end
		end
	end)
end

local function step(dt: number)
	local f = flight
	if not f then
		return
	end
	if not f.root.Parent or f.humanoid.Health <= 0 then
		stopFlight()
		return
	end
	local move = moveVector()
	local turn = math.clamp(move.X, -1, 1)
	-- Keep the sleigh inside the town.
	local flat =
		Vector3.new(f.root.Position.X - f.townOrigin.X, 0, f.root.Position.Z - f.townOrigin.Z)
	if flat.Magnitude > 600 then
		local toCenter = -flat.Unit
		local desiredYaw = math.atan2(-toCenter.X, -toCenter.Z)
		local diff = (desiredYaw - f.yaw + math.pi) % (math.pi * 2) - math.pi
		turn = math.clamp(-diff * 2, -1, 1)
	end
	f.yaw -= turn * 1.6 * dt
	f.bank += ((turn * 0.45) - f.bank) * math.min(1, dt * 5)
	local throttle = 1 - math.clamp(move.Z, -1, 1) * 0.35 -- W speeds up, S slows down
	local speed = f.speed * throttle
	local look = Vector3.new(-math.sin(f.yaw), 0, -math.cos(f.yaw))
	local targetY = f.townOrigin.Y + f.altitude
	local climb = math.clamp((targetY - f.root.Position.Y) * 2, -30, 30)
	f.velocity.VectorVelocity = look * speed + Vector3.new(0, climb, 0)
	f.align.CFrame = CFrame.Angles(0, f.yaw, 0) * CFrame.Angles(0, 0, f.bank)

	-- Timer and in-range highlight
	local remaining = math.max(0, f.endsAt - os.clock())
	timerLabel.Text = `🌙 {Format.time(remaining)}`
	timerFill.Size = UDim2.fromScale(math.clamp(remaining / f.duration, 0, 1), 1)
	local pos = f.root.Position
	for index, m in f.markers do
		if not f.delivered[index] then
			local d = Vector3.new(pos.X - m.part.Position.X, 0, pos.Z - m.part.Position.Z).Magnitude
			local inRange = d <= f.radius
			m.part.Color = if inRange then T.Green else T.Gold
			m.part.Transparency = if inRange then 0.2 else 0.6
		end
	end
end

function SleighFlight.begin()
	if flight then
		return
	end
	local ok, data = Net.request("StartDelivery")
	if not ok or typeof(data) ~= "table" then
		if typeof(data) == "string" then
			Bus.fire("Toast", data, "error")
		end
		return
	end
	Bus.fire("CloseMenus")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		Net.request("EndDelivery")
		return
	end
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	local attachment = Instance.new("Attachment")
	attachment.Name = "SleighFlight"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Attachment0 = attachment
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.MaxTorque = math.huge
	align.Responsiveness = 40
	align.CFrame = CFrame.new()
	align.Parent = root

	local f: Flight = {
		root = root,
		humanoid = humanoid,
		attachment = attachment,
		velocity = velocity,
		align = align,
		yaw = 0,
		bank = 0,
		speed = data.speed,
		radius = data.radius,
		altitude = data.altitude,
		townOrigin = data.townOrigin,
		endsAt = os.clock() + data.duration,
		duration = data.duration,
		delivered = {},
		count = 0,
		markers = {},
		conn = nil,
		lastDrop = 0,
	}
	flight = f
	makeMarkers(f)
	countLabel.Text = "🎁 0 delivered"
	comboLabel.Visible = false
	hud.Visible = true
	summary.Visible = false
	Bus.fire("Announce", "🛷 Drop presents down the glowing chimneys!", T.Gold)
	f.conn = RunService.RenderStepped:Connect(step)
	ContextActionService:BindAction("SleighDrop", function(_, state)
		if state == Enum.UserInputState.Begin then
			tryDrop()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.UserInputType.MouseButton1)
end

local function showSummary(result: any)
	summary.Visible = true
	local body = summary:FindFirstChild("Body") :: TextLabel
	local lines = {
		if result.perfect
			then "🌟 PERFECT NIGHT! Every chimney! 🌟"
			else "🎄 What a night! 🎄",
		`🎁 Presents delivered: {result.count}`,
		`⭐ Cheer earned: {Format.short(result.coins)}`,
		`❄ Snowflakes: {result.snowflakes}`,
		`🔥 Best combo: x{result.bestCombo}`,
	}
	body.Text = table.concat(lines, "\n")
	UI.pop(summary, 0.6)
	UI.sound("Coin", 0.6, 0.9)
end

function SleighFlight.init()
	screen = UI.screen("Sleigh", 8)
	hud = UI.make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = screen,
	})
	local bar: Frame = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.13),
		Size = UDim2.fromScale(0.4, 0.045),
		BackgroundColor3 = Color3.fromRGB(30, 30, 60),
		Parent = hud,
	})
	UI.corner(bar, 10)
	UI.stroke(bar, T.Ink, 2.5)
	timerFill = UI.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(120, 160, 255),
		Parent = bar,
	})
	UI.corner(timerFill, 10)
	timerLabel = UI.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.9),
		Position = UDim2.fromScale(0, 0.05),
		MaxTextSize = 24,
		Parent = bar,
	})
	UI.textStroke(timerLabel, T.Ink, 1.5)
	countLabel = UI.text({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.185),
		Size = UDim2.fromScale(0.3, 0.05),
		MaxTextSize = 30,
		Parent = hud,
	})
	UI.textStroke(countLabel, T.Ink, 2)
	comboLabel = UI.text({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(0.3, 0.07),
		TextColor3 = Color3.fromRGB(255, 160, 60),
		MaxTextSize = 50,
		Visible = false,
		Parent = hud,
	})
	UI.textStroke(comboLabel, T.Ink, 3)

	local drop = UI.button({
		Text = "DROP 🎁",
		Color = T.Red,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -150),
		Size = UDim2.fromScale(0.16, 0.13),
		Parent = hud,
		MaxTextSize = 34,
		OnClick = tryDrop,
	})
	UI.make(
		"UISizeConstraint",
		{ MinSize = Vector2.new(120, 70), MaxSize = Vector2.new(240, 120), Parent = drop }
	)
	UI.button({
		Text = "Land",
		Color = T.Muted,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0.13, 0),
		Size = UDim2.fromScale(0.08, 0.05),
		Parent = hud,
		MaxTextSize = 20,
		OnClick = function()
			Net.request("EndDelivery")
		end,
	})
	UI.text({
		Text = if UserInputService.TouchEnabled
			then "Steer with the thumbstick · Tap DROP over glowing chimneys"
			else "A/D steer · W/S speed · Space or Click to drop",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.97),
		Size = UDim2.fromScale(0.6, 0.04),
		MaxTextSize = 20,
		Parent = hud,
	})

	summary = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.36, 0.44),
		BackgroundColor3 = T.Cream,
		Visible = false,
		Parent = screen,
	})
	UI.make("UIAspectRatioConstraint", { AspectRatio = 1.2, Parent = summary })
	UI.corner(summary, 18)
	UI.stroke(summary, T.Ink, 4)
	local title = UI.text({
		Text = "🛷 Delivery Complete!",
		Size = UDim2.fromScale(0.9, 0.16),
		Position = UDim2.fromScale(0.05, 0.04),
		TextColor3 = T.Red,
		MaxTextSize = 36,
		Parent = summary,
	})
	UI.textStroke(title, T.Ink, 1.5)
	UI.text({
		Name = "Body",
		Text = "",
		Size = UDim2.fromScale(0.9, 0.56),
		Position = UDim2.fromScale(0.05, 0.22),
		TextColor3 = T.Ink,
		FontFace = UI.BodyFont,
		MaxTextSize = 24,
		Parent = summary,
	})
	UI.button({
		Text = "Fly Again",
		Color = T.Blue,
		Size = UDim2.fromScale(0.42, 0.14),
		Position = UDim2.fromScale(0.05, 0.82),
		Parent = summary,
		OnClick = function()
			summary.Visible = false
			SleighFlight.begin()
		end,
	})
	UI.button({
		Text = "Awesome!",
		Color = T.Green,
		Size = UDim2.fromScale(0.42, 0.14),
		Position = UDim2.fromScale(0.53, 0.82),
		Parent = summary,
		OnClick = function()
			summary.Visible = false
		end,
	})
end

function SleighFlight.start()
	Bus.on("StartDelivery", function()
		SleighFlight.begin()
	end)
	Net.on("SleighEnd", function(result)
		stopFlight()
		showSummary(result)
	end)
	UserInputService.JumpRequest:Connect(function()
		if flight then
			tryDrop()
		end
	end)
end

return SleighFlight
