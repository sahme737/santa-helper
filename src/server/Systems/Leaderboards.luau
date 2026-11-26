--!strict
-- Global holiday leaderboards (OrderedDataStore): most presents delivered
-- and most Cheer earned this season. Shown on boards in the hub.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)

local PlayerData = require(script.Parent.PlayerData)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Leaderboards = {}

local UPDATE_INTERVAL = 120

type Board = { key: string, storeName: string, field: string, store: OrderedDataStore? }

local boards: { Board } = {
	{
		key = "Delivered",
		storeName = Config.LEADERBOARD_DELIVERED,
		field = "delivered",
		store = nil,
	},
	{ key = "Cheer", storeName = Config.LEADERBOARD_CHEER, field = "lifetimeCoins", store = nil },
	{ key = "Stars", storeName = Config.LEADERBOARD_STARS, field = "stars", store = nil },
}

local lastSubmitted: { [Player]: { [string]: number } } = {}
local nameCache: { [number]: string } = {}

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and name then name else "Elf #" .. tostring(userId % 10000)
	nameCache[userId] = result
	return result
end

local function submit(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local last = lastSubmitted[player]
	if not last then
		last = {}
		lastSubmitted[player] = last
	end
	for _, board in boards do
		local store = board.store
		local value = math.floor((profile :: any)[board.field] or 0)
		if store and value > 0 and last[board.key] ~= value then
			local ok = pcall(function()
				store:SetAsync(tostring(player.UserId), value)
			end)
			if ok then
				last[board.key] = value
			end
		end
	end
end

local function refreshBoard(board: Board)
	local store = board.store
	local gui = WorldBuilder.boards[board.key]
	if not store or not gui then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		return
	end
	local entries = (pages :: DataStorePages):GetCurrentPage()
	local list = gui:FindFirstChild("List")
	if not list then
		return
	end
	for i = 1, 10 do
		local row = list:FindFirstChild("Row" .. i)
		if row and row:IsA("TextLabel") then
			local entry = entries[i]
			if entry then
				local userId = tonumber(entry.key) or 0
				local medal = if i == 1
					then "🥇"
					elseif i == 2 then "🥈"
					elseif i == 3 then "🥉"
					else `{i}.`
				row.Text = `{medal} {nameFor(userId)}  —  {Format.short(entry.value)}`
			else
				row.Text = `{i}. ...`
			end
		end
	end
end

function Leaderboards.start()
	for _, board in boards do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(board.storeName)
		end)
		if ok then
			board.store = store
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		submit(player)
		lastSubmitted[player] = nil
	end)

	task.spawn(function()
		task.wait(10)
		while true do
			for _, player in Players:GetPlayers() do
				submit(player)
				task.wait(0.5)
			end
			for _, board in boards do
				refreshBoard(board)
			end
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return Leaderboards
