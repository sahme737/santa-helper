--!strict
-- Always-on HUD: currencies with count-up, sack meter, menu buttons, the
-- event/rush banner, the server goal bar, toasts and announcements.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Calendar = require(Shared.Calendar)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Where = require(Lib.Where)
local Net = require(Lib.Net)
local State = require(Lib.State)
local Bus = require(Lib.Bus)

local HUD = {}

local T = UI.Theme
local screen: ScreenGui
local coinValue = Instance.new("NumberValue")
local snowValue = Instance.new("NumberValue")
local coinLabel: TextLabel
local incomeLabel: TextLabel
local snowLabel: TextLabel
local boostChip: TextLabel
local sackFill: Frame
local sackLabel: TextLabel
local sackFrame: Frame
local bannerLabel: TextLabel
local rushLabel: TextLabel
local rushFrame: Frame
local goalFill: Frame
local goalLabel: TextLabel
local toastHolder: Frame
local announceLabel: TextLabel
local giftBadge: Frame
local coinFrame: Frame
local rankLabel: TextLabel
local rankFill: Frame
local rankFrame: Frame
local musicButton: TextButton
local snowFrame: Frame
local topFrame: Frame
local goalFrame: Frame
local lastRank = 0
local flying = false
-- How much of the HUD is shown; grows with Economy.stage so new helpers see
-- only their Cheer and their sack.
local stage = -1
local menuButtons: { { button: TextButton, stage: number } } = {}

local function counter(
	parent: Instance,
	order: number,
	emoji: string,
	color: Color3
): (Frame, TextLabel, TextLabel?)
	local frame: Frame = UI.make("Frame", {
		Size = UDim2.fromScale(1, 0.3),
		BackgroundColor3 = Color3.fromRGB(40, 25, 30),
		BackgroundTransparency = 0.25,
		LayoutOrder = order,
		Parent = parent,
	})
	UI.corner(frame, 14)
	UI.stroke(frame, color, 2.5)
	local icon = UI.text({
		Text = emoji,
		Size = UDim2.fromScale(0.22, 0.9),
		Position = UDim2.fromScale(0.02, 0.05),
		Parent = frame,
	})
	icon.TextXAlignment = Enum.TextXAlignment.Center
	local value = UI.text({
		Text = "0",
		Size = UDim2.fromScale(0.72, 0.62),
		Position = UDim2.fromScale(0.25, 0.04),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		MaxTextSize = 34,
		Parent = frame,
	})
	UI.textStroke(value, T.Ink, 2)
	local sub = UI.text({
		Text = "",
		Size = UDim2.fromScale(0.72, 0.32),
		Position = UDim2.fromScale(0.25, 0.64),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(230, 230, 230),
		FontFace = UI.BodyFont,
		MaxTextSize = 16,
		Parent = frame,
	})
	return frame, value, sub
end

function HUD.toast(text: string, kind: string?)
	local color = if kind == "error"
		then T.Red
		elseif kind == "success" then T.Green
		elseif kind == "event" then T.Purple
		else Color3.fromRGB(60, 50, 70)
	local frame: Frame = UI.make("Frame", {
		Size = UDim2.fromScale(1, 0.3),
		BackgroundColor3 = color,
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = toastHolder,
	})
	UI.corner(frame, 12)
	UI.stroke(frame, T.Ink, 2)
	local label = UI.text({
		Text = text,
		Size = UDim2.fromScale(0.94, 0.8),
		Position = UDim2.fromScale(0.03, 0.1),
		MaxTextSize = 24,
		Parent = frame,
	})
	UI.textStroke(label, T.Ink, 1.5)
	UI.pop(frame, 0.7)
	if kind == "error" then
		UI.sound("Error", 0.4)
	elseif kind == "success" then
		UI.sound("Purchase", 0.45)
	elseif kind == "event" then
		UI.sound("Star", 0.4)
	end
	task.delay(3.2, function()
		UI.tween(frame, UI.SMOOTH, { BackgroundTransparency = 1 })
		UI.tween(label, UI.SMOOTH, { TextTransparency = 1 })
		task.wait(0.35)
		frame:Destroy()
	end)
	local children = toastHolder:GetChildren()
	local frames = {}
	for _, c in children do
		if c:IsA("Frame") then
			table.insert(frames, c)
		end
	end
	if #frames > 3 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
