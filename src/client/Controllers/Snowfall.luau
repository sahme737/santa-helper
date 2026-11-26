--!strict
-- Gentle snowfall around the camera.

local RunService = game:GetService("RunService")

local Snowfall = {}

function Snowfall.start()
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "SnowEmitter"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(160, 1, 160)
	emitterPart.Parent = workspace

	local snow = Instance.new("ParticleEmitter")
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.LightEmission = 0.3
	snow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	snow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.1),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	snow.Lifetime = NumberRange.new(8, 10)
	snow.Rate = 120
	snow.Speed = NumberRange.new(5, 8)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.SpreadAngle = Vector2.new(15, 15)
	snow.Acceleration = Vector3.new(1.5, 0, 0.5)
	snow.RotSpeed = NumberRange.new(-40, 40)
	snow.Parent = emitterPart

	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			emitterPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0))
		end
	end)
end

return Snowfall
