--!strict
-- Small toy models that ride the conveyor, plus wrapped presents.
-- All parts are decorative (no collision); pivot is the base center.

local Build = require(script.Parent.Parent.Util.Build)

local ToyModels = {}

type Maker = (
	model: Model,
	add: (Vector3, CFrame, Color3, Enum.PartType?, Enum.Material?) -> Part
) -> ()

local makers: { [string]: Maker } = {
	Teddy = function(_model, add)
		local fur = Color3.fromRGB(196, 132, 84)
		add(Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 0.6, 0), fur, Enum.PartType.Ball)
		add(Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 1.45, 0), fur, Enum.PartType.Ball)
		add(Vector3.new(0.35, 0.35, 0.35), CFrame.new(-0.38, 1.85, 0), fur, Enum.PartType.Ball)
		add(Vector3.new(0.35, 0.35, 0.35), CFrame.new(0.38, 1.85, 0), fur, Enum.PartType.Ball)
		add(
			Vector3.new(0.35, 0.3, 0.2),
			CFrame.new(0, 1.35, -0.42),
			Color3.fromRGB(235, 200, 160),
			Enum.PartType.Ball
		)
		add(Vector3.new(0.7, 0.18, 0.18), CFrame.new(0, 1.05, -0.3), Color3.fromRGB(220, 40, 50))
	end,
	Train = function(_model, add)
		add(Vector3.new(1, 0.7, 1.6), CFrame.new(0, 0.55, 0), Color3.fromRGB(220, 50, 50))
		add(Vector3.new(0.9, 0.7, 0.6), CFrame.new(0, 1.2, 0.45), Color3.fromRGB(40, 90, 200))
		add(
			Vector3.new(0.5, 0.3, 0.3),
			CFrame.new(0, 1.15, -0.5) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(40, 40, 45),
			Enum.PartType.Cylinder
		)
		for _, z in { -0.5, 0.5 } do
			for _, x in { -0.55, 0.55 } do
				add(
					Vector3.new(0.15, 0.45, 0.45),
					CFrame.new(x, 0.25, z),
					Color3.fromRGB(255, 200, 50),
					Enum.PartType.Cylinder
				)
			end
		end
	end,
	Horse = function(_model, add)
		local wood = Color3.fromRGB(240, 180, 70)
		add(Vector3.new(0.6, 0.6, 1.4), CFrame.new(0, 1.0, 0), wood)
		add(Vector3.new(0.5, 0.8, 0.5), CFrame.new(0, 1.5, -0.6), wood)
		add(Vector3.new(0.45, 0.4, 0.6), CFrame.new(0, 1.85, -0.85), wood)
		add(Vector3.new(0.2, 0.6, 0.2), CFrame.new(0, 1.9, -0.45), Color3.fromRGB(150, 60, 40))
		add(Vector3.new(0.25, 0.12, 1.9), CFrame.new(-0.35, 0.15, 0), Color3.fromRGB(200, 40, 40))
		add(Vector3.new(0.25, 0.12, 1.9), CFrame.new(0.35, 0.15, 0), Color3.fromRGB(200, 40, 40))
		add(Vector3.new(0.6, 0.5, 0.15), CFrame.new(0, 0.5, -0.5), wood)
		add(Vector3.new(0.6, 0.5, 0.15), CFrame.new(0, 0.5, 0.5), wood)
	end,
	House = function(_model, add)
		add(Vector3.new(1.3, 1.0, 1.3), CFrame.new(0, 0.5, 0), Color3.fromRGB(250, 200, 220))
		add(
			Vector3.new(1.0, 0.15, 1.5),
			CFrame.new(-0.35, 1.2, 0) * CFrame.Angles(0, 0, math.rad(40)),
			Color3.fromRGB(230, 90, 150)
		)
		add(
			Vector3.new(1.0, 0.15, 1.5),
			CFrame.new(0.35, 1.2, 0) * CFrame.Angles(0, 0, math.rad(-40)),
			Color3.fromRGB(230, 90, 150)
		)
		add(Vector3.new(0.35, 0.5, 0.05), CFrame.new(0, 0.25, -0.66), Color3.fromRGB(150, 80, 50))
		add(
			Vector3.new(0.3, 0.3, 0.05),
			CFrame.new(0.4, 0.65, -0.66),
			Color3.fromRGB(255, 240, 150),
			nil,
			Enum.Material.Neon
		)
	end,
	Robot = function(_model, add)
		local metal = Color3.fromRGB(150, 180, 220)
		add(Vector3.new(0.9, 0.9, 0.6), CFrame.new(0, 0.9, 0), metal, nil, Enum.Material.Metal)
		add(Vector3.new(0.7, 0.6, 0.6), CFrame.new(0, 1.65, 0), metal, nil, Enum.Material.Metal)
		add(
			Vector3.new(0.15, 0.15, 0.05),
			CFrame.new(-0.15, 1.7, -0.31),
			Color3.fromRGB(80, 255, 255),
			nil,
			Enum.Material.Neon
		)
		add(
			Vector3.new(0.15, 0.15, 0.05),
			CFrame.new(0.15, 1.7, -0.31),
			Color3.fromRGB(80, 255, 255),
			nil,
			Enum.Material.Neon
		)
		add(Vector3.new(0.08, 0.35, 0.08), CFrame.new(0, 2.1, 0), Color3.fromRGB(60, 60, 70))
		add(
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(0, 2.3, 0),
			Color3.fromRGB(255, 60, 60),
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
		add(Vector3.new(0.3, 0.45, 0.3), CFrame.new(-0.25, 0.22, 0), Color3.fromRGB(90, 110, 140))
		add(Vector3.new(0.3, 0.45, 0.3), CFrame.new(0.25, 0.22, 0), Color3.fromRGB(90, 110, 140))
	end,
	Console = function(_model, add)
		add(Vector3.new(1.6, 0.4, 1.0), CFrame.new(0, 0.3, 0), Color3.fromRGB(60, 50, 90))
		add(Vector3.new(0.5, 0.42, 0.5), CFrame.new(-0.45, 0.32, 0), Color3.fromRGB(130, 90, 210))
		add(
			Vector3.new(0.2, 0.1, 0.2),
			CFrame.new(0.4, 0.55, -0.15),
			Color3.fromRGB(255, 80, 80),
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
		add(
			Vector3.new(0.2, 0.1, 0.2),
			CFrame.new(0.6, 0.55, 0.05),
			Color3.fromRGB(80, 200, 255),
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
		add(
			Vector3.new(0.6, 0.05, 0.4),
			CFrame.new(-0.45, 0.55, 0),
			Color3.fromRGB(150, 255, 180),
			nil,
			Enum.Material.Neon
		)
	end,
	Rocket = function(_model, add)
		add(
			Vector3.new(1.6, 0.7, 0.7),
			CFrame.new(0, 1.0, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(240, 240, 245),
			Enum.PartType.Cylinder
		)
		add(
			Vector3.new(0.55, 0.55, 0.55),
			CFrame.new(0, 1.85, 0),
			Color3.fromRGB(230, 50, 60),
			Enum.PartType.Ball
		)
		add(
			Vector3.new(0.25, 0.25, 0.05),
			CFrame.new(0, 1.2, -0.36),
			Color3.fromRGB(120, 220, 255),
			nil,
			Enum.Material.Neon
		)
		for i = 0, 2 do
			local a = math.rad(i * 120)
			add(
				Vector3.new(0.1, 0.5, 0.4),
				CFrame.Angles(0, a, 0) * CFrame.new(0, 0.35, 0.4),
				Color3.fromRGB(70, 200, 160)
			)
		end
		add(
			Vector3.new(0.3, 0.3, 0.3),
			CFrame.new(0, 0.15, 0),
			Color3.fromRGB(255, 160, 40),
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
	end,
	Globe = function(_model, add)
		add(
			Vector3.new(0.35, 1.2, 1.2),
			CFrame.new(0, 0.18, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(120, 70, 40),
			Enum.PartType.Cylinder
		)
		local glass = add(
			Vector3.new(1.3, 1.3, 1.3),
			CFrame.new(0, 0.95, 0),
			Color3.fromRGB(190, 240, 255),
			Enum.PartType.Ball,
			Enum.Material.Glass
		)
		glass.Transparency = 0.5
		add(
			Vector3.new(0.35, 0.35, 0.35),
			CFrame.new(0, 0.7, 0),
			Color3.new(1, 1, 1),
			Enum.PartType.Ball
		)
		add(
			Vector3.new(0.25, 0.25, 0.25),
			CFrame.new(0, 0.98, 0),
			Color3.new(1, 1, 1),
			Enum.PartType.Ball
		)
		add(Vector3.new(0.12, 0.45, 0.12), CFrame.new(0.3, 0.75, 0.15), Color3.fromRGB(40, 140, 70))
	end,
}

local function newModel(
	name: string
): (Model, (Vector3, CFrame, Color3, Enum.PartType?, Enum.Material?) -> Part)
	local model = Instance.new("Model")
	model.Name = name
	local root = Build.deco({
		Name = "Root",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(),
		Transparency = 1,
		Parent = model,
	})
	model.PrimaryPart = root
	local function add(
		size: Vector3,
		cf: CFrame,
		color: Color3,
		shape: Enum.PartType?,
		material: Enum.Material?
	): Part
		local p = Build.deco({
			Size = size,
			CFrame = cf,
			Color = color,
			Shape = shape,
			Material = material,
			CastShadow = false,
			Parent = model,
		})
		return p
	end
	return model, add
end

function ToyModels.build(toy: string): Model
	local model, add = newModel(toy)
	local maker = makers[toy] or makers.Teddy
	maker(model, add)
	return model
end

local WRAP_COLORS = {
	{ Color3.fromRGB(220, 40, 50), Color3.fromRGB(255, 215, 80) },
	{ Color3.fromRGB(40, 150, 80), Color3.fromRGB(230, 40, 50) },
	{ Color3.fromRGB(60, 110, 220), Color3.new(1, 1, 1) },
	{ Color3.fromRGB(240, 240, 245), Color3.fromRGB(220, 40, 50) },
	{ Color3.fromRGB(150, 70, 200), Color3.fromRGB(120, 255, 200) },
}

function ToyModels.present(size: number, variant: number?): Model
	local model, add = newModel("Present")
	local pair = WRAP_COLORS[((variant or math.random(1, #WRAP_COLORS)) - 1) % #WRAP_COLORS + 1]
	local s = size
	add(Vector3.new(s, s, s), CFrame.new(0, s / 2, 0), pair[1])
	add(Vector3.new(s * 1.02, s * 1.02, s * 0.2), CFrame.new(0, s / 2, 0), pair[2])
	add(Vector3.new(s * 0.2, s * 1.02, s * 1.02), CFrame.new(0, s / 2, 0), pair[2])
	add(
		Vector3.new(s * 0.35, s * 0.25, s * 0.35),
		CFrame.new(-s * 0.18, s * 1.08, 0) * CFrame.Angles(0, 0, math.rad(30)),
		pair[2],
		Enum.PartType.Ball
	)
	add(
		Vector3.new(s * 0.35, s * 0.25, s * 0.35),
		CFrame.new(s * 0.18, s * 1.08, 0) * CFrame.Angles(0, 0, math.rad(-30)),
		pair[2],
		Enum.PartType.Ball
	)
	return model
end

return ToyModels
