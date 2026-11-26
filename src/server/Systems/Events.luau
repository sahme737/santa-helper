--!strict
-- Server-wide timed events that give the hub its rhythm:
-- * Sleigh Rush: Santa's sleigh departs every few minutes; loading your sack
--   during the final countdown pays double.
-- * Present Drops: a giant glowing present lands in the hub; everyone who
--   reaches it before it melts gets a gift (once per drop).
-- * Community Goal: every N presents delivered by the server rewards everyone.
-- * Event sign countdown to the end of the Christmas event.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Calendar = require(Shared.Calendar)
local Economy = require(Shared.Economy)
local Build = require(Shared.Util.Build)
local Format = require(Shared.Util.Format)
local ToyModels = require(Shared.Models.ToyModels)

local Net = require(script.Parent.Parent.Lib.Net)
local PlayerData = require(script.Parent.PlayerData)
local PlayerState = require(script.Parent.PlayerState)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Workshop = require(script.Parent.Workshop)

local Events = {}

local communityTotal = 0
local communityNextGoal = Config.COMMUNITY_GOAL.STEP
local rng = Random.new()

local globalState = Instance.new("Folder")
globalState.Name = "GlobalState"

function Events.addCommunityPresents(n: number)
	communityTotal += n
	globalState:SetAttribute("CommunityTotal", communityTotal)
	if communityTotal >= communityNextGoal then
		communityNextGoal += Config.COMMUNITY_GOAL.STEP
		globalState:SetAttribute("CommunityGoal", communityNextGoal)
		PlayerData.forEach(function(player, profile)
			PlayerState.addSnowflakes(player, profile, Config.COMMUNITY_GOAL.SNOWFLAKES, true)
		end)
		Net.toastAll(
			`🎉 This server delivered {communityTotal} presents! Everyone gets {Config.COMMUNITY_GOAL.SNOWFLAKES} Snowflakes!`,
			"event"
		)
		Net.pushAll("Effect", { kind = "Community" })
	end
end

--------------------------------------------------------------------------------
-- Present drops
--------------------------------------------------------------------------------

local function spawnPresentDrop()
	local drops = workspace:FindFirstChild("Drops")
	if not drops or not Calendar.eventActive(os.time()) then
		return
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(70, 110)
	local pos = Vector3.new(math.cos(angle) * radius, 0.5, math.sin(angle) * radius)

	local model = ToyModels.present(7, rng:NextInteger(1, 5))
	model.Name = "PresentDrop"
	model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
	local hitbox = Build.part({
		Name = "Hitbox",
		Size = Vector3.new(12, 12, 12),
		CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)),
		Transparency = 1,
		CanCollide = false,
		CanTouch = true,
		Parent = model,
	})
	local beam = Build.deco({
		Name = "Beacon",
		Size = Vector3.new(3, 200, 3),
		CFrame = CFrame.new(pos + Vector3.new(0, 100, 0)),
		Color = Color3.fromRGB(255, 215, 90),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		Parent = model,
	})
	Build.light(beam, Color3.fromRGB(255, 215, 90), 30, 2)
	Build.billboard(
		hitbox,
		"🎁 Present Drop!",
		UDim2.fromOffset(200, 50),
		Vector3.new(0, 9, 0),
		Color3.fromRGB(255, 230, 120),
		400
	)
	model:SetAttribute("ExpiresAt", os.time() + Config.PRESENT_DROP.LIFETIME)
	model.Parent = drops

	local claimed: { [Player]: boolean } = {}
	hitbox.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or claimed[player] then
			return
		end
		local profile = PlayerData.get(player)
		if not profile then
			return
		end
		claimed[player] = true
		local ctx = PlayerState.ctx(player)
		local coins = math.max(
			Config.PRESENT_DROP.MIN_COINS,
			math.floor(Economy.incomePerSecond(profile, ctx) * Config.PRESENT_DROP.INCOME_SECONDS)
		)
		PlayerState.addCoins(player, profile, coins)
		local text = `🎁 Present Drop! +{Format.short(coins)} Cheer`
		if rng:NextNumber() < Config.PRESENT_DROP.SNOWFLAKE_CHANCE then
			local got =
				PlayerState.addSnowflakes(player, profile, Config.PRESENT_DROP.SNOWFLAKES, true)
			text ..= ` +{got} ❄`
		end
		Net.toast(player, text, "success")
		Net.push(player, "Effect", { kind = "Drop", position = pos })
	end)

	Net.pushAll(
		"Announce",
		{ kind = "PresentDrop", position = pos, lifetime = Config.PRESENT_DROP.LIFETIME }
	)
	task.delay(Config.PRESENT_DROP.LIFETIME, function()
		model:Destroy()
	end)
end

--------------------------------------------------------------------------------

local function updateEventSign()
	local label = WorldBuilder.eventSign
	if not label then
		return
	end
	local now = os.time()
	if Calendar.eventActive(now) then
		local advent = Calendar.adventDay(now)
		local line = if advent
			then `Advent Door #{advent} is open!`
			else `Advent starts in {Calendar.daysUntilAdvent(now)} days`
		label.Text = `🎄 Christmas Event 🎄\nEnds in {Format.time(
			Calendar.eventSecondsLeft(now)
		)}\n{line}`
	else
		label.Text = "🎄 Thanks for a merry Christmas! 🎄\nSee you next season!"
	end
end

function Events.start()
	globalState:SetAttribute("CommunityTotal", 0)
	globalState:SetAttribute("CommunityGoal", communityNextGoal)
	globalState:SetAttribute("RushCycle", Config.SLEIGH_RUSH.CYCLE)
	globalState:SetAttribute("RushWindow", Config.SLEIGH_RUSH.RUSH_WINDOW)
	globalState:SetAttribute("CycleStart", os.time())
	globalState.Parent = game:GetService("ReplicatedStorage")

	-- Sleigh rush cycle
	task.spawn(function()
		local cycleStart = os.time()
		local wasRush = false
		while true do
			local elapsed = os.time() - cycleStart
			local remaining = Config.SLEIGH_RUSH.CYCLE - elapsed
			local rush = remaining <= Config.SLEIGH_RUSH.RUSH_WINDOW
			if rush ~= wasRush then
				wasRush = rush
				Workshop.setRush(rush, Config.SLEIGH_RUSH.MULTIPLIER)
				globalState:SetAttribute("Rush", rush)
				if rush then
					Net.pushAll("Announce", { kind = "RushStart", seconds = remaining })
				end
			end
			if remaining <= 0 then
				cycleStart = os.time()
				globalState:SetAttribute("CycleStart", cycleStart)
				Net.pushAll("Announce", { kind = "SleighDeparted" })
			end
			task.wait(1)
		end
	end)

	-- Present drops
	task.spawn(function()
		task.wait(90)
		while true do
			spawnPresentDrop()
			globalState:SetAttribute("NextDrop", os.time() + Config.PRESENT_DROP.INTERVAL)
			task.wait(Config.PRESENT_DROP.INTERVAL)
		end
	end)
	globalState:SetAttribute("NextDrop", os.time() + 90)

	task.spawn(function()
		while true do
			updateEventSign()
			task.wait(30)
		end
	end)
end

return Events
