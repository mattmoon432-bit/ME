--[[
	Camera effects layered on top of the default camera every frame:
	  * trauma-based shake (Perlin noise, decays) + a continuous "proximity" shake
	  * FOV offsets (chase widening, punches on screams/impacts)
	  * first-person head bob & sway, sprint lean, fear roll
	Respects the Camera Shake setting.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Settings = require(script.Parent.Settings)

local CameraFX = {}

local trauma = 0
local sustained = 0 -- continuous shake level (0..1) set by TensionFX
local fovOffsets: { [string]: number } = {}
local fovPunch = 0
local currentFov = Config.Camera.BaseFOV
local roll = 0
local rollTarget = 0
local bobPhase = 0
local bobAmount = 0
CameraFX.Enabled = true
CameraFX.BaseFOV = Config.Camera.BaseFOV

function CameraFX.AddTrauma(amount: number)
	trauma = math.clamp(trauma + amount, 0, 1)
end

function CameraFX.SetSustained(amount: number)
	sustained = math.clamp(amount, 0, 1)
end

function CameraFX.SetFOVOffset(key: string, value: number)
	fovOffsets[key] = value
end

function CameraFX.PunchFOV(amount: number)
	fovPunch += amount
end

function CameraFX.SetRoll(degrees: number)
	rollTarget = degrees
end

function CameraFX.Init()
	local player = Players.LocalPlayer
	local seed = math.random() * 100
	RunService:BindToRenderStep("HorrorCameraFX", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = Workspace.CurrentCamera
		if not camera or not CameraFX.Enabled then
			return
		end
		local t = os.clock()
		local shakeOn = Settings.Get("CameraShake")

		-- FOV
		local target = CameraFX.BaseFOV
		for _, value in fovOffsets do
			target += value
		end
		fovPunch = Util.damp(fovPunch, 0, 7, dt)
		currentFov = Util.damp(currentFov, target, 4, dt)
		camera.FieldOfView = math.clamp(currentFov + fovPunch, 20, 110)

		-- Shake
		trauma = math.max(0, trauma - dt * 1.1)
		local intensity = trauma * trauma + sustained * 0.35
		local offset = CFrame.identity
		if shakeOn and intensity > 0.001 then
			local freq = 22
			local maxAngle = math.rad(3.2) * intensity
			local maxMove = 0.25 * intensity
			offset = CFrame.new(
				math.noise(seed, t * freq) * maxMove,
				math.noise(seed + 1, t * freq) * maxMove,
				0
			) * CFrame.Angles(
				math.noise(seed + 2, t * freq) * maxAngle,
				math.noise(seed + 3, t * freq) * maxAngle,
				math.noise(seed + 4, t * freq) * maxAngle * 0.6
			)
		end

		-- Head bob / sway (first person, when walking)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local speed = 0
		if humanoid and root and camera.CameraType == Enum.CameraType.Custom then
			speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
			if humanoid.FloorMaterial == Enum.Material.Air then
				speed = 0
			end
		end
		bobAmount = Util.damp(bobAmount, math.clamp(speed / 16, 0, 1.3), 8, dt)
		bobPhase += dt * (4 + speed * 0.42)
		local bobScale = Config.Camera.BobAmount * (shakeOn and 1 or 0.4)
		local bob = CFrame.new(math.cos(bobPhase) * 0.6 * bobAmount * bobScale, math.abs(math.sin(bobPhase)) * bobAmount * bobScale, 0)
			* CFrame.Angles(0, 0, math.cos(bobPhase) * math.rad(0.6) * bobAmount * (shakeOn and 1 or 0.3))

		roll = Util.damp(roll, rollTarget, 3, dt)
		local rollCF = CFrame.Angles(0, 0, math.rad(roll))

		camera.CFrame = camera.CFrame * bob * rollCF * offset
	end)
end

return CameraFX
