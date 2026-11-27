--!strict
-- Purely visual workshop life, computed on each client: toys riding the
-- belts, wrapping into presents, elves hammering, gears spinning, eggs
-- bobbing, sacks swelling. Only plots near the camera are animated.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local PlotLayout = require(Shared.PlotLayout)
local ToyModels = require(Shared.Models.ToyModels)

local Lib = script.Parent.Parent:WaitForChild("Lib")
local Bus = require(Lib.Bus)

local WorkshopFX = {}

local ANIMATE_DISTANCE = 230
local MAX_TOYS_PER_PLOT = 40

type PlotState = { timers: { number }, toys: number, toss: number, pile: number }
local plotStates: { [Model]: PlotState } = {}
local spinBase: { [BasePart]: CFrame } = {}
local bobBase: { [BasePart]: CFrame } = {}
local elfBase: { [Model]: CFrame } = {}
local twinkles: { [BasePart]: number } = {}
local toyFolder: Folder

local BULB_COLORS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(90, 230, 110),
	Color3.fromRGB(255, 215, 80),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(255, 130, 220),
}

local function anchoredModel(model: Model): BasePart
	local root = model.PrimaryPart :: BasePart
	Build.weldModel(model, root)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			d.Massless = true
		end
	end
	root.Anchored = true
	return root
end

-- Throws a wrapped present in an arc from `from` into `to` (world space).
local function tossPresent(from: Vector3, to: Vector3, size: number, variant: number?)
	local present = ToyModels.present(size, variant)
	local root = anchoredModel(present)
	present:PivotTo(CFrame.new(from))
	present.Parent = toyFolder
	local duration = 0.75
	local height = 7
	local spin = math.random() * 4 - 2
	local t = 0
	while t < duration and root.Parent do
		t += RunService.Heartbeat:Wait()
		local a = math.min(1, t / duration)
		local pos = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * height, 0)
		root.CFrame = CFrame.new(pos) * CFrame.Angles(a * spin * 3, a * 5, 0)
	end
	present:Destroy()
end

local function sackTop(plotCF: CFrame): Vector3
	return (plotCF * CFrame.new(PlotLayout.SACK_X, 6.5, PlotLayout.BELT_Z)).Position
end

local function tableTop(plotCF: CFrame): Vector3
	return (plotCF * PlotLayout.WRAP_TABLE * CFrame.new(0, 4.3, 0)).Position
end

