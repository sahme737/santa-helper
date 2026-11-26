--!strict
-- Hats, ugly sweaters and trails built from parts and welded to a character.
-- Works with R15 and R6 rigs. Purely visual: no stats.

local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Parent.Util.Build)

local CosmeticModels = {}

local COSMETIC_BY_ID: { [string]: Config.CosmeticDef } = {}
for _, c in Config.COSMETICS do
	COSMETIC_BY_ID[c.id] = c
end
CosmeticModels.BY_ID = COSMETIC_BY_ID

local function clear(character: Model, slot: string)
	local existing = character:FindFirstChild("Cosmetic_" .. slot)
	if existing then
		existing:Destroy()
	end
end

local function finalize(model: Model, anchor: BasePart, character: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = anchor
			w.Part1 = d
			w.Parent = d
		end
	end
	model.Parent = character
end

type HatBuilder = (model: Model, top: CFrame, size: number, def: Config.CosmeticDef) -> ()

local hatBuilders: { [string]: HatBuilder } = {
	SantaHat = function(model, top, size, def)
		local fur = def.colorB
		-- Thick fur brim with fluffy tufts all the way round
		Build.cylinder(
			model,
			top * CFrame.new(0, 0.02 * size, 0) * CFrame.Angles(0, 0, math.rad(90)),
			0.34 * size,
			1.42 * size,
			fur,
			Enum.Material.Fabric
		)
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			Build.ball(
				model,
				top * CFrame.new(math.cos(a) * 0.66 * size, 0.02 * size, math.sin(a) * 0.66 * size),
				(0.36 + (k % 3) * 0.04) * size,
				fur,
				Enum.Material.Fabric
			)
		end
		-- Soft red cap that tapers, curls over and flops down one side
		local bends = { 0, 6, 12, 20, 28, 34, 34 }
		local segment = 0.25 * size
		local cf = top * CFrame.new(0, 0.12 * size, 0) * CFrame.Angles(math.rad(-6), 0, 0)
		for i, bend in bends do
			local t0 = (i - 1) / #bends
			local radius = (0.58 - 0.44 * t0) * size
			cf *= CFrame.Angles(0, 0, math.rad(-bend))
			Build.cylinder(
				model,
				cf * CFrame.new(0, segment / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
				segment * 1.08,
				radius * 2,
				def.colorA,
				Enum.Material.Fabric
			)
			-- A ball at every joint hides the seams where the cap bends.
			Build.ball(model, cf, radius * 2, def.colorA, Enum.Material.Fabric)
			cf *= CFrame.new(0, segment, 0)
		end
		-- Big fluffy pom-pom on the tip
		Build.ball(model, cf * CFrame.new(0, 0.1 * size, 0), 0.5 * size, fur, Enum.Material.Fabric)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			Build.ball(
				model,
				cf * CFrame.new(math.cos(a) * 0.16 * size, 0.1 * size, math.sin(a) * 0.16 * size),
				0.3 * size,
				fur,
				Enum.Material.Fabric
			)
		end
	end,
	ElfHat = function(model, top, size, def)
		Build.cylinder(
			model,
			top * CFrame.new(0, 0.05 * size, 0) * CFrame.Angles(0, 0, math.rad(90)),
			0.25 * size,
			1.1 * size,
			def.colorB
		)
		Build.cone(
			model,
			top * CFrame.new(0, 0.15 * size, 0) * CFrame.Angles(math.rad(25), 0, 0),
			1.6 * size,
			0.5 * size,
			def.colorA,
			6
		)
		Build.ball(
			model,
			top * CFrame.Angles(math.rad(25), 0, 0) * CFrame.new(0, 1.75 * size, 0),
			0.3 * size,
			Color3.fromRGB(255, 210, 60),
			Enum.Material.Metal
		)
	end,
	Antlers = function(model, top, size, def)
		for _, side in { -1, 1 } do
			local base = top * CFrame.new(0.35 * side * size, 0, 0)
			Build.deco({
				Size = Vector3.new(0.18, 0.9, 0.18) * size,
				CFrame = base
					* CFrame.new(0, 0.4 * size, 0)
					* CFrame.Angles(0, 0, math.rad(-20 * side)),
				Color = def.colorA,
				Parent = model,
			})
			Build.deco({
				Size = Vector3.new(0.55, 0.16, 0.16) * size,
				CFrame = base * CFrame.new(0.3 * side * size, 0.7 * size, 0),
				Color = def.colorA,
				Parent = model,
			})
			Build.deco({
				Size = Vector3.new(0.16, 0.45, 0.16) * size,
				CFrame = base * CFrame.new(0.5 * side * size, 0.95 * size, 0),
				Color = def.colorA,
				Parent = model,
			})
		end
		Build.ball(
			model,
			top * CFrame.new(0, -0.55 * size, -0.62 * size),
			0.3 * size,
			def.colorB,
			Enum.Material.Neon
		)
	end,
	TopHat = function(model, top, size, def)
		Build.cylinder(
			model,
			top * CFrame.new(0, 0.05 * size, 0) * CFrame.Angles(0, 0, math.rad(90)),
			0.1 * size,
			1.5 * size,
			def.colorA
		)
		Build.cylinder(
			model,
			top * CFrame.new(0, 0.55 * size, 0) * CFrame.Angles(0, 0, math.rad(90)),
			1.0 * size,
			0.95 * size,
			def.colorA
		)
		Build.cylinder(
			model,
			top * CFrame.new(0, 0.25 * size, 0) * CFrame.Angles(0, 0, math.rad(90)),
			0.2 * size,
			0.98 * size,
			def.colorB
		)
		Build.ball(
			model,
			top * CFrame.new(0.4 * size, 0.3 * size, -0.25 * size),
			0.25 * size,
			Color3.fromRGB(40, 140, 60)
		)
	end,
	StarHalo = function(model, top, size, def)
		for i = 0, 9 do
			local a = math.rad(i * 36)
			Build.ball(
				model,
				top * CFrame.new(math.cos(a) * 0.6 * size, 0.6 * size, math.sin(a) * 0.6 * size),
				0.18 * size,
				def.colorA,
				Enum.Material.Neon
			)
		end
		local star = Build.deco({
			Size = Vector3.new(0.5, 0.5, 0.1) * size,
			CFrame = top * CFrame.new(0, 1.0 * size, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Color = def.colorB,
			Material = Enum.Material.Neon,
			Parent = model,
		})
		star.Name = "Star"
		Build.light(star, def.colorA, 8, 1)
	end,
	GingerCrown = function(model, top, size, def)
		for i = 0, 7 do
			local a = math.rad(i * 45)
			local cf = top * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.25 * size, -0.5 * size)
			Build.deco({
				Size = Vector3.new(0.42, 0.5, 0.12) * size,
				CFrame = cf,
				Color = def.colorA,
				Parent = model,
			})
			Build.ball(model, cf * CFrame.new(0, 0.32 * size, 0), 0.18 * size, def.colorB)
		end
	end,
	HollyHat = function(model, top, size, def)
		Build.deco({
			Size = Vector3.new(1.25, 0.18, 1.25) * size,
			CFrame = top * CFrame.new(0, -0.1 * size, 0),
			Color = def.colorA,
			Parent = model,
		})
		for i = -1, 1 do
			Build.deco({
				Size = Vector3.new(0.45, 0.08, 0.25) * size,
				CFrame = top
					* CFrame.new(i * 0.25 * size, 0.05 * size, -0.45 * size)
					* CFrame.Angles(0, math.rad(i * 30), math.rad(i * 15)),
				Color = def.colorA,
				Parent = model,
			})
		end
		for i = -1, 1 do
			Build.ball(
				model,
				top * CFrame.new(i * 0.12 * size, 0.12 * size, -0.55 * size),
				0.17 * size,
				def.colorB
			)
		end
	end,
	GoldenCrown = function(model, top, size, def)
		Build.cylinder(
			model,
			top * CFrame.new(0, 0.15 * size, 0) * CFrame.Angles(0, 0, math.rad(90)),
			0.35 * size,
			1.15 * size,
			def.colorA,
			Enum.Material.Foil
		)
		for i = 0, 5 do
			local a = math.rad(i * 60)
			local cf = top * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.5 * size, -0.48 * size)
			Build.deco({
				Size = Vector3.new(0.2, 0.45, 0.2) * size,
				CFrame = cf * CFrame.Angles(0, 0, math.rad(45)),
				Color = def.colorA,
				Material = Enum.Material.Foil,
				Parent = model,
			})
			Build.ball(
				model,
				cf * CFrame.new(0, -0.3 * size, -0.05 * size),
				0.15 * size,
				def.colorB,
				Enum.Material.Neon
			)
		end
	end,
}

function CosmeticModels.applyHat(character: Model, hatId: string?)
	clear(character, "hat")
	if not hatId then
		return
	end
	local def = COSMETIC_BY_ID[hatId]
	local head = character:FindFirstChild("Head")
	if not def or not head or not head:IsA("BasePart") then
		return
	end
	local builder = hatBuilders[hatId]
	if not builder then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Cosmetic_hat"
	local size = head.Size.Y / 1.2
	local top = head.CFrame * CFrame.new(0, head.Size.Y * 0.42, 0)
	builder(model, top, size, def)
	finalize(model, head, character)
end

-- Sleeves weld to their own arm so they follow arm animation.
local function sleeve(model: Model, part: BasePart, color: Color3, scale: Vector3)
	local p = Build.deco({
		Name = "Sleeve",
		Size = part.Size * scale,
		CFrame = part.CFrame,
		Color = color,
		Material = Enum.Material.Fabric,
	})
	p.Anchored = false
	p.Massless = true
	p.CanTouch = false
	p.CastShadow = false
	local w = Instance.new("WeldConstraint")
	w.Part0 = part
	w.Part1 = p
	w.Parent = p
	p.Parent = model
end

function CosmeticModels.applySweater(character: Model, sweaterId: string?)
	clear(character, "sweater")
	if not sweaterId then
		return
	end
	local def = COSMETIC_BY_ID[sweaterId]
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not def or not torso or not torso:IsA("BasePart") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Cosmetic_sweater"

	local body = Build.deco({
		Name = "Sweater",
		Size = torso.Size * Vector3.new(1.1, 1.04, 1.25),
		CFrame = torso.CFrame,
		Color = def.colorA,
		Material = Enum.Material.Fabric,
		Parent = model,
	})
	-- Knitted stripe across the chest
	Build.deco({
		Name = "Stripe",
		Size = Vector3.new(body.Size.X * 1.01, body.Size.Y * 0.14, body.Size.Z * 1.01),
		CFrame = torso.CFrame * CFrame.new(0, -body.Size.Y * 0.35, 0),
		Color = def.colorB,
		Material = Enum.Material.Fabric,
		Parent = model,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.LightInfluence = 0.3
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 60
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.75)
	label.Text = def.motif or "❄"
	label.TextScaled = true
	label.TextColor3 = def.colorB
	label.Parent = surface
	surface.Parent = body

	finalize(model, torso, character)
	for _, name in
		{
			"LeftUpperArm",
			"RightUpperArm",
			"LeftLowerArm",
			"RightLowerArm",
			"Left Arm",
			"Right Arm",
		}
	do
		local arm = character:FindFirstChild(name)
		if arm and arm:IsA("BasePart") then
			sleeve(model, arm, def.colorA, Vector3.new(1.12, 1.02, 1.12))
		end
	end
end

function CosmeticModels.applyTrail(character: Model, trailId: string?)
	clear(character, "trail")
	if not trailId then
		return
	end
	local def = COSMETIC_BY_ID[trailId]
	local root = character:FindFirstChild("HumanoidRootPart")
	if not def or not root or not root:IsA("BasePart") then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "Cosmetic_trail"
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(0, 0.8, 0.4)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(0, -0.9, 0.4)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.6
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.15, 1)
	if trailId == "AuroraTrail" then
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 255, 190)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(80, 160, 255)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(190, 110, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 200)),
		})
	else
		trail.Color = ColorSequence.new(def.colorA, def.colorB)
	end
	trail.Parent = folder
	-- Attachments live on the root; destroy them with the trail container.
	folder.Destroying:Connect(function()
		a0:Destroy()
		a1:Destroy()
	end)
	folder.Parent = character
end

return CosmeticModels
