--!strict
-- Music and ambience. Plays a Christmas playlist in the workshop, switches to
-- an upbeat one in the sleigh, and layers sleigh bells, wind and a ticking
-- clock over the delivery flight. Also turns server "Effect" pushes into
-- reward sounds. The 🎵 button on the HUD mutes the music only.

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Lib = script.Parent.Parent:WaitForChild("Lib")
local UI = require(Lib.UI)
local Net = require(Lib.Net)
local Bus = require(Lib.Bus)

local Audio = {}

local FADE = TweenInfo.new(1.2, Enum.EasingStyle.Sine)

local music: Sound
local bells: Sound
local wind: Sound
local ticking: Sound
local mode = "Workshop"
local trackIndex = 0
local muted = false

local function fade(sound: Sound, volume: number)
	TweenService:Create(sound, FADE, { Volume = volume }):Play()
end

local function playlist(): { string }
	local list = (Config.MUSIC :: any)[mode]
	return if typeof(list) == "table" then list else {}
end

local function nextTrack()
	local list = playlist()
	if #list == 0 then
		music:Stop()
		return
	end
	trackIndex = trackIndex % #list + 1
	music.SoundId = list[trackIndex]
	music.Volume = 0
	music.TimePosition = 0
	music:Play()
	fade(music, if muted then 0 else Config.MUSIC.VOLUME)
end

local function loop(name: string, id: string): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	return s
end

function Audio.setMode(newMode: string)
	if mode == newMode then
		return
	end
	mode = newMode
	trackIndex = 0
	fade(music, 0)
	task.delay(FADE.Time, function()
		if mode == newMode then
			nextTrack()
		end
	end)
end

function Audio.setMuted(value: boolean)
	muted = value
	fade(music, if muted then 0 else Config.MUSIC.VOLUME)
	Bus.fire("MusicMuted", muted)
end

function Audio.init()
	music = Instance.new("Sound")
	music.Name = "Music"
	music.Volume = 0
	music.Parent = SoundService
	bells = loop("SleighBells", Config.SOUNDS.SleighBells)
	wind = loop("Wind", Config.SOUNDS.Wind)
	ticking = loop("Ticking", Config.SOUNDS.Ticking)
end

function Audio.start()
	music.Ended:Connect(nextTrack)
	nextTrack()

	Bus.on("ToggleMusic", function()
		Audio.setMuted(not muted)
	end)

	-- Flight layers: { flying: boolean, wind: number (0..1), hurry: boolean }
	Bus.on("FlightAudio", function(state: { flying: boolean, wind: number, hurry: boolean })
		if state.flying then
			Audio.setMode("Sleigh")
			if not bells.IsPlaying then
				bells:Play()
				wind:Play()
			end
			fade(bells, 0.28)
			fade(wind, 0.12 + state.wind * 0.3)
			if state.hurry and not ticking.IsPlaying then
				ticking.TimePosition = 0
				ticking.Volume = 0.5
				ticking:Play()
			elseif not state.hurry and ticking.IsPlaying then
				ticking:Stop()
			end
		else
			Audio.setMode("Workshop")
			fade(bells, 0)
			fade(wind, 0)
			ticking:Stop()
			task.delay(FADE.Time, function()
				if mode == "Workshop" then
					bells:Stop()
					wind:Stop()
				end
			end)
		end
	end)

	Net.on("Effect", function(payload)
		local kind = payload.kind
		if kind == "Built" then
			UI.sound("Purchase", 0.6)
			UI.sound("Sparkle", 0.4)
		elseif kind == "Purchase" then
			UI.sound("Purchase", 0.6)
		elseif kind == "RankUp" then
			UI.sound("LevelUp", 0.7)
		elseif kind == "Rebirth" then
			UI.sound("Win", 0.7)
			UI.sound("PartyHorn", 0.5)
		elseif kind == "Community" then
			UI.sound("PartyHorn", 0.6)
		end
	end)

	-- Warm the cache so the first click or coin isn't silent.
	task.spawn(function()
		local assets: { Instance } = { bells, wind, ticking }
		for name, id in Config.SOUNDS :: any do
			if typeof(id) == "string" and id ~= "" then
				local s = Instance.new("Sound")
				s.Name = "Preload_" .. name
				s.SoundId = id
				table.insert(assets, s)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(assets)
		end)
	end)
end

return Audio
