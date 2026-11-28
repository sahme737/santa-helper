--!strict
-- A little blocky elf that can walk, carry a present and wave. Purely visual
-- and built on each client. The model faces -Z and its pivot is at the feet.
-- Everything is welded to an anchored Root, so moving the Root moves the elf;
-- arms and legs hang on "Rig" welds that ElfModel.step swings.

local Build = require(script.Parent.Parent.Util.Build)

local ElfModel = {}

export type Pose = "walk" | "carry" | "wave" | "idle" | "sit" | "cheer"

type Limb = { weld: Weld, rest: CFrame, pivot: CFrame, side: number, arm: boolean }
local rigs: { [Model]: { Limb } } = {}

local SKIN = Color3.fromRGB(255, 215, 180)
local RED = Color3.fromRGB(200, 40, 50)
local SUITS = {
	Color3.fromRGB(40, 150, 70),
	Color3.fromRGB(200, 40, 50),
	Color3.fromRGB(50, 120, 200),
	Color3.fromRGB(230, 160, 40),
}

-- Festive visitors: jumper colour, hat colour, skin tone.
local VISITORS = {
	{ Color3.fromRGB(190, 35, 45), Color3.fromRGB(200, 40, 50), Color3.fromRGB(255, 205, 150) },
	{ Color3.fromRGB(35, 120, 70), Color3.fromRGB(245, 245, 250), Color3.fromRGB(150, 100, 70) },
	{ Color3.fromRGB(60, 90, 190), Color3.fromRGB(200, 40, 50), Color3.fromRGB(245, 220, 190) },
	{ Color3.fromRGB(245, 240, 230), Color3.fromRGB(40, 150, 70), Color3.fromRGB(110, 75, 55) },
	{ Color3.fromRGB(150, 70, 190), Color3.fromRGB(255, 200, 60), Color3.fromRGB(230, 180, 140) },
}

