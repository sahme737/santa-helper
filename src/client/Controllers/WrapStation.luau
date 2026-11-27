--!strict
-- Wrapping presents by hand. A big WRAP button appears whenever the player
-- stands at their own wrapping table; holding it (or holding E) wraps one
-- present after another. The server decides what each present is worth.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local PlotLayout = require(Shared.PlotLayout)
local Format = require(Shared.Util.Format)

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local Bus = require(Lib.Bus)

local WrapStation = {}

local T = UI.Theme
local player = Players.LocalPlayer

local SHOW_DISTANCE = 15
local INTERVAL = 0.3

local screen: ScreenGui
local button: TextButton
local hint: TextLabel
local holdingButton = false
local holdingKey = false
local near = false
local flying = false
local busy = false
local lastWrap = 0
local lastComplaint = 0
local streak = 0

local function tablePosition(): Vector3?
	local index = player:GetAttribute("Plot")
	if typeof(index) ~= "number" then
		return nil
	end
	return (PlotLayout.plotCFrame(index, Config.MAX_PLOTS) * PlotLayout.WRAP_TABLE).Position
end

local function floatText(text: string)
	local label = UI.text({
		Text = text,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.12, 0.7),
		Size = UDim2.fromScale(0.3, 0.06),
		TextColor3 = T.Gold,
		MaxTextSize = 38,
		Parent = screen,
	})
	UI.textStroke(label, T.Ink, 2.5)
	UI.pop(label, 1.5)
	UI.tween(
		label,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad),
		{ Position = label.Position - UDim2.fromScale(0, 0.12), TextTransparency = 1 }
	)
	task.delay(1, function()
		label:Destroy()
	end)
end

local function wrapOnce()
	if busy then
		return
	end
	busy = true
	lastWrap = os.clock()
	local ok, data = Net.request("Wrap")
	busy = false
	if ok and typeof(data) == "number" then
		streak += 1
		UI.sound("Pop", 0.35, 1 + math.min(streak, 12) * 0.03)
		UI.pop(button, 1.1)
		floatText(`+{Format.short(data)} 🎁`)
		Bus.fire("Wrapped")
	elseif typeof(data) == "string" and data ~= "Slow down!" then
		streak = 0
		local now = os.clock()
		if now - lastComplaint > 3 then
			lastComplaint = now
			Bus.fire("Toast", data, "error")
		end
	end
end

function WrapStation.init()
	screen = UI.screen("Wrap", 5)
	button = UI.button({
		Name = "WrapButton",
		Text = "🎁 WRAP!",
		Color = T.Red,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(0.26, 0.13),
		MaxTextSize = 54,
		Parent = screen,
	})
	UI.make(
		"UISizeConstraint",
		{ MinSize = Vector2.new(170, 76), MaxSize = Vector2.new(360, 130), Parent = button }
	)
	UI.stroke(button, T.Gold, 4)
	button.Visible = false
	hint = UI.text({
		Text = if UserInputService.TouchEnabled
			then "Hold the button to wrap presents"
			else "Hold the button (or hold E) to wrap presents",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.81),
		Size = UDim2.fromScale(0.5, 0.035),
		MaxTextSize = 20,
		Visible = false,
		Parent = screen,
	})
	UI.textStroke(hint, T.Ink, 2)

	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			holdingButton = true
			task.spawn(wrapOnce)
		end
	end)
	button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			holdingButton = false
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if
			not processed
			and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX)
		then
			holdingKey = true
			if near and not flying then
				task.spawn(wrapOnce)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
			holdingKey = false
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			holdingButton = false
		end
	end)
	Bus.on("Flying", function(value: boolean)
		flying = value
	end)
end

function WrapStation.start()
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum < 0.1 then
			return
		end
		accum = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local pos = tablePosition()
		local isNear = false
		if root and root:IsA("BasePart") and pos and not flying then
			isNear = (root.Position - pos).Magnitude <= SHOW_DISTANCE
		end
		if isNear ~= near then
			near = isNear
			button.Visible = near
			hint.Visible = near
			if near then
				UI.pop(button, 1.25)
			else
				holdingButton = false
				streak = 0
			end
		end
		if near and (holdingButton or holdingKey) and os.clock() - lastWrap >= INTERVAL then
			task.spawn(wrapOnce)
		end
	end)
end

return WrapStation
