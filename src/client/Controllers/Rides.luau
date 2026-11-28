--!strict
-- Christmas Playground rides, drawn on each client and kept in step between
-- players by the shared server clock:
--   * the North Pole Express, a train that circles the plaza carrying elves
--     and festive visitors; buy a ticket at the station to ride a full lap
--   * the reindeer carousel
--   * skaters gliding round the ice rink
-- Also the "Play" list that takes the player to any attraction.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local ElfModel = require(Shared.Models.ElfModel)
local ReindeerModel = require(Shared.Models.ReindeerModel)
local TrainModel = require(Shared.Models.TrainModel)

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local Bus = require(Lib.Bus)

local Rides = {}

local T = UI.Theme
local player = Players.LocalPlayer
local PLAY = Config.PLAYGROUND
local TRAIN = PLAY.TRAIN
local CAROUSEL = PLAY.CAROUSEL
local RINK = PLAY.RINK

local RAIL_Y = 0.6
local RIDER_SCALE = 0.9
local DEER_SCALE = 1.25
local SEATED_ROOT = 1.5 -- how far a seated player's root sits above a bench
local SADDLE_ROOT = 1.1 -- ...and above a reindeer's back

type Rider = { model: Model, seat: CFrame, offset: number }
type Car = { root: BasePart, lag: number, riders: { Rider } }
type Horse = { model: Model, rider: Model?, index: number }
type Skater = {
	model: Model,
	a: number,
	b: number,
	speed: number,
	phase: number,
	spinner: boolean,
}
type Ride = { kind: "Train" | "Carousel", seat: number, endsAt: number, startedAt: number }

local folder: Folder
local screen: ScreenGui
local chip: Frame
local chipLabel: TextLabel
local panel: UI.Panel
local cars: { Car } = {}
local carouselRoot: BasePart
local horses: { Horse } = {}
local skaters: { Skater } = {}
local ride: Ride? = nil
local flying = false
local buying = false

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function now(): number
	return workspace:GetServerTimeNow()
end

local function ringCFrame(radius: number, theta: number, y: number): CFrame
	local pos = Vector3.new(math.cos(theta) * radius, y, math.sin(theta) * radius)
	local tangent = Vector3.new(-math.sin(theta), 0, math.cos(theta))
	return CFrame.lookAt(pos, pos + tangent)
end

local function trainTheta(t: number): number
	return (t * TRAIN.SPEED / TRAIN.RADIUS) % (math.pi * 2)
end

local function carCFrame(t: number, lag: number): CFrame
	return ringCFrame(TRAIN.RADIUS, trainTheta(t) - lag / TRAIN.RADIUS, RAIL_Y)
end

-- Feet position for a rider whose seat (top of the bench) is `seat`.
local function seated(seat: CFrame, scale: number): CFrame
	return seat * CFrame.new(0, -0.9 * scale, 0)
end

local function horseCFrame(t: number, index: number): CFrame
	local angle = t * CAROUSEL.SPIN + index / CAROUSEL.SEATS * math.pi * 2
	local radius = CAROUSEL.RADIUS - 3
	local bob = 1.2 + (math.sin(t * 2.2 + index * math.pi) * 0.5 + 0.5) * 1.3
	local pos = Vector3.new(
		CAROUSEL.CENTER.X + math.cos(angle) * radius,
		0.8 + bob,
		CAROUSEL.CENTER.Z + math.sin(angle) * radius
	)
	local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
	return CFrame.lookAt(pos, pos + tangent)
end

local function rootAndHumanoid(): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid then
		return root, humanoid
	end
	return nil, nil
end

--------------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------------

local function buildTrain()
	local engine = TrainModel.engine()
	engine.Parent = folder
	local driver = ElfModel.build(1, 1)
	driver.Parent = folder
	table.insert(cars, {
		root = engine.PrimaryPart :: BasePart,
		lag = 0,
		riders = { { model = driver, seat = TrainModel.DRIVER, offset = 0 } },
	})
	for i = 1, TRAIN.CARS do
		local coach = TrainModel.coach(i)
		coach.Parent = folder
		local riders: { Rider } = {}
		-- Two seats per coach are taken by elves and visitors; two stay free.
		for k, seatIndex in { 1, 4 } do
			local visitor = (i + k) % 2 == 0
			local model = ElfModel.build(i * 2 + k, RIDER_SCALE, visitor)
			model.Parent = folder
			table.insert(riders, {
				model = model,
				seat = seated(TrainModel.SEATS[seatIndex], RIDER_SCALE),
				offset = i * 1.7 + k * 2.9,
			})
		end
		table.insert(cars, {
			root = coach.PrimaryPart :: BasePart,
			lag = 14.5 + (i - 1) * TRAIN.CAR_SPACING,
			riders = riders,
		})
	end
