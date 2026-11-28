--!strict
-- Packing presents by hand. At their own wrapping table the player gets a
-- small tray: a toy, wrapping paper and a ribbon to drag into an open box.
-- When all three are in, WRAP closes the box, wraps it and ties the bow, and
-- the finished present flies off to the sack. The server decides what each
-- present is worth.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local PlotLayout = require(Shared.PlotLayout)
local Format = require(Shared.Util.Format)

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local Bus = require(Lib.Bus)
local State = require(Lib.State)

local WrapStation = {}

local T = UI.Theme
local player = Players.LocalPlayer

local SHOW_DISTANCE = 15
local TAP_SLOP = 14 -- pixels; a press that barely moves counts as a tap

local TOYS = { "🧸", "🚂", "🤖", "⚽", "🎮", "🚗", "🎸" }
local PAPERS = {
	Color3.fromRGB(214, 48, 58),
	Color3.fromRGB(46, 160, 90),
	Color3.fromRGB(60, 130, 230),
	Color3.fromRGB(150, 90, 210),
	Color3.fromRGB(240, 120, 170),
}
local CARDBOARD = Color3.fromRGB(205, 155, 100)
local CARDBOARD_DARK = Color3.fromRGB(120, 82, 50)

type Tile = {
	button: TextButton,
	home: UDim2,
	slot: GuiObject,
	packed: boolean,
}
type Drag = { tile: Tile, input: InputObject, grab: Vector2, start: Vector2 }

local screen: ScreenGui
local tray: Frame
local hint: TextLabel
local wrapButton: TextButton
local boxHolder: Frame
local boxHome: UDim2
local boxScale: UIScale
local lid: Frame
local paper: Frame
local ribbonV: Frame
local ribbonH: Frame
local bow: TextLabel
local toyLabel: TextLabel
local toySlot: TextLabel
local paperSwatch: Frame
local paperSlot: Frame
local tiles: { Tile } = {}

local mode: "packing" | "ready" | "wrapping" = "packing"
local drag: Drag? = nil
local near = false
local flying = false
local streak = 0
local paperColor = PAPERS[1]

local function tablePosition(): Vector3?
	local index = player:GetAttribute("Plot")
	if typeof(index) ~= "number" then
		return nil
	end
	return (PlotLayout.plotCFrame(index, Config.MAX_PLOTS) * PlotLayout.WRAP_TABLE).Position
end

local function setHint(text: string)
	if hint.Text ~= text then
		hint.Text = text
	end
end

local function floatText(text: string)
	local label = UI.text({
		Text = text,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.62),
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
		{ Position = UDim2.fromScale(0.5, 0.5), TextTransparency = 1 }
	)
	task.delay(1, function()
		label:Destroy()
	end)
end

local function sparkles()
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local star = UI.text({
			Text = if i % 2 == 0 then "✨" else "⭐",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.3, 0.3),
			ZIndex = 9,
			Parent = boxHolder,
		})
		UI.tween(star, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.95, 0.5 + math.sin(angle) * 0.95),
			TextTransparency = 1,
			Rotation = 180,
		})
		task.delay(0.6, function()
			star:Destroy()
		end)
	end
end

