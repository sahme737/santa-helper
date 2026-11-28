--!strict
-- Celebration popups and bursts: offline earnings welcome-back, confetti on
-- purchases, new seasons and server goals.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local Bus = require(Lib.Bus)

local Popups = {}

local T = UI.Theme
local screen: ScreenGui

local CONFETTI = { T.Red, T.Green, T.Gold, Color3.new(1, 1, 1), T.Blue }

function Popups.confetti(amount: number?)
	for _ = 1, amount or 40 do
		local piece: Frame = UI.make("Frame", {
			Size = UDim2.fromOffset(math.random(8, 14), math.random(10, 18)),
			Position = UDim2.fromScale(math.random(), -0.05),
			BackgroundColor3 = CONFETTI[math.random(1, #CONFETTI)],
			Rotation = math.random(0, 360),
			BorderSizePixel = 0,
			Parent = screen,
		})
		local duration = 1.8 + math.random() * 1.4
		UI.tween(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 1.05),
			Rotation = piece.Rotation + math.random(-540, 540),
		})
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

local function modal(title: string, body: string, buttonText: string, color: Color3)
	local frame: Frame = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.36, 0.36),
		BackgroundColor3 = T.Cream,
		Parent = screen,
	})
	UI.make("UIAspectRatioConstraint", { AspectRatio = 1.5, Parent = frame })
	UI.corner(frame, 18)
	UI.stroke(frame, T.Ink, 4)
	local titleLabel = UI.text({
		Text = title,
		Size = UDim2.fromScale(0.9, 0.2),
		Position = UDim2.fromScale(0.05, 0.05),
		TextColor3 = color,
		MaxTextSize = 40,
		Parent = frame,
	})
	UI.textStroke(titleLabel, T.Ink, 1.5)
	UI.text({
		Text = body,
		Size = UDim2.fromScale(0.9, 0.42),
		Position = UDim2.fromScale(0.05, 0.28),
		TextColor3 = T.Ink,
		FontFace = UI.BodyFont,
		TextWrapped = true,
		MaxTextSize = 26,
		Parent = frame,
	})
	UI.button({
		Text = buttonText,
		Color = T.Green,
		Size = UDim2.fromScale(0.5, 0.18),
		Position = UDim2.fromScale(0.25, 0.76),
		Parent = frame,
		OnClick = function()
			frame:Destroy()
		end,
	})
	UI.pop(frame, 0.5)
	UI.sound("Coin", 0.6, 1)
end

function Popups.init()
	screen = UI.screen("Popups", 30)
end

function Popups.start()
	Bus.on("Confetti", function(amount: number?)
		Popups.confetti(amount)
	end)
	Net.on("Offline", function(payload)
		modal(
			"Welcome back! 🎄",
			`While you were away ({Format.time(payload.seconds)}), your elves made\n⭐ {Format.short(
				payload.amount
			)} Cheer!`,
			"Collect!",
			T.Green
		)
		Popups.confetti(30)
	end)
	Net.on("Effect", function(payload)
		if
			payload.kind == "Purchase"
			or payload.kind == "Rebirth"
			or payload.kind == "Community"
		then
			Popups.confetti(60)
		elseif payload.kind == "Built" then
			Popups.confetti(25)
		elseif payload.kind == "Loaded" and not payload.auto then
			Popups.confetti(14)
		elseif payload.kind == "RankUp" then
			Popups.confetti(30)
		end
	end)
end

return Popups