-- `auto` = elves are wrapping, so the toy becomes a present and rides on to
-- the sack. Otherwise it waits on the wrapping table for the player.
local function rideBelt(plot: Model, plotCF: CFrame, slot: number, toy: string, auto: boolean)
	local state = plotStates[plot]
	state.toys += 1
	local out = PlotLayout.MACHINE_OUTPUT[slot]
	local model = ToyModels.build(toy)
	local root = anchoredModel(model)
	local startLocal = CFrame.new(out.X, PlotLayout.BELT_Y + 0.1, out.Z)
	local beltLocal = CFrame.new(out.X, PlotLayout.BELT_Y + 0.1, PlotLayout.BELT_Z)
	local wrapLocal = CFrame.new(PlotLayout.WRAP_X, PlotLayout.BELT_Y + 0.1, PlotLayout.BELT_Z)
	model:PivotTo(plotCF * startLocal * CFrame.Angles(0, math.rad(90), 0))
	model.Parent = toyFolder

	local hop = TweenService:Create(
		root,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad),
		{ CFrame = plotCF * beltLocal * CFrame.Angles(0, math.rad(90), 0) }
	)
	hop:Play()
	hop.Completed:Wait()
	local distance = PlotLayout.WRAP_X - out.X
	local ride = TweenService:Create(
		root,
		TweenInfo.new(distance / PlotLayout.BELT_SPEED, Enum.EasingStyle.Linear),
		{ CFrame = plotCF * wrapLocal * CFrame.Angles(0, math.rad(90), 0) }
	)
	ride:Play()
	ride.Completed:Wait()

	if not auto then
		-- Hop off the belt onto the wrapping table and wait to be wrapped.
		state.pile = (state.pile % 5) + 1
		local spot = PlotLayout.WRAP_TABLE * CFrame.new(-3.2 + state.pile * 1.1, 3.9, -0.9)
		local toTable = TweenService:Create(
			root,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = plotCF * spot * CFrame.Angles(0, state.pile, 0) }
		)
		toTable:Play()
		toTable.Completed:Wait()
		task.wait(5)
		model:Destroy()
		state.toys -= 1
		return
	end
	model:Destroy()

	-- Wrapped!
	local present = ToyModels.present(1.6)
	local proot = anchoredModel(present)
	present:PivotTo(plotCF * wrapLocal)
	present.Parent = toyFolder
	local sackLocal = CFrame.new(PlotLayout.SACK_X - 4, PlotLayout.BELT_Y + 0.1, PlotLayout.BELT_Z)
	local toSack = TweenService:Create(
		proot,
		TweenInfo.new(
			(PlotLayout.SACK_X - 4 - PlotLayout.WRAP_X) / PlotLayout.BELT_SPEED,
			Enum.EasingStyle.Linear
		),
		{ CFrame = plotCF * sackLocal }
	)
	toSack:Play()
	toSack.Completed:Wait()
	local jump = TweenService:Create(
		proot,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = plotCF * CFrame.new(PlotLayout.SACK_X, 7, PlotLayout.BELT_Z) }
	)
	jump:Play()
	jump.Completed:Wait()
	present:Destroy()
	state.toys -= 1
end

local function animatePlots(dt: number, cameraPos: Vector3)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		if not plot:IsA("Model") then
			continue
		end
		local state = plotStates[plot]
		if not state then
			state = { timers = {}, toys = 0, toss = 1, pile = 0 }
			plotStates[plot] = state
		end
		local ownerId = plot:GetAttribute("OwnerId")
		local index = plot:GetAttribute("Index")
		if not ownerId or ownerId == 0 or typeof(index) ~= "number" then
			continue
		end
		local plotCF = PlotLayout.plotCFrame(index, Config.MAX_PLOTS)
		if (plotCF.Position - cameraPos).Magnitude > ANIMATE_DISTANCE then
			continue
		end
		local full = plot:GetAttribute("SackFull") == true
		local elves = plot:GetAttribute("Elves") or 0
		local auto = elves >= 1
		for slot, machine in Config.MACHINES do
			local level = plot:GetAttribute(machine.id)
			if typeof(level) == "number" and level > 0 and not full then
				local t = (state.timers[slot] or math.random() * machine.interval) - dt
				if t <= 0 then
					t = math.max(0.7, machine.interval / (1 + elves * 0.1))
					if state.toys < MAX_TOYS_PER_PLOT then
						task.spawn(rideBelt, plot, plotCF, slot, machine.toy, auto)
					end
				end
				state.timers[slot] = t
			end
		end

		-- Sack swells as it fills.
		local sack = plot:FindFirstChild("Sack")
		if sack and sack:IsA("BasePart") then
			local fill = plot:GetAttribute("SackFill") or 0
			local size = 6 + fill * 6
			sack.Size = sack.Size:Lerp(Vector3.new(size, size, size), math.min(1, dt * 4))
		end

		-- Elves at the wrapping table wrap and toss presents into the sack;
		-- the rest hammer away at their machines.
		local content = plot:FindFirstChild("Content")
		local elvesFolder = content and content:FindFirstChild("Elves")
		if elvesFolder then
			local now = os.clock()
			local wrappers = 0
			for _, elf in elvesFolder:GetChildren() do
				if not elf:IsA("Model") then
					continue
				end
				local base = elfBase[elf]
				if not base then
					base = elf:GetPivot()
					elfBase[elf] = base
					elf.Destroying:Once(function()
						elfBase[elf] = nil
					end)
				end
				local i = tonumber(string.match(elf.Name, "%d+")) or 1
				if i <= PlotLayout.WRAP_ELVES then
					wrappers += 1
					-- Busy hands: quick lean over the table with a little hop.
					local beat = now * 7 + i * 1.7
					local lean = (math.sin(beat) * 0.5 + 0.5) * 22
					local hopY = math.abs(math.sin(beat * 0.5)) * 0.5
					elf:PivotTo(
						(base :: CFrame)
							* CFrame.new(0, hopY, 0)
							* CFrame.Angles(math.rad(-lean), math.sin(beat * 0.5) * 0.2, 0)
					)
				else
					local bob = math.abs(math.sin(now * 6 + i)) * 0.9
					elf:PivotTo(
						(base :: CFrame)
							* CFrame.new(0, bob, 0)
							* CFrame.Angles(math.rad(-bob * 22), 0, 0)
					)
				end
			end
			if wrappers > 0 and not full then
				state.toss -= dt
				if state.toss <= 0 then
					state.toss = 1.3 / wrappers
					task.spawn(
						tossPresent,
						tableTop(plotCF),
						sackTop(plotCF),
						1.5,
						math.random(1, 6)
					)
				end
			end
		end
	end
