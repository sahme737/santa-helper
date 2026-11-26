--!strict
-- First-session guide: a short quest chain with a glowing path to each
-- target. Progress is saved so it never repeats.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local State = require(Lib.State)
local Bus = require(Lib.Bus)

local Tutorial = {}

local T = UI.Theme
local player = Players.LocalPlayer

type Step = { text: string, target: () -> Instance?, done: (any) -> boolean }

local function myPlot(): Model?
	local index = player:GetAttribute("Plot")
	local plots = Workspace:FindFirstChild("Plots")
	if not index or not plots then
		return nil
	end
	return plots:FindFirstChild("Plot" .. tostring(index)) :: Model?
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local STEPS: { Step } = {
	{
		text = "🎁 Your elves are making toys! Step on the green LOAD SLEIGH pad to turn presents into Cheer.",
		target = function()
			local plot = myPlot()
			return plot and plot:FindFirstChild("LoadPad")
		end,
		done = function(s)
			return s.profile.lifetimeCoins > 0
		end,
	},
	{
		text = "🔨 Step on the yellow pad to build your next toy machine!",
		target = function()
			local plot = myPlot()
			return plot and plot:FindFirstChild("PadMachine")
		end,
		done = function(s)
			return count(s.profile.machines) >= 2
		end,
	},
	{
		text = "🧝 Hire an elf to make every machine faster!",
		target = function()
			local plot = myPlot()
			return plot and plot:FindFirstChild("PadElf")
		end,
		done = function(s)
			return s.profile.elves >= 1
		end,
	},
	{
		text = "🦌 Visit the Reindeer Stable and hatch a pet reindeer. It boosts your Cheer!",
		target = function()
			local hub = Workspace:FindFirstChild("World")
			local stable = hub and hub:FindFirstChild("ReindeerStable", true)
			return stable and stable:FindFirstChild("Egg_Snowdrift")
		end,
		done = function(s)
			return #s.profile.pets >= 1
		end,
	},
	{
		text = "🛷 Fly your sleigh and drop presents down chimneys!",
		target = function()
			local plot = myPlot()
			local sleigh = plot and plot:FindFirstChild("Sleigh")
			return sleigh and (sleigh :: Model).PrimaryPart
		end,
		done = function(s)
			return s.profile.delivered >= 1
		end,
	},
}

local banner: Frame
local bannerText: TextLabel
local beam: Beam? = nil
local highlight: Highlight? = nil
local a0: Attachment? = nil
local a1: Attachment? = nil
local currentStep = -1

local function clearGuide()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if a0 then
		a0:Destroy()
		a0 = nil
	end
	if a1 then
		a1:Destroy()
		a1 = nil
	end
end

local function guideTo(target: Instance?)
	clearGuide()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not target or not target:IsA("BasePart") or not root then
		return
	end
	a0 = UI.make("Attachment", { Name = "TutorialFrom", Parent = root })
	a1 = UI.make(
		"Attachment",
		{ Name = "TutorialTo", Position = Vector3.new(0, 2, 0), Parent = target }
	)
	beam = UI.make("Beam", {
		Attachment0 = a0,
		Attachment1 = a1,
		Color = ColorSequence.new(T.Gold),
		LightEmission = 1,
		Width0 = 1.2,
		Width1 = 1.2,
		FaceCamera = true,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		TextureMode = Enum.TextureMode.Static,
		TextureLength = 3,
		TextureSpeed = 1.5,
		Transparency = NumberSequence.new(0.2),
		Parent = target,
	})
	highlight = UI.make("Highlight", {
		Adornee = target,
		FillColor = T.Gold,
		FillTransparency = 0.5,
		OutlineColor = Color3.new(1, 1, 1),
		Parent = target,
	})
end

local function render(snapshot: any)
	local step = snapshot.profile.tutorialStep
	-- Skip any steps already completed (e.g. returning players).
	while STEPS[step + 1] and STEPS[step + 1].done(snapshot) do
		step += 1
		task.spawn(Net.request, "TutorialStep", step)
		if step - 1 == currentStep and STEPS[step + 1] then
			Bus.fire("Toast", "✔ Quest complete!", "success")
		end
	end
	if step ~= currentStep then
		currentStep = step
		local info = STEPS[step + 1]
		if info then
			banner.Visible = true
			bannerText.Text = info.text
			UI.pop(banner, 0.8)
			task.defer(function()
				guideTo(info.target())
			end)
		else
			banner.Visible = false
			clearGuide()
			if snapshot.profile.tutorialStep < #STEPS then
				Bus.fire("Announce", "🎄 You're a true Santa's Helper! 🎄", T.Gold)
				task.delay(3, function()
					Bus.fire(
						"Toast",
						"🎁 Come back every day for bigger gifts and Advent doors!",
						"success"
					)
				end)
			end
		end
	end
end

function Tutorial.init()
	local screen = UI.screen("Tutorial", 6)
	banner = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromScale(0.42, 0.07),
		BackgroundColor3 = Color3.fromRGB(40, 25, 30),
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = screen,
	})
	UI.make("UISizeConstraint", { MaxSize = Vector2.new(620, 80), Parent = banner })
	UI.corner(banner, 14)
	UI.stroke(banner, T.Gold, 2.5)
	bannerText = UI.text({
		Text = "",
		Size = UDim2.fromScale(0.94, 0.86),
		Position = UDim2.fromScale(0.03, 0.07),
		MaxTextSize = 22,
		TextWrapped = true,
		Parent = banner,
	})
	UI.textStroke(bannerText, T.Ink, 1.5)
end

function Tutorial.start()
	State.onChanged(render)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		local info = STEPS[currentStep + 1]
		if info then
			guideTo(info.target())
		end
	end)
	-- Re-target occasionally in case the plot loaded after the step started.
	task.spawn(function()
		while true do
			task.wait(3)
			local info = STEPS[currentStep + 1]
			if info and not beam then
				guideTo(info.target())
			end
		end
	end)
end

return Tutorial