-- Fresh open box and three new things to pack.
local function reset()
	mode = "packing"
	drag = nil
	paperColor = PAPERS[math.random(1, #PAPERS)]
	toyLabel.Text = TOYS[math.random(1, #TOYS)]
	toySlot.Text = toyLabel.Text
	paperSwatch.BackgroundColor3 = paperColor
	paperSlot.BackgroundColor3 = paperColor
	paper.BackgroundColor3 = paperColor
	for i, tile in tiles do
		tile.packed = false
		tile.slot.Visible = false
		tile.button.Position = tile.home
		tile.button.Visible = true
		tile.button.ZIndex = 2
		task.delay((i - 1) * 0.06, UI.pop, tile.button, 0.6)
	end
	lid.Visible = false
	paper.Size = UDim2.fromScale(0, 0.88)
	ribbonV.Size = UDim2.fromScale(0.14, 0)
	ribbonH.Size = UDim2.fromScale(0, 0.12)
	bow.Visible = false
	boxHolder.Rotation = 0
	boxHolder.Position = boxHome
	boxScale.Scale = 0.5
	UI.tween(boxScale, UI.BOUNCY, { Scale = 1 })
	wrapButton.Visible = false
	setHint("Drag everything into the box")
end

local function packedCount(): number
	local n = 0
	for _, tile in tiles do
		if tile.packed then
			n += 1
		end
	end
	return n
end

local function pack(tile: Tile)
	if tile.packed or mode ~= "packing" then
		return
	end
	tile.packed = true
	local button = tile.button
	-- Slide into the box, then show the item peeking out of it.
	local target = boxHolder.AbsolutePosition
		+ boxHolder.AbsoluteSize * Vector2.new(0.5, 0.25)
		- button.AbsoluteSize / 2
		- tray.AbsolutePosition
	local slide =
		UI.tween(button, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(target.X, target.Y),
		})
	local count = packedCount()
	UI.sound("Pop", 0.4, 0.9 + count * 0.12)
	slide.Completed:Once(function()
		button.Visible = false
		tile.slot.Visible = true
		UI.pop(tile.slot, 1.5)
		UI.pop(boxHolder, 1.08)
	end)
	if count >= #tiles then
		mode = "ready"
		task.delay(0.2, function()
			if mode ~= "ready" then
				return
			end
			wrapButton.Visible = true
			UI.pop(wrapButton, 1.3)
			setHint("Now press WRAP!")
		end)
	end
end

local function sendHome(tile: Tile)
	tile.button.ZIndex = 2
	UI.tween(tile.button, UI.BOUNCY, { Position = tile.home })
end

local function wrap()
	if mode ~= "ready" then
		return
	end
	local profile = State.profile()
	if profile and profile.sack >= Economy.sackCapacity(profile.sackLevel) then
		setHint("Your sack is full. Load your sleigh first!")
		UI.pop(hint, 1.15)
		UI.sound("Error", 0.35)
		return
	end
	mode = "wrapping"
	wrapButton.Visible = false
	setHint("Wrapping...")

	local ok: boolean, data: any = false, nil
	local answered = false
	task.spawn(function()
		ok, data = Net.request("Wrap")
		answered = true
	end)

	-- 1. The lid drops on.
	for _, tile in tiles do
		tile.slot.Visible = false
	end
	lid.Position = UDim2.fromScale(-0.04, -0.5)
	lid.Visible = true
	UI.tween(lid, TweenInfo.new(0.22, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(-0.04, 0.12),
	})
	UI.sound("Click", 0.4, 0.8)
	task.wait(0.25)

	-- 2. Paper sweeps across while the box shakes.
	UI.tween(paper, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Size = UDim2.fromScale(1.08, 0.88),
	})
	for i = 1, 5 do
		UI.tween(boxHolder, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {
			Rotation = if i % 2 == 0 then -7 else 7,
		})
		UI.sound("Pop", 0.2, 1.2 + i * 0.06)
		task.wait(0.1)
	end
	UI.tween(boxHolder, UI.FAST, { Rotation = 0 })

	-- 3. Ribbon round both ways, then the bow.
	UI.tween(ribbonV, UI.SMOOTH, { Size = UDim2.fromScale(0.14, 0.88) })
	task.wait(0.12)
	UI.tween(ribbonH, UI.SMOOTH, { Size = UDim2.fromScale(1.08, 0.12) })
	task.wait(0.2)
	bow.Visible = true
	UI.pop(bow, 2.2)
	UI.pop(boxHolder, 1.2)
	UI.sound("Star", 0.45)
	sparkles()
	task.wait(0.4)

	-- 4. Off it goes to the sack.
	UI.tween(boxHolder, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = boxHome + UDim2.fromScale(0.25, -1.6),
		Rotation = 40,
	})
	UI.tween(boxScale, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0.25,
	})
	task.wait(0.35)

	local waited = 0
	while not answered and waited < 2 do
		waited += task.wait()
	end
	if ok and typeof(data) == "number" then
		streak += 1
		UI.sound("Coin", 0.4, 1 + math.min(streak, 10) * 0.03)
		floatText(`+{Format.short(data)} 🎁`)
		Bus.fire("Wrapped")
	elseif typeof(data) == "string" then
		streak = 0
		Bus.fire("Toast", data, "error")
	end
	reset()
end

