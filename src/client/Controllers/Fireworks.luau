--!strict
-- Christmas Fireworks: when anyone sets them off, every player sees a show
-- of coloured bursts in the sky over the plaza. Purely for fun.

local Debris = game:GetService("Debris")

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local Bus = require(Lib.Bus)

local Fireworks = {}

local COLORS = {
	Color3.fromRGB(255, 80, 90),
	Color3.fromRGB(90, 230, 130),
	Color3.fromRGB(255, 215, 80),
	Color3.fromRGB(120, 190, 255),
	Color3.fromRGB(230, 130, 255),
	Color3.fromRGB(255, 255, 255),
}
local BURSTS = 16
local showUntil = 0

local function burst(at: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Name = "Firework"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.new(at)
	part.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3.2),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1.1, 1.9)
	emitter.Speed = NumberRange.new(26, 44)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 2.2
	emitter.Acceleration = Vector3.new(0, -14, 0)
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(90)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 60
	light.Brightness = 4
	light.Parent = part
	UI.tween(light, TweenInfo.new(1.2), { Brightness = 0 })

	UI.sound("Pop", 0.5, 0.7)
	UI.sound("Sparkle", 0.35)
	Debris:AddItem(part, 3)
end

local function show()
	-- A second purchase during a show just makes it longer.
	local running = os.clock() < showUntil
	showUntil = math.max(showUntil, os.clock()) + BURSTS * 0.55
	if running then
		return
	end
	while os.clock() < showUntil do
		local angle = math.random() * math.pi * 2
		local radius = 20 + math.random() * 75
		local at =
			Vector3.new(math.cos(angle) * radius, 75 + math.random() * 45, math.sin(angle) * radius)
		burst(at, COLORS[math.random(1, #COLORS)])
		task.wait(0.3 + math.random() * 0.5)
	end
end

function Fireworks.start()
	Net.on("Fireworks", function(payload)
		local by = if typeof(payload.by) == "string" then payload.by else "Someone"
		Bus.fire("Announce", `🎆 {by} set off Christmas fireworks!`, Color3.fromRGB(255, 215, 80))
		task.spawn(show)
	end)
end

return Fireworks
