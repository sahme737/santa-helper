--!strict
-- The toy workshop tycoon: plot assignment, building machines/decor/elves on
-- the plot, server-side toy production into the present sack, loading the
-- sleigh (cash out), and every workshop purchase/upgrade request.
-- Production is computed on the server; the client only draws toys riding
-- the belt using the plot's attributes.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Types = require(Shared.Types)
local Build = require(Shared.Util.Build)
local Format = require(Shared.Util.Format)
local PlotLayout = require(Shared.PlotLayout)

local Net = require(script.Parent.Parent.Lib.Net)
local Guard = require(script.Parent.Parent.Lib.Guard)
local PlayerData = require(script.Parent.PlayerData)
local PlayerState = require(script.Parent.PlayerState)
local WorldBuilder = require(script.Parent.WorldBuilder)

type Profile = Types.Profile

local Workshop = {}

local TICK = 0.5
local plotOwner: { [number]: Player } = {}
local playerPlot: { [Player]: number } = {}
local lastLoad: { [Player]: number } = {}
local lastPadTouch: { [Player]: { [string]: number } } = {}

local rushActive = false
Workshop.rushMultiplier = 1

--------------------------------------------------------------------------------
-- Models
--------------------------------------------------------------------------------

local function elfModel(cf: CFrame, index: number): Model
	local model = Instance.new("Model")
	model.Name = "Elf" .. index
	local root = Build.deco({
		Name = "Root",
		Size = Vector3.new(1, 1, 1),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Transparency = 1,
		Parent = model,
	})
	model.PrimaryPart = root
	local green = Color3.fromRGB(40, 150, 70)
	local skin = Color3.fromRGB(255, 215, 180)
	Build.deco({
		Size = Vector3.new(0.6, 1.2, 0.6),
		CFrame = cf * CFrame.new(-0.4, 0.6, 0),
		Color = Color3.fromRGB(200, 40, 50),
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(0.6, 1.2, 0.6),
		CFrame = cf * CFrame.new(0.4, 0.6, 0),
		Color = Color3.fromRGB(200, 40, 50),
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(1.8, 1.8, 1.1),
		CFrame = cf * CFrame.new(0, 2.1, 0),
		Color = green,
		Material = Enum.Material.Fabric,
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(1.9, 0.3, 1.2),
		CFrame = cf * CFrame.new(0, 1.5, 0),
		Color = Color3.fromRGB(60, 40, 30),
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(0.4, 0.3, 0.1),
		CFrame = cf * CFrame.new(0, 1.5, -0.62),
		Color = Color3.fromRGB(255, 210, 60),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	Build.ball(model, cf * CFrame.new(0, 3.6, 0), 1.6, skin)
	for _, side in { -1, 1 } do
		Build.deco({
			Size = Vector3.new(0.6, 0.3, 0.2),
			CFrame = cf
				* CFrame.new(0.85 * side, 3.75, 0)
				* CFrame.Angles(0, 0, math.rad(-25 * side)),
			Color = skin,
			Parent = model,
		})
		Build.ball(
			model,
			cf * CFrame.new(0.3 * side, 3.75, -0.72),
			0.25,
			Color3.fromRGB(30, 30, 40)
		)
		Build.deco({
			Size = Vector3.new(0.5, 1.4, 0.5),
			CFrame = cf * CFrame.new(1.1 * side, 2.2, -0.3) * CFrame.Angles(math.rad(-40), 0, 0),
			Color = green,
			Parent = model,
		})
	end
	Build.ball(model, cf * CFrame.new(0, 3.4, -0.8), 0.3, Color3.fromRGB(255, 140, 140))
	Build.cone(
		model,
		cf * CFrame.new(0, 4.2, 0) * CFrame.Angles(math.rad(-20), 0, 0),
		1.8,
		0.8,
		Color3.fromRGB(200, 40, 50),
		4
	)
	Build.ball(
		model,
		cf * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, 6.1, 0),
		0.4,
		Color3.new(1, 1, 1)
	)
	-- Hammer
	Build.deco({
		Size = Vector3.new(0.2, 1.2, 0.2),
		CFrame = cf * CFrame.new(1.2, 2.2, -1.0),
		Color = Color3.fromRGB(140, 95, 60),
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(0.7, 0.4, 0.4),
		CFrame = cf * CFrame.new(1.2, 2.9, -1.0),
		Color = Color3.fromRGB(150, 150, 160),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	return model
end

local function machineModel(
	plotCF: CFrame,
	index: number,
	def: Config.MachineDef,
	level: number
): Model
	local slot = plotCF * PlotLayout.MACHINE_SLOTS[index]
	local model = Instance.new("Model")
	model.Name = def.id
	local base = Build.part({
		Name = "Base",
		Size = Vector3.new(11, 1, 9),
		CFrame = slot * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(80, 70, 70),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	model.PrimaryPart = base
	Build.part({
		Name = "Body",
		Size = Vector3.new(9, 6, 7),
		CFrame = slot * CFrame.new(0, 4, 0.5),
		Color = def.color,
		Parent = model,
	})
	Build.deco({
		Size = Vector3.new(9.2, 0.8, 7.2),
		CFrame = slot * CFrame.new(0, 7.2, 0.5),
		Color = Color3.fromRGB(255, 205, 70),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	-- Chute toward the belt
	Build.deco({
		Size = Vector3.new(3.4, 0.6, 5),
		CFrame = slot * CFrame.new(0, 2.6, -4.6) * CFrame.Angles(math.rad(-25), 0, 0),
		Color = Color3.fromRGB(170, 170, 180),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	-- Window showing the glowing core
	Build.deco({
		Name = "Core",
		Size = Vector3.new(4, 2.5, 0.3),
		CFrame = slot * CFrame.new(0, 4.4, -3.05),
		Color = Color3.fromRGB(255, 230, 150),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	-- Chimney with steam
	local chimney = Build.deco({
		Name = "Chimney",
		Size = Vector3.new(1.6, 3, 1.6),
		CFrame = slot * CFrame.new(2.8, 9, 2),
		Color = Color3.fromRGB(60, 60, 70),
		Parent = model,
	})
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	steam.Size = NumberSequence.new(1, 3)
	steam.Transparency = NumberSequence.new(0.5, 1)
	steam.Lifetime = NumberRange.new(1.5, 2.5)
	steam.Rate = 3
	steam.Speed = NumberRange.new(3, 4)
	steam.SpreadAngle = Vector2.new(10, 10)
	steam.EmissionDirection = Enum.NormalId.Top
	steam.Parent = chimney
	-- Gears on the side (the client spins anything tagged "Spin")
	for _, side in { -1, 1 } do
		local gear = Build.cylinder(
			model,
			slot * CFrame.new(4.7 * side, 4.5, 0.5),
			0.6,
			4,
			Color3.fromRGB(200, 200, 210),
			Enum.Material.Metal
		)
		gear.Name = "Gear"
		game:GetService("CollectionService"):AddTag(gear, "Spin")
	end
	local _, label = Build.billboard(
		base,
		"",
		UDim2.fromScale(13, 2.6),
		Vector3.new(0, 11, 0),
		Color3.new(1, 1, 1),
		70
	)
	label.Name = "Label"
	label.Text = `{def.name}  Lv.{level}`
	return model
end

local function fence(parent: Instance, plotCF: CFrame)
	local size = PlotLayout.SIZE / 2 - 4
	for x = -size, size, 8 do
		for _, z in { -size, size } do
			if math.abs(x) > 14 or z > 0 then
				local cf = plotCF * CFrame.new(x, 0, z)
				for k = 0, 2 do
					Build.deco({
						Size = Vector3.new(0.9, 1.2, 0.9),
						CFrame = cf * CFrame.new(0, 0.6 + k * 1.2, 0),
						Color = if k % 2 == 0
							then Color3.fromRGB(220, 30, 40)
							else Color3.new(1, 1, 1),
						Parent = parent,
					})
				end
				Build.deco({
					Size = Vector3.new(1.8, 0.9, 0.9),
					CFrame = cf * CFrame.new(0.45, 4, 0),
					Color = Color3.fromRGB(220, 30, 40),
					Parent = parent,
				})
			end
		end
	end
end

local function decorModel(parent: Instance, plotCF: CFrame, id: string)
	local cf = plotCF * (PlotLayout.DECOR[id] or CFrame.new())
	local model = Instance.new("Model")
	model.Name = id
	if id == "D1" then
		fence(model, plotCF)
	elseif id == "D2" then
		Build.ball(model, cf * CFrame.new(0, 3.5, 0), 7, Color3.new(1, 1, 1), Enum.Material.Snow)
		Build.ball(model, cf * CFrame.new(0, 8.5, 0), 5, Color3.new(1, 1, 1), Enum.Material.Snow)
		Build.ball(model, cf * CFrame.new(0, 12, 0), 3.6, Color3.new(1, 1, 1), Enum.Material.Snow)
		Build.deco({
			Size = Vector3.new(0.5, 0.5, 2),
			CFrame = cf * CFrame.new(0, 12, -2),
			Color = Color3.fromRGB(255, 140, 40),
			Parent = model,
		})
		Build.cylinder(
			model,
			cf * CFrame.new(0, 14.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			2,
			2.6,
			Color3.fromRGB(30, 30, 35)
		)
		Build.cylinder(
			model,
			cf * CFrame.new(0, 10.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
			0.8,
			4.6,
			Color3.fromRGB(220, 40, 50)
		)
	elseif id == "D3" then
		local half = PlotLayout.SIZE / 2 - 8
		for _, x in { -half, half } do
			for _, z in { -half, half } do
				local base = plotCF * CFrame.new(x, 0, z)
				Build.deco({
					Size = Vector3.new(1, 12, 1),
					CFrame = base * CFrame.new(0, 6, 0),
					Color = Color3.fromRGB(40, 40, 50),
					Parent = model,
				})
				local lamp = Build.deco({
					Size = Vector3.new(2.4, 2.4, 2.4),
					CFrame = base * CFrame.new(0, 13, 0),
					Color = Color3.fromRGB(255, 200, 130),
					Material = Enum.Material.Neon,
					Parent = model,
				})
				Build.light(lamp, Color3.fromRGB(255, 200, 130), 28, 1.5)
			end
		end
	elseif id == "D4" then
		WorldBuilder.pineTree(model, cf, 28, true)
		Build.deco({
			Size = Vector3.new(2.5, 2.5, 0.6),
			CFrame = cf * CFrame.new(0, 29, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Color = Color3.fromRGB(255, 205, 70),
			Material = Enum.Material.Neon,
			Parent = model,
		})
	elseif id == "D5" then
		Build.deco({
			Size = Vector3.new(16, 10, 14),
			CFrame = cf * CFrame.new(0, 5, 0),
			Color = Color3.fromRGB(180, 110, 60),
			Parent = model,
		})
		Build.deco({
			Size = Vector3.new(18, 1.2, 10),
			CFrame = cf * CFrame.new(0, 12.5, -3.5) * CFrame.Angles(math.rad(-35), 0, 0),
			Color = Color3.new(1, 1, 1),
			Parent = model,
		})
		Build.deco({
			Size = Vector3.new(18, 1.2, 10),
			CFrame = cf * CFrame.new(0, 12.5, 3.5) * CFrame.Angles(math.rad(35), 0, 0),
			Color = Color3.new(1, 1, 1),
			Parent = model,
		})
		for k = -2, 2 do
			Build.ball(
				model,
				cf * CFrame.new(k * 3, 10.5, -7.3),
				1.4,
				if k % 2 == 0 then Color3.fromRGB(230, 40, 50) else Color3.fromRGB(60, 200, 90),
				Enum.Material.Neon
			)
		end
		Build.deco({
			Size = Vector3.new(4, 6, 0.5),
			CFrame = cf * CFrame.new(0, 3, -7.1),
			Color = Color3.fromRGB(240, 90, 160),
			Parent = model,
		})
	elseif id == "D6" then
		Build.deco({
			Size = Vector3.new(6, 2, 6),
			CFrame = cf * CFrame.new(0, 1, 0),
			Color = Color3.fromRGB(180, 220, 255),
			Material = Enum.Material.Ice,
			Parent = model,
		})
		Build.deco({
			Size = Vector3.new(3, 10, 3),
			CFrame = cf * CFrame.new(0, 7, 0) * CFrame.Angles(0, math.rad(45), 0),
			Color = Color3.fromRGB(190, 235, 255),
			Material = Enum.Material.Ice,
			Transparency = 0.25,
			Parent = model,
		})
		Build.deco({
			Size = Vector3.new(7, 2, 2),
			CFrame = cf * CFrame.new(0, 10, 0) * CFrame.Angles(0, 0, math.rad(20)),
			Color = Color3.fromRGB(190, 235, 255),
			Material = Enum.Material.Ice,
			Transparency = 0.25,
			Parent = model,
		})
		local glow = Build.ball(
			model,
			cf * CFrame.new(0, 13, 0),
			3,
			Color3.fromRGB(150, 220, 255),
			Enum.Material.Neon
		)
		Build.light(glow, Color3.fromRGB(150, 220, 255), 18, 1)
	elseif id == "D7" then
		Build.deco({
			Size = Vector3.new(1, 34, 1),
			CFrame = cf * CFrame.new(0, 17, 0),
			Color = Color3.fromRGB(60, 60, 70),
			Parent = model,
		})
		Build.deco({
			Size = Vector3.new(16, 1, 1),
			CFrame = cf * CFrame.new(0, 34, 0),
			Color = Color3.fromRGB(60, 60, 70),
			Parent = model,
		})
		local ball = Build.ball(
			model,
			cf * CFrame.new(0, 26, 0),
			10,
			Color3.fromRGB(220, 40, 60),
			Enum.Material.Glass
		)
		ball.Reflectance = 0.3
		Build.cylinder(
			model,
			cf * CFrame.new(0, 31.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
			2,
			3,
			Color3.fromRGB(255, 205, 70),
			Enum.Material.Metal
		)
		ball:SetAttribute("SpinY", true)
		game:GetService("CollectionService"):AddTag(ball, "Spin")
	elseif id == "D8" then
		for _, side in { -1, 1 } do
			Build.deco({
				Size = Vector3.new(2.5, 22, 2.5),
				CFrame = cf * CFrame.new(14 * side, 11, 0),
				Color = Color3.new(1, 1, 1),
				Parent = model,
			})
		end
		Build.deco({
			Size = Vector3.new(32, 3, 3),
			CFrame = cf * CFrame.new(0, 23, 0),
			Color = Color3.fromRGB(40, 60, 140),
			Parent = model,
		})
		local star = Build.deco({
			Size = Vector3.new(7, 7, 1.2),
			CFrame = cf * CFrame.new(0, 29, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Color = Color3.fromRGB(255, 220, 90),
			Material = Enum.Material.Neon,
			Parent = model,
		})
		Build.deco({
			Size = Vector3.new(7, 7, 1.2),
			CFrame = cf * CFrame.new(0, 29, 0),
			Color = Color3.fromRGB(255, 220, 90),
			Material = Enum.Material.Neon,
			Parent = model,
		})
		Build.light(star, Color3.fromRGB(255, 220, 90), 40, 2)
	end
	model.Parent = parent
end

--------------------------------------------------------------------------------
-- Plot rendering
--------------------------------------------------------------------------------

local function plotModel(index: number): Model
	return WorldBuilder.plots[index]
end

local function plotCFrame(index: number): CFrame
	return PlotLayout.plotCFrame(index, Config.MAX_PLOTS)
end

local function setPadLabel(plot: Model, padName: string, text: string?, enabled: boolean)
	local pad = plot:FindFirstChild(padName)
	if not pad or not pad:IsA("BasePart") then
		return
	end
	pad.Transparency = if enabled then 0 else 0.85
	pad:SetAttribute("Enabled", enabled)
	local gui = pad:FindFirstChildOfClass("BillboardGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = text or ""
	end
end

local function nextMachine(profile: Profile): (number?, Config.MachineDef?)
	for i, m in Config.MACHINES do
		if not profile.machines[m.id] then
			return i, m
		end
	end
	return nil, nil
end

local function machinesOwned(profile: Profile): number
	local n = 0
	for _ in profile.machines do
		n += 1
	end
	return n
end

local function nextDecor(profile: Profile): Config.DecorDef?
	local owned = machinesOwned(profile)
	for _, d in Config.DECOR do
		if not profile.decor[d.id] and owned >= d.unlockAfter then
			return d
		end
	end
	return nil
end

local function refreshPads(player: Player, profile: Profile)
	local index = playerPlot[player]
	if not index then
		return
	end
	local plot = plotModel(index)
	local _, machine = nextMachine(profile)
	if machine then
		setPadLabel(
			plot,
			"PadMachine",
			`🔨 {machine.name}\n{Format.short(machine.cost)} Cheer`,
			true
		)
	else
		setPadLabel(plot, "PadMachine", "All machines built!", false)
	end
	local decor = nextDecor(profile)
	if decor then
		setPadLabel(
			plot,
			"PadDecor",
			`🎄 {decor.name}\n{Format.short(decor.cost)} Cheer  (+5%)`,
			true
		)
	else
		setPadLabel(plot, "PadDecor", "Build more machines\nto unlock decorations", false)
	end
	if profile.elves < Config.ELVES.MAX then
		setPadLabel(
			plot,
			"PadElf",
			`🧝 Hire Elf #{profile.elves + 1}\n{Format.short(Economy.elfCost(profile.elves))} Cheer  (+10%)`,
			true
		)
	else
		setPadLabel(plot, "PadElf", "Elf team complete!", false)
	end
end

local function renderMachines(index: number, profile: Profile)
	local plot = plotModel(index)
	local content = plot:FindFirstChild("Content") :: Folder
	local folder = content:FindFirstChild("Machines")
	if folder then
		folder:Destroy()
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Machines"
	for i, m in Config.MACHINES do
		local level = profile.machines[m.id]
		plot:SetAttribute(m.id, level or 0)
		if level then
			machineModel(plotCFrame(index), i, m, level).Parent = newFolder
		end
	end
	newFolder.Parent = content
end

local function updateMachineLabel(index: number, id: string, level: number)
	local plot = plotModel(index)
	plot:SetAttribute(id, level)
	local content = plot:FindFirstChild("Content")
	local machines = content and content:FindFirstChild("Machines")
	local model = machines and machines:FindFirstChild(id)
	local def = Economy.MACHINE_BY_ID[id]
	if model and def then
		local label = model:FindFirstChild("Label", true)
		if label and label:IsA("TextLabel") then
			label.Text = `{def.name}  Lv.{level}`
		end
	end
end

local function renderDecor(index: number, profile: Profile)
	local plot = plotModel(index)
	local content = plot:FindFirstChild("Content") :: Folder
	local folder = content:FindFirstChild("Decor")
	if folder then
		folder:Destroy()
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Decor"
	for _, d in Config.DECOR do
		if profile.decor[d.id] then
			decorModel(newFolder, plotCFrame(index), d.id)
		end
	end
	newFolder.Parent = content
end

local function renderElves(index: number, profile: Profile)
	local plot = plotModel(index)
	local content = plot:FindFirstChild("Content") :: Folder
	local folder = content:FindFirstChild("Elves")
	if folder then
		folder:Destroy()
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Elves"
	for i = 1, math.min(profile.elves, #PlotLayout.ELF_SLOTS) do
		elfModel(plotCFrame(index) * PlotLayout.ELF_SLOTS[i], i).Parent = newFolder
	end
	newFolder.Parent = content
	plot:SetAttribute("Elves", profile.elves)
end

local function renderSack(index: number, profile: Profile)
	local plot = plotModel(index)
	local capacity = Economy.sackCapacity(profile.sackLevel)
	local fill = math.clamp(profile.sack / capacity, 0, 1)
	plot:SetAttribute("SackFill", fill)
	plot:SetAttribute("SackFull", fill >= 1)
	local sack = plot:FindFirstChild("Sack")
	if sack and sack:IsA("BasePart") then
		local label = sack:FindFirstChildOfClass("BillboardGui")
		local text = label and label:FindFirstChildOfClass("TextLabel")
		if text then
			text.Text = if fill >= 1
				then `SACK FULL! Load the sleigh!\n{Format.short(profile.sack)} Cheer`
				else `🎁 {Format.short(profile.sack)} / {Format.short(capacity)}`
			text.TextColor3 = if fill >= 1
				then Color3.fromRGB(255, 120, 120)
				else Color3.new(1, 1, 1)
		end
	end
end

local function renderSign(index: number, player: Player?, profile: Profile?)
	local plot = plotModel(index)
	local signPart = plot:FindFirstChild("OwnerSign")
	local gui = signPart and signPart:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if label then
		if player and profile then
			local stars = if profile.rebirths > 0 then ` ⭐{profile.rebirths}` else ""
			label.Text = `{player.DisplayName}'s Workshop{stars}`
		else
			label.Text = "Free Workshop"
		end
	end
end

local function renderAll(player: Player, profile: Profile)
	local index = playerPlot[player]
	if not index then
		return
	end
	renderMachines(index, profile)
	renderDecor(index, profile)
	renderElves(index, profile)
	renderSack(index, profile)
	renderSign(index, player, profile)
	refreshPads(player, profile)
end

local function clearPlot(index: number)
	local plot = plotModel(index)
	local content = plot:FindFirstChild("Content")
	if content then
		content:ClearAllChildren()
	end
	plot:SetAttribute("OwnerId", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("SackFill", 0)
	plot:SetAttribute("SackFull", false)
	plot:SetAttribute("Elves", 0)
	for _, m in Config.MACHINES do
		plot:SetAttribute(m.id, 0)
	end
	for _, pad in { "PadMachine", "PadDecor", "PadElf" } do
		setPadLabel(plot, pad, "", false)
	end
	renderSign(index, nil, nil)
end

--------------------------------------------------------------------------------
-- Actions (shared by pads and UI requests)
--------------------------------------------------------------------------------

local function afterChange(player: Player, profile: Profile)
	PlayerState.dirty(player)
	refreshPads(player, profile)
end

function Workshop.buyNextMachine(player: Player): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	local index, machine = nextMachine(profile)
	if not index or not machine then
		return false, "All machines built!"
	end
	if not PlayerState.trySpend(player, profile, "coins", machine.cost) then
		return false, `Need {Format.short(machine.cost)} Cheer`
	end
	profile.machines[machine.id] = 1
	local plotIndex = playerPlot[player]
	if plotIndex then
		renderMachines(plotIndex, profile)
		Net.push(
			player,
			"Effect",
			{ kind = "Built", name = machine.name, plot = plotIndex, slot = index }
		)
	end
	afterChange(player, profile)
	return true, `Built the {machine.name}!`
end

function Workshop.upgradeMachine(player: Player, machineId: string): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	local def = Economy.MACHINE_BY_ID[machineId]
	local level = profile.machines[machineId]
	if not def or not level then
		return false, "Build that machine first"
	end
	if level >= Config.MACHINE_MAX_LEVEL then
		return false, "Max level!"
	end
	local cost = Economy.machineUpgradeCost(def, level)
	if not PlayerState.trySpend(player, profile, "coins", cost) then
		return false, `Need {Format.short(cost)} Cheer`
	end
	profile.machines[machineId] = level + 1
	local plotIndex = playerPlot[player]
	if plotIndex then
		updateMachineLabel(plotIndex, machineId, level + 1)
	end
	afterChange(player, profile)
	return true, `{def.name} is now Lv.{level + 1}!`
end

function Workshop.buyDecor(player: Player, decorId: string?): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	local def = if decorId then Economy.DECOR_BY_ID[decorId] else nextDecor(profile)
	if not def then
		return false, "Nothing to buy right now"
	end
	if profile.decor[def.id] then
		return false, "Already placed"
	end
	if machinesOwned(profile) < def.unlockAfter then
		return false, "Build more machines first"
	end
	if not PlayerState.trySpend(player, profile, "coins", def.cost) then
		return false, `Need {Format.short(def.cost)} Cheer`
	end
	profile.decor[def.id] = true
	local plotIndex = playerPlot[player]
	if plotIndex then
		renderDecor(plotIndex, profile)
	end
	afterChange(player, profile)
	return true, `{def.name} placed! +5% Festive Cheer`
end

function Workshop.hireElf(player: Player): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	if profile.elves >= Config.ELVES.MAX then
		return false, "Your elf team is full!"
	end
	local cost = Economy.elfCost(profile.elves)
	if not PlayerState.trySpend(player, profile, "coins", cost) then
		return false, `Need {Format.short(cost)} Cheer`
	end
	profile.elves += 1
	local plotIndex = playerPlot[player]
	if plotIndex then
		renderElves(plotIndex, profile)
	end
	afterChange(player, profile)
	return true, `Elf #{profile.elves} joined your workshop!`
end

function Workshop.upgradeSack(player: Player): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	if profile.sackLevel >= Config.SACK.MAX_LEVEL then
		return false, "Biggest sack in the North Pole!"
	end
	local cost = Economy.sackCost(profile.sackLevel)
	if not PlayerState.trySpend(player, profile, "coins", cost) then
		return false, `Need {Format.short(cost)} Cheer`
	end
	profile.sackLevel += 1
	local plotIndex = playerPlot[player]
	if plotIndex then
		renderSack(plotIndex, profile)
	end
	afterChange(player, profile)
	return true, `Sack holds {Format.short(Economy.sackCapacity(profile.sackLevel))} now!`
end

function Workshop.upgradeSleigh(player: Player, upgradeId: string): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	local def = Economy.SLEIGH_BY_ID[upgradeId]
	if not def then
		return false, "Unknown upgrade"
	end
	local level = profile.sleigh[upgradeId] or 0
	if level >= def.maxLevel then
		return false, "Max level!"
	end
	local cost = Economy.sleighUpgradeCost(def, level)
	if not PlayerState.trySpend(player, profile, "coins", cost) then
		return false, `Need {Format.short(cost)} Cheer`
	end
	profile.sleigh[upgradeId] = level + 1
	afterChange(player, profile)
	return true, `{def.name} Lv.{level + 1}!`
end

function Workshop.rebirth(player: Player): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	if not Economy.canRebirth(profile) then
		return false, "Build every machine and save up first"
	end
	local cost = Economy.rebirthCost(profile.rebirths)
	if not PlayerState.trySpend(player, profile, "coins", cost) then
		return false, "Not enough Cheer"
	end
	profile.rebirths += 1
	profile.coins = 0
	profile.machines = { M1 = 1 }
	profile.decor = {}
	profile.elves = 0
	profile.sack = 0
	profile.sackLevel = 0
	PlayerState.addSnowflakes(player, profile, Config.REBIRTH.SNOWFLAKE_REWARD, true)
	renderAll(player, profile)
	PlayerState.emit("pets", player) -- slot count may have grown
	Net.push(player, "Effect", { kind = "Rebirth", rebirths = profile.rebirths })
	Net.toastAll(`⭐ {player.DisplayName} started New Season #{profile.rebirths}!`, "event")
	return true,
		`New Season! Permanent +{math.floor(profile.rebirths * Config.REBIRTH.BONUS_EACH * 100)}% Cheer`
end

-- Cash out the sack. `auto` = Auto-Loader pass.
function Workshop.loadSleigh(player: Player, auto: boolean): boolean
	local profile = PlayerData.get(player)
	if not profile or profile.sack < 1 then
		return false
	end
	local now = os.clock()
	if not auto and now - (lastLoad[player] or 0) < 0.75 then
		return false
	end
	lastLoad[player] = now
	local mult = if rushActive then Workshop.rushMultiplier else 1
	local amount = math.floor(profile.sack * mult)
	profile.sack = 0
	PlayerState.addCoins(player, profile, amount)
	local plotIndex = playerPlot[player]
	if plotIndex then
		renderSack(plotIndex, profile)
	end
	Net.push(
		player,
		"Effect",
		{ kind = "Loaded", amount = amount, rush = rushActive and mult > 1, auto = auto }
	)
	return true
end

function Workshop.setRush(active: boolean, multiplier: number)
	rushActive = active
	Workshop.rushMultiplier = multiplier
end

function Workshop.plotOf(player: Player): number?
	return playerPlot[player]
end

function Workshop.spawnCFrame(player: Player): CFrame?
	local index = playerPlot[player]
	if not index then
		return nil
	end
	return plotCFrame(index) * PlotLayout.SPAWN
end

function Workshop.sendHome(player: Player)
	local character = player.Character
	local cf = Workshop.spawnCFrame(player)
	if character and cf then
		character:PivotTo(cf)
	end
end

--------------------------------------------------------------------------------
-- Plot ownership + touch pads
--------------------------------------------------------------------------------

local function padTouched(index: number, padName: string, hit: BasePart)
	local character = hit.Parent
	if not character or not character:IsA("Model") then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player or playerPlot[player] ~= index then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local touches = lastPadTouch[player]
	if not touches then
		touches = {}
		lastPadTouch[player] = touches
	end
	local now = os.clock()
	local cooldown = if padName == "LoadPad" then 0.75 else 1.5
	if now - (touches[padName] or 0) < cooldown then
		return
	end
	touches[padName] = now

	local ok, message
	if padName == "LoadPad" then
		Workshop.loadSleigh(player, false)
		return
	elseif padName == "PadMachine" then
		ok, message = Workshop.buyNextMachine(player)
	elseif padName == "PadDecor" then
		ok, message = Workshop.buyDecor(player, nil)
	elseif padName == "PadElf" then
		ok, message = Workshop.hireElf(player)
	end
	if message then
		Net.toast(player, message, if ok then "success" else "error")
	end
end

local function claimPlot(player: Player, profile: Profile)
	if playerPlot[player] then
		return
	end
	for i = 1, Config.MAX_PLOTS do
		if not plotOwner[i] then
			plotOwner[i] = player
			playerPlot[player] = i
			local plot = plotModel(i)
			plot:SetAttribute("OwnerId", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName)
			PlayerState.session(player).plotIndex = i
			player:SetAttribute("Plot", i)
			renderAll(player, profile)
			PlayerState.dirty(player)
			return
		end
	end
	warn(`[Workshop] no free plot for {player.Name}`)
	player:Kick("This North Pole server is full of workshops! Please join another server.")
end

local function releasePlot(player: Player)
	local index = playerPlot[player]
	if index then
		plotOwner[index] = nil
		clearPlot(index)
	end
	playerPlot[player] = nil
	lastLoad[player] = nil
	lastPadTouch[player] = nil
end

--------------------------------------------------------------------------------
-- Production loop
--------------------------------------------------------------------------------

local sackRenderAccum = 0
local function productionTick(dt: number)
	sackRenderAccum += dt
	local renderSacks = sackRenderAccum >= 1
	if renderSacks then
		sackRenderAccum = 0
	end
	for player, index in playerPlot do
		local profile = PlayerData.get(player)
		if profile then
			local capacity = Economy.sackCapacity(profile.sackLevel)
			if profile.sack < capacity then
				local income = Economy.incomePerSecond(profile, PlayerState.ctx(player))
				profile.sack = math.min(capacity, profile.sack + income * dt)
				PlayerState.tickDirty(player)
			end
			if renderSacks then
				renderSack(index, profile)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function Workshop.start()
	for i, plot in WorldBuilder.plots do
		clearPlot(i)
		for _, padName in { "PadMachine", "PadDecor", "PadElf", "LoadPad" } do
			local pad = plot:FindFirstChild(padName)
			if pad and pad:IsA("BasePart") then
				pad.Touched:Connect(function(hit)
					padTouched(i, padName, hit)
				end)
			end
		end
	end

	PlayerData.onLoaded(function(player, profile)
		claimPlot(player, profile)
		local function onCharacter(character: Model)
			task.wait(0.2)
			local cf = Workshop.spawnCFrame(player)
			if cf and character.Parent then
				character:PivotTo(cf)
			end
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end)

	Players.PlayerRemoving:Connect(releasePlot)

	-- Requests from UI
	Net.handle("BuyMachine", 3, 5, function(player)
		return Workshop.buyNextMachine(player)
	end)
	Net.handle("UpgradeMachine", 8, 10, function(player, machineId: unknown)
		local id = Guard.oneOf(machineId, Economy.MACHINE_BY_ID)
		if not id then
			return false, "Unknown machine"
		end
		return Workshop.upgradeMachine(player, id)
	end)
	Net.handle("BuyDecor", 3, 5, function(player, decorId: unknown)
		local id = Guard.oneOf(decorId, Economy.DECOR_BY_ID)
		if not id then
			return false, "Unknown decoration"
		end
		return Workshop.buyDecor(player, id)
	end)
	Net.handle("HireElf", 3, 5, function(player)
		return Workshop.hireElf(player)
	end)
	Net.handle("UpgradeSack", 4, 6, function(player)
		return Workshop.upgradeSack(player)
	end)
	Net.handle("UpgradeSleigh", 4, 6, function(player, upgradeId: unknown)
		local id = Guard.oneOf(upgradeId, Economy.SLEIGH_BY_ID)
		if not id then
			return false, "Unknown upgrade"
		end
		return Workshop.upgradeSleigh(player, id)
	end)
	Net.handle("Rebirth", 0.2, 1, function(player)
		return Workshop.rebirth(player)
	end)
	Net.handle("GoHome", 0.5, 2, function(player)
		Workshop.sendHome(player)
		return true, nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			productionTick(now - last)
			last = now
		end
	end)

	-- Auto-Loader game pass
	task.spawn(function()
		while true do
			task.wait(Config.SACK.AUTOLOAD_INTERVAL)
			for player in playerPlot do
				if PlayerState.hasPass(player, "AutoLoader") then
					Workshop.loadSleigh(player, true)
				end
			end
		end
	end)
end

return Workshop