local function inputPoint(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

local function overBox(tile: Tile): boolean
	local centre = tile.button.AbsolutePosition + tile.button.AbsoluteSize / 2
	local pos = boxHolder.AbsolutePosition
	local size = boxHolder.AbsoluteSize
	local margin = size.X * 0.2
	return centre.X > pos.X - margin
		and centre.X < pos.X + size.X + margin
		and centre.Y > pos.Y - margin
		and centre.Y < pos.Y + size.Y + margin
end

local function endDrag(input: InputObject)
	local d = drag
	if not d then
		return
	end
	drag = nil
	local tapped = (inputPoint(input) - d.start).Magnitude < TAP_SLOP
	if tapped or overBox(d.tile) then
		pack(d.tile)
	else
		sendHome(d.tile)
		UI.sound("Click", 0.25, 0.8)
	end
end

local function makeTile(index: number): TextButton
	local button: TextButton = UI.make("TextButton", {
		Name = "Item" .. index,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = T.Cream,
		Position = UDim2.fromScale(0.03 + (index - 1) * 0.185, 0.3),
		Size = UDim2.fromScale(0.165, 0.56),
		ZIndex = 2,
		Parent = tray,
	})
	UI.make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = button })
	UI.corner(button, 14)
	UI.stroke(button, T.Ink, 2.5)
	return button
end

