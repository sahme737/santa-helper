--!strict
-- Builds the whole festive world from code at server start: lighting, the
-- snowy hub with its giant Christmas tree, six workshop plot bases, hub
-- buildings (stable, gift post, wardrobe, leaderboards, runway, event sign),
-- and the snowy town used by Sleigh Delivery.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local PlotLayout = require(Shared.PlotLayout)
local ToyModels = require(Shared.Models.ToyModels)
local ReindeerModel = require(Shared.Models.ReindeerModel)

local WorldBuilder = {}

WorldBuilder.TOWN_ORIGIN = CFrame.new(5000, 0, 0)
WorldBuilder.plots = {} :: { Model }
WorldBuilder.chimneys = {} :: { Vector3 }
WorldBuilder.boards = {} :: { [string]: SurfaceGui }
WorldBuilder.eventSign = nil :: TextLabel?
WorldBuilder.hubRadius = 200

local rng = Random.new(2026)

local SNOW = Color3.fromRGB(240, 246, 255)
local RED = Color3.fromRGB(205, 35, 45)
local GREEN = Color3.fromRGB(30, 120, 60)
local GOLD = Color3.fromRGB(255, 205, 70)
local WOOD = Color3.fromRGB(140, 95, 60)
local WARM_LIGHT = Color3.fromRGB(255, 200, 130)
local ORNAMENTS = {
	Color3.fromRGB(230, 40, 50),
	Color3.fromRGB(255, 205, 70),
	Color3.fromRGB(70, 140, 255),
	Color3.fromRGB(220, 220, 235),
	Color3.fromRGB(190, 90, 230),
	Color3.fromRGB(80, 230, 160),
}

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function prompt(
	parent: BasePart,
	action: string,
	object: string,
	kind: string,
	distance: number?
): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.MaxActivationDistance = distance or 14
	p.RequiresLineOfSight = false
	p.HoldDuration = 0
	p:SetAttribute("Kind", kind)
	p.Parent = parent
	return p
end

