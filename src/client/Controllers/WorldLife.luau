--!strict
-- Things that move so the North Pole never stands still. Purely visual and
-- built on each client:
--   * elves strolling round the plaza, some carrying presents; they stop and
--     wave when the player walks up
--   * an elf leading reindeer round the plaza, and a toy train circling the
--     giant tree
--   * on every claimed workshop: penguins waddling and belly-sliding by the
--     snowman, the sleigh reindeer pawing the snow, and (once an elf is
--     hired) a porter elf carrying presents from the sack to the sleigh
-- Only what is near the camera is animated.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local PlotLayout = require(Shared.PlotLayout)
local ElfModel = require(Shared.Models.ElfModel)
local ReindeerModel = require(Shared.Models.ReindeerModel)
local ReindeerAnim = require(Shared.Models.ReindeerAnim)
local ToyModels = require(Shared.Models.ToyModels)

local WorldLife = {}

local HUB_RANGE = 430
local PLOT_RANGE = 230
local PLAZA_Y = 0.5
local PLOT_Y = 0.1
local GREET_DISTANCE = 20

local folder: Folder

--------------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------------

-- Welds every part to the model's anchored Root so one CFrame moves it all.
local function assemble(model: Model): BasePart
	local root = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
		end
	end
	root.Anchored = true
	return root
end

local function newModel(name: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	local root = Build.deco({
		Name = "Root",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(),
		Transparency = 1,
		Parent = model,
	})
	model.PrimaryPart = root
	return model, root
end

local function penguinModel(s: number): Model
	local model = newModel("Penguin")
	local black = Color3.fromRGB(35, 38, 50)
	local orange = Color3.fromRGB(255, 150, 40)
	local function block(size: Vector3, cf: CFrame, color: Color3)
		Build.deco({
			Size = size * s,
			CFrame = CFrame.new(cf.Position * s) * cf.Rotation,
			Color = color,
			CastShadow = false,
			Parent = model,
		})
	end
	block(Vector3.new(1.5, 2, 1.3), CFrame.new(0, 1.3, 0), black)
	block(Vector3.new(1.1, 0.95, 0.15), CFrame.new(0, 0.85, -0.62), Color3.new(1, 1, 1))
	block(Vector3.new(1.6, 0.28, 1.4), CFrame.new(0, 1.5, 0), Color3.fromRGB(210, 40, 50))
	block(Vector3.new(0.3, 0.7, 0.2), CFrame.new(0.45, 1.15, -0.72), Color3.fromRGB(210, 40, 50))
	block(Vector3.new(0.45, 0.25, 0.45), CFrame.new(0, 1.85, -0.8), orange)
	for _, side in { -1, 1 } do
		block(Vector3.new(0.3, 0.3, 0.1), CFrame.new(0.32 * side, 2.02, -0.64), Color3.new(1, 1, 1))
		block(Vector3.new(0.14, 0.14, 0.1), CFrame.new(0.32 * side, 2.02, -0.69), black)
		block(Vector3.new(0.55, 0.2, 0.8), CFrame.new(0.4 * side, 0.1, -0.15), orange)
		block(
			Vector3.new(0.2, 1.2, 0.7),
			CFrame.new(0.88 * side, 1.25, 0) * CFrame.Angles(0, 0, math.rad(14 * side)),
			black
		)
	end
	assemble(model)
	return model
end

local function wheels(model: Model, xs: number, y: number, zs: { number }, diameter: number)
	for _, z in zs do
		for _, side in { -1, 1 } do
			Build.cylinder(
				model,
				CFrame.new(xs * side, y, z),
				0.4,
				diameter,
				Color3.fromRGB(255, 200, 60)
			)
		end
	end
end

local function engineModel(): Model
	local model = newModel("TrainEngine")
	local red = Color3.fromRGB(215, 45, 55)
	Build.deco({
		Size = Vector3.new(4, 1, 7.4),
		CFrame = CFrame.new(0, 1.5, 0),
		Color = red,
		Parent = model,
	})
	Build.cylinder(
		model,
		CFrame.new(0, 3.3, -1.3) * CFrame.Angles(0, math.rad(90), 0),
		4.4,
		3,
		Color3.fromRGB(35, 120, 70)
	)
	Build.deco({
		Size = Vector3.new(3.8, 3.6, 2.6),
		CFrame = CFrame.new(0, 3.8, 2.3),
		Color = Color3.fromRGB(45, 95, 200),
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(4.5, 0.45, 3.2),
		CFrame = CFrame.new(0, 5.8, 2.3),
		Color = red,
		Parent = model,
	})
	local chimney = Build.cylinder(
		model,
		CFrame.new(0, 5.4, -2.5) * CFrame.Angles(0, 0, math.rad(90)),
		1.8,
		1.1,
		Color3.fromRGB(40, 40, 45)
	)
	Build.ball(
		model,
		CFrame.new(0, 3.3, -3.6),
		1,
		Color3.fromRGB(255, 235, 160),
		Enum.Material.Neon
	)
	wheels(model, 2.1, 0.9, { -2.4, 0, 2.4 }, 1.8)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(250, 250, 255))
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Size = NumberSequence.new(1.2, 4)
	smoke.Lifetime = NumberRange.new(1.2, 2)
	smoke.Speed = NumberRange.new(4, 6)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Rate = 5
	smoke.Parent = chimney
	assemble(model)
	return model
