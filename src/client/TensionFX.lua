--[[
	Turns "how close is she / is she moving" into music, heartbeat, breathing, screen
	vignette, colour grading and camera shake. Also reacts to scripted scare events.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Audio = require(script.Parent.Audio)
local CameraFX = require(script.Parent.CameraFX)
local Movement = require(script.Parent.Movement)
local PostFX = require(script.Parent.PostFX)

local TensionFX = {}
TensionFX.Active = false -- in-game (not in menu)
TensionFX.Intensity = 0

local function proximityTo(position: Vector3?, range: number): number
	local camera = Workspace.CurrentCamera
	if not position or not camera then
		return 0
	end
	return math.clamp(1 - (position - camera.CFrame.Position).Magnitude / range, 0, 1)
end

local function onScare(name: string, data)
	if not TensionFX.Active then
		return
	end
	data = data or {}
	if name == "Blackout" then
		Audio.Play("Ambient", "PowerDown")
		CameraFX.AddTrauma(0.3)
		PostFX.Flash(Color3.new(0, 0, 0), 0.8, 1)
	elseif name == "Blink" then
		Audio.Play("Ambient", "Whisper", nil, { Volume = 0.6 })
	elseif name == "Stinger" then
		Audio.Play("Music", "Stinger", nil, { Volume = 0.7 })
		CameraFX.AddTrauma(0.3)
	elseif name == "DoorSmash" then
		local p = proximityTo(data.Position, 60)
		if p > 0 then
			CameraFX.AddTrauma(0.15 + p * 0.45)
		end
	end
end

function TensionFX.Reset()
	TensionFX.Intensity = 0
	Audio.Duck(1, 20)
	CameraFX.SetFOVOffset("Sprint", 0)
	CameraFX.SetSustained(0)
	CameraFX.SetRoll(0)
	Audio.SetHeartbeat(0, 0)
	for _, key in { "Pulse", "Tension", "Breathing", "Drone", "OfficeHum" } do
		Audio.StopLoop(key, 3)
	end
	PostFX.Set({ Dark = 0.3, Red = 0, Chromatic = 0, Contrast = 0, Saturation = 0, Tint = Color3.new(1, 1, 1), Blur = 0 })
end

function TensionFX.Init()
	Remotes.Event("ScareEvent").OnClientEvent:Connect(onScare)

	RunService.RenderStepped:Connect(function(dt)
		if not TensionFX.Active then
			return
		end
		local girl = Workspace:FindFirstChild("Girl")
		local camera = Workspace.CurrentCamera
		local distance = math.huge
		local moving = false
		if girl and not girl:GetAttribute("Hidden") and camera then
			local head = girl:FindFirstChild("Head") :: BasePart?
			if head then
				distance = (head.Position - camera.CFrame.Position).Magnitude
			end
			moving = girl:GetAttribute("Moving") == true
		end
		local proximity = math.clamp(1 - distance / 70, 0, 1)
		local target = proximity * (moving and 1 or 0.7)
		TensionFX.Intensity += (target - TensionFX.Intensity) * (1 - math.exp(-3 * dt))
		local i = TensionFX.Intensity

		local stage = Workspace:GetAttribute("Stage") or 0
		local power = Workspace:GetAttribute("Power") == true
		local hunting = stage >= 2 and stage <= 4

		-- Music / ambience
		Audio.SetLoop("OfficeHum", "Ambient", "OfficeHum", power and 0.8 or 0, 1, 4)
		Audio.SetLoop("Drone", "Ambient", "Drone", power and 0.25 or (0.8 - i * 0.3), 1, 1)
		Audio.SetLoop("Tension", "Music", "Tension", hunting and (0.3 + i * 0.5) or 0, 1, 1)
		Audio.SetLoop("Pulse", "Music", "Pulse", (hunting and moving and i > 0.35) and (0.4 + i * 0.6) or 0, 0.9 + i * 0.3, 3)

		-- Body
		local exhausted = Movement.Exhausted
		Audio.SetHeartbeat(68 + i * 100, (i > 0.15 or exhausted) and (0.3 + i * 0.8) or 0)
		local breathing = (i > 0.55 and 0.4 + i * 0.5) or (exhausted and 0.6) or (Movement.Sprinting and 0.25) or 0
		Audio.SetLoop("Breathing", "Player", "Breathing", breathing, 1 + i * 0.3, 3)

		-- Camera & screen
		CameraFX.SetFOVOffset("Sprint", Movement.Sprinting and 4 or 0)
		CameraFX.SetSustained(moving and proximity * proximity * 0.6 or 0)
		PostFX.Set({
			Dark = 0.3 + i * 0.35,
			Red = moving and i * 0.55 or 0,
			Chromatic = i * 0.9,
			Grain = 0.25 + i * 0.5,
			Contrast = 0.04 + i * 0.25,
			Saturation = -0.05 - i * 0.4,
			Tint = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(230, 225, 255), i),
			Brightness = 0,
			Blur = exhausted and 3 or 0,
		})
	end)
end

return TensionFX
