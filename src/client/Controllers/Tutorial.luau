--!strict
-- The guide: one short line at the top of the screen saying what to do next,
-- with a golden path and a small arrow over the place to go. It never shouts
-- and never stacks popups. Progress is saved so it never repeats; after the
-- chain, a reminder appears only when there is something obvious to do.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local State = require(Lib.State)
local Bus = require(Lib.Bus)

local Tutorial = {}

local T = UI.Theme
local player = Players.LocalPlayer

-- Saved progress for this chain starts at SAVE_BASE, so helpers who finished
-- the older, shorter guide are walked through the new one once.
local SAVE_BASE = 20

type Step = { resolve: (any) -> (string, Instance?), done: (any) -> boolean }

local function myPlot(): Model?
	local index = player:GetAttribute("Plot")
	local plots = Workspace:FindFirstChild("Plots")
	if not index or not plots then
		return nil
	end
	return plots:FindFirstChild("Plot" .. tostring(index)) :: Model?
end

local function plotPart(name: string): Instance?
	local plot = myPlot()
	return plot and plot:FindFirstChild(name)
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function nextMachine(profile: any): Config.MachineDef?
	for _, m in Config.MACHINES do
		if not profile.machines[m.id] then
			return m
		end
	end
	return nil
end

-- Shared shape of every "buy something" job: point at the pad when the
-- player can pay, at the LOAD pad when the sack would cover it, and back at
-- the wrapping table when they still need to earn.
local function earnThenBuy(
	s: any,
	cost: number,
	padName: string,
	buyText: string,
	what: string
): (string, Instance?)
	local profile = s.profile
	if profile.coins >= cost then
		return buyText, plotPart(padName)
	end
	local missing = cost - profile.coins
	if profile.sack >= missing then
		return "🛷 Step on the green pad to load your presents", plotPart("LoadPad")
	end
	return `🎁 Pack more presents ({Format.short(missing)} more Cheer for {what})`,
		plotPart("WrapTable")
end

local STEPS: { Step } = {
	{
		resolve = function()
			return "🎁 Pack a present at your wrapping table", plotPart("WrapTable")
		end,
		done = function(s)
			return s.profile.lifetimeCoins > 0 or s.profile.sack >= Config.WRAP.MIN_VALUE * 2
		end,
	},
	{
		resolve = function()
			return "🛷 Step on the green pad to load your sleigh", plotPart("LoadPad")
		end,
		done = function(s)
			return s.profile.lifetimeCoins > 0
		end,
	},
	{
		resolve = function(s)
			local machine = nextMachine(s.profile)
			local cost = if machine then machine.cost else 0
			return earnThenBuy(
				s,
				cost,
				"PadMachine",
				"🔨 Step on the yellow pad to build a toy machine",
				"a toy machine"
			)
		end,
		done = function(s)
			return count(s.profile.machines) >= 2
		end,
	},
	{
		resolve = function(s)
			return earnThenBuy(
				s,
				Economy.elfCost(0),
				"PadElf",
				"🧝 Step on the yellow pad to hire an elf",
				"an elf helper"
			)
		end,
		done = function(s)
			return s.profile.elves >= 1
		end,
	},
	{
		resolve = function()
			local sleigh = plotPart("Sleigh")
			return "🛷 Hop in your sleigh and fly a delivery",
				sleigh and (sleigh :: Model).PrimaryPart
		end,
		done = function(s)
			return s.profile.delivered >= 1
		end,
	},
	{
		resolve = function()
			local hub = Workspace:FindFirstChild("World")
			local stable = hub and hub:FindFirstChild("ReindeerStable", true)
			return "🦌 Hatch a pet at the Reindeer Stable",
				stable and stable:FindFirstChild("Egg_Snowdrift")
		end,
		done = function(s)
			return #s.profile.pets >= 1
		end,
	},
}

