--!strict
-- Where the local player is, for UI that only belongs to one game.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local PlotLayout = require(Shared.PlotLayout)

local Where = {}

local player = Players.LocalPlayer
local REACH = PlotLayout.SIZE * 0.5 + 40

-- True while the player stands on or just outside their own workshop.
function Where.atWorkshop(): boolean
	local index = player:GetAttribute("Plot")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if typeof(index) ~= "number" or not root or not root:IsA("BasePart") then
		return false
	end
	local centre = PlotLayout.plotCFrame(index, Config.MAX_PLOTS).Position
	local away = Vector3.new(root.Position.X - centre.X, 0, root.Position.Z - centre.Z)
	return away.Magnitude < REACH
end

return Where
