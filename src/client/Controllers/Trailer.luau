--!strict
-- The join trailer: about thirty seconds of quick camera shots, one for each
-- game, so a new arrival can see what there is before picking a gate. It can
-- be skipped at any moment and never plays twice in a visit.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local PlotLayout = require(Shared.PlotLayout)

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Bus = require(Lib.Bus)

local Trailer = {}

local T = UI.Theme
local player = Players.LocalPlayer
local PLAY = Config.PLAYGROUND
local BIND = "JoinTrailer"

type Shot = {
	title: string,
	line: string,
	color: Color3,
	length: number,
	-- `u` runs 0..1 over the shot.
	camera: (u: number) -> CFrame,
}

local function lerp(a: number, b: number, u: number): number
	return a + (b - a) * u
end

-- A camera circling `centre`, looking at a point `lift` studs above it.
local function orbit(
	centre: Vector3,
	radius: number,
	height: number,
	fromDeg: number,
	sweepDeg: number,
	lift: number
): (number) -> CFrame
	return function(u: number): CFrame
		local a = math.rad(fromDeg + sweepDeg * u)
		local eye =
			Vector3.new(centre.X + math.cos(a) * radius, height, centre.Z + math.sin(a) * radius)
		return CFrame.lookAt(eye, Vector3.new(centre.X, lift, centre.Z))
	end
end

local function trainShot(_u: number): CFrame
	local train = PLAY.TRAIN
	local theta = (workspace:GetServerTimeNow() * train.SPEED / train.RADIUS) % (math.pi * 2)
	local engine = Vector3.new(math.cos(theta), 0, math.sin(theta)) * train.RADIUS
	-- Just ahead of the engine on the plaza side, so the train rushes past.
	local ahead = theta + 0.24
	local eye = Vector3.new(math.cos(ahead), 0, math.sin(ahead)) * (train.RADIUS - 13)
	return CFrame.lookAt(eye + Vector3.new(0, 7, 0), engine + Vector3.new(0, 4, 0))
end

local function workshopShot(u: number): CFrame
	local index = player:GetAttribute("Plot")
	local plot =
		PlotLayout.plotCFrame(if typeof(index) == "number" then index else 1, Config.MAX_PLOTS)
	local eye = plot * Vector3.new(lerp(-30, 25, u), lerp(46, 24, u), lerp(-112, -62, u))
	return CFrame.lookAt(eye, plot * Vector3.new(20, 4, 0))
end

local function landingShot(u: number): CFrame
	local landing = PLAY.LANDING
	local eye = landing + Vector3.new(0, lerp(24, 10, u), lerp(-34, -16, u))
	return CFrame.lookAt(eye, landing + Vector3.new(0, 9, PLAY.GATE_DISTANCE))
end

local SHOTS: { Shot } = {
	{
		title = "🎄 CHRISTMAS PLAYGROUND 🎄",
		line = "A village full of games. Play any of them!",
		color = T.Gold,
		length = 4,
		camera = orbit(Vector3.zero, 105, 42, 235, 70, 34),
	},
	{
		title = "❄️ SNOWBALL FIGHT",
		line = "Knock the elves flat on their backs",
		color = Color3.fromRGB(120, 190, 255),
		length = 5,
		camera = orbit(Config.SNOWBALL.CENTER, 25, 9, 200, 110, 3),
	},
	{
		title = "🚂 NORTH POLE EXPRESS",
		line = "All aboard for a ride round the village",
		color = Color3.fromRGB(90, 220, 130),
		length = 5,
		camera = trainShot,
	},
	{
		title = "🎠 REINDEER CAROUSEL",
		line = "Saddle up and spin",
		color = Color3.fromRGB(210, 150, 255),
		length = 4,
		camera = orbit(PLAY.CAROUSEL.CENTER, 24, 8, 215, 95, 5),
	},
	{
		title = "⛸ ICE RINK",
		line = "Slip, slide and skate with the elves",
		color = Color3.fromRGB(130, 225, 245),
		length = 4,
		camera = orbit(PLAY.RINK.CENTER, 29, 11, 275, 100, 2),
	},
	{
		title = "🎁 SANTA'S WORKSHOP",
		line = "Wrap presents, then fly the sleigh to deliver them",
		color = Color3.fromRGB(255, 120, 120),
		length = 4.5,
		camera = workshopShot,
	},
	{
		title = "PICK A GATE AND PLAY!",
		line = "Walk through any gate to start",
		color = T.Gold,
		length = 3.5,
		camera = landingShot,
	},
}

