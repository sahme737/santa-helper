--!strict
-- Come-back loops: daily login streak, the Advent calendar (one door per
-- December day), in-session playtime gifts, offline earnings, and the
-- first-time tutorial progress.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Calendar = require(Shared.Calendar)
local Economy = require(Shared.Economy)

local Net = require(script.Parent.Parent.Lib.Net)
local Guard = require(script.Parent.Parent.Lib.Guard)
local PlayerData = require(script.Parent.PlayerData)
local PlayerState = require(script.Parent.PlayerState)

local Rewards = {}

function Rewards.claimDaily(player: Player): (boolean, any)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	local today = Calendar.dayNumber(os.time())
	local daily = profile.daily
	if daily.lastDay == today then
		return false, "Come back tomorrow for more!"
	end
	if daily.lastDay == today - 1 then
		daily.streak += 1
	else
		daily.streak = 1
	end
	daily.lastDay = today
	local index = (daily.streak - 1) % #Config.DAILY_STREAK + 1
	local label = PlayerState.grantReward(player, profile, Config.DAILY_STREAK[index])
	PlayerState.dirty(player)
	return true, { label = label, streak = daily.streak, day = index }
end

function Rewards.claimAdvent(player: Player): (boolean, any)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	local day = Calendar.adventDay(os.time())
	if not day then
		return false, "The Advent calendar is closed today"
	end
	local key = "d" .. tostring(day)
	if profile.advent[key] then
		return false, "You already opened today's door!"
	end
	profile.advent[key] = true
	local reward = Config.ADVENT_SPECIAL[day]
		or { kind = "snowflakes", amount = 10 + day, label = `{10 + day} Snowflakes` }
	local label = PlayerState.grantReward(player, profile, reward)
	PlayerState.dirty(player)
	return true, { label = label, day = day }
end

function Rewards.claimPlaytime(player: Player, index: number): (boolean, any)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "Loading..."
	end
	local gift = Config.PLAYTIME_GIFTS[index]
	if not gift then
		return false, "Unknown gift"
	end
	local session = PlayerState.session(player)
	if session.playtimeClaimed[index] then
		return false, "Already claimed"
	end
	if os.time() - session.joinedAt < gift.minutes * 60 - 2 then
		return false, "Not ready yet"
	end
	session.playtimeClaimed[index] = true
	local label = PlayerState.grantReward(player, profile, gift.reward)
	PlayerState.dirty(player)
	return true, { label = label, index = index }
end

function Rewards.start()
	PlayerData.onLoaded(function(player, profile)
		local now = os.time()
		local amount, elapsed = Economy.offlineEarnings(profile, now)
		if amount > 0 then
			PlayerState.addCoins(player, profile, amount)
			task.delay(4, function()
				Net.push(player, "Offline", { amount = amount, seconds = elapsed })
			end)
		end
		-- Tell returning players a gift is waiting.
		local today = Calendar.dayNumber(now)
		local adventOpen = Calendar.adventDay(now)
		if
			profile.daily.lastDay ~= today or (adventOpen and not profile.advent["d" .. adventOpen])
		then
			task.delay(6, function()
				Net.push(player, "Announce", { kind = "GiftWaiting" })
			end)
		end
	end)

	Net.handle("ClaimDaily", 1, 2, function(player)
		return Rewards.claimDaily(player)
	end)
	Net.handle("ClaimAdvent", 1, 2, function(player)
		return Rewards.claimAdvent(player)
	end)
	Net.handle("ClaimPlaytime", 2, 4, function(player, index: unknown)
		local i = Guard.int(index, 1, #Config.PLAYTIME_GIFTS)
		if not i then
			return false, "Unknown gift"
		end
		return Rewards.claimPlaytime(player, i)
	end)
	Net.handle("TutorialStep", 2, 4, function(player, step: unknown)
		local s = Guard.int(step, 0, 20)
		local profile = PlayerData.get(player)
		if not s or not profile then
			return false, nil
		end
		-- Tutorial progress is cosmetic UI state; only allow moving forward.
		if s > profile.tutorialStep then
			profile.tutorialStep = s
			PlayerState.dirty(player)
		end
		return true, nil
	end)
end

return Rewards
