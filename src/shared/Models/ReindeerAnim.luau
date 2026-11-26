--!strict
-- Leg animation for ReindeerModel builds. Purely visual and local: clients
-- call this every frame for the reindeer they can see.
-- * Anchored reindeer (pets): leg CFrames are set relative to the Root.
-- * Rigged reindeer (ReindeerModel.rig, e.g. the sleigh team): the "Rig"
--   welds' C0 are animated instead, plus the "Bob" weld that holds the Root.

local ReindeerAnim = {}

type Leg = { part: BasePart, rest: CFrame, hip: CFrame, phase: number, front: boolean, weld: Weld? }
type Rig = { root: BasePart, legs: { Leg }, bob: Weld?, bobBase: CFrame }

local rigs: { [Model]: Rig } = {}

local function rigFor(model: Model): Rig?
	local existing = rigs[model]
	if existing then
		return existing
	end
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local legs: { Leg } = {}
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			local hip = d:GetAttribute("Hip")
			if typeof(hip) == "Vector3" then
				local weld = d:FindFirstChild("Rig")
				table.insert(legs, {
					part = d,
					rest = if weld and weld:IsA("Weld")
						then weld.C0
						else root.CFrame:ToObjectSpace(d.CFrame),
					hip = CFrame.new(hip),
					phase = tonumber(d:GetAttribute("Phase")) or 0,
					front = d:GetAttribute("Front") == true,
					weld = if weld and weld:IsA("Weld") then weld else nil,
				})
			end
		end
	end
	local bob = root:FindFirstChild("Bob")
	local rig: Rig = {
		root = root,
		legs = legs,
		bob = if bob and bob:IsA("Weld") then bob else nil,
		bobBase = if bob and bob:IsA("Weld") then bob.C0 else CFrame.new(),
	}
	rigs[model] = rig
	model.Destroying:Once(function()
		rigs[model] = nil
	end)
	return rig
end

-- `t` is a clock in seconds, `rate` the stride frequency in Hz and `swing`
-- the leg swing in radians (0 = standing still). `gallop` makes front and
-- back pairs move together (a bounding run) instead of a diagonal trot.
function ReindeerAnim.step(model: Model, t: number, rate: number, swing: number, gallop: boolean?)
	local rig = rigFor(model)
	if not rig then
		return
	end
	local cycle = t * rate * math.pi * 2
	local rootCF = rig.root.CFrame
	for _, leg in rig.legs do
		local phase = if gallop then (if leg.front then 0 else math.pi * 0.55) else leg.phase
		local angle = math.sin(cycle + phase) * swing
		-- Lift the hoof a little on the forward swing so it reads as a stride.
		local lift = math.max(0, math.cos(cycle + phase)) * swing * 0.35
		local offset = leg.hip
			* CFrame.Angles(angle, 0, 0)
			* CFrame.new(0, lift, 0)
			* leg.hip:Inverse()
			* leg.rest
		if leg.weld then
			leg.weld.C0 = offset
		else
			leg.part.CFrame = rootCF * offset
		end
	end
	if rig.bob then
		local bounce = math.abs(math.sin(cycle)) * swing * 0.9
		rig.bob.C0 = rig.bobBase
			* CFrame.new(0, bounce, 0)
			* CFrame.Angles(math.sin(cycle + 0.6) * swing * 0.18, 0, 0)
	end
end

return ReindeerAnim
