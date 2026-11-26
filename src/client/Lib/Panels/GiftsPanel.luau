--!strict
-- Gifts menu: 7-day login streak, the Advent calendar, and playtime gifts.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Calendar = require(Shared.Calendar)
local Format = require(Shared.Util.Format)

local Lib = script.Parent.Parent
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local Bus = require(Lib.Bus)
local State = require(Lib.State)

local GiftsPanel = {}

local T = UI.Theme
local REWARD_EMOJI = {
	coins = "⭐",
	snowflakes = "❄",
	boost = "☕",
	eggToken = "🎟",
	cosmetic = "🧶",
	pet = "🦌",
}

local function claimed(ok: boolean, data: any)
	if ok and typeof(data) == "table" then
		Bus.fire("Announce", `🎁 {data.label}!`, T.Gold)
		UI.sound("Coin", 0.6, 1.2)
	elseif typeof(data) == "string" then
		Bus.fire("Toast", data, "error")
	end
end

function GiftsPanel.build(screen: ScreenGui)
	local panel = UI.panel(screen, "🎁 Gifts", T.Green)
	local pages: { [string]: Frame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local function show(name: string)
		for key, page in pages do
			page.Visible = key == name
			UI.setButton(tabButtons[key], nil, if key == name then T.Green else T.Muted)
		end
	end
	for i, name in { "Daily", "Advent", "Playtime" } do
		pages[name] = UI.make("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			Parent = panel.content,
		})
		tabButtons[name] = UI.tabButton(panel, name, i, function()
			show(name)
		end)
	end

	------------------------------------------------------------------- daily
	local daily = pages.Daily
	local streakLabel = UI.text({
		Text = "",
		Size = UDim2.fromScale(1, 0.14),
		TextColor3 = T.Ink,
		MaxTextSize = 30,
		Parent = daily,
	})
	local row: Frame = UI.make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.48),
		Position = UDim2.fromScale(0, 0.16),
		Parent = daily,
	})
	UI.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.01, 0),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = row,
	})
	local dayCards: { Frame } = {}
	for i, reward in Config.DAILY_STREAK do
		local card = UI.card(row, { Size = UDim2.fromScale(0.13, 1), LayoutOrder = i })
		UI.text({
			Text = `Day {i}`,
			Size = UDim2.fromScale(0.9, 0.18),
			Position = UDim2.fromScale(0.05, 0.03),
			TextColor3 = T.Ink,
			MaxTextSize = 20,
			Parent = card,
		})
		UI.text({
			Text = REWARD_EMOJI[reward.kind] or "🎁",
			Size = UDim2.fromScale(0.8, 0.38),
			Position = UDim2.fromScale(0.1, 0.22),
			Parent = card,
		})
		UI.text({
			Text = reward.label,
			Size = UDim2.fromScale(0.92, 0.32),
			Position = UDim2.fromScale(0.04, 0.63),
			TextColor3 = T.Muted,
			FontFace = UI.BodyFont,
			TextWrapped = true,
			MaxTextSize = 14,
			Parent = card,
		})
		dayCards[i] = card
	end
	local dailyButton = UI.button({
		Text = "Claim!",
		Size = UDim2.fromScale(0.36, 0.14),
		Position = UDim2.fromScale(0.5, 0.72),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = daily,
		OnClick = function()
			claimed(Net.request("ClaimDaily"))
		end,
	})
	UI.text({
		Text = "Log in every day to grow your streak. Miss a day and it starts over!",
		Size = UDim2.fromScale(0.9, 0.08),
		Position = UDim2.fromScale(0.05, 0.89),
		TextColor3 = T.Muted,
		FontFace = UI.BodyFont,
		MaxTextSize = 16,
		Parent = daily,
	})

	------------------------------------------------------------------ advent
	local advent = pages.Advent
	local adventTitle = UI.text({
		Text = "",
		Size = UDim2.fromScale(0.6, 0.1),
		TextColor3 = T.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		Parent = advent,
	})
	local adventButton = UI.button({
		Text = "Open Today's Door",
		Color = T.Red,
		Size = UDim2.fromScale(0.36, 0.1),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Parent = advent,
		OnClick = function()
			claimed(Net.request("ClaimAdvent"))
		end,
	})
	local doorGrid: Frame = UI.make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.86),
		Position = UDim2.fromScale(0, 0.13),
		Parent = advent,
	})
	UI.make("UIGridLayout", {
		CellSize = UDim2.fromScale(0.135, 0.17),
		CellPadding = UDim2.fromScale(0.01, 0.02),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = doorGrid,
	})
	local doors: { { frame: Frame, label: TextLabel } } = {}
	for day = 1, Config.EVENT.ADVENT_LAST_DAY do
		local special = Config.ADVENT_SPECIAL[day]
		local frame: Frame = UI.make("Frame", {
			BackgroundColor3 = if special then T.Gold else T.Red,
			LayoutOrder = day,
			Parent = doorGrid,
		})
		UI.corner(frame, 8)
		UI.stroke(frame, T.Ink, 2)
		local label = UI.text({
			Text = tostring(day),
			Size = UDim2.fromScale(0.9, 0.8),
			Position = UDim2.fromScale(0.05, 0.1),
			MaxTextSize = 26,
			Parent = frame,
		})
		UI.textStroke(label, T.Ink, 1.5)
		doors[day] = { frame = frame, label = label }
	end

	---------------------------------------------------------------- playtime
	local playtime = UI.scroll(pages.Playtime)
	UI.make(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = playtime }
	)
	local playRows: { { title: TextLabel, button: TextButton } } = {}
	for i, gift in Config.PLAYTIME_GIFTS do
		local card = UI.card(playtime, { Size = UDim2.new(1, -12, 0, 70), LayoutOrder = i })
		UI.text({
			Text = REWARD_EMOJI[gift.reward.kind] or "🎁",
			Size = UDim2.new(0, 56, 0, 56),
			Position = UDim2.new(0, 10, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Parent = card,
		})
		local title = UI.text({
			Text = "",
			Size = UDim2.new(0.6, -80, 0.8, 0),
			Position = UDim2.new(0, 76, 0.1, 0),
			TextColor3 = T.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
			Parent = card,
		})
		local button = UI.button({
			Text = "",
			Size = UDim2.new(0.3, 0, 0, 48),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Parent = card,
			MaxTextSize = 20,
			OnClick = function()
				claimed(Net.request("ClaimPlaytime", i))
			end,
		})
		playRows[i] = { title = title, button = button }
	end

	local function refresh(snapshot: any)
		local profile = snapshot.profile
		local now = State.now()
		local today = Calendar.dayNumber(now)
		local canClaim = profile.daily.lastDay ~= today
		local streak = profile.daily.streak
		local continuing = profile.daily.lastDay == today - 1 or profile.daily.lastDay == today
		local nextIndex = if canClaim
			then (if continuing then streak else 0) % #Config.DAILY_STREAK + 1
			else (streak - 1) % #Config.DAILY_STREAK + 1
		streakLabel.Text = if canClaim
			then `🔥 Streak: {if continuing then streak else 0} days · Today's gift is ready!`
			else `🔥 Streak: {streak} days · Next gift in {Format.time(
				Calendar.secondsUntilNextDay(now)
			)}`
		for i, card in dayCards do
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if i == nextIndex then T.Gold else Color3.fromRGB(230, 200, 190)
				stroke.Thickness = if i == nextIndex then 4 else 2
			end
			card.BackgroundColor3 = if not canClaim and i <= nextIndex
				then Color3.fromRGB(220, 245, 220)
				elseif canClaim and i < nextIndex then Color3.fromRGB(220, 245, 220)
				else Color3.new(1, 1, 1)
		end
		UI.setButton(
			dailyButton,
			if canClaim then "Claim!" else "Claimed ✔",
			if canClaim then T.Green else T.Disabled
		)

		local openDay = Calendar.adventDay(now)
		if openDay then
			adventTitle.Text = `🎄 Advent Calendar · Door #{openDay} is open!`
		elseif Calendar.eventActive(now) and Calendar.daysUntilAdvent(now) > 0 then
			adventTitle.Text =
				`🎄 Advent opens in {Calendar.daysUntilAdvent(now)} days (Dec 1-25)`
		else
			adventTitle.Text = "🎄 Advent Calendar (Dec 1-25)"
		end
		local todayOpen = openDay ~= nil and not profile.advent["d" .. openDay]
		UI.setButton(
			adventButton,
			if todayOpen then "Open Today's Door" elseif openDay then "Opened ✔" else "Closed",
			if todayOpen then T.Red else T.Disabled
		)
		for day, door in doors do
			local special = Config.ADVENT_SPECIAL[day]
			if profile.advent["d" .. day] then
				door.frame.BackgroundColor3 = T.Green
				door.label.Text = `✔ {day}`
			elseif openDay and day < openDay then
				door.frame.BackgroundColor3 = T.Disabled
				door.label.Text = tostring(day)
			elseif openDay == day then
				door.frame.BackgroundColor3 = if math.floor(os.clock() * 2) % 2 == 0
					then T.Gold
					else T.Red
				door.label.Text = `🎁 {day}`
			else
				door.frame.BackgroundColor3 = if special
					then Color3.fromRGB(200, 160, 60)
					else T.Red
				door.label.Text = if special
					then `{day} {REWARD_EMOJI[special.kind]}`
					else tostring(day)
			end
		end

		local elapsed = now - snapshot.joinedAt
		for i, gift in Config.PLAYTIME_GIFTS do
			local r = playRows[i]
			r.title.Text = `{gift.minutes} min · {gift.reward.label}`
			if snapshot.playtimeClaimed[tostring(i)] then
				UI.setButton(r.button, "Claimed ✔", T.Disabled)
			elseif elapsed >= gift.minutes * 60 then
				UI.setButton(r.button, "Claim!", T.Green)
			else
				UI.setButton(r.button, Format.time(gift.minutes * 60 - elapsed), T.Muted)
			end
		end
	end

	-- Countdowns tick while open.
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum >= 0.25 and panel.isOpen() and State.data then
			accum = 0
			refresh(State.data)
		end
	end)

	show("Daily")
	return { panel = panel, refresh = refresh, show = show }
end

return GiftsPanel
