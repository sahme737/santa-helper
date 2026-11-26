--!strict
-- Reindeer menu: inventory grid with a detail pane (equip, evolve, release,
-- gift), the egg shop with visible odds, and the hatch reveal animation.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)
local ReindeerModel = require(Shared.Models.ReindeerModel)

local Lib = script.Parent.Parent
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local Bus = require(Lib.Bus)
local State = require(Lib.State)

local PetsPanel = {}

local T = UI.Theme
local RARITY_ORDER =
	{ Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Exclusive = 7 }

local function toast(ok: boolean, msg: any)
	if typeof(msg) == "string" then
		Bus.fire("Toast", msg, if ok then "success" else "error")
	end
end

--------------------------------------------------------------------------------
-- Hatch reveal
--------------------------------------------------------------------------------
local hatchScreen: ScreenGui? = nil

local function playHatch(eggId: string, petId: string, golden: boolean)
	local screen = hatchScreen :: ScreenGui
	screen.Enabled = true
	screen:ClearAllChildren()
	local egg: Config.EggDef? = nil
	for _, e in Config.EGGS do
		if e.id == eggId then
			egg = e
		end
	end
	local def = Config.PETS[petId]
	local rarityColor = Config.RARITY_COLORS[def.rarity]

	local dim = UI.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Parent = screen,
	})
	local eggFrame: Frame = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.16, 0.3),
		BackgroundColor3 = if egg then egg.color else Color3.new(1, 1, 1),
		Parent = dim,
	})
	UI.make("UIAspectRatioConstraint", { AspectRatio = 0.78, Parent = eggFrame })
	UI.corner(eggFrame, 999)
	UI.stroke(eggFrame, T.Ink, 4)
	UI.gradient(eggFrame, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 220))
	UI.text({
		Text = "❄",
		Size = UDim2.fromScale(0.5, 0.3),
		Position = UDim2.fromScale(0.25, 0.35),
		TextColor3 = Color3.fromRGB(120, 170, 230),
		Parent = eggFrame,
	})

	-- Anticipation: shakes that build up.
	for i = 1, 3 do
		local angle = 8 + i * 6
		for _, r in { angle, -angle, angle * 0.5, 0 } do
			UI.tween(eggFrame, TweenInfo.new(0.06), { Rotation = r })
			task.wait(0.07)
		end
		UI.sound("Pop", 0.4, 0.8 + i * 0.15)
		task.wait(0.35 - i * 0.07)
	end
	local flash = UI.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Parent = dim,
	})
	eggFrame:Destroy()
	UI.tween(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
	UI.sound("Sparkle", 0.6)
	UI.sound("Win", 0.5)

	local holder: Frame = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.35, 0.5),
		BackgroundTransparency = 1,
		Parent = dim,
	})
	UI.make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = holder })
	local rays = UI.make("ImageLabel", {
		Image = "rbxasset://textures/particles/sparkles_main.dds",
		ImageColor3 = rarityColor,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1.4, 1.4),
		Position = UDim2.fromScale(-0.2, -0.2),
		Parent = holder,
	})
	UI.tween(rays, TweenInfo.new(8, Enum.EasingStyle.Linear), { Rotation = 360 })
	UI.viewport(ReindeerModel.build(petId, golden, 1), holder, true)
	UI.pop(holder, 0.3)

	local name = UI.text({
		Text = (if golden then "Golden " else "") .. def.name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromScale(0.6, 0.08),
		TextColor3 = rarityColor,
		MaxTextSize = 56,
		Parent = dim,
	})
	UI.textStroke(name, T.Ink, 3)
	local rarity = UI.text({
		Text = `{def.rarity} · +{math.floor(Economy.petBonus(petId, golden) * 100)}% Cheer`,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(0.5, 0.05),
		MaxTextSize = 30,
		Parent = dim,
	})
	UI.textStroke(rarity, T.Ink, 2)
	UI.button({
		Text = "Awesome!",
		Color = T.Green,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.87),
		Size = UDim2.fromScale(0.18, 0.08),
		Parent = dim,
		OnClick = function()
			screen.Enabled = false
			screen:ClearAllChildren()
		end,
	})
	if RARITY_ORDER[def.rarity] >= 5 then
		Bus.fire("Announce", `✨ {def.rarity:upper()}! ✨`, rarityColor)
	end
end

PetsPanel.playHatch = playHatch

--------------------------------------------------------------------------------

