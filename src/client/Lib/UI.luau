--!strict
-- UI toolkit: festive theme, builders, juicy buttons, panels, sounds and
-- 3D previews. Everything scales with screen size (mobile first).

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local UI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

UI.Theme = {
	Red = Color3.fromRGB(214, 40, 57),
	DarkRed = Color3.fromRGB(150, 25, 40),
	Green = Color3.fromRGB(42, 157, 92),
	DarkGreen = Color3.fromRGB(25, 100, 60),
	Gold = Color3.fromRGB(255, 201, 60),
	Cream = Color3.fromRGB(255, 247, 232),
	Snow = Color3.fromRGB(245, 250, 255),
	Ink = Color3.fromRGB(60, 30, 30),
	Muted = Color3.fromRGB(140, 110, 100),
	Blue = Color3.fromRGB(70, 140, 230),
	Purple = Color3.fromRGB(140, 90, 210),
	Disabled = Color3.fromRGB(170, 160, 160),
}

UI.Font = Font.fromEnum(Enum.Font.FredokaOne)
UI.BodyFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

UI.FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
UI.BOUNCY = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
UI.SMOOTH = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

function UI.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.corner(parent: Instance, radius: number?): UICorner
	return UI.make("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function UI.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return UI.make("UIStroke", {
		Color = color or UI.Theme.Ink,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UI.textStroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return UI.make("UIStroke", {
		Color = color or UI.Theme.Ink,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = parent,
	})
end

function UI.padding(parent: Instance, px: number)
	UI.make("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function UI.gradient(parent: Instance, top: Color3, bottom: Color3): UIGradient
	return UI.make("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
		Parent = parent,
	})
end

function UI.text(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = UI.Font,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in props do
		defaults[k] = v
	end
	local maxSize = defaults.MaxTextSize
	defaults.MaxTextSize = nil
	local label = UI.make("TextLabel", defaults)
	UI.make(
		"UITextSizeConstraint",
		{ MaxTextSize = maxSize or 40, MinTextSize = 8, Parent = label }
	)
	return label
end

function UI.tween(inst: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

-- Scale pop on any GuiObject (adds a UIScale if needed).
function UI.pop(gui: GuiObject, amount: number?)
	local scale = gui:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		scale = UI.make("UIScale", { Name = "PopScale", Parent = gui })
	end
	local s = scale :: UIScale
	s.Scale = amount or 1.15
	UI.tween(s, UI.BOUNCY, { Scale = 1 })
end

local soundCache: { [string]: Sound } = {}
function UI.sound(name: string, volume: number?, pitch: number?)
	local id = (Config.SOUNDS :: any)[name]
	if not id or id == "" then
		return
	end
	local base = soundCache[name]
	if not base then
		base = UI.make("Sound", { SoundId = id, Volume = volume or 0.5, Parent = SoundService })
		soundCache[name] = base
	end
	local s = (base :: Sound):Clone()
	s.PlaybackSpeed = (pitch or 1) * (0.94 + math.random() * 0.12)
	s.Volume = volume or 0.5
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(5, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

export type ButtonProps = {
	Text: string,
	Color: Color3?,
	TextColor: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Parent: Instance?,
	OnClick: (() -> ())?,
	Name: string?,
	MaxTextSize: number?,
}

function UI.button(props: ButtonProps): TextButton
	local color = props.Color or UI.Theme.Green
	local button: TextButton = UI.make("TextButton", {
		Name = props.Name or "Button",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Size = props.Size or UDim2.fromScale(0.3, 0.1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
	})
	UI.corner(button, 10)
	UI.stroke(button, UI.Theme.Ink, 2.5)
	UI.make("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(210, 210, 210)),
		Rotation = 90,
		Parent = button,
	})
	local label = UI.text({
		Name = "Label",
		Text = props.Text,
		TextColor3 = props.TextColor or Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0.9, 0.8),
		Position = UDim2.fromScale(0.05, 0.1),
		MaxTextSize = props.MaxTextSize or 28,
		Parent = button,
	})
	UI.textStroke(label, UI.Theme.Ink, 1.5)
	local scale = UI.make("UIScale", { Name = "PopScale", Parent = button })
	button.MouseEnter:Connect(function()
		UI.tween(scale, UI.FAST, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		UI.tween(scale, UI.FAST, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UI.tween(scale, UI.FAST, { Scale = 0.93 })
	end)
	button.MouseButton1Up:Connect(function()
		UI.tween(scale, UI.BOUNCY, { Scale = 1 })
	end)
	if props.OnClick then
		local cb = props.OnClick
		button.Activated:Connect(function()
			UI.sound("Click", 0.4)
			cb()
		end)
	end
	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

function UI.setButton(button: TextButton, text: string?, color: Color3?)
	local label = button:FindFirstChild("Label") :: TextLabel?
	if label and text then
		label.Text = text
	end
	if color then
		button.BackgroundColor3 = color
	end
end

function UI.screen(name: string, order: number): ScreenGui
	return UI.make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		Parent = playerGui,
	})
end

-- 3D preview of a model inside a ViewportFrame, framed by bounding box.
function UI.viewport(model: Model, parent: GuiObject, spin: boolean?): ViewportFrame
	local vp: ViewportFrame = UI.make("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	})
	model:PivotTo(CFrame.new())
	model.Parent = vp
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = vp
	vp.CurrentCamera = camera
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	local angle = math.rad(-35)
	local function place(a: number)
		local offset = Vector3.new(math.sin(a), 0.35, -math.cos(a)).Unit * distance
		camera.CFrame = CFrame.lookAt(cf.Position + offset, cf.Position)
	end
	place(angle)
	if spin then
		task.spawn(function()
			while vp.Parent do
				angle += 0.03
				place(angle)
				task.wait(1 / 30)
			end
		end)
	end
	return vp
end

export type Panel = {
	frame: Frame,
	content: Frame,
	tabs: Frame,
	title: TextLabel,
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
}

local openPanel: Panel? = nil

-- Centered modal window with a candy-striped header and close button.
function UI.panel(screen: ScreenGui, title: string, color: Color3?): Panel
	local headerColor = color or UI.Theme.Red
	local frame: Frame = UI.make("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.62, 0.72),
		BackgroundColor3 = UI.Theme.Cream,
		Visible = false,
		Parent = screen,
	})
	UI.corner(frame, 18)
	UI.stroke(frame, UI.Theme.Ink, 4)
	UI.make("UIAspectRatioConstraint", { AspectRatio = 1.45, Parent = frame })
	UI.make("UISizeConstraint", { MaxSize = Vector2.new(980, 680), Parent = frame })
	local scale = UI.make("UIScale", { Parent = frame })

	local header: Frame = UI.make("Frame", {
		Name = "Header",
		Size = UDim2.fromScale(1, 0.13),
		BackgroundColor3 = headerColor,
		Parent = frame,
	})
	UI.corner(header, 18)
	UI.make("Frame", {
		Size = UDim2.fromScale(1, 0.4),
		Position = UDim2.fromScale(0, 0.6),
		BackgroundColor3 = headerColor,
		BorderSizePixel = 0,
		Parent = header,
	})
	-- Candy stripes
	UI.make("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(225, 225, 225)),
		Rotation = 90,
		Parent = header,
	})
	local titleLabel = UI.text({
		Name = "Title",
		Text = title,
		Size = UDim2.fromScale(0.7, 0.8),
		Position = UDim2.fromScale(0.04, 0.1),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 42,
		Parent = header,
	})
	UI.textStroke(titleLabel, UI.Theme.Ink, 2)

	local tabs: Frame = UI.make("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.96, 0.09),
		Position = UDim2.fromScale(0.02, 0.145),
		Parent = frame,
	})
	UI.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.01, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabs,
	})

	local content: Frame = UI.make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.96, 0.73),
		Position = UDim2.fromScale(0.02, 0.25),
		Parent = frame,
	})

	local panel: Panel
	local function close()
		if openPanel == panel then
			openPanel = nil
		end
		UI.tween(scale, UI.FAST, { Scale = 0.8 })
		task.delay(0.1, function()
			if openPanel ~= panel then
				frame.Visible = false
			end
		end)
	end
	local function open()
		if openPanel and openPanel ~= panel then
			openPanel.close()
		end
		openPanel = panel
		frame.Visible = true
		scale.Scale = 0.6
		UI.tween(scale, UI.BOUNCY, { Scale = 1 })
		UI.sound("Pop", 0.4)
	end

	UI.button({
		Name = "Close",
		Text = "X",
		Color = UI.Theme.DarkRed,
		Size = UDim2.fromScale(0.07, 0.75),
		Position = UDim2.fromScale(0.985, 0.5),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = header,
		OnClick = close,
	})
	UI.make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = header:FindFirstChild("Close") })

	panel = {
		frame = frame,
		content = content,
		tabs = tabs,
		title = titleLabel,
		open = open,
		close = close,
		isOpen = function()
			return openPanel == panel
		end,
	}
	return panel
end

function UI.closeAll()
	if openPanel then
		openPanel.close()
	end
end

-- Scrolling grid/list helpers
function UI.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.Theme.Red,
		BorderSizePixel = 0,
		Parent = parent,
	}
	if props then
		for k, v in props do
			defaults[k] = v
		end
	end
	return UI.make("ScrollingFrame", defaults)
end

function UI.card(parent: Instance, props: { [string]: any }?): Frame
	local defaults: { [string]: any } = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, -12, 0, 90),
		Parent = parent,
	}
	if props then
		for k, v in props do
			defaults[k] = v
		end
	end
	local card = UI.make("Frame", defaults)
	UI.corner(card, 12)
	UI.stroke(card, Color3.fromRGB(230, 200, 190), 2)
	return card
end

function UI.tabButton(panel: Panel, text: string, order: number, onClick: () -> ()): TextButton
	local b = UI.button({
		Text = text,
		Color = UI.Theme.Muted,
		Size = UDim2.fromScale(0.19, 1),
		LayoutOrder = order,
		Parent = panel.tabs,
		OnClick = onClick,
		MaxTextSize = 22,
	})
	return b
end

return UI
