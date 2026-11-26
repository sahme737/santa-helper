--!strict
-- Wardrobe (hats, ugly sweaters, trails), Robux developer products with an
-- idempotent ProcessReceipt, the VIP name tag, and Studio-only QA commands.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Build = require(Shared.Util.Build)
local Format = require(Shared.Util.Format)
local CosmeticModels = require(Shared.Models.CosmeticModels)
local Types = require(Shared.Types)

local Net = require(script.Parent.Parent.Lib.Net)
local Guard = require(script.Parent.Parent.Lib.Guard)
local PlayerData = require(script.Parent.PlayerData)
local PlayerState = require(script.Parent.PlayerState)

type Profile = Types.Profile

local Shop = {}

local PRODUCT_BY_ID: { [number]: Config.ProductDef } = {}
for _, product in Config.DEV_PRODUCTS do
	if product.id ~= 0 then
		PRODUCT_BY_ID[product.id] = product
	end
end

local SLOTS = { hat = true, sweater = true, trail = true }

local function owns(player: Player, profile: Profile, id: string): boolean
	if profile.cosmetics.owned[id] then
		return true
	end
	local def = CosmeticModels.BY_ID[id]
	if def and def.currency == "free" then
		return true
	end
	if id == "GoldenCrown" and PlayerState.hasPass(player, "VIP") then
		return true
	end
	return false
end

local function applyCosmetics(player: Player, profile: Profile)
	local character = player.Character
	if not character then
		return
	end
	local c = profile.cosmetics
	CosmeticModels.applyHat(
		character,
		if c.hat and owns(player, profile, c.hat) then c.hat else nil
	)
	CosmeticModels.applySweater(
		character,
		if c.sweater and owns(player, profile, c.sweater) then c.sweater else nil
	)
	CosmeticModels.applyTrail(
		character,
		if c.trail and owns(player, profile, c.trail) then c.trail else nil
	)

	local head = character:FindFirstChild("Head")
	local existing = head and head:FindFirstChild("VipTag")
	if existing then
		existing:Destroy()
	end
	if head and head:IsA("BasePart") and PlayerState.hasPass(player, "VIP") then
		local gui = Build.billboard(
			head,
			"⭐ VIP",
			UDim2.fromOffset(90, 28),
			Vector3.new(0, 4.1, 0),
			Color3.fromRGB(255, 210, 60),
			80
		)
		gui.Name = "VipTag"
	end

	-- Helper Rank tag: everyone can see how far you've come.
	local oldRank = head and head:FindFirstChild("RankTag")
	if oldRank then
		oldRank:Destroy()
	end
	if head and head:IsA("BasePart") then
		local stars = if profile.stars > 0 then `  ⭐{profile.stars}` else ""
		local gui = Build.billboard(
			head,
			`Lv.{profile.rank} {Economy.rankTitle(profile.rank)}{stars}`,
			UDim2.fromScale(9, 0.9),
			Vector3.new(0, 3.1, 0),
			if profile.rank >= 30
				then Color3.fromRGB(255, 215, 90)
				elseif profile.rank >= 10 then Color3.fromRGB(150, 220, 255)
				else Color3.fromRGB(235, 235, 235),
			70
		)
		gui.Name = "RankTag"
	end
end

function Shop.buyCosmetic(player: Player, id: string): (boolean, string?)
	local profile = PlayerData.get(player)
	local def = CosmeticModels.BY_ID[id]
	if not profile or not def then
		return false, "Unknown item"
	end
	if owns(player, profile, id) then
		return false, "You already own this"
	end
	if def.currency ~= "coins" and def.currency ~= "snowflakes" then
		return false,
			if def.currency == "event"
				then "Find this in the Advent calendar!"
				else "Unlock with North Pole VIP"
	end
	if not PlayerState.trySpend(player, profile, def.currency, def.price) then
		local unit = if def.currency == "coins" then "Cheer" else "Snowflakes"
		return false, `Need {Format.short(def.price)} {unit}`
	end
	profile.cosmetics.owned[id] = true
	profile.cosmetics[def.slot] = id
	PlayerState.emit("cosmetics", player)
	return true, `{def.name} is yours!`
end

function Shop.equipCosmetic(player: Player, slot: string, id: string?): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	if id then
		local def = CosmeticModels.BY_ID[id]
		if not def or def.slot ~= slot or not owns(player, profile, id) then
			return false, "You don't own that"
		end
	end
	profile.cosmetics[slot] = id
	PlayerState.emit("cosmetics", player)
	return true, nil
