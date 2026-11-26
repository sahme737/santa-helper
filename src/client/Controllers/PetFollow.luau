--!strict
-- Animates every pet reindeer locally so they trot and hop after their
-- owners. Pet models are anchored server instances; moving them here is a
-- local-only change, which costs no network traffic.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PetFollow = {}

local current: { [Model]: CFrame } = {}

function PetFollow.start()
	local folder = workspace:WaitForChild("Pets")
	folder.ChildRemoved:Connect(function(child)
		current[child :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for _, model in folder:GetChildren() do
			if not model:IsA("Model") then
				continue
			end
			local ownerId = model:GetAttribute("OwnerId")
			local owner = if typeof(ownerId) == "number"
				then Players:GetPlayerByUserId(ownerId)
				else nil
			local character = owner and owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then
				continue
			end
			local slot = model:GetAttribute("Slot") or 1
			local count = model:GetAttribute("SlotCount") or 1
			-- Fan pets out in an arc behind the owner.
			local spread = (slot - (count + 1) / 2) * 4
			local back = 6 + math.abs(spread) * 0.3
			local flying = character:FindFirstChild("DeliverySleigh") ~= nil
			local height = if flying then 2 else -2.6
			local target = root.CFrame * CFrame.new(spread, height, back)
			local speed = root.AssemblyLinearVelocity.Magnitude
			local hop = if speed > 2
				then math.abs(math.sin(t * 10 + slot)) * 0.8
				else math.sin(t * 2 + slot) * 0.15
			local look = CFrame.lookAt(target.Position, target.Position + root.CFrame.LookVector)
			local goal = look * CFrame.new(0, hop, 0)
			local prev = current[model] or goal
			local alpha = math.min(1, dt * (if flying then 12 else 8))
			local nextCF = prev:Lerp(goal, alpha)
			if (prev.Position - goal.Position).Magnitude > 80 then
				nextCF = goal
			end
			current[model] = nextCF
			model:PivotTo(nextCF)
		end
	end)
end

return PetFollow