end

function HUD.announce(text: string, color: Color3?)
	announceLabel.Text = text
	announceLabel.TextColor3 = color or T.Gold
	announceLabel.Visible = true
	announceLabel.TextTransparency = 0
	local stroke = announceLabel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end
	UI.pop(announceLabel, 0.5)
	task.delay(2.6, function()
		if announceLabel.Text ~= text then
			return
		end
		UI.tween(announceLabel, UI.SMOOTH, { TextTransparency = 1 })
		if stroke then
			UI.tween(stroke, UI.SMOOTH, { Transparency = 1 })
		end
		task.delay(0.6, function()
			if announceLabel.Text == text then
				announceLabel.Visible = false
			end
		end)
	end)
end

-- Floating "+123" that rises from the cheer counter.
function HUD.floatGain(text: string, color: Color3?)
	local label = UI.text({
		Text = text,
		Size = UDim2.fromScale(0.25, 0.06),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.98, 0.2),
		TextColor3 = color or T.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 40,
		Parent = screen,
	})
	UI.textStroke(label, T.Ink, 2.5)
	UI.pop(label, 1.6)
	UI.tween(
		label,
		TweenInfo.new(1.4, Enum.EasingStyle.Quad),
		{ Position = UDim2.fromScale(0.98, 0.12), TextTransparency = 1 }
	)
	task.delay(1.5, function()
		label:Destroy()
	end)
end

local function menuButton(
	parent: Instance,
	order: number,
	emoji: string,
	text: string,
	color: Color3,
	onClick: () -> ()
): TextButton
	local b = UI.button({
		Text = "",
		Color = color,
		Size = UDim2.fromScale(1, 0.115),
		LayoutOrder = order,
		Parent = parent,
		OnClick = onClick,
	})
	UI.make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = b })
	local label = b:FindFirstChild("Label") :: TextLabel
	label.Text = emoji
	label.Size = UDim2.fromScale(0.8, 0.62)
	label.Position = UDim2.fromScale(0.1, 0.04)
	local caption = UI.text({
		Text = text,
		Size = UDim2.fromScale(1, 0.3),
		Position = UDim2.fromScale(0, 0.68),
		MaxTextSize = 14,
		Parent = b,
	})
	UI.textStroke(caption, T.Ink, 1.2)
	b.Visible = false
	return b
end

local function applyStage(newStage: number)
	if newStage == stage then
		return
	end
	local first = stage < 0
	stage = newStage
	for _, entry in menuButtons do
		local visible = stage >= entry.stage
		if visible and not entry.button.Visible and not first then
			entry.button.Visible = true
			UI.pop(entry.button, 1.3)
		else
			entry.button.Visible = visible
		end
	end
	snowFrame.Visible = stage >= Economy.STAGE_ALL
	goalFrame.Visible = stage >= Economy.STAGE_ALL
	topFrame.Visible = stage >= Economy.STAGE_ALL and not flying
end