end

local function grantProduct(player: Player, profile: Profile, product: Config.ProductDef)
	local grant = product.grant
	if grant.kind == "snowflakes" then
		PlayerState.addSnowflakes(player, profile, grant.amount, false)
	elseif grant.kind == "boost" then
		profile.boostUntil = math.max(profile.boostUntil, os.time()) + grant.amount * 60
	elseif grant.kind == "pet" and grant.id then
		if not PlayerState.addPet(player, profile, grant.id, false) then
			-- Stable full: grant equivalent snowflakes so the purchase is never lost.
			PlayerState.addSnowflakes(player, profile, 800, false)
		end
	end
	PlayerState.dirty(player)
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = PlayerData.get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(profile.receipts, purchaseId) then
		-- Already granted (e.g. the save after granting failed last time).
		return if PlayerData.saveNow(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = PRODUCT_BY_ID[receipt.ProductId]
	if not product then
		warn(`[Shop] unknown product {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grantProduct(player, profile, product)
	table.insert(profile.receipts, purchaseId)
	while #profile.receipts > 50 do
		table.remove(profile.receipts, 1)
	end
	Net.toast(player, `Thank you! {product.name} received!`, "success")
	Net.push(player, "Effect", { kind = "Purchase", key = product.key })
	if PlayerData.saveNow(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function isAdmin(player: Player): boolean
	return RunService:IsStudio() or table.find(Config.ADMINS, player.UserId) ~= nil
end

function Shop.start()
	MarketplaceService.ProcessReceipt = processReceipt

	local function onCharacter(player: Player)
		task.wait(0.4)
		local profile = PlayerData.get(player)
		if profile then
			applyCosmetics(player, profile)
		end
	end
	PlayerData.onLoaded(function(player, profile)
		player.CharacterAppearanceLoaded:Connect(function()
			onCharacter(player)
		end)
		if player.Character then
			applyCosmetics(player, profile)
		end
	end)
	PlayerState.onChanged("cosmetics", applyCosmetics)
	PlayerState.onChanged("passes", applyCosmetics)
	PlayerState.onChanged("rank", applyCosmetics)

	Net.handle("BuyCosmetic", 3, 5, function(player, id: unknown)
		local cid = Guard.oneOf(id, CosmeticModels.BY_ID)
		if not cid then
			return false, "Unknown item"
		end
		return Shop.buyCosmetic(player, cid)
	end)
	Net.handle("EquipCosmetic", 6, 10, function(player, slot: unknown, id: unknown)
		local s = Guard.oneOf(slot, SLOTS)
		if not s then
			return false, "Bad slot"
		end
		if id == nil then
			return Shop.equipCosmetic(player, s, nil)
		end
		local cid = Guard.oneOf(id, CosmeticModels.BY_ID)
		if not cid then
			return false, "Unknown item"
		end
		return Shop.equipCosmetic(player, s, cid)
	end)

	-- QA commands: Studio, or UserIds listed in Config.ADMINS.
	Net.handle("Dev", 4, 8, function(player, command: unknown)
		if not isAdmin(player) then
			return false, nil
		end
		local profile = PlayerData.get(player)
		if not profile or typeof(command) ~= "string" then
			return false, nil
		end
		if command == "coins" then
			PlayerState.addCoins(player, profile, math.max(1e5, profile.coins * 10))
		elseif command == "snowflakes" then
			PlayerState.addSnowflakes(player, profile, 500, false)
		elseif command == "xp" then
			PlayerState.addXp(player, profile, 500)
		elseif command == "routes" then
			for _, def in Config.ROUTES do
				local key = tostring(def.id)
				if not profile.routes[key] then
					profile.routes[key] = { stars = 1, best = def.stars[1] }
				end
			end
			profile.stars = Economy.totalStars(profile)
			PlayerState.emit("rank", player)
		elseif command == "boost" then
			profile.boostUntil = os.time() + 600
		elseif string.sub(command, 1, 5) == "pass:" then
			local key = string.sub(command, 6)
			for _, pass in Config.GAME_PASSES do
				if pass.key == key then
					PlayerState.setPass(player, key)
				end
			end
		elseif command == "reset" then
			profile.daily.lastDay = 0
			profile.advent = {}
			PlayerState.session(player).playtimeClaimed = {}
			PlayerState.session(player).joinedAt = os.time() - 3700
		else
			return false, "unknown command"
		end
		PlayerState.dirty(player)
		return true, command
	end)
end

return Shop
