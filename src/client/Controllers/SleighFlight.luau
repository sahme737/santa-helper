--!strict
-- Sleigh Delivery: the route picker, the flight itself (steering, wind,
-- blizzards, drop button, house markers, run HUD) and the star summary.
-- The server validates every drop and decides every reward.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Build = require(Shared.Util.Build)
local Format = require(Shared.Util.Format)
local ToyModels = require(Shared.Models.ToyModels)

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local Bus = require(Lib.Bus)
local Rows = require(Lib.Rows)
local State = require(Lib.State)

local SleighFlight = {}

local T = UI.Theme
local player = Players.LocalPlayer

local COAL_COLOR = Color3.fromRGB(150, 40, 40)
local GOLD_COLOR = Color3.fromRGB(255, 225, 90)

type Marker = { part: BasePart, gui: BillboardGui, kind: string }

type Flight = {
	route: Config.RouteDef,
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
	targets: number,
	markers: { [number]: Marker },
	conn: RBXScriptConnection?,
	lastDrop: number,
	windSeed: number,
	hurry: boolean,
	baseDensity: number?,
	baseFov: number,
}

local flight: Flight? = nil
local controls: any = nil
local screen: ScreenGui
local hud: Frame
local timerFill: Frame
local timerLabel: TextLabel
local countLabel: TextLabel
local starLabel: TextLabel
local comboLabel: TextLabel
local windLabel: TextLabel
local routeLabel: TextLabel
local summary: Frame
local summaryStars: { TextLabel } = {}
local summaryNext: TextButton
local picker: UI.Panel
local pickerRows: { Rows.Row } = {}
local lastRoute = 1

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

local function starText(stars: number): string
	return string.rep("★", stars) .. string.rep("☆", 3 - stars)
end

--------------------------------------------------------------------------------
-- House markers
--------------------------------------------------------------------------------