local function build()
	screen = UI.screen("HUD", 5)

	-- Roblox chat sits top-left and the default player list top-right, so the
	-- currencies take the top-right corner and the player list is hidden (the
	-- world leaderboards replace it).
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	-- Currencies (top-right)
	local left: Frame = UI.make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromScale(0.24, 0.26),
		Parent = screen,
	})
	UI.make("UISizeConstraint", { MaxSize = Vector2.new(320, 260), Parent = left })
	UI.make(
		"UIListLayout",
		{ Padding = UDim.new(0.025, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left }
	)
	local cf, cl, il = counter(left, 1, "⭐", T.Gold)
	coinFrame = cf
	coinLabel = cl
	incomeLabel = il :: TextLabel
	local sf, sl, ssub = counter(left, 2, "❄", Color3.fromRGB(150, 210, 255))
	snowFrame = sf
	snowLabel = sl;
	(ssub :: TextLabel).Text = "Snowflakes"

	-- Sack meter
	sackFrame = UI.make("Frame", {
		Size = UDim2.fromScale(1, 0.2),
		BackgroundColor3 = Color3.fromRGB(40, 25, 30),
		BackgroundTransparency = 0.25,
		LayoutOrder = 3,
		Parent = left,
	})
	UI.corner(sackFrame, 12)
	UI.stroke(sackFrame, T.Green, 2.5)
	local bar: Frame = UI.make("Frame", {
		Size = UDim2.fromScale(0.96, 0.5),
		Position = UDim2.fromScale(0.02, 0.45),
		BackgroundColor3 = Color3.fromRGB(70, 50, 55),
		Parent = sackFrame,
	})
	UI.corner(bar, 8)
	sackFill =
		UI.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Green, Parent = bar })
	UI.corner(sackFill, 8)
	UI.gradient(sackFill, Color3.fromRGB(140, 255, 160), T.Green)
	sackLabel = UI.text({
		Text = "🎁 Sack",
		Size = UDim2.fromScale(0.96, 0.42),
		Position = UDim2.fromScale(0.02, 0.02),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = sackFrame,
	})
	UI.textStroke(sackLabel, T.Ink, 1.5)

	boostChip = UI.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.12),
		LayoutOrder = 4,
		TextColor3 = Color3.fromRGB(255, 200, 150),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Visible = false,
		Parent = left,
	})
	UI.textStroke(boostChip, T.Ink, 1.5)

	-- Menu buttons (left side)
	local menu: Frame = UI.make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.64, 0),
		Size = UDim2.fromScale(0.075, 0.6),
		Parent = screen,
	})
	UI.make(
		"UISizeConstraint",
		{ MaxSize = Vector2.new(84, 600), MinSize = Vector2.new(46, 200), Parent = menu }
	)
	UI.make(
		"UIListLayout",
		{ Padding = UDim.new(0.012, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu }
	)
	local function add(unlock: number, button: TextButton)
		table.insert(menuButtons, { button = button, stage = unlock })
	end
	add(
		Economy.STAGE_ELVES,
		menuButton(menu, 1, "🔨", "Workshop", T.Red, function()
			Bus.fire("OpenMenu", "Workshop")
		end)
	)
	add(
		Economy.STAGE_ALL,
		menuButton(menu, 2, "🦌", "Reindeer", Color3.fromRGB(150, 100, 60), function()
			Bus.fire("OpenMenu", "Pets")
		end)
	)
	local gifts = menuButton(menu, 3, "🎁", "Gifts", T.Green, function()
		Bus.fire("OpenMenu", "Gifts")
	end)
	add(Economy.STAGE_ALL, gifts)
	giftBadge = UI.make("Frame", {
		Size = UDim2.fromScale(0.3, 0.3),
		Position = UDim2.fromScale(0.78, -0.08),
		BackgroundColor3 = Color3.fromRGB(255, 60, 60),
		Visible = false,
		Parent = gifts,
	})
	UI.corner(giftBadge, 100)
	UI.stroke(giftBadge, Color3.new(1, 1, 1), 2)
	UI.text({ Text = "!", Parent = giftBadge })
	add(
		Economy.STAGE_ALL,
		menuButton(menu, 4, "🧶", "Wardrobe", T.Purple, function()
			Bus.fire("OpenMenu", "Wardrobe")
		end)
	)
	add(
		Economy.STAGE_FLY,
		menuButton(menu, 5, "🛷", "Deliver", T.Blue, function()
			Bus.fire("StartDelivery")
		end)
	)
	-- The store sells playground extras too, so it is there from the start.
	add(
		0,
		menuButton(menu, 6, "💎", "Store", Color3.fromRGB(230, 160, 30), function()
			Bus.fire("OpenMenu", "Store")
		end)
	)
	-- The list of games (and the way back to the plaza) is always there.
	add(
		0,
		menuButton(menu, 0, "🎡", "Games", Color3.fromRGB(70, 150, 220), function()
			Bus.fire("OpenPlay")
		end)
	)

	-- Top center banner
	local top: Frame = UI.make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromScale(0.36, 0.11),
		Parent = screen,
	})
	UI.make("UISizeConstraint", { MaxSize = Vector2.new(520, 110), Parent = top })
	top.Visible = false
	topFrame = top
	-- The flight HUD takes this spot while the sleigh is in the air.
	Bus.on("Flying", function(value: boolean)
		flying = value
		top.Visible = not value and stage >= Economy.STAGE_ALL
	end)
	bannerLabel = UI.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.38),
		TextColor3 = Color3.new(1, 1, 1),
		MaxTextSize = 20,
		Parent = top,
	})
	UI.textStroke(bannerLabel, T.Ink, 1.5)
	rushFrame = UI.make("Frame", {
		Size = UDim2.fromScale(0.9, 0.55),
		Position = UDim2.fromScale(0.05, 0.42),
		BackgroundColor3 = Color3.fromRGB(40, 25, 30),
		BackgroundTransparency = 0.25,
		Parent = top,
	})
	UI.corner(rushFrame, 12)
	UI.stroke(rushFrame, T.Gold, 2)
	rushLabel = UI.text({
		Text = "",
		Size = UDim2.fromScale(0.94, 0.8),
		Position = UDim2.fromScale(0.03, 0.1),
		MaxTextSize = 24,
		Parent = rushFrame,
	})
	UI.textStroke(rushLabel, T.Ink, 1.5)

	-- Server goal (top right, under the currencies)
	local goal: Frame = UI.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8 + left.AbsoluteSize.Y + 8),
		Size = UDim2.fromScale(0.2, 0.07),
		BackgroundColor3 = Color3.fromRGB(40, 25, 30),
		BackgroundTransparency = 0.25,
		Parent = screen,
	})
	UI.make("UISizeConstraint", { MaxSize = Vector2.new(280, 70), Parent = goal })
	goal.Visible = false
	goalFrame = goal

	-- Helper Rank (under the server goal): level, title and XP bar
	rankFrame = UI.make("Frame", {
		Position = UDim2.new(0, 0, 1, 6),
		Size = UDim2.fromScale(1, 0.95),
		BackgroundColor3 = Color3.fromRGB(40, 25, 30),
		BackgroundTransparency = 0.25,
		Parent = goal,
	})
	UI.corner(rankFrame, 12)
	UI.stroke(rankFrame, T.Gold, 2)
	local rankBar: Frame = UI.make("Frame", {
		Size = UDim2.fromScale(0.92, 0.32),
		Position = UDim2.fromScale(0.04, 0.58),
		BackgroundColor3 = Color3.fromRGB(70, 50, 55),
		Parent = rankFrame,
	})
	UI.corner(rankBar, 6)
	rankFill = UI.make(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Gold, Parent = rankBar }
	)
	UI.corner(rankFill, 6)
	rankLabel = UI.text({
		Text = "Lv.1 Trainee Elf",
		Size = UDim2.fromScale(0.94, 0.48),
		Position = UDim2.fromScale(0.03, 0.04),
		TextColor3 = T.Gold,
		MaxTextSize = 18,
		Parent = rankFrame,
	})
	UI.textStroke(rankLabel, T.Ink, 1.5)

	-- Music on/off, tucked left of the currencies
	musicButton = UI.button({
		Text = "🎵",
		Color = Color3.fromRGB(60, 50, 70),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20 - left.AbsoluteSize.X, 0, 8),
		Size = UDim2.fromOffset(40, 40),
		Parent = screen,
		MaxTextSize = 24,
		OnClick = function()
			Bus.fire("ToggleMusic")
		end,
	})
	left:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		goal.Position = UDim2.new(1, -12, 0, 8 + left.AbsoluteSize.Y + 8)
		musicButton.Position = UDim2.new(1, -20 - left.AbsoluteSize.X, 0, 8)
	end)
	UI.corner(goal, 12)
	UI.stroke(goal, T.Purple, 2)
	goalLabel = UI.text({
		Text = "Server Goal",
		Size = UDim2.fromScale(0.94, 0.45),
		Position = UDim2.fromScale(0.03, 0.03),
		MaxTextSize = 16,
		Parent = goal,
	})
	local goalBar: Frame = UI.make("Frame", {
		Size = UDim2.fromScale(0.92, 0.32),
		Position = UDim2.fromScale(0.04, 0.56),
		BackgroundColor3 = Color3.fromRGB(70, 50, 75),
		Parent = goal,
	})
	UI.corner(goalBar, 8)
	goalFill = UI.make(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Purple, Parent = goalBar }
	)
	UI.corner(goalFill, 8)

	-- Toasts (bottom center)
	toastHolder = UI.make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromScale(0.4, 0.2),
		Parent = screen,
	})
	UI.make("UISizeConstraint", { MaxSize = Vector2.new(560, 200), Parent = toastHolder })
	UI.make("UIListLayout", {
		Padding = UDim.new(0.03, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = toastHolder,
	})

	announceLabel = UI.text({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(0.7, 0.1),
		MaxTextSize = 60,
		Visible = false,
		Parent = screen,
	})
	UI.textStroke(announceLabel, T.Ink, 3)
end

local function giftsAvailable(snapshot: any): boolean
	local profile = snapshot.profile
	local now = State.now()
	if profile.daily.lastDay ~= Calendar.dayNumber(now) then
		return true
	end
	local advent = Calendar.adventDay(now)
	if advent and not profile.advent["d" .. advent] then
		return true
	end
	local elapsed = now - snapshot.joinedAt
	for i, gift in Config.PLAYTIME_GIFTS do
		if not snapshot.playtimeClaimed[tostring(i)] and elapsed >= gift.minutes * 60 then
			return true
		end
	end
	return false
end

local function onState(snapshot: any)
	local profile = snapshot.profile
	applyStage(Economy.stage(profile))
	if math.abs(coinValue.Value - profile.coins) > 0.5 then
		UI.tween(coinValue, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Value = profile.coins })
	end
	if snowValue.Value ~= profile.snowflakes then
		UI.tween(
			snowValue,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad),
			{ Value = profile.snowflakes }
		)
	end
	-- Nothing is earned automatically until an elf is hired to wrap.
	incomeLabel.Text = if profile.elves >= 1
		then `+{Format.short(snapshot.income.total)}/s`
		else "Cheer"
	local capacity = Economy.sackCapacity(profile.sackLevel)
	local fill = math.clamp(profile.sack / capacity, 0, 1)
	UI.tween(sackFill, UI.FAST, { Size = UDim2.fromScale(fill, 1) })
	if fill >= 1 then
		sackLabel.Text = "🎁 Sack full! Load your sleigh"
		sackFill.BackgroundColor3 = T.Red
	else
		sackLabel.Text = `🎁 Sack {Format.short(profile.sack)} / {Format.short(capacity)}`
		sackFill.BackgroundColor3 = T.Green
	end
	giftBadge.Visible = giftsAvailable(snapshot)

	local rank = profile.rank or 1
	local need = Economy.xpForRank(rank)
	local stars = profile.stars or 0
	rankLabel.Text = `Lv.{rank} {Economy.rankTitle(rank)}`
		.. (if stars > 0 then `  ⭐{stars}` else "")
	UI.tween(rankFill, UI.FAST, {
		Size = UDim2.fromScale(
			if rank >= Config.RANK.MAX then 1 else math.clamp((profile.xp or 0) / need, 0, 1),
			1
		),
	})
	if lastRank ~= 0 and rank > lastRank then
		UI.pop(rankFrame, 1.25)
	end
	lastRank = rank
