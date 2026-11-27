--!strict
-- Session-level player state that sits next to the persistent profile:
-- game pass ownership, playtime gifts, leaderstats, and the throttled state
-- snapshot pushed to each client. Also the one place currency is granted.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Types = require(Shared.Types)
local Format = require(Shared.Util.Format)

local Net = require(script.Parent.Parent.Lib.Net)
local PlayerData = require(script.Parent.PlayerData)

type Profile = Types.Profile

local PlayerState = {}

type Session = {
	passes: { [string]: boolean },
	joinedAt: number,
	playtimeClaimed: { [number]: boolean },
	dirty: boolean,
	tickDirty: boolean, -- only coins/sack changed (cheap update)
	plotIndex: number?,
	extra: { [string]: any }, -- per-system session values included in the snapshot
	leaderstats: Folder?,
}

local sessions: { [Player]: Session } = {}
local changeListeners: { [string]: { (Player, Profile) -> () } } = {}

local function session(player: Player): Session
	local s = sessions[player]
	if not s and player.Parent ~= Players then
		-- Player already left: hand back a throwaway session instead of leaking one.
		return {
			passes = {},
			joinedAt = os.time(),
			playtimeClaimed = {},
			dirty = false,
			tickDirty = false,
			plotIndex = nil,
			extra = {},
			leaderstats = nil,
		}
	end
	if not s then
		s = {
			passes = {},
			joinedAt = os.time(),
			playtimeClaimed = {},
			dirty = true,
			tickDirty = false,
			plotIndex = nil,
			extra = {},
			leaderstats = nil,
		}
		sessions[player] = s
	end
	return s
end

function PlayerState.ctx(player: Player): Types.Context
	return { passes = session(player).passes, now = os.time() }
end

function PlayerState.hasPass(player: Player, key: string): boolean
	return session(player).passes[key] == true
end

function PlayerState.setPass(player: Player, key: string)
	session(player).passes[key] = true
	PlayerState.dirty(player)
	PlayerState.emit("passes", player)
end

function PlayerState.session(player: Player): Session
	return session(player)
end

function PlayerState.setExtra(player: Player, key: string, value: any)
	session(player).extra[key] = value
	PlayerState.dirty(player)
end

function PlayerState.dirty(player: Player)
	session(player).dirty = true
end

-- Production ticks only change coins and the sack: send a tiny update
-- instead of the whole snapshot.
function PlayerState.tickDirty(player: Player)
	session(player).tickDirty = true
end

function PlayerState.onChanged(kind: string, cb: (Player, Profile) -> ())
	local list = changeListeners[kind]
	if not list then
		list = {}
		changeListeners[kind] = list
	end
	table.insert(list, cb)
end