end

local WAGON_COLORS = {
	Color3.fromRGB(45, 150, 80),
	Color3.fromRGB(230, 170, 40),
	Color3.fromRGB(60, 120, 215),
}

local function wagonModel(index: number): Model
	local model, root = newModel("TrainWagon")
	local color = WAGON_COLORS[(index - 1) % #WAGON_COLORS + 1]
	Build.deco({
		Size = Vector3.new(3.8, 0.8, 6),
		CFrame = CFrame.new(0, 1.4, 0),
		Color = color,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		Build.deco({
			Size = Vector3.new(0.3, 1.2, 6),
			CFrame = CFrame.new(1.75 * side, 2.4, 0),
			Color = color,
			Parent = model,
		})
	end
	wheels(model, 2, 0.8, { -1.8, 1.8 }, 1.6)
	for k = 1, 3 do
		local present = ToyModels.present(1.5 + (k % 2) * 0.5, index + k)
		present:PivotTo(
			CFrame.new((k - 2) * 0.5, 1.8, (k - 2) * 1.8) * CFrame.Angles(0, k * 0.7, 0)
		)
		for _, d in present:GetChildren() do
			if d ~= present.PrimaryPart then
				d.Parent = model
			end
		end
		present:Destroy()
	end
	root.Anchored = true
	assemble(model)
	return model
end

--------------------------------------------------------------------------------
-- Plaza
--------------------------------------------------------------------------------

type Walker = {
	model: Model,
	radius: number,
	speed: number, -- studs per second, sign = direction round the plaza
	theta: number,
	carry: boolean,
	offset: number,
	greet: number,
}
type Follower = { model: Model, leader: Walker, lag: number, scale: number, offset: number }
type Car = { root: BasePart, lag: number }

local walkers: { Walker } = {}
local followers: { Follower } = {}
local cars: { Car } = {}
local trainTheta = 0
local TRAIN_RADIUS = 43
local TRAIN_SPEED = 10

local function ringCFrame(radius: number, theta: number, direction: number, y: number): CFrame
	local pos = Vector3.new(math.cos(theta) * radius, y, math.sin(theta) * radius)
	local tangent = Vector3.new(-math.sin(theta), 0, math.cos(theta)) * direction
	return CFrame.lookAt(pos, pos + tangent)
end

local function buildPlaza()
	local rng = Random.new(2512)
	for i = 1, 9 do
		local carry = i % 3 ~= 0
		local elf = ElfModel.build(i, 1)
		if carry then
			ElfModel.hold(elf, ToyModels.present(1.3, i), CFrame.new(0, 1.9, -1.5))
		end
		elf.Parent = folder
		table.insert(walkers, {
			model = elf,
			radius = 58 + (i - 1) * 5.5 + rng:NextNumber(-1.5, 1.5),
			speed = (if i % 2 == 0 then -1 else 1) * rng:NextNumber(5.5, 8.5),
			theta = rng:NextNumber(0, math.pi * 2),
			carry = carry,
			offset = rng:NextNumber(0, 10),
			greet = 0,
		})
	end

	-- An elf walking the reindeer.
	local herder: Walker = {
		model = ElfModel.build(2, 1.1),
		radius = 110,
		speed = 6.5,
		theta = rng:NextNumber(0, math.pi * 2),
		carry = false,
		offset = 3,
		greet = 0,
	}
	herder.model.Parent = folder
	table.insert(walkers, herder)
	local k = 0
	for id in Config.PETS do
		k += 1
		if k > 3 then
			break
		end
		local deer = ReindeerModel.build(id, false, 1.3)
		deer.Parent = folder
		table.insert(
			followers,
			{ model = deer, leader = herder, lag = k * 9, scale = 1.3, offset = k * 0.31 }
		)
	end

	-- The toy train round the giant tree.
	local engine = engineModel()
	engine.Parent = folder
	table.insert(cars, { root = engine.PrimaryPart :: BasePart, lag = 0 })
	for i = 1, 3 do
		local wagon = wagonModel(i)
		wagon.Parent = folder
		table.insert(cars, { root = wagon.PrimaryPart :: BasePart, lag = 1.5 + i * 7.6 })
	end
end

local function stepPlaza(t: number, dt: number, playerPos: Vector3?)
	for _, w in walkers do
		local direction = if w.speed >= 0 then 1 else -1
		local cf = ringCFrame(w.radius, w.theta, direction, PLAZA_Y)
		local greeting = not w.carry
			and playerPos ~= nil
			and (playerPos - cf.Position).Magnitude < GREET_DISTANCE
		w.greet = math.clamp(w.greet + (if greeting then dt else -dt) * 4, 0, 1)
		if greeting and playerPos then
			-- Stop, turn to the player, wave and bounce.
			local look = Vector3.new(playerPos.X, cf.Position.Y, playerPos.Z)
			if (look - cf.Position).Magnitude > 0.5 then
				cf = cf:Lerp(CFrame.lookAt(cf.Position, look), w.greet)
			end
			local hop = math.abs(math.sin(t * 7 + w.offset)) * 0.6
			ElfModel.place(w.model, cf * CFrame.new(0, hop, 0))
			ElfModel.step(w.model, t, 0, "wave")
		else
			w.theta += w.speed / w.radius * dt
			local clock = t + w.offset
			local bob = math.abs(math.sin(clock * 9)) * 0.18
			ElfModel.place(w.model, cf * CFrame.new(0, bob, 0))
			ElfModel.step(w.model, clock, 0.6, if w.carry then "carry" else "walk")
		end
	end
	for _, f in followers do
		local leader = f.leader
		local direction = if leader.speed >= 0 then 1 else -1
		local theta = leader.theta - direction * f.lag / leader.radius
		local moving = leader.greet < 0.5
		local cf = ringCFrame(leader.radius, theta, direction, PLAZA_Y + 0.5 * f.scale)
		f.model:PivotTo(cf)
		ReindeerAnim.step(f.model, t + f.offset, 1.9, if moving then 0.5 else 0.06)
	end
	trainTheta += TRAIN_SPEED / TRAIN_RADIUS * dt
	for _, car in cars do
		car.root.CFrame =
			ringCFrame(TRAIN_RADIUS, trainTheta - car.lag / TRAIN_RADIUS, 1, PLAZA_Y + 0.06)
	end
end

--------------------------------------------------------------------------------
-- Workshops
--------------------------------------------------------------------------------

type Penguin = {
	model: Model,
	at: Vector3, -- plot-local position
	target: Vector3,
	facing: number,
	pause: number,
	slide: boolean,
	offset: number,
}
type Porter = {
	model: Model,
	parcel: { BasePart },
	carrying: boolean,
	progress: number,
	forward: boolean,
	pause: number,
}
type PlotLife = { penguins: { Penguin }, porter: Porter? }

local plotLife: { [Model]: PlotLife } = {}

local YARD_MIN = Vector3.new(-62, 0, -64)
local YARD_MAX = Vector3.new(-36, 0, -24)
local PORTER_FROM = Vector3.new(47, 0, -1)
local PORTER_TO = Vector3.new(50, 0, -18)

local function yardPoint(): Vector3
	return Vector3.new(
		YARD_MIN.X + math.random() * (YARD_MAX.X - YARD_MIN.X),
		0,
		YARD_MIN.Z + math.random() * (YARD_MAX.Z - YARD_MIN.Z)
	)
end

local function clearPlot(plot: Model)
	local life = plotLife[plot]
	if not life then
		return
	end
	plotLife[plot] = nil
	for _, p in life.penguins do
		p.model:Destroy()
	end
	if life.porter then
		life.porter.model:Destroy()
	end
end

local function stepPenguin(p: Penguin, plotCF: CFrame, t: number, dt: number)
	local toTarget = p.target - p.at
	local distance = toTarget.Magnitude
	local pitch, roll, lift = 0, 0, 0
	if p.pause > 0 then
		-- Standing about: a happy little bounce.
		p.pause -= dt
		lift = math.abs(math.sin(t * 5 + p.offset)) * 0.25
		if p.pause <= 0 then
			p.target = yardPoint()
			p.slide = math.random() < 0.35
		end
	elseif distance < 0.6 then
		p.pause = 1 + math.random() * 2.5
		p.slide = false
	else
		local speed = if p.slide then 10 else 3.2
		p.at += toTarget.Unit * math.min(distance, speed * dt)
		p.facing = math.atan2(-toTarget.X, -toTarget.Z)
		if p.slide then
			pitch = math.rad(-78)
			lift = 0.9
		else
			roll = math.sin(t * 11 + p.offset) * 0.22
			lift = math.abs(math.sin(t * 11 + p.offset)) * 0.12
		end
	end
	local root = p.model.PrimaryPart :: BasePart
	root.CFrame = plotCF
		* CFrame.new(p.at.X, PLOT_Y + lift, p.at.Z)
		* CFrame.Angles(0, p.facing, 0)
		* CFrame.Angles(pitch, 0, roll)
end

local function stepPorter(porter: Porter, plotCF: CFrame, t: number, dt: number)
	local length = (PORTER_TO - PORTER_FROM).Magnitude
	if porter.pause > 0 then
		porter.pause -= dt
		if porter.pause <= 0 then
			porter.forward = not porter.forward
			-- Picks a present up at the sack, puts it down at the sleigh.
			porter.carrying = porter.forward
			for _, part in porter.parcel do
				part.Transparency = if porter.carrying then 0 else 1
			end
		end
	else
		porter.progress += (if porter.forward then 1 else -1) * 6 * dt / length
		if porter.progress >= 1 or porter.progress <= 0 then
			porter.progress = math.clamp(porter.progress, 0, 1)
			porter.pause = 0.7
		end
	end
	local at = PORTER_FROM:Lerp(PORTER_TO, porter.progress)
	local heading = if porter.forward then PORTER_TO - PORTER_FROM else PORTER_FROM - PORTER_TO
	local walking = porter.pause <= 0
	local bob = if walking then math.abs(math.sin(t * 9)) * 0.18 else 0
	ElfModel.place(
		porter.model,
		plotCF
			* CFrame.lookAt(
				Vector3.new(at.X, PLOT_Y + bob, at.Z),
				Vector3.new(at.X + heading.X, PLOT_Y + bob, at.Z + heading.Z)
			)
	)
	ElfModel.step(
		porter.model,
		t,
		if walking then 0.6 else 0,
		if porter.carrying then "carry" else if walking then "walk" else "idle"
	)
end

local function stepPlots(t: number, dt: number, cameraPos: Vector3)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		if not plot:IsA("Model") then
			continue
		end
		local ownerId = plot:GetAttribute("OwnerId")
		local index = plot:GetAttribute("Index")
		if not ownerId or ownerId == 0 or typeof(index) ~= "number" then
			clearPlot(plot)
			continue
		end
		local plotCF = PlotLayout.plotCFrame(index, Config.MAX_PLOTS)
		if (plotCF.Position - cameraPos).Magnitude > PLOT_RANGE then
			continue
		end
		local life = plotLife[plot]
		if not life then
			life = { penguins = {}, porter = nil }
			plotLife[plot] = life
			for i = 1, 2 do
				local model = penguinModel(1.25)
				model.Parent = folder
				local at = yardPoint()
				table.insert(life.penguins, {
					model = model,
					at = at,
					target = at,
					facing = 0,
					pause = i * 0.8,
					slide = false,
					offset = i * 1.9,
				})
			end
		end
		for _, p in life.penguins do
			stepPenguin(p, plotCF, t, dt)
		end
		local elves = tonumber(plot:GetAttribute("Elves")) or 0
		local porter = life.porter
		if elves >= 1 and not porter then
			local elf = ElfModel.build(2, 1)
			local present = ToyModels.present(1.4, 2)
			local parcel: { BasePart } = {}
			for _, d in present:GetDescendants() do
				if d:IsA("BasePart") and d ~= present.PrimaryPart then
					table.insert(parcel, d)
				end
			end
			ElfModel.hold(elf, present, CFrame.new(0, 1.9, -1.5))
			elf.Parent = folder
			porter = {
				model = elf,
				parcel = parcel,
				carrying = true,
				progress = 0,
				forward = true,
				pause = 0,
			}
			life.porter = porter
		elseif elves < 1 and porter then
			porter.model:Destroy()
			life.porter = nil
			porter = nil
		end
		if porter then
			stepPorter(porter, plotCF, t, dt)
		end
	end
end

--------------------------------------------------------------------------------

function WorldLife.start()
	folder = Instance.new("Folder")
	folder.Name = "WorldLife"
	folder.Parent = workspace
	buildPlaza()

	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPos = camera.CFrame.Position
		local t = os.clock()
		if Vector3.new(cameraPos.X, 0, cameraPos.Z).Magnitude < HUB_RANGE then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			stepPlaza(t, dt, if root and root:IsA("BasePart") then root.Position else nil)
		end
		stepPlots(t, dt, cameraPos)
		-- Reindeer hitched to parked sleighs paw at the snow.
		for _, deer in CollectionService:GetTagged("IdleDeer") do
			if
				deer:IsA("Model")
				and deer.PrimaryPart
				and (deer.PrimaryPart.Position - cameraPos).Magnitude < PLOT_RANGE
			then
				local phase = deer.PrimaryPart.Position.X * 0.13
				local paw = math.max(0, math.sin(t * 0.9 + phase)) * 0.22
				ReindeerAnim.step(deer, t + phase, 1.6, paw)
			end
		end
	end)
end

return WorldLife