end

local function onHeartbeat()
	coinLabel.Text = Format.short(coinValue.Value)
	snowLabel.Text = Format.short(snowValue.Value)
	local now = State.now()

	local profile = State.profile()
	if profile and profile.boostUntil > now then
		boostChip.Visible = true
		boostChip.Text = `☕ Hot Cocoa x2 · {Format.time(profile.boostUntil - now)}`
	else
		boostChip.Visible = false
	end
	-- The sack only matters while working in the workshop.
	sackFrame.Visible = Where.atWorkshop()
	if profile and State.data then
		local capacity = Economy.sackCapacity(profile.sackLevel)
		sackFrame.BackgroundColor3 = if profile.sack >= capacity
				and math.floor(os.clock() * 2) % 2 == 0
			then Color3.fromRGB(120, 30, 40)
			else Color3.fromRGB(40, 25, 30)
	end

	if Calendar.eventActive(now) then
		bannerLabel.Text =
			`🎄 Christmas Event ends in {Format.time(Calendar.eventSecondsLeft(now))}`
	else
		bannerLabel.Text = "🎄 Merry Christmas from the North Pole!"
	end

	local global = ReplicatedStorage:FindFirstChild("GlobalState")
	if global then
		local cycle = global:GetAttribute("RushCycle") or Config.SLEIGH_RUSH.CYCLE
		local start = global:GetAttribute("CycleStart") or now
		local remaining = math.max(0, cycle - (now - start))
		if global:GetAttribute("Rush") then
			rushLabel.Text =
				`🔥 SLEIGH RUSH! Load for x{Config.SLEIGH_RUSH.MULTIPLIER} · {Format.time(
					remaining
				)}`
			rushLabel.TextColor3 = if math.floor(os.clock() * 3) % 2 == 0
				then T.Gold
				else Color3.new(1, 1, 1)
			rushFrame.BackgroundColor3 = Color3.fromRGB(140, 30, 40)
		else
			rushLabel.Text = `🛷 Santa's sleigh departs in {Format.time(remaining)}`
			rushLabel.TextColor3 = Color3.new(1, 1, 1)
			rushFrame.BackgroundColor3 = Color3.fromRGB(40, 25, 30)
		end
		local total = global:GetAttribute("CommunityTotal") or 0
		local goalAt = global:GetAttribute("CommunityGoal") or Config.COMMUNITY_GOAL.STEP
		local prev = goalAt - Config.COMMUNITY_GOAL.STEP
		goalLabel.Text = `🎁 Server goal: {total - prev}/{Config.COMMUNITY_GOAL.STEP}`
		goalFill.Size =
			UDim2.fromScale(math.clamp((total - prev) / Config.COMMUNITY_GOAL.STEP, 0, 1), 1)
	end