function PlayerState.emit(kind: string, player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	PlayerState.dirty(player)
	for _, cb in changeListeners[kind] or {} do
		task.spawn(cb, player, profile)
	end
end

--------------------------------------------------------------------------------
-- Currency
--------------------------------------------------------------------------------

local function updateLeaderstats(player: Player, profile: Profile)
	local folder = session(player).leaderstats
	if not folder then
		return
	end
	local delivered = folder:FindFirstChild("🎁 Delivered")
	if delivered and delivered:IsA("IntValue") then
		delivered.Value = profile.delivered
	end
	local cheer = folder:FindFirstChild("Cheer")
	if cheer and cheer:IsA("StringValue") then
		cheer.Value = Format.short(profile.coins)
	end
end

function PlayerState.addCoins(player: Player, profile: Profile, amount: number)
	if amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	amount = math.floor(amount)
	profile.coins += amount
	profile.lifetimeCoins += amount
	PlayerState.dirty(player)
end

function PlayerState.trySpend(
	player: Player,
	profile: Profile,
	currency: string,
	amount: number
): boolean
	if amount < 0 or amount ~= amount then
		return false
	end
	if currency == "coins" then
		if profile.coins < amount then
			return false
		end
		profile.coins -= amount
	elseif currency == "snowflakes" then
		if profile.snowflakes < amount then
			return false
		end
		profile.snowflakes -= amount
	else
		return false
	end
	PlayerState.dirty(player)
	return true
end

-- `earned` snowflakes get the VIP bonus; purchased ones do not.
function PlayerState.addSnowflakes(
	player: Player,
	profile: Profile,
	amount: number,
	earned: boolean
): number
	if amount ~= amount or amount <= 0 then
		return 0
	end
	local total = amount
	if earned and PlayerState.hasPass(player, "VIP") then
		total = math.floor(amount * (1 + Config.VIP_SNOWFLAKE_BONUS) + 0.5)
	end
	profile.snowflakes += math.floor(total)
	PlayerState.dirty(player)
	return math.floor(total)
end

-- Grants Helper Rank XP and handles rank-ups (snowflakes, popup, name tag).
function PlayerState.addXp(player: Player, profile: Profile, amount: number)
	if amount ~= amount or amount <= 0 or profile.rank >= Config.RANK.MAX then
		return
	end
	profile.xp += math.floor(amount)
	local ranked = false
	while profile.rank < Config.RANK.MAX and profile.xp >= Economy.xpForRank(profile.rank) do
		profile.xp -= Economy.xpForRank(profile.rank)
		profile.rank += 1
		ranked = true
		PlayerState.addSnowflakes(player, profile, Config.RANK.SNOWFLAKES_EACH, false)
	end
	if profile.rank >= Config.RANK.MAX then
		profile.xp = 0
	end
	if ranked then
		Net.push(player, "Effect", {
			kind = "RankUp",
			rank = profile.rank,
			title = Economy.rankTitle(profile.rank),
			snowflakes = Config.RANK.SNOWFLAKES_EACH,
		})
		PlayerState.emit("rank", player)
	end
	PlayerState.dirty(player)
end

function PlayerState.addPet(
	player: Player,
	profile: Profile,
	petId: string,
	golden: boolean
): Types.PetEntry?
	if not Config.PETS[petId] then
		return nil
	end
	if #profile.pets >= Config.MAX_PETS then
		return nil
	end
	local entry: Types.PetEntry =
		{ uid = "p" .. tostring(profile.nextPetUid), id = petId, golden = golden }
	profile.nextPetUid += 1
	table.insert(profile.pets, entry)
	-- Auto-equip into a free slot so new players feel the bonus immediately.
	if #profile.equipped < Economy.petSlots(profile, session(player).passes) then
		table.insert(profile.equipped, entry.uid)
	end
	PlayerState.emit("pets", player)
	return entry
end

-- Grants a reward definition and returns a short human label.
function PlayerState.grantReward(player: Player, profile: Profile, reward: Config.RewardDef): string
	local kind = reward.kind
	if kind == "coins" then
		local amount =
			Economy.scaledCoins(profile, PlayerState.ctx(player), reward.amount, reward.floor)
		PlayerState.addCoins(player, profile, amount)
		return Format.short(amount) .. " Cheer"
	elseif kind == "snowflakes" then
		local got = PlayerState.addSnowflakes(player, profile, reward.amount, true)
		return tostring(got) .. " Snowflakes"
	elseif kind == "boost" then
		local now = os.time()
		profile.boostUntil = math.max(profile.boostUntil, now) + reward.amount * 60
		PlayerState.dirty(player)
		return `Hot Cocoa x2 ({reward.amount} min)`
	elseif kind == "eggToken" then
		profile.eggTokens += reward.amount
		PlayerState.dirty(player)
		return "Free Hatch Token"
	elseif kind == "cosmetic" and reward.id then
		if profile.cosmetics.owned[reward.id] then
			-- Already owned: convert to snowflakes so the reward never feels wasted.
			local got = PlayerState.addSnowflakes(player, profile, 25, true)
			return tostring(got) .. " Snowflakes"
		end
		profile.cosmetics.owned[reward.id] = true
		PlayerState.emit("cosmetics", player)
		return reward.label
	elseif kind == "pet" and reward.id then
		local entry = PlayerState.addPet(player, profile, reward.id, false)
		if entry then
			return reward.label
		end
		local got = PlayerState.addSnowflakes(player, profile, 50, true)
		return tostring(got) .. " Snowflakes (stable full)"
	end
	return reward.label
end

--------------------------------------------------------------------------------
-- Snapshot
--------------------------------------------------------------------------------

local function snapshot(player: Player, profile: Profile): { [string]: any }
	local s = session(player)
	local ctx = PlayerState.ctx(player)
	-- Sparse numeric keys don't survive remotes; send string keys.
	local claimedKeys = {}
	for index in s.playtimeClaimed do
		claimedKeys[tostring(index)] = true
	end
	return {
		profile = {
			coins = profile.coins,
			snowflakes = profile.snowflakes,
			lifetimeCoins = profile.lifetimeCoins,
			delivered = profile.delivered,
			machines = profile.machines,
			decor = profile.decor,
			elves = profile.elves,
			sackLevel = profile.sackLevel,
			sack = profile.sack,
			sleigh = profile.sleigh,
			rebirths = profile.rebirths,
			pets = profile.pets,
			nextPetUid = profile.nextPetUid,
			equipped = profile.equipped,
			cosmetics = profile.cosmetics,
			daily = profile.daily,
			advent = profile.advent,
			boostUntil = profile.boostUntil,
			eggTokens = profile.eggTokens,
			lastOnline = profile.lastOnline,
			incomeRate = profile.incomeRate,
			receipts = {},
			tutorialStep = profile.tutorialStep,
			createdAt = profile.createdAt,
			version = profile.version,
			xp = profile.xp,
			rank = profile.rank,
			routes = profile.routes,
			stars = profile.stars,
		},
		passes = s.passes,
		income = Economy.breakdown(profile, ctx),
		serverTime = ctx.now,
		joinedAt = s.joinedAt,
		playtimeClaimed = claimedKeys,
		plotIndex = s.plotIndex,
		extra = s.extra,
	}
end

local function flush()
	for player, s in sessions do
		if s.dirty then
			local profile = PlayerData.get(player)
			if profile then
				s.dirty = false
				s.tickDirty = false
				updateLeaderstats(player, profile)
				Net.push(player, "State", snapshot(player, profile))
			end
		elseif s.tickDirty then
			local profile = PlayerData.get(player)
			if profile then
				s.tickDirty = false
				Net.push(
					player,
					"Tick",
					{ coins = profile.coins, sack = profile.sack, serverTime = os.time() }
				)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Game passes
--------------------------------------------------------------------------------

local function loadPasses(player: Player)
	for _, pass in Config.GAME_PASSES do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				session(player).passes[pass.key] = true
			end
		end
	end
	PlayerState.dirty(player)
	PlayerState.emit("passes", player)
end

function PlayerState.start()
	PlayerData.onLoaded(function(player, profile)
		local s = session(player)
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local delivered = Instance.new("IntValue")
		delivered.Name = "🎁 Delivered"
		delivered.Parent = folder
		local cheer = Instance.new("StringValue")
		cheer.Name = "Cheer"
		cheer.Parent = folder
		folder.Parent = player
		s.leaderstats = folder
		updateLeaderstats(player, profile)
		task.spawn(loadPasses, player)
		PlayerState.dirty(player)
	end)

	PlayerData.onBeforeSave(function(player, profile)
		profile.incomeRate = Economy.autoIncome(profile, PlayerState.ctx(player))
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, pass in Config.GAME_PASSES do
			if pass.id ~= 0 and pass.id == passId then
				-- Re-verify ownership instead of trusting the event flag.
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
				end)
				if ok and owns then
					PlayerState.setPass(player, pass.key)
					Net.toast(player, `Thank you! {pass.name} unlocked!`, "success")
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Delay cleanup so PlayerData's releasing callbacks can still read context.
		task.delay(5, function()
			sessions[player] = nil
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.STATE_PUSH_RATE)
			flush()
		end
	end)
end

return PlayerState
