--!strict
-- Pet reindeer: hatching eggs, equipping, evolving 3 -> golden, releasing,
-- and gifting to another player in the server. The server spawns world pet
-- models (anchored) tagged with their owner; clients animate them following
-- their owners so movement costs no network traffic.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Types = require(Shared.Types)
local Format = require(Shared.Util.Format)
local ReindeerModel = require(Shared.Models.ReindeerModel)

local Net = require(script.Parent.Parent.Lib.Net)
local Guard = require(script.Parent.Parent.Lib.Guard)
local PlayerData = require(script.Parent.PlayerData)
local PlayerState = require(script.Parent.PlayerState)

type Profile = Types.Profile

local Pets = {}

local EGG_BY_ID: { [string]: Config.EggDef } = {}
for _, egg in Config.EGGS do
	EGG_BY_ID[egg.id] = egg
end

local rng = Random.new()
local petsFolder: Folder

local function clearWorldPets(player: Player)
	for _, model in petsFolder:GetChildren() do
		if model:GetAttribute("OwnerId") == player.UserId then
			model:Destroy()
		end
	end
end

-- Make sure equipped uids are valid, unique, and within the slot limit.
local function sanitizeEquipped(player: Player, profile: Profile)
	local slots = Economy.petSlots(profile, PlayerState.session(player).passes)
	local seen: { [string]: boolean } = {}
	local clean: { string } = {}
	for _, uid in profile.equipped do
		if not seen[uid] and Economy.findPet(profile, uid) and #clean < slots then
			seen[uid] = true
			table.insert(clean, uid)
		end
	end
	profile.equipped = clean
end

