--!strict
-- Ugly Sweater Shop: hats, sweaters and trails. Purely cosmetic.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)

local Lib = script.Parent.Parent
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local Bus = require(Lib.Bus)
local State = require(Lib.State)

local WardrobePanel = {}

local T = UI.Theme
local ICONS = {
	SantaHat = "🎅",
	ElfHat = "🧝",
	Antlers = "🦌",
	TopHat = "🎩",
	StarHalo = "😇",
	GingerCrown = "👑",
	HollyHat = "🌿",
	GoldenCrown = "👑",
	ClassicSweater = "🧶",
	EvergreenSweater = "🎄",
	ReindeerSweater = "🦌",
	SnowmanSweater = "⛄",
	GingerSweater = "🍪",
	CandyTrail = "🍬",
	SnowTrail = "❄",
	EvergreenTrail = "🌲",
	AuroraTrail = "🌈",
}

local function toast(ok: boolean, msg: any)
	if typeof(msg) == "string" then
		Bus.fire("Toast", msg, if ok then "success" else "error")
	end
end

function WardrobePanel.build(screen: ScreenGui)
	local panel = UI.panel(screen, "🧶 Ugly Sweater Shop", T.Purple)
	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local function show(name: string)
		for key, page in pages do
			page.Visible = key == name
			UI.setButton(tabButtons[key], nil, if key == name then T.Purple else T.Muted)
		end
	end
	local slotNames = { hat = "Hats", sweater = "Sweaters", trail = "Trails" }
	for i, slot in { "hat", "sweater", "trail" } do
		local name = slotNames[slot]
		local page = UI.scroll(panel.content, { Visible = false })
		UI.make("UIGridLayout", {
			CellSize = UDim2.new(0.31, 0, 0, 170),
			CellPadding = UDim2.new(0.02, 0, 0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = page,
		})
		pages[name] = page
		tabButtons[name] = UI.tabButton(panel, name, i, function()
			show(name)
		end)
	end

	local cards: { { def: Config.CosmeticDef, button: TextButton, status: TextLabel } } = {}
	for i, def in Config.COSMETICS do
		local page = pages[slotNames[def.slot]]
		local card = UI.card(page, { LayoutOrder = i })
		UI.gradient(card, Color3.new(1, 1, 1), def.colorA:Lerp(Color3.new(1, 1, 1), 0.7))
		UI.text({
			Text = ICONS[def.id] or "🎁",
			Size = UDim2.fromScale(0.5, 0.36),
			Position = UDim2.fromScale(0.25, 0.04),
			Parent = card,
		})
		UI.text({
			Text = def.name,
			Size = UDim2.fromScale(0.92, 0.16),
			Position = UDim2.fromScale(0.04, 0.42),
			TextColor3 = T.Ink,
			MaxTextSize = 20,
			Parent = card,
		})
		local status = UI.text({
			Text = "",
			Size = UDim2.fromScale(0.92, 0.12),
			Position = UDim2.fromScale(0.04, 0.58),
			TextColor3 = T.Muted,
			FontFace = UI.BodyFont,
			MaxTextSize = 14,
			Parent = card,
		})
		local button = UI.button({
			Text = "",
			Size = UDim2.fromScale(0.86, 0.22),
			Position = UDim2.fromScale(0.07, 0.74),
			Parent = card,
			MaxTextSize = 20,
			OnClick = function()
				local profile = State.profile()
				if not profile then
					return
				end
				local owned = profile.cosmetics.owned[def.id]
					or def.currency == "free"
					or (def.id == "GoldenCrown" and State.data.passes.VIP)
				if owned then
					local equipped = profile.cosmetics[def.slot] == def.id
					toast(Net.request("EquipCosmetic", def.slot, if equipped then nil else def.id))
				elseif def.currency == "robux" then
					Bus.fire("OpenMenu", "Store")
				else
					toast(Net.request("BuyCosmetic", def.id))
				end
			end,
		})
		cards[i] = { def = def, button = button, status = status }
	end

	local function refresh(snapshot: any)
		local profile = snapshot.profile
		for _, c in cards do
			local def = c.def
			local owned = profile.cosmetics.owned[def.id]
				or def.currency == "free"
				or (def.id == "GoldenCrown" and snapshot.passes.VIP)
			local equipped = profile.cosmetics[def.slot] == def.id
			if owned then
				c.status.Text = if equipped then "Wearing" else "Owned"
				UI.setButton(
					c.button,
					if equipped then "Take Off" else "Wear",
					if equipped then T.Muted else T.Green
				)
			elseif def.currency == "coins" then
				c.status.Text = "Cheer"
				UI.setButton(
					c.button,
					`⭐ {Format.short(def.price)}`,
					if profile.coins >= def.price then T.Green else Color3.fromRGB(200, 120, 110)
				)
			elseif def.currency == "snowflakes" then
				c.status.Text = "Snowflakes"
				UI.setButton(
					c.button,
					`❄ {Format.short(def.price)}`,
					if profile.snowflakes >= def.price
						then T.Green
						else Color3.fromRGB(200, 120, 110)
				)
			elseif def.currency == "event" then
				c.status.Text = "Advent calendar reward"
				UI.setButton(c.button, "🎄 Event", T.Disabled)
			else
				c.status.Text = "North Pole VIP"
				UI.setButton(c.button, "💎 VIP", Color3.fromRGB(230, 160, 30))
			end
		end
	end

	show("Hats")
	return { panel = panel, refresh = refresh, show = show }
end

return WardrobePanel
