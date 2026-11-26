--!strict
-- Tiny helpers for building parts and models from code (the whole world is
-- procedural, so this is used everywhere).

local Build = {}

export type PartProps = {
	Name: string?,
	Size: Vector3?,
	CFrame: CFrame?,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	Reflectance: number?,
	Anchored: boolean?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	CanTouch: boolean?,
	CastShadow: boolean?,
	Massless: boolean?,
	Parent: Instance?,
}

function Build.part(props: PartProps): Part
	local p = Instance.new("Part")
	p.Name = props.Name or "Part"
	p.Size = props.Size or Vector3.new(4, 1, 4)
	p.CFrame = props.CFrame or CFrame.new()
	p.Color = props.Color or Color3.new(1, 1, 1)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Transparency = props.Transparency or 0
	p.Reflectance = props.Reflectance or 0
	p.Anchored = if props.Anchored == nil then true else props.Anchored
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.CanQuery = if props.CanQuery == nil then true else props.CanQuery
	p.CanTouch = if props.CanTouch == nil then false else props.CanTouch
	p.CastShadow = if props.CastShadow == nil then true else props.CastShadow
	p.Massless = props.Massless or false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Parent then
		p.Parent = props.Parent
	end
	return p
end

-- Decorative part: no collision, no touch, no raycast hits.
function Build.deco(props: PartProps): Part
	local copy = table.clone(props)
	if copy.CanCollide == nil then
		copy.CanCollide = false
	end
	if copy.CanQuery == nil then
		copy.CanQuery = false
	end
	return Build.part(copy)
end

function Build.ball(
	parent: Instance,
	cf: CFrame,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	return Build.deco({
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

function Build.cylinder(
	parent: Instance,
	cf: CFrame,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	-- Cylinders extend along their local X axis.
	return Build.deco({
		Name = "Cylinder",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- A cone made of stacked shrinking cylinders (Roblox has no cone primitive).
function Build.cone(
	parent: Instance,
	base: CFrame,
	height: number,
	radius: number,
	color: Color3,
	steps: number?,
	material: Enum.Material?
): Model
	local model = Instance.new("Model")
	model.Name = "Cone"
	local n = steps or 5
	local layer = height / n
	for i = 0, n - 1 do
		local r = radius * (1 - i / n)
		Build.cylinder(
			model,
			base * CFrame.new(0, layer * (i + 0.5), 0) * CFrame.Angles(0, 0, math.rad(90)),
			layer,
			r * 2,
			color,
			material
		)
	end
	model.Parent = parent
	return model
end

function Build.light(
	parent: Instance,
	color: Color3,
	range: number,
	brightness: number?
): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = parent
	return l
end

function Build.billboard(
	parent: Instance,
	text: string,
	size: UDim2,
	offset: Vector3,
	color: Color3?,
	maxDistance: number?
): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 120
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(40, 20, 20)
	label.Parent = gui
	gui.Parent = parent
	return gui, label
end

function Build.weldModel(model: Model, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
end

function Build.setProps(model: Instance, anchored: boolean, massless: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored
			d.Massless = massless
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

return Build
