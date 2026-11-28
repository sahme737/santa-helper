--!strict
-- The North Pole Express: a chunky engine and open-top coaches with benches.
-- Purely visual, built on each client. Models face -Z, pivot on the rails,
-- and every part is welded to an anchored Root so one CFrame moves it all.

local Build = require(script.Parent.Parent.Util.Build)

local TrainModel = {}

local RED = Color3.fromRGB(205, 40, 50)
local GREEN = Color3.fromRGB(35, 120, 70)
local GOLD = Color3.fromRGB(255, 200, 60)
local DARK = Color3.fromRGB(40, 40, 46)
local WOOD = Color3.fromRGB(150, 100, 62)

-- Where riders sit in a coach, relative to its pivot (top of the bench).
TrainModel.SEATS = {
	CFrame.new(-1.7, 3.3, -2.4),
	CFrame.new(1.7, 3.3, -2.4),
	CFrame.new(-1.7, 3.3, 2.6),
	CFrame.new(1.7, 3.3, 2.6),
}
-- Where the driver stands in the engine cab.
TrainModel.DRIVER = CFrame.new(0, 2.6, 4.2)

local function newModel(name: string): Model
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
	return model
end

local function finish(model: Model)
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
end

local function box(model: Model, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?)
	return Build.deco({
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material,
		Parent = model,
	})
end

local function wheels(model: Model, x: number, y: number, zs: { number }, diameter: number)
	for _, z in zs do
		for _, side in { -1, 1 } do
			Build.cylinder(model, CFrame.new(x * side, y, z), 0.6, diameter, GOLD)
			Build.cylinder(model, CFrame.new((x + 0.2) * side, y, z), 0.3, diameter * 0.4, RED)
		end
	end
end

function TrainModel.engine(): Model
	local model = newModel("ExpressEngine")
	box(model, Vector3.new(6.4, 1.2, 14), CFrame.new(0, 2, 0), RED)
	Build.cylinder(
		model,
		CFrame.new(0, 5, -2.2) * CFrame.Angles(0, math.rad(90), 0),
		8.6,
		4.6,
		GREEN
	)
	for _, z in { -5.6, -2.2, 1.2 } do
		Build.cylinder(
			model,
			CFrame.new(0, 5, z) * CFrame.Angles(0, math.rad(90), 0),
			0.5,
			4.9,
			GOLD
		)
	end
	-- Cab: back wall, side walls with windows left open, roof.
	box(model, Vector3.new(6.2, 5.4, 0.6), CFrame.new(0, 5.3, 6.6), RED)
	for _, side in { -1, 1 } do
		box(model, Vector3.new(0.5, 2.4, 4.4), CFrame.new(2.85 * side, 3.8, 4.4), RED)
		box(model, Vector3.new(0.5, 3, 0.6), CFrame.new(2.85 * side, 6.5, 2.4), RED)
	end
	box(model, Vector3.new(7.2, 0.6, 5.6), CFrame.new(0, 8.3, 4.4), GREEN)
	box(
		model,
		Vector3.new(7.4, 0.3, 5.8),
		CFrame.new(0, 8.7, 4.4),
		Color3.new(1, 1, 1),
		Enum.Material.Snow
	)
	-- Chimney, bell and lamp.
	local chimney = Build.cylinder(
		model,
		CFrame.new(0, 8.2, -4.6) * CFrame.Angles(0, 0, math.rad(90)),
		2.6,
		1.6,
		DARK
	)
	Build.cylinder(
		model,
		CFrame.new(0, 9.6, -4.6) * CFrame.Angles(0, 0, math.rad(90)),
		0.5,
		2.2,
		GOLD
	)
	Build.ball(model, CFrame.new(0, 7.9, -1.4), 1.3, GOLD, Enum.Material.Metal)
	local lamp = Build.ball(
		model,
		CFrame.new(0, 5, -6.7),
		1.6,
		Color3.fromRGB(255, 240, 170),
		Enum.Material.Neon
	)
	Build.light(lamp, Color3.fromRGB(255, 235, 170), 28, 1.6)
	-- Cow-catcher and wheels.
	box(
		model,
		Vector3.new(5.6, 1.4, 1),
		CFrame.new(0, 1.6, -7.4) * CFrame.Angles(math.rad(-30), 0, 0),
		GOLD
	)
	wheels(model, 3.2, 1.6, { -4.4, -1.2, 2, 5.2 }, 3.2)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(250, 250, 255))
	smoke.Transparency = NumberSequence.new(0.25, 1)
	smoke.Size = NumberSequence.new(2, 7)
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Speed = NumberRange.new(8, 11)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Rate = 7
	smoke.Parent = chimney
	finish(model)
	return model
end

local COACH_COLORS = { GREEN, RED, Color3.fromRGB(50, 110, 200), Color3.fromRGB(230, 165, 40) }
local BULBS = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(100, 235, 120),
	Color3.fromRGB(255, 215, 80),
	Color3.fromRGB(100, 170, 255),
}

function TrainModel.coach(index: number): Model
	local model = newModel("ExpressCoach")
	local color = COACH_COLORS[(index - 1) % #COACH_COLORS + 1]
	box(model, Vector3.new(6.6, 0.8, 11), CFrame.new(0, 2, 0), color)
	-- Low side walls with a step-in gap in the middle, and end walls.
	for _, side in { -1, 1 } do
		for _, z in { -3.6, 3.6 } do
			box(model, Vector3.new(0.4, 1.8, 3.6), CFrame.new(3.1 * side, 3.3, z), color)
		end
		for _, z in { -5.2, 5.2 } do
			box(
				model,
				Vector3.new(0.5, 5.6, 0.5),
				CFrame.new(3.05 * side, 5.2, z),
				Color3.new(1, 1, 1)
			)
		end
	end
	for _, z in { -5.3, 5.3 } do
		box(model, Vector3.new(6.6, 1.8, 0.4), CFrame.new(0, 3.3, z), color)
	end
	-- Two benches facing forward.
	for _, z in { -2.4, 2.6 } do
		box(
			model,
			Vector3.new(5.6, 0.5, 1.6),
			CFrame.new(0, 3.05, z),
			WOOD,
			Enum.Material.WoodPlanks
		)
		box(
			model,
			Vector3.new(5.6, 1.8, 0.4),
			CFrame.new(0, 3.9, z + 1),
			WOOD,
			Enum.Material.WoodPlanks
		)
	end
	-- Open top, so riders can see out (and the camera can see them): just a
	-- string of fairy lights along each side between the corner posts.
	for _, side in { -1, 1 } do
		box(
			model,
			Vector3.new(0.3, 0.3, 10.8),
			CFrame.new(3.05 * side, 7.9, 0),
			Color3.new(1, 1, 1)
		)
		for k = 0, 5 do
			Build.ball(
				model,
				CFrame.new(3.05 * side, 7.4, -5 + k * 2),
				0.6,
				BULBS[(k + index) % #BULBS + 1],
				Enum.Material.Neon
			)
		end
	end
	wheels(model, 3.2, 1.2, { -3.4, 3.4 }, 2.4)
	finish(model)
	return model
end

return TrainModel