end

local function buildCarousel()
	local model = Instance.new("Model")
	model.Name = "Carousel"
	local root = Build.deco({
		Name = "Root",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(),
		Transparency = 1,
		Parent = model,
	})
	model.PrimaryPart = root
	local gold = Color3.fromRGB(255, 200, 60)
	local radius = CAROUSEL.RADIUS
	Build.cylinder(
		model,
		CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		0.5,
		radius * 2,
		Color3.fromRGB(250, 240, 220)
	)
	Build.cylinder(
		model,
		CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		12,
		2.4,
		Color3.fromRGB(205, 40, 50)
	)
	Build.cone(model, CFrame.new(0, 13, 0), 5, radius + 1.5, Color3.fromRGB(205, 40, 50), 5)
	Build.cylinder(
		model,
		CFrame.new(0, 12.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		0.7,
		(radius + 1.5) * 2,
		Color3.fromRGB(250, 250, 250)
	)
	Build.ball(model, CFrame.new(0, 18.6, 0), 1.8, gold, Enum.Material.Neon)
	local bulbs = {
		Color3.fromRGB(255, 80, 80),
		Color3.fromRGB(100, 235, 120),
		Color3.fromRGB(255, 215, 80),
		Color3.fromRGB(100, 170, 255),
	}
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		Build.ball(
			model,
			CFrame.new(math.cos(a) * (radius + 1.4), 12.2, math.sin(a) * (radius + 1.4)),
			0.8,
			bulbs[k % #bulbs + 1],
			Enum.Material.Neon
		)
	end
	for k = 0, CAROUSEL.SEATS - 1 do
		local a = k / CAROUSEL.SEATS * math.pi * 2
		Build.cylinder(
			model,
			CFrame.new(math.cos(a) * (radius - 3), 7, math.sin(a) * (radius - 3))
				* CFrame.Angles(0, 0, math.rad(90)),
			11.5,
			0.35,
			gold,
			Enum.Material.Metal
		)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
			d.Anchored = false
			d.Massless = true
		end
	end
	model.Parent = folder
	carouselRoot = root

	local ids: { string } = {}
	for id in Config.PETS do
		table.insert(ids, id)
	end
	table.sort(ids)
	for k = 0, CAROUSEL.SEATS - 1 do
		local deer = ReindeerModel.build(ids[k % #ids + 1], false, DEER_SCALE)
		deer.Parent = folder
		local rider: Model? = nil
		-- Every other reindeer already has someone on it.
		if k % 2 == 1 then
			local r = ElfModel.build(k, RIDER_SCALE, k % 4 == 1)
			r.Parent = folder
			rider = r
		end
		table.insert(horses, { model = deer, rider = rider, index = k })
	end
end

local function buildSkaters()
	for i = 1, 5 do
		local model = ElfModel.build(i + 2, 1, i % 2 == 0)
		model.Parent = folder
		table.insert(skaters, {
			model = model,
			a = 7 + (i * 5.3) % 12,
			b = 8 + (i * 3.7) % 11,
			speed = (if i % 2 == 0 then -1 else 1) * (0.45 + i * 0.06),
			phase = i * 1.3,
			spinner = i == 3,
		})
	end
end

--------------------------------------------------------------------------------
-- Stepping
--------------------------------------------------------------------------------

local function stepTrain(t: number)
	for _, car in cars do
		local cf = carCFrame(t, car.lag)
		car.root.CFrame = cf
		for _, rider in car.riders do
			ElfModel.place(rider.model, cf * rider.seat)
			local cheering = math.sin(t * 0.6 + rider.offset) > 0.55
			if car.lag == 0 then
				ElfModel.step(rider.model, t, 0, if cheering then "wave" else "idle")
			else
				ElfModel.step(rider.model, t, 0, if cheering then "cheer" else "sit")
			end
		end
	end
end

local function stepCarousel(t: number)
	carouselRoot.CFrame = CFrame.new(CAROUSEL.CENTER.X, 0, CAROUSEL.CENTER.Z)
		* CFrame.Angles(0, -t * CAROUSEL.SPIN, 0)
	for _, horse in horses do
		local cf = horseCFrame(t, horse.index)
		horse.model:PivotTo(cf)
		local rider = horse.rider
		if rider then
			local back = cf * CFrame.new(0, (2.55 - 0.5) * DEER_SCALE, 0.2)
			ElfModel.place(rider, seated(back, RIDER_SCALE))
			local cheering = math.sin(t * 0.8 + horse.index) > 0.3
			ElfModel.step(rider, t, 0, if cheering then "cheer" else "sit")
		end
	end
end

local function stepSkaters(t: number)
	for _, s in skaters do
		local u = t * s.speed + s.phase
		local pos = Vector3.new(
			RINK.CENTER.X + math.cos(u) * s.a,
			RINK.ICE_Y,
			RINK.CENTER.Z + math.sin(u) * s.b
		)
		local direction = if s.speed >= 0 then 1 else -1
		local heading = Vector3.new(-math.sin(u) * s.a, 0, math.cos(u) * s.b) * direction
		local cf = CFrame.lookAt(pos, pos + heading)
		local spinning = s.spinner and math.sin(t * 0.5) > 0.7
		if spinning then
			cf *= CFrame.Angles(0, t * 9, 0)
		else
			-- Lean into the curve and glide from one skate to the other.
			cf *= CFrame.Angles(0, 0, -0.18 * direction + math.sin(t * 2.4 + s.phase) * 0.12)
		end
		ElfModel.place(s.model, cf)
		ElfModel.step(s.model, t * 0.27 + s.phase, 0.45, if spinning then "cheer" else "walk")
	end
end

--------------------------------------------------------------------------------
-- Riding
--------------------------------------------------------------------------------

local function seatCFrame(r: Ride, t: number): CFrame
	if r.kind == "Train" then
		local car = cars[2 + r.seat % TRAIN.CARS] or cars[2]
		return carCFrame(t, car.lag) * TrainModel.SEATS[2 + math.floor(r.seat / TRAIN.CARS) % 2]
	end
	return horseCFrame(t, r.seat) * CFrame.new(0, (2.55 - 0.5) * DEER_SCALE, 0.2)
end

local function endRide()
	local r = ride
	if not r then
		return
	end
	ride = nil
	chip.Visible = false
	ProximityPromptService.Enabled = true
	local root, humanoid = rootAndHumanoid()
	if root and humanoid then
		root.Anchored = false
		humanoid.Sit = false
		-- Step off beside the ride.
		local seat = seatCFrame(r, now())
		local out = Vector3.new(seat.Position.X, 0, seat.Position.Z)
		local step = out.Unit * 9
		if r.kind == "Carousel" then
			local centre = Vector3.new(CAROUSEL.CENTER.X, 0, CAROUSEL.CENTER.Z)
			step = (out - centre).Unit * (CAROUSEL.RADIUS + 5) - (out - centre)
		end
		local character = root.Parent
		if character and character:IsA("Model") then
			character:PivotTo(CFrame.new(out + step + Vector3.new(0, 5, 0)))
		end
	end
end

local function startRide(kind: "Train" | "Carousel")
	if ride or buying or flying then
		return
	end
	buying = true
	local ok, message = Net.request("RideTicket", kind)
	buying = false
	if not ok then
		if typeof(message) == "string" then
			Bus.fire("Toast", message, "error")
		end
		return
	end
	local t = now()
	local seat = player.UserId % 2
	local duration = 2 * math.pi * TRAIN.RADIUS / TRAIN.SPEED
	if kind == "Train" then
		-- Board the coach that is closest to the station right now.
		local root = rootAndHumanoid()
		local best = math.huge
		for i = 2, #cars do
			local at = carCFrame(t, cars[i].lag).Position
			local distance = if root then (at - root.Position).Magnitude else 0
			if distance < best then
				best = distance
				seat = (i - 2) + (player.UserId % 2) * TRAIN.CARS
			end
		end
	else
		duration = CAROUSEL.DURATION
		-- Free reindeer are the even ones.
		seat = (player.UserId % (CAROUSEL.SEATS / 2)) * 2
	end
	ride = { kind = kind, seat = seat, endsAt = t + duration, startedAt = t }
	chipLabel.Text = if kind == "Train"
		then "🚂 All aboard the North Pole Express!"
		else "🎠 Round and round we go!"
	chip.Visible = true
	-- No "Ride the ..." prompts floating in view during the ride.
	ProximityPromptService.Enabled = false
	UI.pop(chip, 1.2)
	UI.sound("Purchase", 0.5)
end

local function stepRide(t: number)
	local r = ride
	if not r then
		return
	end
	local root, humanoid = rootAndHumanoid()
	if not root or not humanoid or humanoid.Health <= 0 or flying then
		ride = nil
		chip.Visible = false
		ProximityPromptService.Enabled = true
		return
	end
	if t >= r.endsAt then
		endRide()
		return
	end
	root.Anchored = true
	humanoid.Sit = true
	root.CFrame = seatCFrame(r, t)
		* CFrame.new(0, if r.kind == "Train" then SEATED_ROOT else SADDLE_ROOT, 0)
	root.AssemblyLinearVelocity = Vector3.zero
end

--------------------------------------------------------------------------------
-- Play list
--------------------------------------------------------------------------------

local PLACES = {
	{ id = "Snowball", text = "❄️ Snowball Fight\nFree", color = Color3.fromRGB(70, 150, 220) },
	{
		id = "Train",
		text = `🚂 North Pole Express\n{TRAIN.COST} Cheer`,
		color = Color3.fromRGB(35, 130, 75),
	},
	{
		id = "Carousel",
		text = `🎠 Reindeer Carousel\n{CAROUSEL.COST} Cheer`,
		color = Color3.fromRGB(150, 80, 200),
	},
	{ id = "Rink", text = "⛸ Ice Rink\nFree", color = Color3.fromRGB(60, 170, 200) },
	{
		id = "Workshop",
		text = "🎁 Santa's Workshop\nWrap and deliver presents",
		color = Color3.fromRGB(200, 40, 50),
	},
	{ id = "Plaza", text = "🎄 Plaza\nBack to the gates", color = Color3.fromRGB(90, 90, 110) },
}

local function buildPanel()
	panel = UI.panel(screen, "🎄 Christmas Playground", T.Green)
	UI.make("UIGridLayout", {
		CellSize = UDim2.fromScale(0.47, 0.3),
		CellPadding = UDim2.fromScale(0.04, 0.04),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = panel.content,
	})
	for i, place in PLACES do
		UI.button({
			Name = place.id,
			Text = place.text,
			Color = place.color,
			LayoutOrder = i,
			MaxTextSize = 30,
			Parent = panel.content,
			OnClick = function()
				panel.close()
				task.spawn(function()
					if ride then
						endRide()
					end
					local ok, message = Net.request("GoPlace", place.id)
					if not ok and typeof(message) == "string" then
						Bus.fire("Toast", message, "error")
					end
				end)
			end,
		})
	end
end

--------------------------------------------------------------------------------

function Rides.init()
	screen = UI.screen("Rides", 11)
	chip = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.4, 0.055),
		BackgroundColor3 = Color3.fromRGB(30, 60, 40),
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = screen,
	})
	UI.make(
		"UISizeConstraint",
		{ MinSize = Vector2.new(300, 34), MaxSize = Vector2.new(560, 50), Parent = chip }
	)
	UI.corner(chip, 14)
	UI.stroke(chip, T.Gold, 1.5)
	chipLabel = UI.text({
		Text = "",
		Size = UDim2.fromScale(0.66, 0.76),
		Position = UDim2.fromScale(0.03, 0.12),
		MaxTextSize = 22,
		Parent = chip,
	})
	UI.textStroke(chipLabel, T.Ink, 1.5)
	UI.button({
		Name = "HopOff",
		Text = "Hop off",
		Color = T.Red,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.985, 0.5),
		Size = UDim2.fromScale(0.27, 0.8),
		MaxTextSize = 20,
		Parent = chip,
		OnClick = function()
			endRide()
		end,
	})
	buildPanel()
	Bus.on("Flying", function(value: boolean)
		flying = value
	end)
	Bus.on("OpenPlay", function()
		if panel.isOpen() then
			panel.close()
		else
			panel.open()
		end
	end)
	Bus.on("Ride", function(kind: string)
		if kind == "Train" or kind == "Carousel" then
			task.spawn(startRide, kind)
		end
	end)
end

function Rides.start()
	folder = Instance.new("Folder")
	folder.Name = "Rides"
	folder.Parent = workspace
	buildTrain()
	buildCarousel()
	buildSkaters()

	-- Hop off with the button, or by jumping (Space, gamepad A, the touch
	-- jump button). The first second is ignored so the key that bought the
	-- ticket cannot also end the ride.
	local function hopOff()
		local r = ride
		if r and now() - r.startedAt > 1 then
			endRide()
		end
	end
	UserInputService.JumpRequest:Connect(hopOff)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			hopOff()
		end
	end)

	-- Before the camera each frame, so a riding player does not jitter.
	RunService:BindToRenderStep("Rides", Enum.RenderPriority.Camera.Value - 5, function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local t = now()
		local at = camera.CFrame.Position
		local near = Vector3.new(at.X, 0, at.Z).Magnitude < 560
		if near or ride then
			stepTrain(t)
		end
		if (at - CAROUSEL.CENTER).Magnitude < 280 or ride then
			stepCarousel(t)
		end
		if (at - RINK.CENTER).Magnitude < 280 then
			stepSkaters(t)
		end
		stepRide(t)
	end)
end

return Rides
