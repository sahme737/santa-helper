--!strict
-- Player profiles: the single source of truth for persistent player state.
-- * Session locked: one server owns a profile at a time (prevents dupes).
-- * Every DataStore call uses pcall + retry with backoff.
-- * Saves on autosave (staggered), leave, and BindToClose.
-- * A failed load kicks the player instead of handing out a blank profile.
-- Gameplay code reads/writes the in-memory profile via PlayerData.get().

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)

type Profile = Types.Profile

local PlayerData = {}

local CURRENT_VERSION = 1
local LOCK_TIMEOUT = Config.AUTOSAVE_INTERVAL * 3
local JOB_ID = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(math.random(1, 1e9))

local DEFAULT_PROFILE: Profile = {
	version = CURRENT_VERSION,
	coins = Config.PLAYGROUND.STARTING_CHEER,
	snowflakes = 0,
	lifetimeCoins = 0,
	delivered = 0,
	machines = { M1 = 1 },
	decor = {},
	elves = 0,
	sackLevel = 0,
	sack = 0,
	sleigh = { speed = 0, magnet = 0, time = 0 },
	rebirths = 0,
	pets = {},
	nextPetUid = 1,
	equipped = {},
	cosmetics = { owned = { SantaHat = true }, hat = "SantaHat", sweater = nil, trail = nil },
	daily = { lastDay = 0, streak = 0 },
	advent = {},
	boostUntil = 0,
	eggTokens = 0,
	lastOnline = 0,
	incomeRate = 0,
	receipts = {},
	tutorialStep = 0,
	createdAt = 0,
	xp = 0,
	rank = 1,
	routes = {},
	stars = 0,
}

-- Future schema changes: add MIGRATIONS[n] that upgrades version n to n + 1.
local MIGRATIONS: { [number]: (any) -> any } = {}

local function deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value :: any do
		out[k] = deepCopy(v)
	end
	return out :: any
end

-- Fill any missing fields from defaults (non-destructive) and migrate.
local function reconcile(data: any): Profile
	if typeof(data) ~= "table" then
		data = deepCopy(DEFAULT_PROFILE)
		data.createdAt = os.time()
		return data
	end
	data.version = data.version or 1
	while data.version < CURRENT_VERSION do
		local step = MIGRATIONS[data.version]
		if not step then
			error(`missing migration from v{data.version}`)
		end
		data = step(data)
		data.version += 1
	end
	for key, default in DEFAULT_PROFILE :: any do
		if data[key] == nil then
			data[key] = deepCopy(default)
		end
	end
	if data.cosmetics.owned == nil then
		data.cosmetics.owned = { SantaHat = true }
	end
	return data
end

type Session = {
	profile: Profile,
	saving: boolean,
	releasing: boolean, -- a final save is in progress; gameplay must stop touching the profile
	released: boolean,
	persist: boolean, -- false when DataStores are unavailable in Studio
}

