--[[
	The chase director on the client: turns "how close is it / is it hunting me"
	into music layers, heartbeat, breathing, FOV, camera shake, vignette, chromatic
	fringing and colour grading - and plays the beats of the detection sequence:

	  HeadTurn -> world dims, a slow dolly-zoom, your character flinches
	  Silence  -> every sound drops out
	  Scream   -> sound slams back, flash, violent shake, FOV punch
	  Chase    -> drums, drone, heartbeat, red pulsing vignette, wider FOV
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Audio = require(script.Parent.Audio)
local CameraFX = require(script.Parent.CameraFX)
local Movement = require(script.Parent.Movement)
local PostFX = require(script.Parent.PostFX)

local ChaseFX = {}
ChaseFX.Active = false -- in-game (not in menu)
ChaseFX.Intensity = 0

local player = Players.LocalPlayer
local glimpseUntil = 0
local dreadUntil = 0

local function monsterInfo(): (Model?, number)
	local monster = Workspace:FindFirstChild("Grinner") :: Model?
	local camera = Workspace.CurrentCamera
	if not monster or monster:GetAttribute("Hidden") or not camera then
		return monster, math.huge
	end
	local head = monster:FindFirstChild("Head") :: BasePart?
	if not head then
		return monster, math.huge
	end
	return monster, (head.Position - camera.CFrame.Position).Magnitude
end

local function proximityTo(position: Vector3?, range: number): number
	local camera = Workspace.CurrentCamera
	if not position or not camera then
		return 0
	end
	return math.clamp(1 - (position - camera.CFrame.Position).Magnitude / range, 0, 1)
end

local function onCue(cue: string, data)
	if not ChaseFX.Active then
		return
	end
	data = data or {}
	local isTarget = data.Target == player.UserId or data.Final == true
	local near = proximityTo(data.Position, 160)
	if cue == "HeadTurn" then
		if isTarget or near > 0.3 then
			dreadUntil = os.clock() + Config.Monster.HeadTurnTime + Config.Monster.SilenceTime
			Audio.Duck(0.45, 3)
			CameraFX.SetFOVOffset("Dread", -8)
			CameraFX.SetRoll(3)
			if isTarget then
				Movement.SetAfraid(true)
				Audio.Play("Player", "Gasp", nil, { Volume = 0.5 })
			end
		end
	elseif cue == "Silence" then
		if isTarget or near > 0.3 then
			Audio.Duck(0, 14)
		end
	elseif cue == "Scream" then
		Audio.Duck(1, 40)
		CameraFX.SetFOVOffset("Dread", 0)
		CameraFX.SetRoll(0)
		if isTarget or near > 0.2 then
			local strength = isTarget and 1 or near
			CameraFX.AddTrauma(0.95 * strength)
			CameraFX.PunchFOV(14 * strength)
			PostFX.Flash(Color3.fromRGB(255, 220, 220), 0.45 * strength, 0.4)
			Audio.Play("Music", "Stinger", nil, { Volume = strength })
		end
		task.delay(0.8, function()
			Movement.SetAfraid(false)
		end)
	elseif cue == "ChaseEnd" then
		CameraFX.SetFOVOffset("Dread", 0)
		CameraFX.SetRoll(0)
		Movement.SetAfraid(false)
		if data.Reason == "Safe" or data.Reason == "Lost" then
			task.delay(1.5, function()
				Audio.Play("Player", "Gasp", nil, { Volume = 0.4, Pitch = 0.9 })
			end)
		end
	elseif cue == "Glimpse" then
		glimpseUntil = os.clock() + 6
		Audio.Play("Music", "Stinger", nil, { Volume = 0.35, Pitch = 0.8 })
		CameraFX.PunchFOV(-4)
	end
end

local function onScare(name: string, data)
	if not ChaseFX.Active then
		return
	end
	data = data or {}
	if name == "PowerOn" then
		PostFX.Flash(Color3.new(1, 1, 1), 0.2, 0.5)
		CameraFX.AddTrauma(0.25)
	elseif name == "PowerSurge" then
		PostFX.Flash(Color3.new(0, 0, 0), 0.9, 1.2)
		CameraFX.AddTrauma(0.3)
	elseif name == "Blackout" then
		Audio.Play("Ambient", "PowerOn", nil, { Pitch = 0.6, Volume = 0.8 })
		CameraFX.AddTrauma(0.2)
		Audio.Play("Music", "Stinger", nil, { Volume = 0.4, Pitch = 0.7 })
	elseif name == "Stinger" then
		Audio.Play("Music", "Stinger", nil, { Volume = 0.7 })
		CameraFX.AddTrauma(0.3)
		CameraFX.PunchFOV(-5)
		Movement.SetAfraid(true)
		task.delay(1.4, function()
			if not Workspace:GetAttribute("ChaseActive") then
				Movement.SetAfraid(false)
			end
		end)
	elseif name == "DoorSmash" or name == "Bang" then
		local p = proximityTo(data.Position, 60)
		if p > 0 then
			CameraFX.AddTrauma(0.15 + p * 0.45)
			CameraFX.PunchFOV(p * 3)
		end
	elseif name == "SafeSealed" then
		CameraFX.AddTrauma(0.35)
	elseif name == "Alarm" then
		CameraFX.AddTrauma(0.35)
		Audio.Play("Music", "Stinger", nil, { Volume = 0.8 })
	end
end

function ChaseFX.Reset()
	ChaseFX.Intensity = 0
	Audio.Duck(1, 20)
	CameraFX.SetFOVOffset("Chase", 0)
	CameraFX.SetFOVOffset("Dread", 0)
	CameraFX.SetFOVOffset("Sprint", 0)
	CameraFX.SetSustained(0)
	CameraFX.SetRoll(0)
	Audio.SetHeartbeat(0, 0)
	for _, key in { "ChaseLoop", "ChaseDrone", "Tension", "Breathing" } do
		Audio.StopLoop(key, 3)
	end
	PostFX.Set({ Dark = 0.35, Red = 0, Chromatic = 0, Contrast = 0, Saturation = 0, Tint = Color3.new(1, 1, 1), Blur = 0 })
end

function ChaseFX.Init()
	Remotes.Event("ChaseCue").OnClientEvent:Connect(onCue)
	Remotes.Event("ScareEvent").OnClientEvent:Connect(onScare)

	RunService.RenderStepped:Connect(function(dt)
		if not ChaseFX.Active then
			return
		end
		local monster, distance = monsterInfo()
		local chase = Workspace:GetAttribute("ChaseActive") == true
		local final = Workspace:GetAttribute("FinalChase") == true
		local targetId = monster and monster:GetAttribute("ChaseTarget") or 0
		local hunted = chase and (targetId == player.UserId or final)
		local proximity = math.clamp(1 - distance / 85, 0, 1)

		local intensity
		if hunted then
			intensity = math.max(0.5, proximity)
		elseif chase then
			intensity = proximity * 0.7
		else
			intensity = proximity * 0.35
		end
		if os.clock() < glimpseUntil then
			intensity = math.max(intensity, 0.3)
		end
		if os.clock() < dreadUntil then
			intensity = math.max(intensity, 0.55)
		end
		ChaseFX.Intensity += (intensity - ChaseFX.Intensity) * (1 - math.exp(-3 * dt))
		local i = ChaseFX.Intensity

		-- Music layers
		local stage = Workspace:GetAttribute("Stage") or 1
		Audio.SetLoop("Drone", "Ambient", "Drone", 0.8 - i * 0.4, 1, 1)
		Audio.SetLoop("Tension", "Music", "Tension", (stage >= 4 and not chase) and (0.35 + i * 0.4) or 0, 1, 1)
		Audio.SetLoop("ChaseLoop", "Music", "ChaseLoop", chase and (0.55 + i * 0.45) or 0, 0.95 + i * 0.25, chase and 6 or 1)
		Audio.SetLoop("ChaseDrone", "Music", "ChaseDrone", chase and (0.4 + i * 0.6) or 0, 1 + i * 0.2, chase and 4 or 0.8)

		-- Body: heartbeat & breathing
		local exhausted = Movement.Exhausted
		Audio.SetHeartbeat(68 + i * 105, (i > 0.12 or exhausted) and (0.35 + i * 0.75) or 0)
		local breathing = (hunted and 0.6 + i * 0.4) or (exhausted and 0.6) or (Movement.Sprinting and 0.25) or 0
		Audio.SetLoop("Breathing", "Player", "Breathing", breathing, 1 + i * 0.35, 3)

		-- Camera
		local fovBoost = hunted and (Config.Camera.ChaseFOV - Config.Camera.BaseFOV) * (0.55 + 0.45 * i) or 0
		CameraFX.SetFOVOffset("Chase", fovBoost)
		CameraFX.SetFOVOffset("Sprint", Movement.Sprinting and 4 or 0)
		CameraFX.SetSustained(chase and proximity * proximity or 0)

		-- Screen
		PostFX.Set({
			Dark = 0.35 + i * 0.35,
			Red = chase and i * 0.85 or 0,
			Chromatic = chase and i * 1.3 or i * 0.4,
			Grain = 0.25 + i * 0.5,
			Contrast = 0.04 + i * 0.28,
			Saturation = -0.05 - i * 0.45,
			Tint = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 196, 196), chase and i or 0),
			Brightness = -i * 0.04,
			Blur = exhausted and 3 or 0,
		})
	end)
end

return ChaseFX
