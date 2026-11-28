--!strict
-- Santa's Little Helper server entry point.
-- Systems are started in an explicit order because some depend on others
-- (the world must exist before plots are claimed, data before gameplay).

local Systems = script:WaitForChild("Systems")

local WorldBuilder = require(Systems.WorldBuilder)
local PlayerData = require(Systems.PlayerData)
local PlayerState = require(Systems.PlayerState)
local Workshop = require(Systems.Workshop)
local Events = require(Systems.Events)
local Sleigh = require(Systems.Sleigh)
local Pets = require(Systems.Pets)
local Rewards = require(Systems.Rewards)
local Shop = require(Systems.Shop)
local Leaderboards = require(Systems.Leaderboards)
local Snowball = require(Systems.Snowball)

WorldBuilder.init()

-- Gameplay systems register their PlayerData callbacks before data starts
-- loading so no player is missed.
PlayerState.start()
Workshop.start()
Events.start()
Sleigh.start()
Pets.start()
Rewards.start()
Shop.start()
Leaderboards.start()
Snowball.start()

PlayerData.start()

print("[Santa's Little Helper] server started 🎄")