local sessions: { [Player]: Session } = {}
local loading: { [Player]: boolean } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}
local beforeSaveCallbacks: { (Player, Profile) -> () } = {}
local releasingCallbacks: { (Player, Profile) -> () } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[PlayerData] DataStore unavailable: {result}`)
	end
end

local function keyFor(userId: number): string
	return "u_" .. tostring(userId)
end

local function withRetry<T>(attempts: number, fn: () -> T): (boolean, T | string)
	local delaySeconds = 1
	local lastErr: any = nil
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		warn(`[PlayerData] attempt {attempt}/{attempts} failed: {result}`)
		if attempt < attempts then
			task.wait(delaySeconds)
			delaySeconds = math.min(delaySeconds * 2, 8)
		end
	end
	return false, tostring(lastErr)
end

-- Claim the session lock and load. Returns ("ok", profile) | ("locked", nil) | ("error", nil)
local function claimAndLoad(userId: number): (string, Profile?)
	local ds = store
	if not ds then
		return "error", nil
	end
	local status = "error"
	local loaded: Profile? = nil
	local ok = withRetry(4, function()
		ds:UpdateAsync(keyFor(userId), function(old: any)
			local now = os.time()
			if
				typeof(old) == "table"
				and old.lockJob
				and old.lockJob ~= JOB_ID
				and now - (old.lockTime or 0) < LOCK_TIMEOUT
			then
				status = "locked"
				loaded = nil
				return nil -- abort: another server still owns this profile
			end
			local data = reconcile(if typeof(old) == "table" then deepCopy(old.data) else nil)
			status = "ok"
			loaded = data
			return { data = data, lockJob = JOB_ID, lockTime = now }
		end)
		return true
	end)
	if not ok then
		return "error", nil
	end
	return status, loaded
end

local function writeProfile(player: Player, session: Session, release: boolean): boolean
	if not session.persist then
		return true
	end
	local ds = store
	if not ds then
		return false
	end
	for _, cb in beforeSaveCallbacks do
		local ok, err = pcall(cb, player, session.profile)
		if not ok then
			warn(`[PlayerData] beforeSave callback failed: {err}`)
		end
	end
	session.profile.lastOnline = os.time()
	local snapshot = deepCopy(session.profile)
	local aborted = false
	local ok = withRetry(if release then 5 else 3, function()
		ds:UpdateAsync(keyFor(player.UserId), function(old: any)
			if typeof(old) == "table" and old.lockJob and old.lockJob ~= JOB_ID then
				aborted = true
				return nil -- someone else owns it now; never overwrite their data
			end
			aborted = false
			return {
				data = snapshot,
				lockJob = if release then nil else JOB_ID,
				lockTime = os.time(),
			}
		end)
		return true
	end)
	if aborted then
		warn(`[PlayerData] save aborted for {player.UserId}: lock owned by another server`)
		return false
	end
	return ok
end

local function save(player: Player, release: boolean): boolean
	local session = sessions[player]
	if not session or session.released then
		return false
	end
	if release then
		-- From here on PlayerData.get() returns nil, so nothing can be granted
		-- into a profile whose final snapshot is about to be written.
		session.releasing = true
	elseif session.releasing then
		return false
	end
	-- Avoid overlapping writes to the same key.
	local waited = 0
	while session.saving and waited < 30 do
		task.wait(0.5)
		waited += 0.5
	end
	-- Re-check: a release may have finished (or started) while we waited.
	if session.released or (not release and session.releasing) then
		return false
	end
	session.saving = true
	local ok = writeProfile(player, session, release)
	session.saving = false
	if release then
		session.released = true
	end
	return ok
end

local function onPlayerAdded(player: Player)
	loading[player] = true
	local status, profile = "error", nil
	for attempt = 1, 5 do
		status, profile = claimAndLoad(player.UserId)
		if status ~= "locked" then
			break
		end
		-- The previous server may still be releasing the profile.
		task.wait(attempt * 2)
	end

	local persist = true
	if status ~= "ok" and RunService:IsStudio() then
		warn(
			"[PlayerData] Studio: DataStores unavailable (enable API access in Game Settings to test saving). Using a temporary profile."
		)
		profile = reconcile(nil)
		status = "ok"
		persist = false
	end

	loading[player] = nil
	if status ~= "ok" or not profile then
		player:Kick(
			if status == "locked"
				then "Your workshop is still being saved on another server. Please rejoin in a moment!"
				else "We couldn't load your workshop. Please rejoin!"
		)
		return
	end

	local session: Session = {
		profile = profile,
		saving = false,
		releasing = false,
		released = false,
		persist = persist,
	}

	if player.Parent ~= Players then
		-- Left while loading: release the lock right away.
		sessions[player] = session
		save(player, true)
		sessions[player] = nil
		return
	end

	sessions[player] = session
	for _, cb in loadedCallbacks do
		task.spawn(cb, player, profile)
	end

	-- Staggered autosave loop.
	task.spawn(function()
		task.wait(player.UserId % Config.AUTOSAVE_INTERVAL)
		while sessions[player] == session and not session.released do
			save(player, false)
			task.wait(Config.AUTOSAVE_INTERVAL)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	for _, cb in releasingCallbacks do
		pcall(cb, player, session.profile)
	end
	save(player, true)
	sessions[player] = nil
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function PlayerData.get(player: Player): Profile?
	local session = sessions[player]
	if session and not session.released and not session.releasing then
		return session.profile
	end
	return nil
end

function PlayerData.onLoaded(cb: (Player, Profile) -> ())
	table.insert(loadedCallbacks, cb)
	for player, session in sessions do
		task.spawn(cb, player, session.profile)
	end
end

function PlayerData.onBeforeSave(cb: (Player, Profile) -> ())
	table.insert(beforeSaveCallbacks, cb)
end

function PlayerData.onReleasing(cb: (Player, Profile) -> ())
	table.insert(releasingCallbacks, cb)
end

-- Immediate save (used after Robux purchases). Returns true when persisted.
function PlayerData.saveNow(player: Player): boolean
	return save(player, false)
end

function PlayerData.forEach(cb: (Player, Profile) -> ())
	for player, session in sessions do
		if not session.released and not session.releasing then
			cb(player, session.profile)
		end
	end
end

function PlayerData.isLoading(player: Player): boolean
	return loading[player] == true
end

function PlayerData.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				local session = sessions[player]
				if session then
					for _, cb in releasingCallbacks do
						pcall(cb, player, session.profile)
					end
				end
				save(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		local limit = if RunService:IsStudio() then 3 else 25
		while pending > 0 and os.clock() - started < limit do
			task.wait(0.1)
		end
	end)
end

return PlayerData