local screen: ScreenGui
local title: TextLabel
local line: TextLabel
local flash: Frame
local playing = false
local played = false

local function build()
	screen = UI.screen("Trailer", 100)
	screen.IgnoreGuiInset = true
	screen.Enabled = false
	for _, y in { 0, 1 } do
		UI.make("Frame", {
			Name = "Bar",
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.fromScale(1, 0.1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = screen,
		})
	end
	title = UI.text({
		Name = "Title",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.82),
		Size = UDim2.fromScale(0.86, 0.13),
		MaxTextSize = 84,
		Parent = screen,
	})
	UI.textStroke(title, T.Ink, 4)
	line = UI.text({
		Name = "Line",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.885),
		Size = UDim2.fromScale(0.86, 0.055),
		MaxTextSize = 34,
		Parent = screen,
	})
	UI.textStroke(line, T.Ink, 2.5)
	flash = UI.make("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = screen,
	})
	local skip = UI.button({
		Name = "Skip",
		Text = "Skip ⏭",
		Color = Color3.fromRGB(60, 60, 75),
		-- Bottom right: the Roblox top bar swallows clicks near the top edge.
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 0.885, 0),
		Size = UDim2.fromOffset(120, 44),
		MaxTextSize = 24,
		Parent = screen,
		OnClick = function()
			playing = false
		end,
	})
	-- Above the white flash, which covers the whole screen on every cut.
	skip.ZIndex = 10
end

local function cut(shot: Shot)
	title.Text = shot.title
	title.TextColor3 = shot.color
	line.Text = shot.line
	UI.pop(title, 1.5)
	flash.BackgroundTransparency = 0.15
	UI.tween(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 })
	UI.sound("Whoosh", 0.45)
	UI.sound("Sparkle", 0.3)
end

function Trailer.play()
	local camera = workspace.CurrentCamera
	if playing or not camera then
		return
	end
	playing = true

	-- Everything else on screen steps aside for the trailer.
	local hidden: { ScreenGui } = {}
	local playerGui = player:WaitForChild("PlayerGui")
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui ~= screen and gui.Enabled then
			gui.Enabled = false
			table.insert(hidden, gui)
		end
	end
	local oldFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 58
	screen.Enabled = true
	Bus.fire("MusicMode", "Trailer")

	local index = 0
	local shot: Shot? = nil
	local shotStart = 0
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock()
		local current = shot
		if not current or t - shotStart >= current.length then
			index += 1
			current = SHOTS[index]
			if not current then
				playing = false
				return
			end
			shot = current
			shotStart = t
			cut(current)
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = current.camera(math.clamp((t - shotStart) / current.length, 0, 1))
	end)

	while playing do
		task.wait(0.05)
	end

	RunService:UnbindFromRenderStep(BIND)
	screen.Enabled = false
	camera.FieldOfView = oldFov
	camera.CameraType = Enum.CameraType.Custom
	for _, gui in hidden do
		gui.Enabled = true
	end
	Bus.fire("MusicMode", "Workshop")
end

function Trailer.init()
	build()
end

function Trailer.start()
	if played then
		return
	end
	played = true
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	-- A moment for the world and the first music track to arrive.
	task.wait(1.5)
	Trailer.play()
end

return Trailer