function PetsPanel.build(screen: ScreenGui)
	hatchScreen = UI.screen("Hatch", 20)
	local panel = UI.panel(screen, "🦌 Reindeer Stable", Color3.fromRGB(150, 100, 60))
	local pages: { [string]: Frame } = {}
	local tabButtons: { [string]: TextButton } = {}

	local function show(name: string)
		for key, page in pages do
			page.Visible = key == name
			UI.setButton(
				tabButtons[key],
				nil,
				if key == name then Color3.fromRGB(150, 100, 60) else T.Muted
			)
		end
	end
	for i, name in { "My Reindeer", "Eggs" } do
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

	----------------------------------------------------------------- inventory
	local inv = pages["My Reindeer"]
	local summary = UI.text({
		Text = "",
		Size = UDim2.fromScale(0.58, 0.1),
		TextColor3 = T.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = inv,
	})
	UI.button({
		Text = "Equip Best",
		Color = T.Gold,
		Size = UDim2.fromScale(0.2, 0.1),
		Position = UDim2.fromScale(0.39, 0),
		Parent = inv,
		OnClick = function()
			toast(Net.request("EquipBest"))
		end,
	})
	local grid =
		UI.scroll(inv, { Size = UDim2.fromScale(0.6, 0.88), Position = UDim2.fromScale(0, 0.12) })
	UI.make("UIGridLayout", {
		CellSize = UDim2.new(0.23, 0, 0, 96),
		CellPadding = UDim2.new(0.02, 0, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local detail =
		UI.card(inv, { Size = UDim2.fromScale(0.38, 1), Position = UDim2.fromScale(0.62, 0) })
	local detailView: Frame = UI.make(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.4), Parent = detail }
	)
	local detailName = UI.text({
		Text = "Pick a reindeer",
		Size = UDim2.fromScale(0.9, 0.08),
		Position = UDim2.fromScale(0.05, 0.4),
		TextColor3 = T.Ink,
		MaxTextSize = 28,
		Parent = detail,
	})
	local detailInfo = UI.text({
		Text = "",
		Size = UDim2.fromScale(0.9, 0.12),
		Position = UDim2.fromScale(0.05, 0.48),
		TextColor3 = T.Muted,
		FontFace = UI.BodyFont,
		TextWrapped = true,
		MaxTextSize = 18,
		Parent = detail,
	})
	local selected: string? = nil

	local equipButton = UI.button({
		Text = "Equip",
		Size = UDim2.fromScale(0.9, 0.09),
		Position = UDim2.fromScale(0.05, 0.62),
		Parent = detail,
		OnClick = function()
			local profile = State.profile()
			if not selected or not profile then
				return
			end
			local equipped = table.find(profile.equipped, selected) ~= nil
			toast(Net.request("EquipPet", selected, not equipped))
		end,
	})
	local evolveButton = UI.button({
		Text = "Evolve (3 → Golden)",
		Color = T.Gold,
		Size = UDim2.fromScale(0.9, 0.09),
		Position = UDim2.fromScale(0.05, 0.72),
		Parent = detail,
		OnClick = function()
			local profile = State.profile()
			if not selected or not profile then
				return
			end
			local pet = Economy.findPet(profile, selected)
			if pet then
				local ok, data = Net.request("EvolvePet", pet.id)
				if ok and typeof(data) == "table" then
					playHatch("Snowdrift", data.id, true)
				else
					toast(ok, data)
				end
			end
		end,
	})
	local releaseButton: TextButton
	local confirmRelease = false
	releaseButton = UI.button({
		Text = "Release",
		Color = T.Red,
		Size = UDim2.fromScale(0.43, 0.09),
		Position = UDim2.fromScale(0.05, 0.82),
		Parent = detail,
		OnClick = function()
			if not selected then
				return
			end
			if not confirmRelease then
				confirmRelease = true
				UI.setButton(releaseButton, "Sure?")
				task.delay(2.5, function()
					confirmRelease = false
					UI.setButton(releaseButton, "Release")
				end)
				return
			end
			confirmRelease = false
			UI.setButton(releaseButton, "Release")
			toast(Net.request("ReleasePet", selected))
			selected = nil
		end,
	})

	-- Gift picker
	local giftPicker: Frame = UI.make("Frame", {
		Visible = false,
		BackgroundColor3 = T.Cream,
		Size = UDim2.fromScale(0.9, 0.5),
		Position = UDim2.fromScale(0.05, 0.42),
		ZIndex = 5,
		Parent = detail,
	})
	UI.corner(giftPicker, 12)
	UI.stroke(giftPicker, T.Ink, 2)
	local giftList = UI.scroll(giftPicker, { ZIndex = 5 })
	UI.make("UIListLayout", { Padding = UDim.new(0, 6), Parent = giftList })
	UI.button({
		Text = "Gift 🎁",
		Color = T.Purple,
		Size = UDim2.fromScale(0.43, 0.09),
		Position = UDim2.fromScale(0.52, 0.82),
		Parent = detail,
		OnClick = function()
			if not selected then
				return
			end
			giftPicker.Visible = not giftPicker.Visible
			for _, c in giftList:GetChildren() do
				if c:IsA("TextButton") then
					c:Destroy()
				end
			end
			local any = false
			for _, other in Players:GetPlayers() do
				if other ~= Players.LocalPlayer then
					any = true
					local uid = selected
					local b = UI.button({
						Text = `Give to {other.DisplayName}`,
						Color = T.Purple,
						Size = UDim2.new(1, -10, 0, 40),
						Parent = giftList,
						OnClick = function()
							giftPicker.Visible = false
							toast(Net.request("GiftPet", uid, other.UserId))
						end,
					})
					b.ZIndex = 6
				end
			end
			if not any then
				giftPicker.Visible = false
				Bus.fire("Toast", "Nobody else is here to gift to yet!", "error")
			end
		end,
	})

	local lastSignature = ""
	local function renderDetail(profile: any)
		for _, c in detailView:GetChildren() do
			c:Destroy()
		end
		local pet = selected and Economy.findPet(profile, selected)
		if not pet then
			selected = nil
			detailName.Text = "Pick a reindeer"
			detailInfo.Text = "Equipped reindeer follow you and boost your Cheer!"
			return
		end
		local def = Config.PETS[pet.id]
		UI.viewport(ReindeerModel.build(pet.id, pet.golden, 1), detailView, true)
		detailName.Text = (if pet.golden then "Golden " else "") .. def.name
		detailName.TextColor3 = Config.RARITY_COLORS[def.rarity]
		local copies = 0
		for _, p in profile.pets do
			if p.id == pet.id and not p.golden then
				copies += 1
			end
		end
		detailInfo.Text =
			`{def.rarity} · +{math.floor(Economy.petBonus(pet.id, pet.golden) * 100)}% Cheer\nCopies: {copies}/{Config.EVOLVE_COUNT} to evolve`
		local equipped = table.find(profile.equipped, pet.uid) ~= nil
		UI.setButton(
			equipButton,
			if equipped then "Unequip" else "Equip",
			if equipped then T.Muted else T.Green
		)
		UI.setButton(
			evolveButton,
			nil,
			if copies >= Config.EVOLVE_COUNT and not pet.golden then T.Gold else T.Disabled
		)
	end

	local function renderGrid(snapshot: any)
		local profile = snapshot.profile
		local sig = ""
		for _, p in profile.pets do
			sig ..= p.uid .. (if table.find(profile.equipped, p.uid) then "*" else "") .. ","
		end
		sig ..= tostring(selected)
		if sig == lastSignature then
			return
		end
		lastSignature = sig
		for _, c in grid:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		local sorted = table.clone(profile.pets)
		table.sort(sorted, function(a, b)
			local ea = table.find(profile.equipped, a.uid) ~= nil
			local eb = table.find(profile.equipped, b.uid) ~= nil
			if ea ~= eb then
				return ea
			end
			return Economy.petBonus(a.id, a.golden) > Economy.petBonus(b.id, b.golden)
		end)
		for i, pet in sorted do
			local def = Config.PETS[pet.id]
			if def then
				local color = Config.RARITY_COLORS[def.rarity]
				local cell: TextButton = UI.make("TextButton", {
					Text = "",
					AutoButtonColor = true,
					BackgroundColor3 = Color3.new(1, 1, 1),
					LayoutOrder = i,
					Parent = grid,
				})
				UI.corner(cell, 10)
				UI.stroke(
					cell,
					if pet.uid == selected then T.Gold else color,
					if pet.uid == selected then 4 else 2.5
				)
				UI.gradient(cell, Color3.new(1, 1, 1), color:Lerp(Color3.new(1, 1, 1), 0.5))
				UI.text({
					Text = if pet.golden then "🌟" else "🦌",
					Size = UDim2.fromScale(0.8, 0.5),
					Position = UDim2.fromScale(0.1, 0.05),
					Parent = cell,
				})
				local n = UI.text({
					Text = def.name,
					Size = UDim2.fromScale(0.92, 0.22),
					Position = UDim2.fromScale(0.04, 0.55),
					TextColor3 = T.Ink,
					MaxTextSize = 16,
					Parent = cell,
				})
				n.TextColor3 = T.Ink
				UI.text({
					Text = `+{math.floor(Economy.petBonus(pet.id, pet.golden) * 100)}%`,
					Size = UDim2.fromScale(0.92, 0.2),
					Position = UDim2.fromScale(0.04, 0.77),
					TextColor3 = T.Green,
					MaxTextSize = 14,
					Parent = cell,
				})
				if table.find(profile.equipped, pet.uid) then
					local tag = UI.text({
						Text = "✔",
						Size = UDim2.fromScale(0.3, 0.3),
						Position = UDim2.fromScale(0.7, 0),
						TextColor3 = T.Green,
						Parent = cell,
					})
					UI.textStroke(tag, T.Ink, 1.5)
				end
				local uid = pet.uid
				cell.Activated:Connect(function()
					selected = uid
					lastSignature = ""
					renderGrid(State.data)
					renderDetail(State.profile())
				end)
			end
		end
		renderDetail(profile)
	end

	---------------------------------------------------------------------- eggs
	local eggList = UI.scroll(pages.Eggs)
	UI.make(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = eggList }
	)
	local tokenLabel = UI.text({
		Text = "",
		Size = UDim2.new(1, 0, 0, 30),
		TextColor3 = T.Green,
		LayoutOrder = 0,
		MaxTextSize = 22,
		Parent = eggList,
	})
	local eggCards: { { odds: TextLabel, buy: TextButton, token: TextButton, egg: Config.EggDef } } =
		{}
	for i, egg in Config.EGGS do
		local card = UI.card(eggList, { Size = UDim2.new(1, -12, 0, 130), LayoutOrder = i })
		local eggIcon: Frame = UI.make("Frame", {
			Size = UDim2.fromOffset(70, 92),
			Position = UDim2.new(0, 14, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = egg.color,
			Parent = card,
		})
		UI.corner(eggIcon, 999)
		UI.stroke(eggIcon, T.Ink, 2.5)
		UI.text({
			Text = egg.name,
			Size = UDim2.new(0.55, -100, 0, 34),
			Position = UDim2.fromOffset(100, 8),
			TextColor3 = T.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 26,
			Parent = card,
		})
		local odds = UI.text({
			Text = "",
			Size = UDim2.new(0.6, -100, 0, 74),
			Position = UDim2.fromOffset(100, 44),
			TextColor3 = T.Muted,
			FontFace = UI.BodyFont,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			MaxTextSize = 16,
			Parent = card,
		})
		local unit = if egg.currency == "coins" then "⭐" else "❄"
		local buy = UI.button({
			Text = `Hatch {unit} {Format.short(egg.price)}`,
			Size = UDim2.new(0.3, 0, 0, 50),
			Position = UDim2.new(1, -12, 0, 12),
			AnchorPoint = Vector2.new(1, 0),
			Parent = card,
			MaxTextSize = 22,
			OnClick = function()
				local ok, data = Net.request("HatchEgg", egg.id, false)
				if ok and typeof(data) == "table" then
					playHatch(egg.id, data.id, false)
				else
					toast(ok, data)
				end
			end,
		})
		local token = UI.button({
			Text = "Use Free Token",
			Color = T.Purple,
			Size = UDim2.new(0.3, 0, 0, 44),
			Position = UDim2.new(1, -12, 0, 72),
			AnchorPoint = Vector2.new(1, 0),
			Parent = card,
			MaxTextSize = 18,
			OnClick = function()
				local ok, data = Net.request("HatchEgg", egg.id, true)
				if ok and typeof(data) == "table" then
					playHatch(egg.id, data.id, false)
				else
					toast(ok, data)
				end
			end,
		})
		token.Visible = false
		eggCards[i] = { odds = odds, buy = buy, token = token, egg = egg }
	end

	local function refresh(snapshot: any)
		local profile = snapshot.profile
		local slots = Economy.petSlots(profile, snapshot.passes)
		summary.Text = `Stalls {#profile.equipped}/{slots} · Reindeer bonus {Format.percent(
			snapshot.income.pets
		)} · {#profile.pets}/{Config.MAX_PETS}`
		renderGrid(snapshot)
		tokenLabel.Text = if profile.eggTokens > 0
			then `🎟 You have {profile.eggTokens} free hatch token(s)!`
			else "Odds are shown for every egg. Lucky Hooves doubles Epic+ odds."
		local lucky = snapshot.passes.LuckyHooves == true
		for _, card in eggCards do
			local pct = Economy.oddsPercent(card.egg, lucky)
			local parts = {}
			for _, entry in card.egg.odds do
				local def = Config.PETS[entry.pet]
				table.insert(
					parts,
					`{def.name} ({def.rarity}) {string.format("%.1f", pct[entry.pet])}%`
				)
			end
			card.odds.Text = table.concat(parts, "  ·  ")
			local balance = if card.egg.currency == "coins"
				then profile.coins
				else profile.snowflakes
			UI.setButton(
				card.buy,
				nil,
				if balance >= card.egg.price then T.Green else Color3.fromRGB(200, 120, 110)
			)
			card.token.Visible = profile.eggTokens > 0 and card.egg.currency == "coins"
		end
	end

	show("My Reindeer")
	return { panel = panel, refresh = refresh, show = show }
end

return PetsPanel