-- `visitor` builds a festive person (Christmas jumper, bobble hat, scarf)
-- instead of an elf; they share the same rig and poses.
function ElfModel.build(variant: number?, scale: number?, visitor: boolean?): Model
	local s = scale or 1
	local index = (variant or 1) - 1
	local suit = SUITS[index % #SUITS + 1]
	local hat = if suit == RED then SUITS[1] else RED
	local skin = SKIN
	local legs = RED
	if visitor then
		local look = VISITORS[index % #VISITORS + 1]
		suit, hat, skin = look[1], look[2], look[3]
		legs = Color3.fromRGB(50, 70, 120)
	end
	local model = Instance.new("Model")
	model.Name = "Elf"
	local root = Build.deco({
		Name = "Root",
		Size = Vector3.new(1, 1, 1) * s,
		CFrame = CFrame.new(0, 0.5 * s, 0),
		Transparency = 1,
		Parent = model,
	})
	model.PrimaryPart = root
	model:SetAttribute("Scale", s)

	local function block(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		return Build.deco({
			Size = size * s,
			CFrame = CFrame.new(cf.Position * s) * cf.Rotation,
			Color = color,
			Material = material,
			CastShadow = false,
			Parent = model,
		})
	end
	local function limb(name: string, size: Vector3, at: Vector3, color: Color3, pivotY: number)
		local part = block(size, CFrame.new(at), color)
		part.Name = name
		part:SetAttribute("Pivot", Vector3.new(at.X, pivotY, at.Z) * s)
	end

	limb("LegL", Vector3.new(0.6, 1.2, 0.6), Vector3.new(-0.4, 0.6, 0), legs, 1.2)
	limb("LegR", Vector3.new(0.6, 1.2, 0.6), Vector3.new(0.4, 0.6, 0), legs, 1.2)
	limb("ArmL", Vector3.new(0.5, 1.4, 0.5), Vector3.new(-1.15, 2.2, 0), suit, 2.8)
	limb("ArmR", Vector3.new(0.5, 1.4, 0.5), Vector3.new(1.15, 2.2, 0), suit, 2.8)
	block(Vector3.new(1.8, 1.8, 1.1), CFrame.new(0, 2.1, 0), suit, Enum.Material.Fabric)
	if visitor then
		-- Jumper stripe, scarf and a bobble hat.
		block(Vector3.new(1.85, 0.35, 1.15), CFrame.new(0, 2.2, 0), Color3.new(1, 1, 1))
		block(Vector3.new(1.5, 0.35, 1.3), CFrame.new(0, 3.0, 0), hat)
		block(Vector3.new(0.4, 0.9, 0.2), CFrame.new(0.45, 2.55, -0.62), hat)
	else
		block(Vector3.new(1.9, 0.3, 1.2), CFrame.new(0, 1.5, 0), Color3.fromRGB(60, 40, 30))
		block(
			Vector3.new(0.4, 0.3, 0.1),
			CFrame.new(0, 1.5, -0.62),
			Color3.fromRGB(255, 210, 60),
			Enum.Material.Metal
		)
	end
	Build.ball(model, CFrame.new(0, 3.6 * s, 0), 1.6 * s, skin)
	for _, side in { -1, 1 } do
		if not visitor then
			block(
				Vector3.new(0.6, 0.3, 0.2),
				CFrame.new(0.85 * side, 3.75, 0) * CFrame.Angles(0, 0, math.rad(-25 * side)),
				skin
			)
		end
		Build.ball(
			model,
			CFrame.new(0.3 * side * s, 3.75 * s, -0.72 * s),
			0.25 * s,
			Color3.fromRGB(30, 30, 40)
		)
	end
	if visitor then
		block(Vector3.new(1.75, 0.45, 1.75), CFrame.new(0, 4.15, 0), Color3.new(1, 1, 1))
		block(Vector3.new(1.5, 0.7, 1.5), CFrame.new(0, 4.6, 0), hat)
		Build.ball(model, CFrame.new(0, 5.15 * s, 0), 0.6 * s, Color3.new(1, 1, 1))
	else
		Build.ball(model, CFrame.new(0, 3.4 * s, -0.8 * s), 0.3 * s, Color3.fromRGB(255, 140, 140))
		Build.cone(
			model,
			CFrame.new(0, 4.2 * s, 0) * CFrame.Angles(math.rad(-20), 0, 0),
			1.8 * s,
			0.8 * s,
			hat,
			4
		)
		Build.ball(
			model,
			CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, 6.1 * s, 0),
			0.4 * s,
			Color3.new(1, 1, 1)
		)
	end

	local limbs: { Limb } = {}
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") or d == root then
			continue
		end
		d.Anchored = false
		d.Massless = true
		d.CanCollide = false
		local pivot = d:GetAttribute("Pivot")
		if typeof(pivot) == "Vector3" then
			local weld = Instance.new("Weld")
			weld.Name = "Rig"
			weld.Part0 = root
			weld.Part1 = d
			weld.C0 = root.CFrame:ToObjectSpace(d.CFrame)
			weld.Parent = d
			table.insert(limbs, {
				weld = weld,
				rest = weld.C0,
				pivot = root.CFrame:ToObjectSpace(CFrame.new(pivot)),
				side = if string.sub(d.Name, -1) == "L" then -1 else 1,
				arm = string.sub(d.Name, 1, 3) == "Arm",
			})
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	rigs[model] = limbs
	model.Destroying:Once(function()
		rigs[model] = nil
	end)
	return model
end

-- Welds `thing` (a model with a PrimaryPart) to the elf at `offset` from the
-- feet, in units of an unscaled elf. Used for a present held in the arms.
function ElfModel.hold(elf: Model, thing: Model, offset: CFrame)
	local root = elf.PrimaryPart
	local held = thing.PrimaryPart
	if not root or not held then
		return
	end
	local s = tonumber(elf:GetAttribute("Scale")) or 1
	thing:PivotTo(
		root.CFrame * CFrame.new(0, -0.5 * s, 0) * CFrame.new(offset.Position * s) * offset.Rotation
	)
	for _, d in thing:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	thing.Parent = elf
end

-- Puts the elf's feet at `cf`.
function ElfModel.place(elf: Model, cf: CFrame)
	local root = elf.PrimaryPart
	if root then
		local s = tonumber(elf:GetAttribute("Scale")) or 1
		root.CFrame = cf * CFrame.new(0, 0.5 * s, 0)
	end
end

-- `t` is a clock in seconds; `stride` is how hard the legs swing (0 = still).
function ElfModel.step(elf: Model, t: number, stride: number, pose: Pose)
	local limbs = rigs[elf]
	if not limbs then
		return
	end
	local cycle = t * 9
	for _, l in limbs do
		local angle = 0
		local roll = 0
		if l.arm then
			if pose == "carry" then
				angle = math.rad(75) + math.sin(cycle * 2) * 0.05
			elseif pose == "cheer" then
				angle = math.rad(160) + math.sin(t * 8 + l.side) * 0.25
			elseif pose == "wave" and l.side > 0 then
				angle = math.rad(165)
				roll = math.sin(t * 11) * 0.45
			elseif pose == "walk" then
				angle = math.sin(cycle) * stride * 0.9 * l.side
			end
		elseif pose == "sit" or pose == "cheer" then
			angle = math.rad(82)
		else
			angle = math.sin(cycle) * stride * -l.side
		end
		l.weld.C0 = l.pivot * CFrame.Angles(angle, 0, roll) * l.pivot:Inverse() * l.rest
	end
end

return ElfModel