local function build()
	screen = UI.screen("Wrap", 5)
	tray = UI.make("Frame", {
		Name = "PackingTray",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.97),
		Size = UDim2.fromScale(0.46, 0.27),
		BackgroundColor3 = Color3.fromRGB(30, 22, 30),
		BackgroundTransparency = 0.35,
		Visible = false,
		Parent = screen,
	})
	UI.make(
		"UISizeConstraint",
		{ MinSize = Vector2.new(330, 150), MaxSize = Vector2.new(600, 230), Parent = tray }
	)
	UI.corner(tray, 18)
	UI.stroke(tray, T.Gold, 2)
	hint = UI.text({
		Text = "Drag everything into the box",
		Position = UDim2.fromScale(0.04, 0.05),
		Size = UDim2.fromScale(0.92, 0.17),
		MaxTextSize = 22,
		Parent = tray,
	})
	UI.textStroke(hint, T.Ink, 1.5)

	-- The three things to pack.
	local toyButton = makeTile(1)
	toyLabel = UI.text({
		Text = TOYS[1],
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.1, 0.1),
		MaxTextSize = 70,
		Parent = toyButton,
	})
	local paperButton = makeTile(2)
	paperSwatch = UI.make("Frame", {
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.15, 0.15),
		BackgroundColor3 = paperColor,
		Rotation = -8,
		Parent = paperButton,
	})
	UI.corner(paperSwatch, 6)
	UI.stroke(paperSwatch, T.Ink, 1.5)
	UI.text({
		Text = "✦ ✦\n✦ ✦",
		TextTransparency = 0.25,
		MaxTextSize = 22,
		Parent = paperSwatch,
	})
	local ribbonButton = makeTile(3)
	UI.text({
		Text = "🎀",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.1, 0.1),
		MaxTextSize = 70,
		Parent = ribbonButton,
	})

	-- The box.
	boxHome = UDim2.fromScale(0.8, 0.6)
	boxHolder = UI.make("Frame", {
		Name = "Box",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = boxHome,
		Size = UDim2.fromScale(0.3, 0.7),
		BackgroundTransparency = 1,
		Parent = tray,
	})
	UI.make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = boxHolder })
	boxScale = UI.make("UIScale", { Name = "PopScale", Parent = boxHolder })
	local inside: Frame = UI.make("Frame", {
		Position = UDim2.fromScale(0.05, 0.16),
		Size = UDim2.fromScale(0.9, 0.3),
		BackgroundColor3 = CARDBOARD_DARK,
		Parent = boxHolder,
	})
	UI.corner(inside, 6)
	toySlot = UI.text({
		Text = TOYS[1],
		Position = UDim2.fromScale(0.02, 0),
		Size = UDim2.fromScale(0.42, 0.48),
		MaxTextSize = 60,
		ZIndex = 2,
		Visible = false,
		Parent = boxHolder,
	})
	paperSlot = UI.make("Frame", {
		Position = UDim2.fromScale(0.42, 0.06),
		Size = UDim2.fromScale(0.26, 0.36),
		BackgroundColor3 = paperColor,
		Rotation = 10,
		ZIndex = 2,
		Visible = false,
		Parent = boxHolder,
	})
	UI.corner(paperSlot, 4)
	UI.stroke(paperSlot, T.Ink, 1.5)
	local ribbonSlot = UI.text({
		Text = "🎀",
		Position = UDim2.fromScale(0.62, 0.02),
		Size = UDim2.fromScale(0.36, 0.42),
		MaxTextSize = 50,
		ZIndex = 2,
		Visible = false,
		Parent = boxHolder,
	})
	local body: Frame = UI.make("Frame", {
		Position = UDim2.fromScale(0, 0.3),
		Size = UDim2.fromScale(1, 0.7),
		BackgroundColor3 = CARDBOARD,
		ZIndex = 3,
		Parent = boxHolder,
	})
	UI.corner(body, 8)
	UI.stroke(body, CARDBOARD_DARK, 3)
	UI.gradient(body, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	lid = UI.make("Frame", {
		Position = UDim2.fromScale(-0.04, 0.12),
		Size = UDim2.fromScale(1.08, 0.22),
		BackgroundColor3 = CARDBOARD,
		ZIndex = 4,
		Visible = false,
		Parent = boxHolder,
	})
	UI.corner(lid, 6)
	UI.stroke(lid, CARDBOARD_DARK, 3)
	paper = UI.make("Frame", {
		Position = UDim2.fromScale(-0.04, 0.12),
		Size = UDim2.fromScale(0, 0.88),
		BackgroundColor3 = paperColor,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = boxHolder,
	})
	UI.corner(paper, 8)
	UI.gradient(paper, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	ribbonV = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.fromScale(0.14, 0),
		BackgroundColor3 = T.Gold,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = boxHolder,
	})
	ribbonH = UI.make("Frame", {
		Position = UDim2.fromScale(-0.04, 0.5),
		Size = UDim2.fromScale(0, 0.12),
		BackgroundColor3 = T.Gold,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = boxHolder,
	})
	bow = UI.text({
		Text = "🎀",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.fromScale(0.6, 0.5),
		MaxTextSize = 70,
		ZIndex = 7,
		Visible = false,
		Parent = boxHolder,
	})

	wrapButton = UI.button({
		Name = "WrapButton",
		Text = "🎁 WRAP!",
		Color = T.Red,
		Position = UDim2.fromScale(0.05, 0.32),
		Size = UDim2.fromScale(0.5, 0.52),
		MaxTextSize = 48,
		Parent = tray,
		OnClick = function()
			task.spawn(wrap)
		end,
	})
	UI.stroke(wrapButton, T.Gold, 3)
	wrapButton.ZIndex = 8
	wrapButton.Visible = false

	local slots: { GuiObject } = { toySlot, paperSlot, ribbonSlot }
	for i, button in { toyButton, paperButton, ribbonButton } do
		local tile: Tile =
			{ button = button, home = button.Position, slot = slots[i], packed = false }
		tiles[i] = tile
		button.InputBegan:Connect(function(input)
			if
				mode ~= "packing"
				or tile.packed
				or drag
				or (
					input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch
				)
			then
				return
			end
			local point = inputPoint(input)
			drag = {
				tile = tile,
				input = input,
				grab = point - button.AbsolutePosition,
				start = point,
			}
			button.ZIndex = 10
			UI.pop(button, 1.15)
			UI.sound("Click", 0.3, 1.2)
		end)
	end
end

function WrapStation.init()
	build()
	UserInputService.InputChanged:Connect(function(input)
		local d = drag
		if not d then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input == d.input then
			local at = inputPoint(input) - d.grab - tray.AbsolutePosition
			d.tile.button.Position = UDim2.fromOffset(at.X, at.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local d = drag
		if not d then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input == d.input then
			endDrag(input)
		end
	end)
	-- Keyboard and gamepad: E / X packs the next thing, then wraps.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not tray.Visible then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.E and input.KeyCode ~= Enum.KeyCode.ButtonX then
			return
		end
		if mode == "ready" then
			task.spawn(wrap)
		elseif mode == "packing" and not drag then
			for _, tile in tiles do
				if not tile.packed then
					pack(tile)
					break
				end
			end
		end
	end)
	Bus.on("Flying", function(value: boolean)
		flying = value
	end)
	reset()
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
			if near then
				UI.pop(tray, 1.12)
			else
				streak = 0
				local d = drag
				if d then
					drag = nil
					sendHome(d.tile)
				end
			end
		end
		tray.Visible = near and not UI.anyPanelOpen()
	end)
end

return WrapStation
