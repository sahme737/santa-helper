--!strict
-- Robux store. Everything here is optional: the whole game is playable free.
-- Items with an id of 0 in Config show as "Coming soon".

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Lib = script.Parent.Parent
local UI = require(Lib.UI)
local Rows = require(Lib.Rows)

local StorePanel = {}

local T = UI.Theme
local PASS_ICONS = {
	DoubleCheer = "⭐",
	AutoLoader = "🧝",
	LuckyHooves = "🍀",
	ExtraStall = "🦌",
	VIP = "👑",
}
local PRODUCT_ICONS = {
	Snowflakes100 = "❄",
	Snowflakes550 = "❄",
	Snowflakes1500 = "❄",
	CocoaBoost = "☕",
	NorthernLights = "🌌",
}

function StorePanel.build(screen: ScreenGui)
	local panel = UI.panel(screen, "💎 North Pole Store", Color3.fromRGB(230, 160, 30))
	local list = Rows.list(panel.content)
	local player = Players.LocalPlayer

	UI.text({
		Text = "The whole game is free to play. These are optional extras! 🎄",
		Size = UDim2.new(1, 0, 0, 30),
		TextColor3 = T.Muted,
		FontFace = UI.BodyFont,
		LayoutOrder = 0,
		MaxTextSize = 18,
		Parent = list,
	})

	local passRows: { [string]: Rows.Row } = {}
	for i, pass in Config.GAME_PASSES do
		local row = Rows.row(list, i, PASS_ICONS[pass.key] or "🎁", function()
			if pass.id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end
		end)
		row.title.Text = pass.name
		row.desc.Text = pass.description
		passRows[pass.key] = row
	end
	for i, product in Config.DEV_PRODUCTS do
		local row = Rows.row(list, 100 + i, PRODUCT_ICONS[product.key] or "🎁", function()
			if product.id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, product.id)
			end
		end)
		row.title.Text = product.name
		row.desc.Text = product.description
		if product.id == 0 then
			Rows.setPrice(row, "Coming soon", false, false)
		else
			Rows.setPrice(row, `R$ {product.robux}`, true, true)
		end
	end

	local function refresh(snapshot: any)
		for _, pass in Config.GAME_PASSES do
			local row = passRows[pass.key]
			if snapshot.passes[pass.key] then
				Rows.setPrice(row, "Owned ✔", false, false)
			elseif pass.id == 0 then
				Rows.setPrice(row, "Coming soon", false, false)
			else
				Rows.setPrice(row, `R$ {pass.robux}`, true, true)
			end
		end
	end

	return { panel = panel, refresh = refresh, show = function(_: string) end }
end

return StorePanel