local function refreshWorldPets(player: Player, profile: Profile)
	sanitizeEquipped(player, profile)
	clearWorldPets(player)
	for slot, uid in profile.equipped do
		local pet = Economy.findPet(profile, uid)
		if pet then
			local model = ReindeerModel.build(pet.id, pet.golden, 0.75)
			model.Name = `{player.Name}_{pet.uid}`
			model:SetAttribute("OwnerId", player.UserId)
			model:SetAttribute("Slot", slot)
			model:SetAttribute("SlotCount", #profile.equipped)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				model:PivotTo(root.CFrame * CFrame.new(slot * 3, -2.5, 5))
			end
			model.Parent = petsFolder
		end
	end
	PlayerState.dirty(player)
end

function Pets.hatch(player: Player, eggId: string, useToken: boolean): (boolean, any)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	local egg = EGG_BY_ID[eggId]
	if not egg then
		return false, "Unknown egg"
	end
	if #profile.pets >= Config.MAX_PETS then
		return false, "Your stable is full! Release or evolve some reindeer."
	end
	if useToken then
		if profile.eggTokens < 1 then
			return false, "No free hatch tokens"
		end
		if egg.currency ~= "coins" then
			return false, "Tokens work on Cheer eggs"
		end
		profile.eggTokens -= 1
	elseif not PlayerState.trySpend(player, profile, egg.currency, egg.price) then
		local unit = if egg.currency == "coins" then "Cheer" else "Snowflakes"
		return false, `Need {Format.short(egg.price)} {unit}`
	end
	local petId = Economy.rollEgg(egg, PlayerState.hasPass(player, "LuckyHooves"), rng:NextNumber())
	local entry = PlayerState.addPet(player, profile, petId, false)
	if not entry then
		return false, "Could not add reindeer"
	end
	PlayerState.addXp(player, profile, Config.RANK.XP_HATCH)
	local def = Config.PETS[petId]
	if def.rarity == "Legendary" or def.rarity == "Mythic" then
		Net.toastAll(`🦌 {player.DisplayName} hatched a {def.rarity} {def.name}!`, "event")
	end
	return true, { uid = entry.uid, id = petId, egg = eggId }
end

function Pets.setEquipped(player: Player, uid: string, equip: boolean): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	if not Economy.findPet(profile, uid) then
		return false, "Reindeer not found"
	end
	local idx = table.find(profile.equipped, uid)
	if equip then
		if idx then
			return true, nil
		end
		local slots = Economy.petSlots(profile, PlayerState.session(player).passes)
		if #profile.equipped >= slots then
			return false, `All {slots} stalls are full`
		end
		table.insert(profile.equipped, uid)
	else
		if not idx then
			return true, nil
		end
		table.remove(profile.equipped, idx)
	end
	PlayerState.emit("pets", player)
	return true, nil
end

-- Equip the strongest reindeer automatically.
function Pets.equipBest(player: Player): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	local sorted = table.clone(profile.pets)
	table.sort(sorted, function(a, b)
		return Economy.petBonus(a.id, a.golden) > Economy.petBonus(b.id, b.golden)
	end)
	local slots = Economy.petSlots(profile, PlayerState.session(player).passes)
	local equipped = {}
	for i = 1, math.min(slots, #sorted) do
		table.insert(equipped, sorted[i].uid)
	end
	profile.equipped = equipped
	PlayerState.emit("pets", player)
	return true, "Best reindeer equipped!"
end

function Pets.evolve(player: Player, petId: string): (boolean, any)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	if not Config.PETS[petId] then
		return false, "Unknown reindeer"
	end
	local matches: { number } = {}
	for i, pet in profile.pets do
		if pet.id == petId and not pet.golden then
			table.insert(matches, i)
			if #matches >= Config.EVOLVE_COUNT then
				break
			end
		end
	end
	if #matches < Config.EVOLVE_COUNT then
		return false, `Need {Config.EVOLVE_COUNT} {Config.PETS[petId].name} to evolve`
	end
	-- Remove from the highest index down so earlier indices stay valid.
	table.sort(matches, function(a, b)
		return a > b
	end)
	for _, i in matches do
		local removed = table.remove(profile.pets, i)
		if removed then
			local eq = table.find(profile.equipped, removed.uid)
			if eq then
				table.remove(profile.equipped, eq)
			end
		end
	end
	local entry = PlayerState.addPet(player, profile, petId, true)
	if not entry then
		return false, "Could not evolve"
	end
	return true, { uid = entry.uid, id = petId, golden = true }
end

function Pets.release(player: Player, uid: string): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	local pet, index = Economy.findPet(profile, uid)
	if not pet or not index then
		return false, "Reindeer not found"
	end
	local def = Config.PETS[pet.id]
	if def and def.rarity == "Exclusive" then
		return false, "Exclusive reindeer can't be released"
	end
	table.remove(profile.pets, index)
	local eq = table.find(profile.equipped, uid)
	if eq then
		table.remove(profile.equipped, eq)
	end
	local reward = if def then (Config.RELEASE_REWARD_SNOWFLAKES[def.rarity] or 0) else 0
	if pet.golden then
		reward *= 3
	end
	if reward > 0 then
		PlayerState.addSnowflakes(player, profile, reward, false)
	end
	PlayerState.emit("pets", player)
	return true, if reward > 0 then `Released! +{reward} Snowflakes` else "Released into the wild!"
end

-- One-way gift to another player in this server. Both profiles are held by
-- this server under session locks, so the move is atomic in memory.
function Pets.gift(player: Player, uid: string, targetUserId: number): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return false, "That player isn't here"
	end
	local targetProfile = PlayerData.get(target)
	if not targetProfile then
		return false, "That player is still loading"
	end
	if #targetProfile.pets >= Config.MAX_PETS then
		return false, `{target.DisplayName}'s stable is full`
	end
	local pet, index = Economy.findPet(profile, uid)
	if not pet or not index then
		return false, "Reindeer not found"
	end
	local def = Config.PETS[pet.id]
	if def and def.rarity == "Exclusive" then
		return false, "Exclusive reindeer can't be gifted"
	end
	table.remove(profile.pets, index)
	local eq = table.find(profile.equipped, uid)
	if eq then
		table.remove(profile.equipped, eq)
	end
	PlayerState.emit("pets", player)
	PlayerState.addPet(target, targetProfile, pet.id, pet.golden)
	-- Persist both sides right away so a crash can't roll back only the
	-- sender (which would duplicate the reindeer). Sender first.
	task.spawn(function()
		PlayerData.saveNow(player)
		PlayerData.saveNow(target)
	end)
	local name = (if pet.golden then "Golden " else "") .. (if def then def.name else pet.id)
	Net.toast(target, `🎁 {player.DisplayName} gifted you a {name}!`, "success")
	return true, `Gifted {name} to {target.DisplayName}!`
end

function Pets.start()
	petsFolder = workspace:WaitForChild("Pets") :: Folder

	PlayerState.onChanged("pets", refreshWorldPets)
	PlayerState.onChanged("passes", refreshWorldPets)
	PlayerData.onLoaded(function(player, profile)
		refreshWorldPets(player, profile)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			local p = PlayerData.get(player)
			if p then
				refreshWorldPets(player, p)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(clearWorldPets)

	Net.handle("HatchEgg", 2, 3, function(player, eggId: unknown, useToken: unknown)
		local id = Guard.oneOf(eggId, EGG_BY_ID)
		if not id then
			return false, "Unknown egg"
		end
		return Pets.hatch(player, id, useToken == true)
	end)
	Net.handle("EquipPet", 6, 10, function(player, uid: unknown, equip: unknown)
		local id = Guard.string(uid, 16)
		local flag = Guard.boolean(equip)
		if not id or flag == nil then
			return false, "Bad request"
		end
		return Pets.setEquipped(player, id, flag)
	end)
	Net.handle("EquipBest", 1, 2, function(player)
		return Pets.equipBest(player)
	end)
	Net.handle("EvolvePet", 2, 3, function(player, petId: unknown)
		local id = Guard.oneOf(petId, Config.PETS)
		if not id then
			return false, "Unknown reindeer"
		end
		return Pets.evolve(player, id)
	end)
	Net.handle("ReleasePet", 4, 6, function(player, uid: unknown)
		local id = Guard.string(uid, 16)
		if not id then
			return false, "Bad request"
		end
		return Pets.release(player, id)
	end)
	Net.handle("GiftPet", 0.5, 2, function(player, uid: unknown, targetUserId: unknown)
		local id = Guard.string(uid, 16)
		local target = Guard.int(targetUserId, -(2 ^ 53), 2 ^ 53) -- Studio test players are negative
		if not id or not target then
			return false, "Bad request"
		end
		return Pets.gift(player, id, target)
	end)
end

return Pets