local function makeMarkers(f: Flight, houses: { [string]: string })
	for _, part in CollectionService:GetTagged("Chimney") do
		if not part:IsA("BasePart") then
			continue
		end
		local index = tonumber(part:GetAttribute("Index")) or 0
		local kind = houses[tostring(index)]
		if not kind then
			continue
		end
		local color = if kind == "coal"
			then COAL_COLOR
			elseif kind == "gold" then GOLD_COLOR
			else T.Gold
		local ring = Build.deco({
			Name = "ChimneyGuide",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, f.radius * 2, f.radius * 2),
			CFrame = CFrame.new(part.Position + Vector3.new(0, 0.5, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			CastShadow = false,
			Parent = workspace,
		})
		-- A beam of light so houses read from far away (not in a blizzard).
		if kind ~= "coal" and not f.route.fog then
			Build.deco({
				Name = "Beacon",
				Size = Vector3.new(1.2, 60, 1.2),
				CFrame = CFrame.new(part.Position + Vector3.new(0, 30, 0)),
				Color = color,
				Material = Enum.Material.Neon,
				Transparency = if kind == "gold" then 0.45 else 0.75,
				CastShadow = false,
				Parent = ring,
			})
		end
		local gui = Build.billboard(
			ring,
			if kind == "coal" then "🚫" elseif kind == "gold" then "🌟" else "🎁",
			if kind == "gold" then UDim2.fromOffset(60, 60) else UDim2.fromOffset(46, 46),
			Vector3.new(0, 10, 0),
			Color3.new(1, 1, 1),
			if f.route.fog then 330 else 900
		)
		gui.AlwaysOnTop = not f.route.fog
		f.markers[index] = { part = ring, gui = gui, kind = kind }
	end
end

local function clearMarkers(f: Flight)
	for _, m in f.markers do
		m.part:Destroy()
	end
	table.clear(f.markers)
end

local function burst(at: Vector3, color: Color3, amount: number)
	local holder = Build.deco({
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(at),
		Transparency = 1,
		Parent = workspace,
	})
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(1.8, 0)
	sparkle.Lifetime = NumberRange.new(0.5, 1.1)
	sparkle.Speed = NumberRange.new(8, 18)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Rate = 0
	sparkle.Parent = holder
	sparkle:Emit(amount)
	task.delay(1.6, function()
		holder:Destroy()
	end)
end

local function dropVisual(from: Vector3, to: Vector3, hitColor: Color3?)
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
		if hitColor then
			burst(to, hitColor, 40)
		end
		present:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Flight
--------------------------------------------------------------------------------

local function atmosphere(): Atmosphere?
	return Lighting:FindFirstChildOfClass("Atmosphere")
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
	local fog = atmosphere()
	if fog and f.baseDensity then
		UI.tween(fog, UI.SMOOTH, { Density = f.baseDensity })
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		UI.tween(camera, UI.SMOOTH, { FieldOfView = f.baseFov })
	end
	hud.Visible = false
	Bus.fire("Flying", false)
	Bus.fire("FlightAudio", { flying = false, wind = 0, hurry = false })
end

local function updateCount(f: Flight)
	local stars = Economy.starsFor(f.route, f.count)
	local nextNeed = f.route.stars[stars + 1]
	countLabel.Text = `🎁 {f.count} / {f.targets}`
	starLabel.Text = if nextNeed
		then `{starText(stars)}  next ★ at {nextNeed}`
		else `{starText(stars)}  all stars!`
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
	UI.sound("Drop", 0.35)
	task.spawn(function()
		local ok, data = Net.request("DropPresent")
		if flight ~= f then
			return
		end
		if ok and typeof(data) == "table" then
			f.delivered[data.index] = true
			local marker = f.markers[data.index]
			local target = if marker then marker.part.Position else from - Vector3.new(0, 40, 0)
			if marker then
				marker.part.Transparency = 0.9
				marker.gui.Enabled = false
				for _, child in marker.part:GetChildren() do
					if child:IsA("BasePart") then
						child:Destroy()
					end
				end
			end
			if data.coal then
				-- Naughty house: lose time and the combo.
				if marker then
					marker.part.Color = Color3.fromRGB(40, 40, 40)
				end
				f.endsAt = os.clock() + data.remaining
				dropVisual(from, target, COAL_COLOR)
				UI.sound("Error", 0.6)
				comboLabel.Text = `🚫 NAUGHTY HOUSE!  -{Config.ROUTE.COAL_TIME_PENALTY}s`
				comboLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
				comboLabel.Visible = true
				UI.pop(comboLabel, 1.5)
				UI.pop(timerLabel, 1.4)
				return
			end
			local before = Economy.starsFor(f.route, f.count)
			f.count = data.count
			if marker then
				marker.part.Color = T.Green
			end
			dropVisual(from, target, if data.golden then GOLD_COLOR else T.Gold)
			-- The chime climbs with the combo.
			UI.sound("Coin", 0.55, 1 + math.min(data.combo, 12) * 0.06)
			if data.golden then
				UI.sound("Sparkle", 0.5)
			end
			Bus.fire("FloatGain", `+{Format.short(data.reward)}`, T.Gold)
			updateCount(f)
			comboLabel.TextColor3 = Color3.fromRGB(255, 160, 60)
			if data.stars > before then
				UI.sound("Star", 0.7)
				comboLabel.Text = `{starText(data.stars)}  STAR!`
				comboLabel.TextColor3 = GOLD_COLOR
				comboLabel.Visible = true
				UI.pop(comboLabel, 1.7)
				UI.pop(starLabel, 1.4)
			elseif data.golden then
				comboLabel.Text = "🌟 GOLDEN HOUSE x3!"
				comboLabel.Visible = true
				UI.pop(comboLabel, 1.5)
			elseif data.combo >= 2 then
				comboLabel.Text = `COMBO x{data.combo}!`
				comboLabel.Visible = true
				UI.pop(comboLabel, 1.5)
			end
		else
			local ground = f.townOrigin.Y
			dropVisual(from, Vector3.new(from.X, ground + 1, from.Z), nil)
			if data == "miss" then
				comboLabel.Text = "Miss!"
				comboLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
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
	local now = os.clock()
	local move = moveVector()
	local turn = math.clamp(move.X, -1, 1)
	-- Keep the sleigh inside the town.
	local flat =
		Vector3.new(f.root.Position.X - f.townOrigin.X, 0, f.root.Position.Z - f.townOrigin.Z)
	if flat.Magnitude > 720 then
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

	-- Chase camera: sits behind and above the sleigh and looks ahead and down,
	-- so the chimneys coming up are always in view.
	local cam = workspace.CurrentCamera
	if cam then
		local pos = f.root.Position
		local goal = CFrame.lookAt(
			pos - look * 30 + Vector3.new(0, 15, 0),
			pos + look * 34 - Vector3.new(0, 8, 0)
		)
		if cam.CameraType ~= Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = goal
		else
			cam.CFrame = cam.CFrame:Lerp(goal, math.min(1, dt * 6))
		end
	end
	local targetY = f.townOrigin.Y + f.altitude
	local climb = math.clamp((targetY - f.root.Position.Y) * 2, -30, 30)

	-- Wind: gusts swell and fade and slowly swing round the compass, so the
	-- pilot has to keep correcting instead of flying straight lines.
	local gust = 0
	local windVector = Vector3.zero
	if f.route.wind > 0 then
		local t = now + f.windSeed
		gust = (0.55 + 0.45 * math.sin(t * 0.9)) * math.clamp(math.sin(t * 0.31) * 1.6, -1, 1)
		local heading = t * 0.12
		windVector = Vector3.new(math.cos(heading), 0, math.sin(heading)) * gust * f.route.wind
		-- Arrow shows where the wind pushes, relative to the sleigh's nose.
		local right = Vector3.new(-look.Z, 0, look.X)
		local angle = math.deg(math.atan2(windVector:Dot(right), windVector:Dot(look)))
		windLabel.Rotation = angle - 90
		windLabel.TextTransparency = 1 - math.clamp(math.abs(gust) * 1.4, 0.35, 1)
	end
	f.velocity.VectorVelocity = look * speed + windVector + Vector3.new(0, climb, 0)
	f.align.CFrame = CFrame.Angles(0, f.yaw, 0)
		* CFrame.Angles(math.sin(now * 2.8) * 0.03, 0, f.bank + gust * 0.12)

	-- Timer and in-range highlight
	local remaining = math.max(0, f.endsAt - now)
	timerLabel.Text = `🌙 {Format.time(remaining)}`
	timerFill.Size = UDim2.fromScale(math.clamp(remaining / f.duration, 0, 1), 1)
	local hurry = remaining <= 10
	timerFill.BackgroundColor3 = if hurry
		then (if math.floor(now * 4) % 2 == 0
			then Color3.fromRGB(255, 90, 90)
			else Color3.fromRGB(255, 170, 90))
		else Color3.fromRGB(120, 160, 255)
	if hurry ~= f.hurry then
		f.hurry = hurry
		Bus.fire("FlightAudio", { flying = true, wind = f.route.wind / 24, hurry = hurry })
	end
	local pos = f.root.Position
	for index, m in f.markers do
		if not f.delivered[index] then
			local d = Vector3.new(pos.X - m.part.Position.X, 0, pos.Z - m.part.Position.Z).Magnitude
			local inRange = d <= f.radius
			if m.kind == "gift" then
				m.part.Color = if inRange then T.Green else T.Gold
			end
			m.part.Transparency = if inRange then 0.2 else 0.6
		end
	end
end

function SleighFlight.begin(routeId: number)
	if flight then
		return
	end
	local ok, data = Net.request("StartDelivery", routeId)
	if not ok or typeof(data) ~= "table" then
		if typeof(data) == "string" then
			Bus.fire("Toast", data, "error")
		end
		return
	end
	local def = Config.ROUTES[data.route]
	if not def then
		return
	end
	lastRoute = def.id
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

	local camera = workspace.CurrentCamera
	local fog = atmosphere()
	local f: Flight = {
		route = def,
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
		targets = data.targets,
		markers = {},
		conn = nil,
		lastDrop = 0,
		windSeed = math.random() * 100,
		hurry = false,
		baseDensity = if fog then fog.Density else nil,
		baseFov = if camera then camera.FieldOfView else 70,
	}
	flight = f
	makeMarkers(f, data.houses)
	updateCount(f)
	routeLabel.Text = `{def.emoji} Route {def.id}: {def.name}`
	comboLabel.Visible = false
	windLabel.Visible = def.wind > 0
	hud.Visible = true
	summary.Visible = false
	if fog and def.fog then
		UI.tween(fog, UI.SMOOTH, { Density = 0.62 })
	end
	if camera then
		UI.tween(camera, UI.SMOOTH, { FieldOfView = 82 })
	end
	UI.sound("Whoosh", 0.6)
	Bus.fire("Flying", true)
	Bus.fire("FlightAudio", { flying = true, wind = def.wind / 24, hurry = false })
	Bus.fire(
		"Announce",
		if def.coal > 0
			then "🛷 Deliver to the glowing houses. Skip the 🚫 naughty ones!"
			else "🛷 Drop presents down the glowing chimneys!",
		T.Gold
	)
	f.conn = RunService.RenderStepped:Connect(step)
	ContextActionService:BindAction("SleighDrop", function(_, state)
		if state == Enum.UserInputState.Begin then
			tryDrop()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.UserInputType.MouseButton1)
end

--------------------------------------------------------------------------------
-- Route picker
--------------------------------------------------------------------------------

local function refreshPicker()
	local profile = State.profile()
	if not profile then
		return
	end
	for i, def in Config.ROUTES do
		local row = pickerRows[i]
		local stars = Economy.routeStars(profile, def.id)
		local unlocked = Economy.routeUnlocked(profile, def.id)
		row.title.Text = `{def.id}. {def.name}  {starText(stars)}`
		local hazards = {}
		if def.coal > 0 then
			table.insert(hazards, `🚫{def.coal}`)
		end
		if def.wind > 0 then
			table.insert(hazards, "💨")
		end
		if def.fog then
			table.insert(hazards, "🌫")
		end
		if def.radius < 1 then
			table.insert(hazards, "🎯")
		end
		if unlocked then
			local best = Economy.routeBest(profile, def.id)
			row.desc.Text = `★ at {def.stars[1]}/{def.stars[2]}/{def.stars[3]} 🎁 · x{def.reward} Cheer · {def.time}s`
				.. (if #hazards > 0 then " · " .. table.concat(hazards, " ") else "")
				.. (if best > 0 then ` · Best {best}` else "")
			Rows.setPrice(row, if stars >= 3 then "Fly again" else "Fly!", true, true)
		else
			row.desc.Text =
				`🔒 Earn a star on {Config.ROUTES[def.id - 1].name} to unlock · {def.blurb}`
			Rows.setPrice(row, "Locked", false, false)
		end
		row.icon.Text = if unlocked then def.emoji else "🔒"
	end
end

local function openPicker()
	if flight then
		return
	end
	if picker.isOpen() then
		picker.close()
		return
	end
	refreshPicker()
	summary.Visible = false
	picker.open()
end

--------------------------------------------------------------------------------
-- Summary
--------------------------------------------------------------------------------

local function showSummary(result: any)
	local def = Config.ROUTES[result.route] or Config.ROUTES[1]
	summary.Visible = true
	local title = summary:FindFirstChild("Title") :: TextLabel
	title.Text = `{def.emoji} {def.name}`
	local body = summary:FindFirstChild("Body") :: TextLabel
	local lines = {
		if result.stars == 0
			then `Deliver {def.stars[1]} presents to earn a star`
			elseif result.perfect then "🌟 PERFECT NIGHT! Every house! 🌟"
			elseif result.newStars > 0 then "✨ New stars earned! ✨"
			else "🎄 What a night! 🎄",
		`🎁 Delivered: {result.count} / {result.targets}` .. (if result.count
					> result.previousBest
				and result.previousBest > 0
			then "  (new best!)"
			else ""),
		`⭐ Cheer: {Format.short(result.coins)}   ❄ {result.snowflakes}   🔥 x{result.bestCombo}`,
		`🎖 +{result.xp} XP`,
	}
	if result.unlocked then
		table.insert(lines, `🔓 Unlocked: {result.unlocked}!`)
	elseif result.stars < 3 then
		table.insert(lines, `Next ★ at {def.stars[result.stars + 1]} presents`)
	end
	body.Text = table.concat(lines, "\n")
	UI.pop(summary, 0.6)

	-- Stars land one at a time.
	for _, label in summaryStars do
		label.Text = "☆"
		label.TextColor3 = Color3.fromRGB(190, 180, 170)
	end
	task.spawn(function()
		for i = 1, result.stars do
			task.wait(0.4)
			if not summary.Visible then
				return
			end
			local label = summaryStars[i]
			label.Text = "★"
			label.TextColor3 = GOLD_COLOR
			UI.pop(label, 1.8)
			UI.sound("Star", 0.7, 0.9 + i * 0.12)
		end
		if result.stars >= 3 then
			UI.sound("PartyHorn", 0.6)
			Bus.fire("Confetti", 70)
		elseif result.stars >= 1 then
			UI.sound("Win", 0.6)
			if result.newStars > 0 then
				Bus.fire("Confetti", 35)
			end
		end
	end)

	local profile = State.profile()
	local nextDef = Config.ROUTES[def.id + 1]
	local canNext = nextDef ~= nil
		and (result.stars >= 1 or (profile and Economy.routeUnlocked(profile, nextDef.id)))
	summaryNext.Visible = canNext == true
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
		Position = UDim2.fromScale(0.5, 0.075),
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
	routeLabel = UI.text({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.07),
		Size = UDim2.fromScale(0.4, 0.04),
		MaxTextSize = 20,
		Parent = hud,
	})
	UI.textStroke(routeLabel, T.Ink, 1.5)
	countLabel = UI.text({
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.495, 0.13),
		Size = UDim2.fromScale(0.2, 0.05),
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 30,
		Parent = hud,
	})
	UI.textStroke(countLabel, T.Ink, 2)
	starLabel = UI.text({
		Text = "",
		Position = UDim2.fromScale(0.505, 0.13),
		Size = UDim2.fromScale(0.24, 0.05),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD_COLOR,
		MaxTextSize = 30,
		Parent = hud,
	})
	UI.textStroke(starLabel, T.Ink, 2)
	comboLabel = UI.text({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(0.5, 0.07),
		TextColor3 = Color3.fromRGB(255, 160, 60),
		MaxTextSize = 50,
		Visible = false,
		Parent = hud,
	})
	UI.textStroke(comboLabel, T.Ink, 3)
	-- Wind arrow: points the way the gust is pushing the sleigh.
	local windHolder: Frame = UI.make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromOffset(64, 64),
		Parent = hud,
	})
	windLabel = UI.text({
		Text = "➡️",
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(190, 230, 255),
		MaxTextSize = 54,
		Visible = false,
		Parent = windHolder,
	})
	UI.textStroke(windLabel, T.Ink, 2)

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
		-- Sits just left of DROP so it never collides with the top-right HUD.
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -12, 0.5, 0),
		Size = UDim2.fromOffset(110, 48),
		Parent = drop,
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

	-- Summary card
	summary = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.4, 0.56),
		BackgroundColor3 = T.Cream,
		Visible = false,
		Parent = screen,
	})
	UI.make("UIAspectRatioConstraint", { AspectRatio = 1.05, Parent = summary })
	UI.corner(summary, 18)
	UI.stroke(summary, T.Ink, 4)
	local title = UI.text({
		Name = "Title",
		Text = "🛷 Delivery Complete!",
		Size = UDim2.fromScale(0.9, 0.12),
		Position = UDim2.fromScale(0.05, 0.03),
		TextColor3 = T.Red,
		MaxTextSize = 36,
		Parent = summary,
	})
	UI.textStroke(title, T.Ink, 1.5)
	for i = 1, 3 do
		local star = UI.text({
			Text = "☆",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + (i - 2) * 0.22, if i == 2 then 0.25 else 0.28),
			Size = UDim2.fromScale(0.22, 0.2),
			TextColor3 = Color3.fromRGB(190, 180, 170),
			MaxTextSize = 90,
			Parent = summary,
		})
		UI.textStroke(star, T.Ink, 3)
		summaryStars[i] = star
	end
	UI.text({
		Name = "Body",
		Text = "",
		Size = UDim2.fromScale(0.9, 0.4),
		Position = UDim2.fromScale(0.05, 0.4),
		TextColor3 = T.Ink,
		FontFace = UI.BodyFont,
		MaxTextSize = 22,
		Parent = summary,
	})
	UI.button({
		Text = "Retry",
		Color = T.Blue,
		Size = UDim2.fromScale(0.28, 0.12),
		Position = UDim2.fromScale(0.04, 0.84),
		Parent = summary,
		OnClick = function()
			summary.Visible = false
			SleighFlight.begin(lastRoute)
		end,
	})
	summaryNext = UI.button({
		Text = "Next Route ▶",
		Color = T.Gold,
		Size = UDim2.fromScale(0.34, 0.12),
		Position = UDim2.fromScale(0.34, 0.84),
		Parent = summary,
		OnClick = function()
			summary.Visible = false
			SleighFlight.begin(lastRoute + 1)
		end,
	})
	UI.button({
		Text = "Done",
		Color = T.Green,
		Size = UDim2.fromScale(0.26, 0.12),
		Position = UDim2.fromScale(0.7, 0.84),
		Parent = summary,
		OnClick = function()
			summary.Visible = false
		end,
	})

	-- Route picker
	picker = UI.panel(screen, "🛷 Choose Your Route", T.Blue)
	local list = Rows.list(picker.content)
	-- No tabs on this panel, so the list uses that strip too.
	list.Size = UDim2.fromScale(1, 1.137)
	list.Position = UDim2.fromScale(0, -0.137)
	for i, def in Config.ROUTES do
		pickerRows[i] = Rows.row(list, i, def.emoji, function()
			local profile = State.profile()
			if profile and Economy.routeUnlocked(profile, def.id) then
				picker.close()
				SleighFlight.begin(def.id)
			else
				Bus.fire("Toast", "Earn a star on the route before it first", "error")
			end
		end)
	end
end

function SleighFlight.start()
	Bus.on("StartDelivery", openPicker)
	State.onChanged(function()
		if picker.isOpen() then
			refreshPicker()
		end
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