local function sign(
	parent: Instance,
	cf: CFrame,
	text: string,
	width: number,
	height: number,
	bg: Color3,
	fg: Color3
): Part
	local board = Build.part({
		Name = "Sign",
		Size = Vector3.new(width, height, 0.6),
		CFrame = cf,
		Color = bg,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.86)
	label.Position = UDim2.fromScale(0.03, 0.07)
	label.Text = text
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextColor3 = fg
	label.Parent = gui
	gui.Parent = board
	-- Frame around the sign
	local trim = Build.deco({
		Size = Vector3.new(width + 1, height + 1, 0.4),
		CFrame = cf * CFrame.new(0, 0, 0.2),
		Color = Color3.new(1, 1, 1),
		Parent = parent,
	})
	trim.Name = "Trim"
	return board
end

local function candyPole(parent: Instance, base: CFrame, height: number, width: number)
	local segments = math.max(2, math.floor(height / 2))
	local seg = height / segments
	for i = 0, segments - 1 do
		Build.deco({
			Size = Vector3.new(width, seg, width),
			CFrame = base * CFrame.new(0, seg * (i + 0.5), 0),
			Color = if i % 2 == 0 then RED else Color3.new(1, 1, 1),
			Parent = parent,
		})
	end
end

function WorldBuilder.pineTree(parent: Instance, base: CFrame, height: number, decorated: boolean)
	local model = Instance.new("Model")
	model.Name = "Pine"
	Build.cylinder(
		model,
		base * CFrame.new(0, height * 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)),
		height * 0.16,
		height * 0.1,
		WOOD
	)
	local tiers = 3
	for t = 0, tiers - 1 do
		local r = height * (0.34 - t * 0.08)
		local y = height * (0.12 + t * 0.24)
		Build.cone(
			model,
			base * CFrame.new(0, y, 0),
			height * 0.36,
			r,
			GREEN,
			3,
			Enum.Material.Grass
		)
		-- Snow cap
		Build.cylinder(
			model,
			base * CFrame.new(0, y + height * 0.36 * 0.68, 0) * CFrame.Angles(0, 0, math.rad(90)),
			height * 0.04,
			r * 0.7,
			SNOW,
			Enum.Material.Snow
		)
		if decorated then
			for _ = 1, 5 do
				local a = rng:NextNumber(0, math.pi * 2)
				local rr = r * 0.75
				Build.ball(
					model,
					base * CFrame.new(math.cos(a) * rr, y + height * 0.06, math.sin(a) * rr),
					height * 0.05,
					ORNAMENTS[rng:NextInteger(1, #ORNAMENTS)],
					Enum.Material.Neon
				)
			end
		end
	end
	model.Parent = parent
end

--------------------------------------------------------------------------------
-- Lighting
--------------------------------------------------------------------------------
local function buildLighting()
	Lighting.ClockTime = 17.4
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(95, 95, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 185)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.GeographicLatitude = 60

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(200, 215, 255)
	atmosphere.Decay = Color3.fromRGB(130, 110, 170)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.15
	color.Contrast = 0.05
	color.TintColor = Color3.fromRGB(255, 246, 240)
	color.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.04
	sunRays.Parent = Lighting
end

--------------------------------------------------------------------------------
-- Hub
--------------------------------------------------------------------------------
local function buildGiantTree(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "GiantTree"
	Build.cylinder(model, CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)), 10, 9, WOOD)
	local radii = { 34, 29, 24, 19, 14, 9 }
	local baseY = 8
	local tierHeight = 17
	for i, r in radii do
		local y = baseY + (i - 1) * 11
		Build.cone(
			model,
			CFrame.new(0, y, 0),
			tierHeight,
			r,
			Color3.fromRGB(25, 110, 55),
			4,
			Enum.Material.Grass
		)
		for k = 1, 9 do
			local a = (k / 9) * math.pi * 2 + i
			local rr = r * 0.78
			local ball = Build.ball(
				model,
				CFrame.new(math.cos(a) * rr, y + 3, math.sin(a) * rr),
				2.6,
				ORNAMENTS[(k + i) % #ORNAMENTS + 1],
				if k % 3 == 0 then Enum.Material.Neon else Enum.Material.Glass
			)
			ball.Reflectance = 0.2
		end
	end
	-- Spiral garland of lights
	local top = baseY + 5 * 11 + tierHeight
	for k = 0, 110 do
		local t = k / 110
		local y = baseY + 2 + t * (top - baseY - 6)
		local r = 33 * (1 - t) + 2
		local a = t * math.pi * 12
		Build.ball(
			model,
			CFrame.new(math.cos(a) * r, y, math.sin(a) * r),
			1,
			if k % 2 == 0 then GOLD else Color3.fromRGB(255, 120, 120),
			Enum.Material.Neon
		)
	end
	-- Star
	local starCF = CFrame.new(0, top + 3, 0)
	local star = Build.deco({
		Name = "Star",
		Size = Vector3.new(7, 7, 1.5),
		CFrame = starCF * CFrame.Angles(0, 0, math.rad(45)),
		Color = GOLD,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(7, 7, 1.5),
		CFrame = starCF,
		Color = GOLD,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	Build.light(star, GOLD, 60, 3)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(GOLD)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(1.5, 0)
	sparkle.Rate = 12
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = star
	star:SetAttribute("SpinY", true)
	CollectionService:AddTag(star, "Spin")
	model.Parent = parent

	-- Presents under the tree
	for k = 1, 14 do
		local a = (k / 14) * math.pi * 2
		local r = rng:NextNumber(36, 44)
		local size = rng:NextNumber(3, 6)
		local present = ToyModels.present(size, k)
		present:PivotTo(
			CFrame.new(math.cos(a) * r, 0.5, math.sin(a) * r)
				* CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		)
		present.Parent = parent
	end
end

local function buildHub(world: Instance)
	local hub = folder("Hub", world)

	Build.part({
		Name = "Ground",
		Size = Vector3.new(2048, 4, 2048),
		CFrame = CFrame.new(0, -2, 0),
		Color = SNOW,
		Material = Enum.Material.Snow,
		Parent = hub,
	})
	Build.part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 250, 250),
		CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(205, 210, 222),
		Material = Enum.Material.Slate,
		Parent = hub,
	})
	Build.part({
		Name = "PlazaRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.1, 100, 100),
		CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(180, 40, 50),
		Material = Enum.Material.Brick,
		Parent = hub,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.6, -80)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	buildGiantTree(hub)

	-- Candy cane fence around the tree
	for k = 1, 24 do
		local a = (k / 24) * math.pi * 2
		candyPole(hub, CFrame.new(math.cos(a) * 50, 0.5, math.sin(a) * 50), 5, 1.2)
	end

	-- Lamp posts around the plaza
	for k = 1, 12 do
		local a = (k / 12) * math.pi * 2 + math.rad(15)
		local base = CFrame.new(math.cos(a) * 118, 0.5, math.sin(a) * 118)
		candyPole(hub, base, 14, 1.4)
		local lamp = Build.deco({
			Name = "Lamp",
			Size = Vector3.new(3, 3, 3),
			CFrame = base * CFrame.new(0, 15.5, 0),
			Color = WARM_LIGHT,
			Material = Enum.Material.Neon,
			Parent = hub,
		})
		Build.light(lamp, WARM_LIGHT, 30, 1.6)
		Build.deco({
			Size = Vector3.new(4, 0.6, 4),
			CFrame = base * CFrame.new(0, 17.2, 0),
			Color = GREEN,
			Parent = hub,
		})
	end

	-- Paths to each plot
	for i = 1, Config.MAX_PLOTS do
		local plotCF = PlotLayout.plotCFrame(i, Config.MAX_PLOTS)
		local dir = -plotCF.LookVector
		local mid = dir * 175
		Build.part({
			Name = "Path",
			Size = Vector3.new(18, 1, 110),
			CFrame = CFrame.lookAt(mid, mid + dir) * CFrame.new(0, 0.05, 0),
			Color = Color3.fromRGB(190, 195, 210),
			Material = Enum.Material.Slate,
			Parent = hub,
		})
	end

	-- Outer forest and mountains
	local forest = folder("Forest", hub)
	for _ = 1, 140 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(470, 1000)
		WorldBuilder.pineTree(
			forest,
			CFrame.new(math.cos(a) * r, 0, math.sin(a) * r),
			rng:NextNumber(30, 60),
			rng:NextNumber() < 0.15
		)
	end
	for _ = 1, 30 do
		-- Trees in the gaps between plots, inside the ring.
		local a = math.rad(rng:NextInteger(0, 5) * 60 + rng:NextNumber(-12, 12))
		local r = rng:NextNumber(230, 420)
		WorldBuilder.pineTree(
			forest,
			CFrame.new(math.cos(a) * r, 0, math.sin(a) * r),
			rng:NextNumber(22, 40),
			rng:NextNumber() < 0.4
		)
	end
	for k = 1, 14 do
		local a = (k / 14) * math.pi * 2
		local r = 1150
		local h = rng:NextNumber(220, 420)
		Build.part({
			Name = "Mountain",
			Size = Vector3.new(h * 1.2, h, h * 1.2),
			CFrame = CFrame.new(math.cos(a) * r, h * 0.2, math.sin(a) * r)
				* CFrame.Angles(math.rad(45), rng:NextNumber(0, 6), math.rad(45)),
			Color = Color3.fromRGB(230, 238, 250),
			Material = Enum.Material.Snow,
			CanCollide = false,
			Parent = hub,
		})
	end
	-- Invisible boundary
	for k = 1, 4 do
		local a = k * math.pi / 2
		Build.part({
			Name = "Boundary",
			Size = Vector3.new(2000, 400, 4),
			CFrame = CFrame.new(math.cos(a) * 980, 200, math.sin(a) * 980)
				* CFrame.Angles(0, -a + math.pi / 2, 0),
			Transparency = 1,
			Parent = hub,
		})
	end

	return hub
end

local function hubCF(angleDeg: number, radius: number): CFrame
	local a = math.rad(angleDeg)
	local pos = Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
	return CFrame.lookAt(pos, Vector3.new(0, 0, 0))
end

local function buildStable(hub: Instance)
	local model = Instance.new("Model")
	model.Name = "ReindeerStable"
	local cf = hubCF(0, 175)
	-- Barn
	Build.part({
		Size = Vector3.new(50, 22, 26),
		CFrame = cf * CFrame.new(0, 11, 14),
		Color = Color3.fromRGB(170, 35, 40),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(52, 2, 28),
		CFrame = cf * CFrame.new(0, 22, 14),
		Color = Color3.new(1, 1, 1),
		Parent = model,
	})
	Build.part({
		Size = Vector3.new(54, 3, 18),
		CFrame = cf * CFrame.new(0, 27, 7) * CFrame.Angles(math.rad(-30), 0, 0),
		Color = Color3.fromRGB(90, 50, 40),
		Parent = model,
	})
	Build.part({
		Size = Vector3.new(54, 3, 18),
		CFrame = cf * CFrame.new(0, 27, 21) * CFrame.Angles(math.rad(30), 0, 0),
		Color = Color3.fromRGB(90, 50, 40),
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(55, 1.2, 17),
		CFrame = cf * CFrame.new(0, 28.6, 7) * CFrame.Angles(math.rad(-30), 0, 0),
		Color = SNOW,
		Material = Enum.Material.Snow,
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(55, 1.2, 17),
		CFrame = cf * CFrame.new(0, 28.6, 21) * CFrame.Angles(math.rad(30), 0, 0),
		Color = SNOW,
		Material = Enum.Material.Snow,
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(14, 14, 0.5),
		CFrame = cf * CFrame.new(0, 7, 0.8),
		Color = Color3.fromRGB(90, 50, 35),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	sign(
		model,
		cf * CFrame.new(0, 19, -0.5) * CFrame.Angles(0, math.pi, 0),
		"🦌 Reindeer Stable",
		30,
		5,
		GREEN,
		Color3.new(1, 1, 1)
	)

	-- Egg pedestals
	for i, egg in Config.EGGS do
		local x = (i - (#Config.EGGS + 1) / 2) * 12
		local base = cf * CFrame.new(x, 0, -10)
		Build.part({
			Name = "Pedestal",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 8, 8),
			CFrame = base * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(230, 230, 240),
			Material = Enum.Material.Marble,
			Parent = model,
		})
		local eggPart = Build.part({
			Name = "Egg_" .. egg.id,
			Size = Vector3.new(5, 6.5, 5),
			CFrame = base * CFrame.new(0, 6.3, 0),
			Color = egg.color,
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = eggPart
		-- Spots on the egg
		for k = 1, 5 do
			local a = k * 1.3
			Build.ball(
				model,
				base * CFrame.new(math.cos(a) * 2.3, 5.5 + (k % 3), math.sin(a) * 2.3),
				1.1,
				Color3.new(1, 1, 1),
				Enum.Material.Neon
			)
		end
		Build.billboard(
			eggPart,
			egg.name,
			UDim2.fromOffset(160, 40),
			Vector3.new(0, 5.5, 0),
			egg.color,
			80
		)
		CollectionService:AddTag(eggPart, "Bob")
		local p = prompt(eggPart, "Hatch", egg.name, "Egg", 12)
		p:SetAttribute("EggId", egg.id)
	end
	-- A couple of decorative reindeer by the barn
	for i, petId in { "Cocoa", "Frostbite" } do
		local deer = ReindeerModel.build(petId, false, 2.2)
		deer:PivotTo(
			cf
				* CFrame.new(-30 + (i - 1) * 60, 0.6, 2)
				* CFrame.Angles(0, math.rad(i == 1 and 35 or -35), 0)
		)
		deer.Parent = model
	end
	model.Parent = hub
end

local function buildGiftPost(hub: Instance)
	local model = Instance.new("Model")
	model.Name = "GiftPost"
	local cf = hubCF(60, 170)
	-- Giant mailbox
	Build.part({
		Size = Vector3.new(4, 12, 4),
		CFrame = cf * CFrame.new(0, 6, 4),
		Color = Color3.fromRGB(60, 60, 70),
		Parent = model,
	})
	local box = Build.part({
		Name = "Mailbox",
		Size = Vector3.new(14, 10, 18),
		CFrame = cf * CFrame.new(0, 17, 4),
		Color = RED,
		Parent = model,
	})
	Build.cylinder(
		model,
		cf * CFrame.new(0, 22, 4) * CFrame.Angles(0, math.rad(90), 0),
		18,
		14,
		RED
	)
	Build.deco({
		Size = Vector3.new(1, 6, 1),
		CFrame = cf * CFrame.new(7.6, 22, 6),
		Color = GOLD,
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(1, 1, 4),
		CFrame = cf * CFrame.new(7.6, 25, 7.5),
		Color = GOLD,
		Parent = model,
	})
	sign(
		model,
		cf * CFrame.new(0, 31, 4) * CFrame.Angles(0, math.pi, 0),
		"🎁 Daily Gifts & Advent",
		26,
		5,
		RED,
		Color3.new(1, 1, 1)
	)
	for k = 1, 8 do
		local present = ToyModels.present(rng:NextNumber(2.5, 4.5), k)
		present:PivotTo(
			cf
				* CFrame.new(rng:NextNumber(-12, 12), 0.5, rng:NextNumber(-6, -2))
				* CFrame.Angles(0, rng:NextNumber(0, 6), 0)
		)
		present.Parent = model
	end
	prompt(box, "Open", "Daily Gifts", "Gifts", 18)
	model.Parent = hub
end

local function buildWardrobe(hub: Instance)
	local model = Instance.new("Model")
	model.Name = "Wardrobe"
	local cf = hubCF(120, 175)
	Build.part({
		Size = Vector3.new(36, 18, 22),
		CFrame = cf * CFrame.new(0, 9, 12),
		Color = Color3.fromRGB(240, 220, 190),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	Build.part({
		Size = Vector3.new(40, 3, 26),
		CFrame = cf * CFrame.new(0, 19.5, 12),
		Color = Color3.fromRGB(40, 130, 70),
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(41, 1.5, 27),
		CFrame = cf * CFrame.new(0, 21.6, 12),
		Color = SNOW,
		Material = Enum.Material.Snow,
		Parent = model,
	})
	-- Striped awning
	for k = 0, 7 do
		Build.deco({
			Size = Vector3.new(4.5, 0.6, 7),
			CFrame = cf
				* CFrame.new(-15.75 + k * 4.5, 15, -2.5)
				* CFrame.Angles(math.rad(20), 0, 0),
			Color = if k % 2 == 0 then RED else Color3.new(1, 1, 1),
			Parent = model,
		})
	end
	local counter = Build.part({
		Name = "Counter",
		Size = Vector3.new(20, 4, 3),
		CFrame = cf * CFrame.new(0, 2, -1),
		Color = WOOD,
		Parent = model,
	})
	sign(
		model,
		cf * CFrame.new(0, 24.5, 0.5) * CFrame.Angles(0, math.pi, 0),
		"🧶 Ugly Sweater Shop",
		28,
		5,
		Color3.fromRGB(40, 130, 70),
		Color3.new(1, 1, 1)
	)
	-- Mannequins wearing sweaters
	local sweaterColors = { RED, GREEN, Color3.fromRGB(40, 80, 160) }
	for k = 1, 3 do
		local m = cf * CFrame.new(-10 + (k - 1) * 10, 0, -6)
		Build.deco({
			Size = Vector3.new(1, 3, 1),
			CFrame = m * CFrame.new(0, 1.5, 0),
			Color = Color3.fromRGB(60, 60, 60),
			Parent = model,
		})
		Build.deco({
			Size = Vector3.new(3.6, 3.2, 1.8),
			CFrame = m * CFrame.new(0, 4.6, 0),
			Color = sweaterColors[k],
			Material = Enum.Material.Fabric,
			Parent = model,
		})
		Build.ball(model, m * CFrame.new(0, 7, 0), 2, Color3.fromRGB(230, 230, 230))
	end
	prompt(counter, "Shop", "Ugly Sweater Shop", "Wardrobe", 18)
	model.Parent = hub
end

local function boardGui(part: BasePart, title: string): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, 0.14)
	titleLabel.Text = title
	titleLabel.TextScaled = true
	titleLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	titleLabel.TextColor3 = GOLD
	titleLabel.Parent = gui
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.05, 0.16)
	list.Size = UDim2.fromScale(0.9, 0.82)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 0.1)
		row.Text = `{i}. ...`
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		row.TextColor3 = if i <= 3 then Color3.fromRGB(255, 240, 200) else Color3.new(1, 1, 1)
		row.Parent = list
	end
	list.Parent = gui
	gui.Parent = part
	return gui
end

local function buildLeaderboards(hub: Instance)
	local model = Instance.new("Model")
	model.Name = "Leaderboards"
	for i, info in
		{
			{ key = "Delivered", title = "🎁 Top Present Deliverers", angle = 170 },
			{ key = "Cheer", title = "⭐ Merriest Workshops", angle = 190 },
		}
	do
		local cf = hubCF(info.angle, 180)
		local board = Build.part({
			Name = "Board_" .. info.key,
			Size = Vector3.new(26, 30, 1),
			CFrame = cf * CFrame.new(0, 18, 0) * CFrame.Angles(0, math.pi, 0),
			Color = Color3.fromRGB(25, 50, 40),
			Parent = model,
		})
		Build.deco({
			Size = Vector3.new(28, 32, 0.6),
			CFrame = cf * CFrame.new(0, 18, 0.6),
			Color = if i == 1 then RED else GOLD,
			Parent = model,
		})
		Build.part({
			Size = Vector3.new(2, 4, 2),
			CFrame = cf * CFrame.new(-11, 2, 0.5),
			Color = WOOD,
			Parent = model,
		})
		Build.part({
			Size = Vector3.new(2, 4, 2),
			CFrame = cf * CFrame.new(11, 2, 0.5),
			Color = WOOD,
			Parent = model,
		})
		WorldBuilder.boards[info.key] = boardGui(board, info.title)
	end
	model.Parent = hub
end

local function buildRunway(hub: Instance)
	local model = Instance.new("Model")
	model.Name = "SleighRunway"
	local cf = hubCF(240, 170)
	Build.part({
		Name = "Runway",
		Size = Vector3.new(24, 1, 60),
		CFrame = cf * CFrame.new(0, 0.3, 10),
		Color = Color3.fromRGB(70, 70, 90),
		Material = Enum.Material.Slate,
		Parent = model,
	})
	for k = 0, 9 do
		local light = Build.deco({
			Size = Vector3.new(1.5, 0.6, 1.5),
			CFrame = cf * CFrame.new(-11, 1, -18 + k * 6),
			Color = if k % 2 == 0 then Color3.fromRGB(80, 200, 255) else GOLD,
			Material = Enum.Material.Neon,
			Parent = model,
		})
		light.Name = "RunwayLight"
		Build.deco({
			Size = Vector3.new(1.5, 0.6, 1.5),
			CFrame = cf * CFrame.new(11, 1, -18 + k * 6),
			Color = if k % 2 == 0 then Color3.fromRGB(80, 200, 255) else GOLD,
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end
	local sleigh = WorldBuilder.sleighModel(1.6)
	sleigh:PivotTo(cf * CFrame.new(0, 1, 14) * CFrame.Angles(0, math.pi, 0))
	sleigh.Parent = model
	for i = 1, 2 do
		local deer = ReindeerModel.build(if i == 1 then "Starlight" else "Twinkle", false, 1.8)
		deer:PivotTo(cf * CFrame.new(-4 + (i - 1) * 8, 0.8, 0) * CFrame.Angles(0, math.pi, 0))
		deer.Parent = model
	end
	local seat = sleigh.PrimaryPart :: BasePart
	sign(
		model,
		cf * CFrame.new(0, 16, 30) * CFrame.Angles(0, math.pi, 0),
		"🛷 Sleigh Delivery",
		24,
		5,
		Color3.fromRGB(40, 60, 140),
		Color3.new(1, 1, 1)
	)
	Build.part({
		Size = Vector3.new(1.5, 14, 1.5),
		CFrame = cf * CFrame.new(-11, 7, 30.6),
		Color = WOOD,
		Parent = model,
	})
	Build.part({
		Size = Vector3.new(1.5, 14, 1.5),
		CFrame = cf * CFrame.new(11, 7, 30.6),
		Color = WOOD,
		Parent = model,
	})
	prompt(seat, "Fly!", "Sleigh Delivery", "Sleigh", 18)
	model.Parent = hub
end

local function buildEventSign(hub: Instance)
	local model = Instance.new("Model")
	model.Name = "EventSign"
	local cf = hubCF(300, 175)
	local globe = Build.deco({
		Name = "SnowGlobe",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(26, 26, 26),
		CFrame = cf * CFrame.new(0, 17, 10),
		Color = Color3.fromRGB(190, 230, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		Parent = model,
	})
	Build.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 24, 24),
		CFrame = cf * CFrame.new(0, 3, 10) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 70, 45),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	WorldBuilder.pineTree(model, cf * CFrame.new(0, 6, 10), 14, true)
	local snow = Instance.new("ParticleEmitter")
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.Size = NumberSequence.new(0.4)
	snow.Rate = 20
	snow.Lifetime = NumberRange.new(3, 4)
	snow.Speed = NumberRange.new(1, 2)
	snow.SpreadAngle = Vector2.new(180, 180)
	snow.Acceleration = Vector3.new(0, -1, 0)
	snow.Parent = globe
	local board = sign(
		model,
		cf * CFrame.new(0, 8, -6) * CFrame.Angles(0, math.pi, 0),
		"Christmas Event",
		26,
		7,
		RED,
		Color3.new(1, 1, 1)
	)
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if gui then
		WorldBuilder.eventSign = gui:FindFirstChildOfClass("TextLabel")
	end
	model.Parent = hub
end

--------------------------------------------------------------------------------
-- Sleigh model (shared by runway, plots and delivery runs)
--------------------------------------------------------------------------------
function WorldBuilder.sleighModel(scale: number, compact: boolean?): Model
	local s = scale
	local model = Instance.new("Model")
	model.Name = "Sleigh"
	local root = Build.deco({
		Name = "Root",
		Size = Vector3.new(6, 1, 9) * s,
		CFrame = CFrame.new(0, 1.5 * s, 0),
		Transparency = 1,
		Parent = model,
	})
	model.PrimaryPart = root
	local function box(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?)
		Build.deco({
			Size = size * s,
			CFrame = CFrame.new(cf.Position * s) * cf.Rotation,
			Color = color,
			Material = mat or Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	box(Vector3.new(6, 2.5, 8), CFrame.new(0, 2.2, 0.5), RED)
	box(Vector3.new(6.2, 0.5, 8.2), CFrame.new(0, 3.5, 0.5), GOLD, Enum.Material.Metal)
	box(Vector3.new(6, 3.5, 1.2), CFrame.new(0, 3.5, 4.2), RED)
	box(Vector3.new(6, 1.6, 1.4), CFrame.new(0, 2.2, -4) * CFrame.Angles(math.rad(-25), 0, 0), RED)
	box(Vector3.new(5, 0.6, 1), CFrame.new(0, 2.5, 1.5), Color3.fromRGB(120, 30, 40))
	for _, x in { -2.6, 2.6 } do
		box(Vector3.new(0.4, 0.4, 10), CFrame.new(x, 0.3, 0), GOLD, Enum.Material.Metal)
		box(Vector3.new(0.4, 2.0, 0.4), CFrame.new(x, 1.0, -2.8), GOLD, Enum.Material.Metal)
		box(Vector3.new(0.4, 2.0, 0.4), CFrame.new(x, 1.0, 2.8), GOLD, Enum.Material.Metal)
		box(
			Vector3.new(0.4, 1.5, 0.4),
			CFrame.new(x, 1.0, -5.2) * CFrame.Angles(math.rad(-50), 0, 0),
			GOLD,
			Enum.Material.Metal
		)
	end
	-- Sack of presents in the back
	local sackSize = if compact then 2 else 3.6
	local sackY = if compact then 4.4 else 5.5
	local sack = Build.ball(
		model,
		CFrame.new(0, sackY * s, 3 * s),
		sackSize * s,
		Color3.fromRGB(150, 100, 60),
		Enum.Material.Fabric
	)
	sack.Name = "Sack"
	local p = ToyModels.present((if compact then 1 else 1.4) * s, 1)
	p:PivotTo(CFrame.new(1.2 * s, (sackY + sackSize * 0.3) * s, 2.6 * s))
	p.Parent = model
	return model
end

--------------------------------------------------------------------------------
-- Plot bases (static parts; Workshop fills in owned content)
--------------------------------------------------------------------------------
local function buildPlot(plots: Instance, index: number): Model
	local plotCF = PlotLayout.plotCFrame(index, Config.MAX_PLOTS)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("Index", index)
	model:SetAttribute("OwnerId", 0)

	local function at(cf: CFrame): CFrame
		return plotCF * cf
	end
	local size = PlotLayout.SIZE

	local floor = Build.part({
		Name = "Floor",
		Size = Vector3.new(size, 1, size),
		CFrame = at(CFrame.new(0, -0.4, 0)),
		Color = Color3.fromRGB(235, 240, 250),
		Material = Enum.Material.Snow,
		Parent = model,
	})
	model.PrimaryPart = floor
	Build.part({
		Name = "WorkFloor",
		Size = Vector3.new(130, 0.4, 50),
		CFrame = at(CFrame.new(-4, 0.2, PlotLayout.BELT_Z + 2)),
		Color = Color3.fromRGB(165, 115, 75),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})

	-- Conveyor belt
	local beltLength = PlotLayout.SACK_X - PlotLayout.BELT_START_X
	local beltCenter = (PlotLayout.SACK_X + PlotLayout.BELT_START_X) / 2
	Build.part({
		Name = "Belt",
		Size = Vector3.new(beltLength, 1.2, 6),
		CFrame = at(CFrame.new(beltCenter, 1.0, PlotLayout.BELT_Z)),
		Color = Color3.fromRGB(45, 45, 55),
		Material = Enum.Material.Rubber,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		Build.part({
			Name = "BeltRail",
			Size = Vector3.new(beltLength, 1.6, 0.6),
			CFrame = at(CFrame.new(beltCenter, 1.4, PlotLayout.BELT_Z + side * 3.3)),
			Color = Color3.fromRGB(200, 40, 50),
			Material = Enum.Material.Metal,
			Parent = model,
		})
	end
	for x = PlotLayout.BELT_START_X + 2, PlotLayout.SACK_X - 2, 6 do
		Build.cylinder(
			model,
			at(CFrame.new(x, 0.6, PlotLayout.BELT_Z) * CFrame.Angles(0, math.rad(90), 0)),
			6.4,
			1.2,
			Color3.fromRGB(150, 150, 160),
			Enum.Material.Metal
		)
	end

	-- Wrapping station arch
	local wx = PlotLayout.WRAP_X
	Build.part({
		Size = Vector3.new(6, 10, 1.5),
		CFrame = at(CFrame.new(wx, 5, PlotLayout.BELT_Z - 4.5)),
		Color = Color3.fromRGB(40, 140, 70),
		Parent = model,
	})
	Build.part({
		Size = Vector3.new(6, 10, 1.5),
		CFrame = at(CFrame.new(wx, 5, PlotLayout.BELT_Z + 4.5)),
		Color = Color3.fromRGB(40, 140, 70),
		Parent = model,
	})
	Build.part({
		Size = Vector3.new(7, 2.5, 11),
		CFrame = at(CFrame.new(wx, 11, PlotLayout.BELT_Z)),
		Color = RED,
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(7.2, 2.6, 1.2),
		CFrame = at(CFrame.new(wx, 11, PlotLayout.BELT_Z)),
		Color = GOLD,
		Parent = model,
	})
	Build.ball(model, at(CFrame.new(wx - 1.2, 13, PlotLayout.BELT_Z)), 2, GOLD)
	Build.ball(model, at(CFrame.new(wx + 1.2, 13, PlotLayout.BELT_Z)), 2, GOLD)
	local wrapGlow = Build.deco({
		Name = "WrapGlow",
		Size = Vector3.new(5.5, 0.3, 5.5),
		CFrame = at(CFrame.new(wx, 9.6, PlotLayout.BELT_Z)),
		Color = Color3.fromRGB(255, 230, 150),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	Build.light(wrapGlow, WARM_LIGHT, 14, 1.5)
	Build.billboard(
		wrapGlow,
		"🎀 Wrapping Station",
		UDim2.fromScale(10, 2),
		Vector3.new(0, 5, 0),
		Color3.new(1, 1, 1),
		70
	)

	-- Present sack (Workshop scales it with fill)
	local sx = PlotLayout.SACK_X
	Build.part({
		Name = "SackStand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 14, 14),
		CFrame = at(CFrame.new(sx, 0.5, PlotLayout.BELT_Z) * CFrame.Angles(0, 0, math.rad(90))),
		Color = Color3.fromRGB(120, 80, 50),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	local sack = Build.part({
		Name = "Sack",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7),
		CFrame = at(CFrame.new(sx, 4.5, PlotLayout.BELT_Z)),
		Color = Color3.fromRGB(160, 110, 65),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = model,
	})
	Build.billboard(
		sack,
		"Sack 0%",
		UDim2.fromScale(11, 2.8),
		Vector3.new(0, 9, 0),
		Color3.new(1, 1, 1),
		90
	)

	-- Sleigh + load pad
	local sleigh = WorldBuilder.sleighModel(1.3)
	sleigh:PivotTo(at(PlotLayout.SLEIGH * CFrame.new(0, 0.2, 0)))
	sleigh.Parent = model
	for i = 1, 2 do
		local deer = ReindeerModel.build("Cocoa", false, 1.4)
		deer:PivotTo(at(PlotLayout.SLEIGH * CFrame.new(-2.5 + (i - 1) * 5, 0.5, -13)))
		deer.Parent = model
	end
	local sleighSeat = sleigh.PrimaryPart :: BasePart
	local flyPrompt = prompt(sleighSeat, "Fly Delivery!", "Your Sleigh", "Sleigh", 16)
	flyPrompt.KeyboardKeyCode = Enum.KeyCode.F

	local loadPad = Build.part({
		Name = "LoadPad",
		Size = Vector3.new(12, 0.6, 12),
		CFrame = at(PlotLayout.LOAD_PAD * CFrame.new(0, 0.3, 0)),
		Color = Color3.fromRGB(60, 220, 110),
		Material = Enum.Material.Neon,
		CanTouch = true,
		Parent = model,
	})
	Build.billboard(
		loadPad,
		"🛷 LOAD SLEIGH",
		UDim2.fromScale(13, 3),
		Vector3.new(0, 5, 0),
		Color3.new(1, 1, 1),
		100
	)
	Build.light(loadPad, Color3.fromRGB(100, 255, 150), 16, 1)

	-- Buy pads (Workshop updates labels and visibility)
	for name, cf in
		{
			PadMachine = PlotLayout.PAD_MACHINE,
			PadDecor = PlotLayout.PAD_DECOR,
			PadElf = PlotLayout.PAD_ELF,
		}
	do
		local pad = Build.part({
			Name = name,
			Size = Vector3.new(10, 0.6, 10),
			CFrame = at(cf * CFrame.new(0, 0.3, 0)),
			Color = Color3.fromRGB(255, 200, 60),
			Material = Enum.Material.Neon,
			CanTouch = true,
			Parent = model,
		})
		Build.billboard(
			pad,
			"",
			UDim2.fromScale(13, 4.2),
			Vector3.new(0, 5.5, 0),
			Color3.new(1, 1, 1),
			90
		)
	end

	-- Owner sign
	Build.part({
		Size = Vector3.new(1.5, 12, 1.5),
		CFrame = at(PlotLayout.SIGN * CFrame.new(-9, 6, 0)),
		Color = WOOD,
		Parent = model,
	})
	Build.part({
		Size = Vector3.new(1.5, 12, 1.5),
		CFrame = at(PlotLayout.SIGN * CFrame.new(9, 6, 0)),
		Color = WOOD,
		Parent = model,
	})
	local ownerSign = sign(
		model,
		at(PlotLayout.SIGN * CFrame.new(0, 10, 0)),
		"Free Workshop",
		20,
		4.5,
		RED,
		Color3.new(1, 1, 1)
	)
	ownerSign.Name = "OwnerSign"

	-- Snowy border
	for _, side in { -1, 1 } do
		Build.part({
			Size = Vector3.new(size, 2, 3),
			CFrame = at(CFrame.new(0, 1, side * (size / 2 - 1.5))),
			Color = SNOW,
			Material = Enum.Material.Snow,
			Parent = model,
		})
		Build.part({
			Size = Vector3.new(3, 2, size),
			CFrame = at(CFrame.new(side * (size / 2 - 1.5), 1, 0)),
			Color = SNOW,
			Material = Enum.Material.Snow,
			Parent = model,
		})
	end

	local content = Instance.new("Folder")
	content.Name = "Content"
	content.Parent = model

	model.Parent = plots
	return model
end

--------------------------------------------------------------------------------
-- Sleigh delivery town
--------------------------------------------------------------------------------
local HOUSE_COLORS = {
	Color3.fromRGB(245, 230, 200),
	Color3.fromRGB(190, 220, 245),
	Color3.fromRGB(245, 200, 210),
	Color3.fromRGB(200, 240, 210),
	Color3.fromRGB(250, 235, 160),
	Color3.fromRGB(175, 80, 70),
}
local ROOF_COLORS = {
	Color3.fromRGB(130, 35, 40),
	Color3.fromRGB(40, 90, 60),
	Color3.fromRGB(80, 55, 45),
	Color3.fromRGB(60, 70, 110),
}

local function buildHouse(parent: Instance, base: CFrame, index: number)
	local model = Instance.new("Model")
	model.Name = "House" .. index
	local w = rng:NextNumber(24, 32)
	local d = rng:NextNumber(20, 26)
	local h = rng:NextNumber(14, 22)
	Build.part({
		Size = Vector3.new(w, h, d),
		CFrame = base * CFrame.new(0, h / 2, 0),
		Color = HOUSE_COLORS[rng:NextInteger(1, #HOUSE_COLORS)],
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = model,
	})
	local roofColor = ROOF_COLORS[rng:NextInteger(1, #ROOF_COLORS)]
	local slope = math.rad(32)
	local half = d / 2
	local roofLen = half / math.cos(slope) + 2
	local roofRise = half * math.tan(slope)
	for _, side in { -1, 1 } do
		local cf = base
			* CFrame.new(0, h + roofRise / 2, side * half / 2)
			* CFrame.Angles(side * slope, 0, 0)
		Build.deco({
			Size = Vector3.new(w + 2, 1.2, roofLen),
			CFrame = cf,
			Color = roofColor,
			Parent = model,
		})
		Build.deco({
			Size = Vector3.new(w + 2.2, 0.6, roofLen * 0.9),
			CFrame = cf * CFrame.new(0, 0.8, 0),
			Color = SNOW,
			Material = Enum.Material.Snow,
			Parent = model,
		})
	end
	-- Chimney
	local cx = rng:NextNumber(-w / 3, w / 3)
	local chimneyTop = h + roofRise + 6
	Build.deco({
		Size = Vector3.new(4, chimneyTop - h, 4),
		CFrame = base * CFrame.new(cx, h + (chimneyTop - h) / 2, -half / 3),
		Color = Color3.fromRGB(150, 60, 50),
		Material = Enum.Material.Brick,
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(4.8, 1, 4.8),
		CFrame = base * CFrame.new(cx, chimneyTop, -half / 3),
		Color = Color3.fromRGB(120, 50, 45),
		Material = Enum.Material.Brick,
		Parent = model,
	})
	local marker = Build.deco({
		Name = "Chimney",
		Size = Vector3.new(3, 0.4, 3),
		CFrame = base * CFrame.new(cx, chimneyTop + 0.6, -half / 3),
		Color = Color3.fromRGB(30, 20, 20),
		Parent = model,
	})
	marker:SetAttribute("Index", index)
	CollectionService:AddTag(marker, "Chimney")
	WorldBuilder.chimneys[index] = marker.Position
	-- Windows and door
	for _, x in { -w / 4, w / 4 } do
		Build.deco({
			Size = Vector3.new(4, 4, 0.4),
			CFrame = base * CFrame.new(x, h * 0.6, -d / 2 - 0.1),
			Color = WARM_LIGHT,
			Material = Enum.Material.Neon,
			Parent = model,
		})
	end
	Build.deco({
		Size = Vector3.new(4.5, 7, 0.4),
		CFrame = base * CFrame.new(0, 3.5, -d / 2 - 0.1),
		Color = Color3.fromRGB(110, 60, 40),
		Parent = model,
	})
	Build.ball(model, base * CFrame.new(0, 8.5, -d / 2 - 0.4), 2.2, Color3.fromRGB(40, 140, 60))
	-- String lights along the roof edge
	for k = 0, 6 do
		Build.ball(
			model,
			base * CFrame.new(-w / 2 + k * (w / 6), h + 0.2, -d / 2 - 0.4),
			0.9,
			ORNAMENTS[(k + index) % #ORNAMENTS + 1],
			Enum.Material.Neon
		)
	end
	model.Parent = parent
end

local function buildTown(world: Instance)
	local town = folder("Town", world)
	local origin = WorldBuilder.TOWN_ORIGIN
	Build.part({
		Name = "TownGround",
		Size = Vector3.new(1300, 4, 1300),
		CFrame = origin * CFrame.new(0, -2, 0),
		Color = SNOW,
		Material = Enum.Material.Snow,
		Parent = town,
	})
	local index = 0
	for gx = -4, 4 do
		for gz = -4, 4 do
			if rng:NextNumber() < 0.82 and not (gx == 0 and gz == 0) then
				index += 1
				local base = origin
					* CFrame.new(
						gx * 115 + rng:NextNumber(-15, 15),
						0,
						gz * 115 + rng:NextNumber(-15, 15)
					)
					* CFrame.Angles(0, math.rad(rng:NextInteger(0, 3) * 90), 0)
				buildHouse(town, base, index)
			elseif rng:NextNumber() < 0.6 then
				WorldBuilder.pineTree(
					town,
					origin * CFrame.new(gx * 115, 0, gz * 115),
					rng:NextNumber(25, 45),
					true
				)
			end
		end
	end
	-- Streets
	for k = -4, 3 do
		Build.part({
			Size = Vector3.new(14, 0.3, 1050),
			CFrame = origin * CFrame.new(k * 115 + 57, 0.15, 0),
			Color = Color3.fromRGB(150, 155, 170),
			Material = Enum.Material.Slate,
			Parent = town,
		})
		Build.part({
			Size = Vector3.new(1050, 0.3, 14),
			CFrame = origin * CFrame.new(0, 0.18, k * 115 + 57),
			Color = Color3.fromRGB(150, 155, 170),
			Material = Enum.Material.Slate,
			Parent = town,
		})
	end
	-- Town square tree
	WorldBuilder.pineTree(town, origin, 70, true)
	for _ = 1, 60 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(560, 640)
		WorldBuilder.pineTree(
			town,
			origin * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r),
			rng:NextNumber(30, 55),
			false
		)
	end
	-- Floating guide rings mark the start
	local start = Build.deco({
		Name = "StartGate",
		Size = Vector3.new(30, 30, 2),
		CFrame = origin * CFrame.new(0, Config.SLEIGH.ALTITUDE, 560),
		Color = GOLD,
		Material = Enum.Material.Neon,
		Transparency = 0.7,
		Parent = town,
	})
	start.Name = "StartGate"
end

--------------------------------------------------------------------------------

function WorldBuilder.init()
	buildLighting()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	local hub = buildHub(world)
	buildStable(hub)
	buildGiftPost(hub)
	buildWardrobe(hub)
	buildLeaderboards(hub)
	buildRunway(hub)
	buildEventSign(hub)

	local plots = folder("Plots", workspace)
	for i = 1, Config.MAX_PLOTS do
		WorldBuilder.plots[i] = buildPlot(plots, i)
	end

	buildTown(world)

	folder("Pets", workspace)
	folder("Drops", workspace)
end

function WorldBuilder.townStart(): CFrame
	return WorldBuilder.TOWN_ORIGIN * CFrame.new(0, Config.SLEIGH.ALTITUDE, 540)
end

return WorldBuilder
