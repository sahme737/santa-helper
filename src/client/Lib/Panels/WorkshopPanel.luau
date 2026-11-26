--!strict
-- Workshop menu: machines, elves/sack/decor, sleigh upgrades, New Season.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Util.Format)

local Lib = script.Parent.Parent
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local Bus = require(Lib.Bus)
local Rows = require(Lib.Rows)
local State = require(Lib.State)

local WorkshopPanel = {}

local TOY_EMOJI = {
	Teddy = "🧸",
	Train = "🚂",
	Horse = "🐴",
	House = "🏠",
	Robot = "🤖",
	Console = "🎮",
	Rocket = "🚀",
	Globe = "🔮",
}
local DECOR_EMOJI = {
	D1 = "🍭",
	D2 = "⛄",
	D3 = "💡",
	D4 = "🎄",
	D5 = "🍪",
	D6 = "🧊",
	D7 = "🔴",
	D8 = "⭐",
}
local SLEIGH_EMOJI = { speed = "🦌", magnet = "🧲", time = "🌙" }

local function act(action: string, ...: any)
	local ok, msg = Net.request(action, ...)
	if msg and typeof(msg) == "string" then
		Bus.fire("Toast", msg, if ok then "success" else "error")
	end
end

function WorkshopPanel.build(screen: ScreenGui)
	local panel = UI.panel(screen, "🔨 Workshop", UI.Theme.Red)
	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}

	local function show(name: string)
		for key, page in pages do
			page.Visible = key == name
			UI.setButton(tabButtons[key], nil, if key == name then UI.Theme.Red else UI.Theme.Muted)
		end
	end

	for i, name in { "Machines", "Workshop", "Sleigh", "New Season" } do
		pages[name] = Rows.list(panel.content)
		pages[name].Visible = false
		tabButtons[name] = UI.tabButton(panel, name, i, function()
			show(name)
		end)
	end

	-- Machines
	local machineRows: { Rows.Row } = {}
	for i, m in Config.MACHINES do
		machineRows[i] = Rows.row(pages.Machines, i, TOY_EMOJI[m.toy] or "🎁", function()
			local profile = State.profile()
			if profile and profile.machines[m.id] then
				act("UpgradeMachine", m.id)
			else
				act("BuyMachine")
			end
		end)
	end

	-- Workshop: elves, sack, decorations
	local elfRow = Rows.row(pages.Workshop, 1, "🧝", function()
		act("HireElf")
	end)
	local sackRow = Rows.row(pages.Workshop, 2, "🎒", function()
		act("UpgradeSack")
	end)
	local decorRows: { Rows.Row } = {}
	for i, d in Config.DECOR do
		decorRows[i] = Rows.row(pages.Workshop, 10 + i, DECOR_EMOJI[d.id] or "🎄", function()
			act("BuyDecor", d.id)
		end)
	end

	-- Sleigh
	local sleighRows: { Rows.Row } = {}
	for i, s in Config.SLEIGH_UPGRADES do
		sleighRows[i] = Rows.row(pages.Sleigh, i, SLEIGH_EMOJI[s.id] or "🛷", function()
			act("UpgradeSleigh", s.id)
		end)
	end
	local flyRow = Rows.row(pages.Sleigh, 10, "🛷", function()
		panel.close()
		Bus.fire("StartDelivery")
	end)
	flyRow.title.Text = "Fly Sleigh Delivery"
	flyRow.desc.Text = "Drop presents down chimneys for big Cheer + Snowflakes"
	Rows.setPrice(flyRow, "Fly!", true, true)

	-- New Season (rebirth)
	local seasonCard =
		UI.card(pages["New Season"], { Size = UDim2.new(1, 0, 0, 300), LayoutOrder = 1 })
	local seasonText = UI.text({
		Text = "",
		Size = UDim2.fromScale(0.92, 0.62),
		Position = UDim2.fromScale(0.04, 0.05),
		TextColor3 = UI.Theme.Ink,
		FontFace = UI.BodyFont,
		TextWrapped = true,
		MaxTextSize = 22,
		Parent = seasonCard,
	})
	local seasonButton = UI.button({
		Text = "Start New Season",
		Color = UI.Theme.Gold,
		TextColor = Color3.new(1, 1, 1),
		Size = UDim2.new(0.5, 0, 0, 60),
		Position = UDim2.fromScale(0.5, 0.82),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = seasonCard,
		OnClick = function()
			act("Rebirth")
		end,
	})

	local function refresh(snapshot: any)
		local profile = snapshot.profile
		local coins = profile.coins
		local ctx = { passes = snapshot.passes, now = snapshot.serverTime }
		local nextFound = false
		local breakdown = Economy.breakdown(profile, ctx)
		local mult = breakdown.total / math.max(1e-9, breakdown.base)
		for i, m in Config.MACHINES do
			local row = machineRows[i]
			local level = profile.machines[m.id]
			if level then
				local perSec = Economy.toyValue(m, level) / m.interval * mult
				row.title.Text = `{m.name}  Lv.{level}`
				row.desc.Text = `Makes {Format.short(perSec)} Cheer/s`
				if level >= Config.MACHINE_MAX_LEVEL then
					Rows.setPrice(row, "MAX", false, false)
				else
					local cost = Economy.machineUpgradeCost(m, level)
					Rows.setPrice(row, `⬆ {Format.short(cost)}`, coins >= cost, true)
				end
				row.frame.Visible = true
			elseif not nextFound then
				nextFound = true
				row.title.Text = m.name
				row.desc.Text = `New machine! {Format.short(m.value / m.interval)}/s base`
				Rows.setPrice(row, `🔨 {Format.short(m.cost)}`, coins >= m.cost, true)
				row.frame.Visible = true
			else
				row.title.Text = "???"
				row.desc.Text = "Build the machine above to reveal"
				Rows.setPrice(row, "Locked", false, false)
				row.frame.Visible = true
			end
		end

		if profile.elves >= Config.ELVES.MAX then
			elfRow.title.Text = `Elf Team ({profile.elves}/{Config.ELVES.MAX})`
			elfRow.desc.Text = `All elves hired! +{profile.elves * 10}% production`
			Rows.setPrice(elfRow, "FULL", false, false)
		else
			local cost = Economy.elfCost(profile.elves)
			elfRow.title.Text = `Hire Elf ({profile.elves}/{Config.ELVES.MAX})`
			elfRow.desc.Text = "+10% production each. They work while you're away!"
			Rows.setPrice(elfRow, `🧝 {Format.short(cost)}`, coins >= cost, true)
		end

		local capacity = Economy.sackCapacity(profile.sackLevel)
		if profile.sackLevel >= Config.SACK.MAX_LEVEL then
			sackRow.title.Text = "Present Sack (MAX)"
			sackRow.desc.Text = `Holds {Format.short(capacity)} Cheer`
			Rows.setPrice(sackRow, "MAX", false, false)
		else
			local cost = Economy.sackCost(profile.sackLevel)
			sackRow.title.Text = `Bigger Sack Lv.{profile.sackLevel + 1}`
			sackRow.desc.Text = `{Format.short(capacity)} → {Format.short(
				Economy.sackCapacity(profile.sackLevel + 1)
			)} capacity`
			Rows.setPrice(sackRow, `🎒 {Format.short(cost)}`, coins >= cost, true)
		end

		local owned = 0
		for _ in profile.machines do
			owned += 1
		end
		for i, d in Config.DECOR do
			local row = decorRows[i]
			row.title.Text = d.name
			if profile.decor[d.id] then
				row.desc.Text = "Placed! +5% Festive Cheer"
				Rows.setPrice(row, "✔ Owned", false, false)
			elseif owned < d.unlockAfter then
				row.desc.Text = `Unlocks after {d.unlockAfter} machines`
				Rows.setPrice(row, "Locked", false, false)
			else
				row.desc.Text = "+5% Festive Cheer for your whole workshop"
				Rows.setPrice(row, `🎄 {Format.short(d.cost)}`, coins >= d.cost, true)
			end
		end

		local stats = Economy.sleighStats(profile)
		for i, s in Config.SLEIGH_UPGRADES do
			local row = sleighRows[i]
			local level = profile.sleigh[s.id] or 0
			row.title.Text = `{s.name} Lv.{level}`
			local current = if s.id == "speed"
				then `{stats.speed} speed`
				elseif s.id == "magnet" then `{stats.radius} stud range`
				else `{stats.duration}s flights`
			row.desc.Text = `{s.description} · now {current}`
			if level >= s.maxLevel then
				Rows.setPrice(row, "MAX", false, false)
			else
				local cost = Economy.sleighUpgradeCost(s, level)
				Rows.setPrice(row, `⬆ {Format.short(cost)}`, coins >= cost, true)
			end
		end

		local cost = Economy.rebirthCost(profile.rebirths)
		local allBuilt = owned >= #Config.MACHINES
		local nextBonus = math.floor((profile.rebirths + 1) * Config.REBIRTH.BONUS_EACH * 100)
		seasonText.Text =
			`⭐ New Season #{profile.rebirths + 1} ⭐\n\nRestart your workshop for a PERMANENT +{nextBonus}% Cheer, {Config.REBIRTH.SNOWFLAKE_REWARD} Snowflakes, and extra reindeer stalls at seasons 1 and 3.\nYou keep reindeer, outfits, snowflakes and sleigh upgrades.\n\nNeeds: all 8 machines {if allBuilt
				then "✔"
				else "✖"} and {Format.short(cost)} Cheer {if coins >= cost then "✔" else "✖"}`
		UI.setButton(
			seasonButton,
			nil,
			if Economy.canRebirth(profile) then UI.Theme.Gold else UI.Theme.Disabled
		)
	end

	show("Machines")
	return { panel = panel, refresh = refresh, show = show }
end

return WorkshopPanel
