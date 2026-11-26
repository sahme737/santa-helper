--!strict
-- Builds a cute blocky reindeer from parts. Used for pets (server), egg
-- reveals and inventory previews (client), and the sleigh team.
-- The model faces -Z (its LookVector) and its pivot sits at the hooves.

local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Parent.Util.Build)

local ReindeerModel = {}

local GOLD = Color3.fromRGB(255, 200, 50)

function ReindeerModel.build(petId: string, golden: boolean, scale: number?): Model
	local def = Config.PETS[petId] or Config.PETS.Cocoa
	local s = scale or 1
	local body = if golden then GOLD else def.body
	local accent = if golden then Color3.fromRGB(255, 240, 170) else def.accent
	local material = if golden then Enum.Material.Foil else Enum.Material.SmoothPlastic

	local model = Instance.new("Model")
	model.Name = def.name

	local root = Build.deco({
		Name = "Root",
		Size = Vector3.new(1, 1, 1) * s,
		CFrame = CFrame.new(0, 0.5 * s, 0),
		Transparency = 1,
		Parent = model,
	})
	model.PrimaryPart = root

	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	local function box(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		mat: Enum.Material?
	): Part
		return Build.deco({
			Name = name,
			Size = size * s,
			CFrame = cf,
			Color = color,
			Material = mat or material,
			Parent = model,
		})
	end

	-- Torso + belly
	box("Body", Vector3.new(1.6, 1.3, 2.6), at(0, 1.9, 0), body)
	box("Belly", Vector3.new(1.3, 0.4, 2.0), at(0, 1.25, 0), accent)
	-- Legs
	for _, x in { -0.55, 0.55 } do
		for _, z in { -0.9, 0.9 } do
			box("Leg", Vector3.new(0.4, 1.2, 0.4), at(x, 0.7, z), body)
			box(
				"Hoof",
				Vector3.new(0.45, 0.25, 0.45),
				at(x, 0.12, z),
				Color3.fromRGB(50, 35, 30),
				Enum.Material.SmoothPlastic
			)
		end
	end
	-- Neck and head
	box(
		"Neck",
		Vector3.new(0.7, 1.0, 0.7),
		at(0, 2.7, -1.0) * CFrame.Angles(math.rad(-20), 0, 0),
		body
	)
	box("Head", Vector3.new(1.1, 1.0, 1.3), at(0, 3.3, -1.4), body)
	box("Snout", Vector3.new(0.8, 0.6, 0.6), at(0, 3.1, -2.1), accent)
	local nose = Build.ball(model, at(0, 3.2, -2.45), 0.45 * s, def.nose, Enum.Material.Neon)
	nose.Name = "Nose"
	-- Eyes
	for _, x in { -0.32, 0.32 } do
		Build.ball(
			model,
			at(x, 3.5, -2.02),
			0.24 * s,
			Color3.fromRGB(20, 20, 25),
			Enum.Material.SmoothPlastic
		)
		Build.ball(
			model,
			at(x + 0.05, 3.55, -2.1),
			0.08 * s,
			Color3.new(1, 1, 1),
			Enum.Material.Neon
		)
	end
	-- Ears
	for _, x in { -0.7, 0.7 } do
		box(
			"Ear",
			Vector3.new(0.5, 0.2, 0.3),
			at(x, 3.6, -1.2) * CFrame.Angles(0, 0, math.rad(x > 0 and -25 or 25)),
			body
		)
	end
	-- Antlers
	local antlerColor = if golden
		then Color3.fromRGB(255, 250, 220)
		else Color3.fromRGB(205, 170, 120)
	for _, side in { -1, 1 } do
		box(
			"Antler",
			Vector3.new(0.2, 1.1, 0.2),
			at(0.35 * side, 4.25, -1.25) * CFrame.Angles(0, 0, math.rad(-20 * side)),
			antlerColor,
			Enum.Material.SmoothPlastic
		)
		box(
			"Antler",
			Vector3.new(0.6, 0.18, 0.18),
			at(0.65 * side, 4.55, -1.25),
			antlerColor,
			Enum.Material.SmoothPlastic
		)
		box(
			"Antler",
			Vector3.new(0.18, 0.5, 0.18),
			at(0.85 * side, 4.8, -1.25),
			antlerColor,
			Enum.Material.SmoothPlastic
		)
		box(
			"Antler",
			Vector3.new(0.18, 0.45, 0.18),
			at(0.45 * side, 4.85, -1.25),
			antlerColor,
			Enum.Material.SmoothPlastic
		)
	end
	-- Tail
	box("Tail", Vector3.new(0.4, 0.4, 0.4), at(0, 2.3, 1.4), accent)
	-- Little collar with a bell
	box(
		"Collar",
		Vector3.new(0.8, 0.2, 0.8),
		at(0, 2.45, -1.05),
		Color3.fromRGB(200, 30, 40),
		Enum.Material.SmoothPlastic
	)
	Build.ball(model, at(0, 2.25, -1.5), 0.3 * s, Color3.fromRGB(255, 210, 60), Enum.Material.Metal)

	if def.sparkle or golden then
		local emitterPart = Build.deco({
			Name = "Sparkles",
			Size = Vector3.new(1, 1, 1),
			CFrame = at(0, 2.2, 0),
			Transparency = 1,
			Parent = model,
		})
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(if golden then GOLD else def.accent)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.35 * s, 0)
		sparkle.Lifetime = NumberRange.new(0.6, 1.0)
		sparkle.Rate = 6
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = emitterPart
	end

	return model
end

return ReindeerModel