-- After the chain: a reminder only when the next move is obvious.
local function reminder(s: any): (string?, Instance?)
	local profile = s.profile
	if profile.sack >= Economy.sackCapacity(profile.sackLevel) then
		return "🛷 Sack full! Step on the green pad", plotPart("LoadPad")
	end
	if profile.elves < 1 then
		return earnThenBuy(
			s,
			Economy.elfCost(0),
			"PadElf",
			"🧝 Step on the yellow pad to hire an elf",
			"an elf helper"
		)
	end
	return nil, nil
end

local screen: ScreenGui
local banner: Frame
local bannerText: TextLabel
local pointer: TextLabel
local beam: Beam? = nil
local highlight: Highlight? = nil
local arrow: BillboardGui? = nil
local a0: Attachment? = nil
local a1: Attachment? = nil
local currentTarget: Instance? = nil
local currentText: string? = nil
local lastStep = -1
local arrowHeight = 8
local flying = false

local function clearGuide()
	if beam then
		beam:Destroy()
	end
	if highlight then
		highlight:Destroy()
	end
	if arrow then
		arrow:Destroy()
	end
	if a0 then
		a0:Destroy()
	end
	if a1 then
		a1:Destroy()
	end
	beam, highlight, arrow, a0, a1 = nil, nil, nil, nil, nil
	currentTarget = nil
	if pointer then
		pointer.Visible = false
	end
end