end

function HUD.init()
	build()
end

function HUD.start()
	State.onChanged(onState)
	RunService.Heartbeat:Connect(onHeartbeat)

	Net.on("Toast", function(payload)
		-- Server-wide news waits until the helper knows the game.
		if payload.kind == "event" and stage < Economy.STAGE_ALL then
			return
		end
		HUD.toast(payload.text, payload.kind)
	end)
	Bus.on("Toast", function(text: string, kind: string?)
		HUD.toast(text, kind)
	end)
	Bus.on("Announce", function(text: string, color: Color3?)
		HUD.announce(text, color)
	end)
	Bus.on("FloatGain", function(text: string, color: Color3?)
		HUD.floatGain(text, color)
	end)
	Bus.on("MusicMuted", function(muted: boolean)
		UI.setButton(
			musicButton,
			if muted then "🔇" else "🎵",
			if muted then T.Disabled else Color3.fromRGB(60, 50, 70)
		)
	end)

	Net.on("Effect", function(payload)
		if payload.kind == "Loaded" then
			HUD.floatGain(
				`+{Format.short(payload.amount)}`,
				if payload.rush then Color3.fromRGB(255, 140, 60) else T.Gold
			)
			UI.pop(coinFrame, 1.12)
			UI.sound("Coin", 0.5, if payload.rush then 1.3 else 1)
			if payload.rush and not payload.auto then
				HUD.announce(
					`🔥 RUSH x{Config.SLEIGH_RUSH.MULTIPLIER}! +{Format.short(payload.amount)}`,
					Color3.fromRGB(255, 160, 60)
				)
			end
		elseif payload.kind == "Built" then
			HUD.announce(`🔨 {payload.name}!`, T.Gold)
		elseif payload.kind == "Rebirth" then
			HUD.announce(`⭐ NEW SEASON #{payload.rebirths}! ⭐`, T.Gold)
		elseif payload.kind == "Community" and stage >= Economy.STAGE_ALL then
			HUD.announce("🎉 SERVER GOAL REACHED! 🎉", Color3.fromRGB(200, 150, 255))
		elseif payload.kind == "RankUp" and stage >= Economy.STAGE_ALL then
			HUD.announce(`🎖 Rank up! Lv.{payload.rank} {payload.title}`, T.Gold)
		end
	end)

	Net.on("Announce", function(payload)
		if stage < Economy.STAGE_ALL then
			return
		end
		if payload.kind == "RushStart" then
			HUD.announce("🔥 SLEIGH RUSH! Load your sack for x2!", Color3.fromRGB(255, 160, 60))
		elseif payload.kind == "SleighDeparted" then
			HUD.toast("🛷 Santa's sleigh took off! Next one is on its way.", "info")
		elseif payload.kind == "PresentDrop" then
			HUD.announce("🎁 A PRESENT DROP landed in the plaza!", T.Gold)
		elseif payload.kind == "GiftWaiting" then
			HUD.toast("🎁 Your daily gift is waiting! Tap Gifts.", "success")
		end
	end)
end

return HUD