end

local function track(tag: string, store: { [BasePart]: CFrame })
	local function add(inst: Instance)
		if inst:IsA("BasePart") then
			store[inst] = inst.CFrame
		end
	end
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
		store[inst :: BasePart] = nil
	end)
end

function WorkshopFX.start()
	toyFolder = Instance.new("Folder")
	toyFolder.Name = "LocalToys"
	toyFolder.Parent = workspace
	track("Spin", spinBase)
	track("Bob", bobBase)
	local function addTwinkle(inst: Instance)
		if inst:IsA("BasePart") then
			twinkles[inst] = tonumber(inst:GetAttribute("Phase")) or 0
		end
	end
	for _, inst in CollectionService:GetTagged("Twinkle") do
		addTwinkle(inst)
	end
	CollectionService:GetInstanceAddedSignal("Twinkle"):Connect(addTwinkle)
	CollectionService:GetInstanceRemovedSignal("Twinkle"):Connect(function(inst)
		twinkles[inst :: BasePart] = nil
	end)

	-- The player wrapped a present by hand: it flies from the table to the sack.
	Bus.on("Wrapped", function()
		local index = Players.LocalPlayer:GetAttribute("Plot")
		if typeof(index) ~= "number" then
			return
		end
		local plotCF = PlotLayout.plotCFrame(index, Config.MAX_PLOTS)
		tossPresent(tableTop(plotCF), sackTop(plotCF), 1.8, math.random(1, 6))
	end)

	local twinkleStep = -1

	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local cameraPos = if camera then camera.CFrame.Position else Vector3.zero
		animatePlots(dt, cameraPos)
		local t = os.clock()
		-- Fairy lights change colour twice a second, each bulb out of step.
		local beat = math.floor(t * 2)
		if beat ~= twinkleStep then
			twinkleStep = beat
			for part, phase in twinkles do
				if part.Parent and (part.Position - cameraPos).Magnitude < 260 then
					part.Color = BULB_COLORS[(beat + phase) % #BULB_COLORS + 1]
				end
			end
		end
		for part, base in spinBase do
			if part.Parent and (part.Position - cameraPos).Magnitude < 300 then
				part.CFrame = if part:GetAttribute("SpinY")
					then base * CFrame.Angles(0, t * 0.8, 0)
					else base * CFrame.Angles(t * 1.5, 0, 0)
			end
		end
		for part, base in bobBase do
			if part.Parent then
				part.CFrame = base
					* CFrame.new(0, math.sin(t * 2) * 0.6, 0)
					* CFrame.Angles(0, t * 0.8, 0)
			end
		end
	end)
end

return WorkshopFX