local function guideTo(target: Instance?)
	clearGuide()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not target or not target:IsA("BasePart") or not root then
		return
	end
	currentTarget = target
	arrowHeight = target.Size.Y / 2 + 7
	a0 = UI.make("Attachment", { Name = "GuideFrom", Parent = root })
	a1 = UI.make(
		"Attachment",
		{ Name = "GuideTo", Position = Vector3.new(0, 2, 0), Parent = target }
	)
	beam = UI.make("Beam", {
		Attachment0 = a0,
		Attachment1 = a1,
		Color = ColorSequence.new(T.Gold),
		LightEmission = 1,
		Width0 = 1,
		Width1 = 1,
		FaceCamera = true,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		TextureMode = Enum.TextureMode.Static,
		TextureLength = 3,
		TextureSpeed = 2,
		Transparency = NumberSequence.new(0.35),
		Parent = target,
	})
	highlight = UI.make("Highlight", {
		Adornee = target,
		FillColor = T.Gold,
		FillTransparency = 0.75,
		OutlineColor = Color3.new(1, 1, 1),
		Parent = target,
	})
	-- Big bouncing arrow that shows through walls.
	local gui: BillboardGui = UI.make("BillboardGui", {
		Name = "GuideArrow",
		Size = UDim2.fromOffset(64, 64),
		StudsOffsetWorldSpace = Vector3.new(0, arrowHeight, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 600,
		Parent = target,
	})
	local label = UI.text({ Text = "⬇️", MaxTextSize = 64, Parent = gui })
	UI.textStroke(label, T.Ink, 2)
	arrow = gui
end

local function show(text: string?, target: Instance?)
	if not text then
		banner.Visible = false
		currentText = nil
		clearGuide()
		return
	end
	if text ~= currentText then
		currentText = text
		bannerText.Text = text
		banner.Visible = true
		UI.pop(banner, 1.04)
	end
	if target ~= currentTarget then
		task.defer(guideTo, target)
	end
end

local function render(snapshot: any)
	local step = math.clamp(snapshot.profile.tutorialStep - SAVE_BASE, 0, #STEPS)
	local advanced = false
	-- Skip any jobs already done (for example returning players).
	while STEPS[step + 1] and STEPS[step + 1].done(snapshot) do
		step += 1
		advanced = true
	end
	if advanced then
		task.spawn(Net.request, "TutorialStep", SAVE_BASE + step)
		if lastStep >= 0 then
			UI.sound("Star", 0.35)
			if not STEPS[step + 1] then
				Bus.fire("Confetti", 40)
				Bus.fire("Announce", "🎄 You know the ropes now. Have fun!", T.Gold)
			end
		end
	end
	lastStep = step
	local info = STEPS[step + 1]
	if info then
		local text, target = info.resolve(snapshot)
		show(text, target)
	else
		local text, target = reminder(snapshot)
		show(text, target)
	end
end

-- Bounce the arrow and aim the screen-edge pointer every frame.
local function animate()
	-- The guide steps aside for menus and while the sleigh is in the air.
	screen.Enabled = not flying and not UI.anyPanelOpen()
	local target = currentTarget
	local gui = arrow
	if not target or not gui or not target:IsA("BasePart") or not target.Parent then
		pointer.Visible = false
		return
	end
	local bounce = math.abs(math.sin(os.clock() * 3)) * 1.5
	gui.StudsOffsetWorldSpace = Vector3.new(0, arrowHeight + bounce, 0)
	local camera = Workspace.CurrentCamera
	if not camera or flying then
		pointer.Visible = false
		return
	end
	local view = camera.ViewportSize
	local point, onScreen =
		camera:WorldToViewportPoint(target.Position + Vector3.new(0, arrowHeight, 0))
	local inside = onScreen
		and point.X > view.X * 0.06
		and point.X < view.X * 0.94
		and point.Y > view.Y * 0.08
		and point.Y < view.Y * 0.92
	if inside then
		pointer.Visible = false
		return
	end
	local centre = view / 2
	local dir = Vector2.new(point.X, point.Y) - centre
	if point.Z < 0 then
		dir = -dir
	end
	if dir.Magnitude < 1 then
		dir = Vector2.new(0, 1)
	end
	dir = dir.Unit
	local reach = math.min(
		centre.X * 0.82 / math.max(math.abs(dir.X), 0.001),
		centre.Y * 0.7 / math.max(math.abs(dir.Y), 0.001)
	)
	local at = centre + dir * reach
	pointer.Position = UDim2.fromOffset(at.X, at.Y)
	pointer.Rotation = math.deg(math.atan2(dir.Y, dir.X))
	pointer.Visible = true
end

function Tutorial.init()
	screen = UI.screen("Tutorial", 6)
	screen.IgnoreGuiInset = true
	-- The guide steps aside while the sleigh is in the air.
	Bus.on("Flying", function(value: boolean)
		flying = value
	end)
	banner = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.13),
		Size = UDim2.fromScale(0.36, 0.06),
		BackgroundColor3 = Color3.fromRGB(30, 22, 30),
		BackgroundTransparency = 0.3,
		Visible = false,
		Parent = screen,
	})
	UI.make(
		"UISizeConstraint",
		{ MinSize = Vector2.new(260, 36), MaxSize = Vector2.new(560, 52), Parent = banner }
	)
	UI.corner(banner, 14)
	UI.stroke(banner, T.Gold, 1.5)
	bannerText = UI.text({
		Text = "",
		Size = UDim2.fromScale(0.94, 0.76),
		Position = UDim2.fromScale(0.03, 0.12),
		MaxTextSize = 22,
		Parent = banner,
	})
	UI.textStroke(bannerText, T.Ink, 1.5)
	pointer = UI.text({
		Name = "Pointer",
		Text = "➡️",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(54, 54),
		MaxTextSize = 54,
		Visible = false,
		Parent = screen,
	})
end

function Tutorial.start()
	State.onChanged(render)
	RunService.RenderStepped:Connect(animate)
	local function retarget()
		local wanted = currentTarget
		currentTarget = nil
		currentText = nil
		clearGuide()
		local snapshot = State.data
		if snapshot then
			render(snapshot)
		elseif wanted then
			guideTo(wanted)
		end
	end
	player.CharacterAdded:Connect(function()
		task.wait(1)
		retarget()
	end)
	-- Re-target now and then in case the plot loaded after the job started.
	task.spawn(function()
		while true do
			task.wait(3)
			if banner.Visible and not beam then
				retarget()
			end
		end
	end)
end

return Tutorial
