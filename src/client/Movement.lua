--[[
	Player movement & body state:
	  Shift  sprint (stamina; slower drain during a chase - adrenaline)
	  C/Ctrl crouch (quieter, harder to see, lower camera)
	  F      flashlight (camera-mounted spotlight with lag & sway; visible to others)
	First/third-person view, control locks (see Lock.lua) and server replication of state.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local Audio = require(script.Parent.Audio)
local Lock = require(script.Parent.Lock)
local Settings = require(script.Parent.Settings)

local Movement = {}

local P = Config.Player
Movement.Active = false
Movement.Stamina = P.StaminaMax
Movement.MaxStamina = P.StaminaMax
Movement.Exhausted = false
Movement.Sprinting = false
Movement.Crouching = false
Movement.Flashlight = false
Movement.Afraid = false
Movement.Frozen = false

local player = Players.LocalPlayer
local wantSprint = false
local lastDrain = 0
local sent = { Crouching = false, Sprinting = false, Flashlight = false, Afraid = false }
local flashPart: Part? = nil
local flashLight: SpotLight? = nil
local flashCF = CFrame.identity

local function sendState()
	local changed = false
	local payload = {
		Crouching = Movement.Crouching,
		Sprinting = Movement.Sprinting,
		Flashlight = Movement.Flashlight,
		Afraid = Movement.Afraid,
	}
	for key, value in payload do
		if sent[key] ~= value then
			changed = true
		end
	end
	if changed then
		sent = payload
		Remotes.Event("SetMoveState"):FireServer(payload)
	end
end

function Movement.SetAfraid(afraid: boolean)
	Movement.Afraid = afraid
	sendState()
end

local function applyView()
	if not Movement.Active then
		player.CameraMode = Enum.CameraMode.Classic
		return
	end
	if Settings.Get("View") == "Third" then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = 9
		player.CameraMinZoomDistance = 6
	else
		player.CameraMaxZoomDistance = 0.5
		player.CameraMinZoomDistance = 0.5
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

function Movement.SetActive(active: boolean)
	Movement.Active = active
	Movement.Frozen = false
	Movement.Stamina = P.StaminaMax
	Movement.Exhausted = false
	Movement.Crouching = false
	Movement.Sprinting = false
	wantSprint = false
	applyView()
	sendState()
	if flashPart then
		flashPart.Parent = active and Workspace.CurrentCamera or nil
	end
end

local function hasFlashlight(): boolean
	return Workspace:GetAttribute("FlashlightTaken") == true
end

function Movement.SetFlashlight(on: boolean)
	Movement.Flashlight = on and hasFlashlight()
	sendState()
end

local function toggleFlashlight()
	if not hasFlashlight() then
		return
	end
	Movement.Flashlight = not Movement.Flashlight
	Audio.Play("Player", "Flashlight")
	sendState()
end

local function bindInputs()
	ContextActionService:BindAction("HorrorSprint", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			wantSprint = true
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			wantSprint = false
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("HorrorSprint", "RUN")
	ContextActionService:SetPosition("HorrorSprint", UDim2.new(1, -170, 1, -150))

	ContextActionService:BindAction("HorrorCrouch", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and Movement.Active then
			Movement.Crouching = not Movement.Crouching
			sendState()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("HorrorCrouch", "CROUCH")
	ContextActionService:SetPosition("HorrorCrouch", UDim2.new(1, -95, 1, -210))

	ContextActionService:BindAction("HorrorFlashlight", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and Movement.Active then
			toggleFlashlight()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("HorrorFlashlight", "LIGHT")
	ContextActionService:SetPosition("HorrorFlashlight", UDim2.new(1, -170, 1, -230))
end

function Movement.Init()
	bindInputs()

	local part = Instance.new("Part")
	part.Name = "Flashlight"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	flashPart = part
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Angle = 52
	spot.Range = P.FlashlightRange
	spot.Brightness = 0
	spot.Color = Color3.fromRGB(255, 244, 222)
	spot.Shadows = true
	spot.Parent = part
	flashLight = spot
	-- soft spill so the near area is readable
	local spill = Instance.new("PointLight")
	spill.Range = 7
	spill.Brightness = 0
	spill.Color = Color3.fromRGB(255, 240, 220)
	spill.Shadows = false
	spill.Name = "Spill"
	spill.Parent = part

	Settings.Changed:Connect(function(key)
		if key == "View" then
			applyView()
		elseif key == "Graphics" and flashLight then
			flashLight.Shadows = Settings.Get("Graphics") ~= "Low"
		end
	end)

	local lookTimer = 0
	local lastLook = Vector3.zero
	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

		local girl = Workspace:FindFirstChild("Girl")
		local locked = Lock.MoveLocked()
		if humanoid then
			humanoid.JumpHeight = (locked or Movement.Frozen) and 0 or 4.5
		end

		if Movement.Active and humanoid and root and not Movement.Frozen and not locked and not player:GetAttribute("Dead") then
			local moving = humanoid.MoveDirection.Magnitude > 0.1
			local sprinting = wantSprint and moving and not Movement.Crouching and not Movement.Exhausted
			if sprinting then
				Movement.Stamina = math.max(0, Movement.Stamina - P.StaminaDrain * dt)
				lastDrain = os.clock()
				if Movement.Stamina <= 0 then
					Movement.Exhausted = true
					sprinting = false
					Audio.Play("Player", "Gasp", nil, { Volume = 0.6 })
				end
			elseif os.clock() - lastDrain > P.StaminaRegenDelay then
				Movement.Stamina = math.min(P.StaminaMax, Movement.Stamina + P.StaminaRegen * dt)
				if Movement.Exhausted and Movement.Stamina >= P.ExhaustedThreshold then
					Movement.Exhausted = false
				end
			end
			Movement.Sprinting = sprinting

			local speed
			if Movement.Crouching then
				speed = P.CrouchSpeed
			elseif sprinting then
				speed = P.SprintSpeed
			else
				speed = P.WalkSpeed
			end
			if Movement.Exhausted then
				speed *= 0.85
			end
			humanoid.WalkSpeed = speed
			local offsetY = Movement.Crouching and P.CrouchCameraOffset or 0
			local current = humanoid.CameraOffset
			humanoid.CameraOffset = Vector3.new(0, Util.damp(current.Y, offsetY, 10, dt), 0)
			sendState()
		elseif humanoid and (Movement.Frozen or locked or player:GetAttribute("Dead")) then
			humanoid.WalkSpeed = 0
		end

		-- Flashlight follows the camera with a little lag and sway.
		if flashPart and flashLight and camera then
			local on = Movement.Active and Movement.Flashlight and hasFlashlight() and not player:GetAttribute("Dead")
			local target = camera.CFrame * CFrame.new(0.6, -0.5, -0.4)
			flashCF = flashCF:Lerp(target, 1 - math.exp(-18 * dt))
			flashCF = CFrame.new(target.Position) * (flashCF - flashCF.Position)
			flashPart.CFrame = flashCF
			local brightness = on and P.FlashlightBrightness or 0
			-- dies completely during a blink; stutters when she is close
			if Workspace:GetAttribute("Blink") then
				brightness = 0
			elseif on and girl and not girl:GetAttribute("Hidden") then
				local head = girl:FindFirstChild("Head") :: BasePart?
				if head and (head.Position - camera.CFrame.Position).Magnitude < 22 then
					brightness *= math.noise(os.clock() * 25, 3) > 0.15 and 1 or 0.1
				end
			end
			flashLight.Brightness = brightness
			local spill = flashPart:FindFirstChild("Spill") :: PointLight?
			if spill then
				spill.Brightness = on and 0.35 or 0
			end
			if flashPart.Parent ~= camera and Movement.Active then
				flashPart.Parent = camera
			end
		end

		-- Report where we're looking (she can only move while nobody is looking).
		lookTimer += dt
		if Movement.Active and camera and lookTimer > 0.08 then
			lookTimer = 0
			local look = camera.CFrame.LookVector
			if look:Dot(lastLook) < 0.999 then
				lastLook = look
				Remotes.Event("CameraLook"):FireServer(look)
			end
		end
	end)
end

return Movement
