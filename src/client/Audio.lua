--[[
	Client audio director.
	  * Master / Music / SFX volumes (SoundGroups) from Settings, with a global "duck"
	    used for the dead-silence beat before the monster screams
	  * smoothly cross-faded loops (ambient drone, tension bed, chase layers, breathing)
	  * heartbeat scheduler (lub-dub at a variable BPM)
	  * random positional ambience: distant bangs, creaks, whispers, footsteps above, drips
]]

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local SoundLibrary = require(Shared.SoundLibrary)
local Util = require(Shared.Util)

local Settings = require(script.Parent.Settings)

local Audio = {}

local groups = {} :: { [string]: SoundGroup? }
local loops = {} :: { [string]: { Sound: Sound, Target: number, Current: number, Pitch: number, Speed: number } }
local duck = 1
local duckTarget = 1
local duckSpeed = 6

Audio.InGame = false
Audio.OnThunder = nil :: (() -> ())?

local function applyVolumes()
	if groups.Master then
		(groups.Master :: SoundGroup).Volume = Settings.Get("Master") * duck
	end
	if groups.Music then
		(groups.Music :: SoundGroup).Volume = Settings.Get("Music")
	end
	if groups.SFX then
		(groups.SFX :: SoundGroup).Volume = Settings.Get("SFX")
	end
end

function Audio.Play(category: string, name: string, target: any?, options: { [string]: any }?): Sound?
	return SoundLibrary.Play(category, name, target, options)
end

-- Ensures a loop exists and fades it to `volume` (0..1 of its base volume).
function Audio.SetLoop(key: string, category: string, name: string, volume: number, pitch: number?, fadeSpeed: number?)
	local entry = loops[key]
	if not entry then
		if volume <= 0 then
			return
		end
		local sound = SoundLibrary.Create(category, name, SoundService)
		if not sound then
			return
		end
		sound.Looped = true
		sound.Volume = 0
		sound:Play()
		entry = { Sound = sound, Target = 0, Current = 0, Pitch = 1, Speed = 2 }
		loops[key] = entry
	end
	entry.Target = volume
	entry.Pitch = pitch or 1
	entry.Speed = fadeSpeed or 2
end

function Audio.StopLoop(key: string, fadeSpeed: number?)
	local entry = loops[key]
	if entry then
		entry.Target = 0
		entry.Speed = fadeSpeed or 2
	end
end

function Audio.StopAllLoops(fadeSpeed: number?)
	for key in loops do
		Audio.StopLoop(key, fadeSpeed)
	end
end

-- Drops everything to `level` (0 = silence) over ~1/speed seconds.
function Audio.Duck(level: number, speed: number?)
	duckTarget = level
	duckSpeed = speed or 6
end

---------------------------------------------------------------------------------------------
-- Heartbeat
---------------------------------------------------------------------------------------------
local heartRate = 0 -- beats per minute; 0 = off
local heartVolume = 0
local nextBeat = 0

function Audio.SetHeartbeat(bpm: number, volume: number)
	heartRate = bpm
	heartVolume = volume
end

---------------------------------------------------------------------------------------------
-- Random ambience
---------------------------------------------------------------------------------------------
local AMBIENT_POOL = {
	{ Name = "DistantBang", Weight = 3, Min = 40, Max = 90 },
	{ Name = "MetalCreak", Weight = 3, Min = 25, Max = 70 },
	{ Name = "Whisper", Weight = 1.5, Min = 4, Max = 10 },
	{ Name = "FootstepsAbove", Weight = 2, Min = 15, Max = 40, Above = true },
	{ Name = "Drip", Weight = 2.5, Min = 6, Max = 20 },
	{ Name = "Thunder", Weight = 1.2, Min = 0, Max = 0, Global = true },
}
local nextAmbient = os.clock() + 8

local function pickAmbient()
	local total = 0
	for _, entry in AMBIENT_POOL do
		total += entry.Weight
	end
	local roll = math.random() * total
	for _, entry in AMBIENT_POOL do
		roll -= entry.Weight
		if roll <= 0 then
			return entry
		end
	end
	return AMBIENT_POOL[1]
end

local function playAmbient()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local entry = pickAmbient()
	if entry.Global then
		task.delay(math.random() * 0.4, function()
			Audio.Play("Ambient", "Thunder", nil, { PitchVariance = 0.15, Volume = 0.6 + math.random() * 0.5 })
		end)
		if Audio.OnThunder then
			Audio.OnThunder()
		end
		return
	end
	local angle = math.random() * math.pi * 2
	local distance = entry.Min + math.random() * (entry.Max - entry.Min)
	local offset = Vector3.new(math.cos(angle) * distance, entry.Above and 16 or math.random(-2, 4), math.sin(angle) * distance)
	Audio.Play("Ambient", entry.Name, camera.CFrame.Position + offset, { PitchVariance = 0.12 })
end

---------------------------------------------------------------------------------------------

function Audio.Init()
	groups.Master = SoundLibrary.GetGroup("Master")
	groups.Music = SoundLibrary.GetGroup("Music")
	groups.SFX = SoundLibrary.GetGroup("SFX")
	applyVolumes()
	Settings.Changed:Connect(function(key)
		if key == "Master" or key == "Music" or key == "SFX" then
			applyVolumes()
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		-- duck
		if duck ~= duckTarget then
			duck = Util.damp(duck, duckTarget, duckSpeed, dt)
			if math.abs(duck - duckTarget) < 0.005 then
				duck = duckTarget
			end
			applyVolumes()
		end
		-- loops
		for key, entry in loops do
			entry.Current = Util.damp(entry.Current, entry.Target, entry.Speed, dt)
			local sound = entry.Sound
			sound.Volume = (sound:GetAttribute("BaseVolume") or 0.5) * entry.Current
			sound.PlaybackSpeed = (sound:GetAttribute("BasePitch") or 1) * entry.Pitch
			if entry.Target <= 0 and entry.Current < 0.01 then
				sound:Destroy()
				loops[key] = nil
			end
		end
		-- heartbeat
		local now = os.clock()
		if heartRate > 0 and heartVolume > 0.01 and now >= nextBeat then
			nextBeat = now + 60 / heartRate
			Audio.Play("Player", "Heartbeat", nil, { Volume = heartVolume })
			task.delay(math.clamp(14 / heartRate, 0.12, 0.24), function()
				Audio.Play("Player", "Heartbeat", nil, { Volume = heartVolume * 0.7, Pitch = 0.88 })
			end)
		end
		-- ambience
		if Audio.InGame and now >= nextAmbient then
			nextAmbient = now + Config.Audio.AmbientMinGap + math.random() * (Config.Audio.AmbientMaxGap - Config.Audio.AmbientMinGap)
			if not (Workspace:GetAttribute("Stage") == 0) then
				playAmbient()
			end
		end
	end)
end

return Audio
