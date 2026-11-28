--!strict
-- World interactions: proximity prompts open menus or start a delivery.
-- Prompts only open UI; every purchase still goes through validated requests.

local ProximityPromptService = game:GetService("ProximityPromptService")

local Lib = script.Parent.Parent:WaitForChild("Lib")
local Bus = require(Lib.Bus)

local Prompts = {}

function Prompts.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local kind = prompt:GetAttribute("Kind")
		if kind == "Egg" then
			Bus.fire("OpenMenu", "Pets", "Eggs")
		elseif kind == "Gifts" then
			Bus.fire("OpenMenu", "Gifts", "Daily")
		elseif kind == "Wardrobe" then
			Bus.fire("OpenMenu", "Wardrobe", "Hats")
		elseif kind == "Sleigh" then
			Bus.fire("StartDelivery")
		elseif kind == "TrainRide" then
			Bus.fire("Ride", "Train")
		elseif kind == "CarouselRide" then
			Bus.fire("Ride", "Carousel")
		end
	end)
end

return Prompts
