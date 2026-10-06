--[[
	Animated jumpscare: the Girl leaps into your face.

	  1. controls freeze; the camera locks (whipping toward her if she caught you)
	  2. a local copy of her crouches for a split second, then LEAPS at the lens
	     (arms flung wide, mouth torn open) with an ear-splitting scream
	  3. her face shakes inches from the camera: flashes, static, colour crush, blur
	  4. hard cut to black

	Jumpscare.Play({ From = girlCFrame?, Fatal = true/false })
	  Fatal = true  : the screen stays black (death / the ending)
	  Fatal = false : control is handed back afterwards (the flashlight scare)
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GirlRig = require(Shared.GirlRig)
local RigAnimator = require(Shared.RigAnimator)
local SoundLibrary = require(Shared.SoundLibrary)

local Audio = require(script.Parent.Audio)
local CameraFX = require(script.Parent.CameraFX)
local GirlVisuals = require(script.Parent.GirlVisuals)
local Lock = require(script.Parent.Lock)
local Movement = require(script.Parent.Movement)
local PostFX = require(script.Parent.PostFX)

local Jumpscare = {}
Jumpscare.Playing = false

local CROUCH_TIME = 0.14
local LEAP_TIME = 0.3
local FACE_TIME = 0.7

local function easeOutQuint(x: number): number
	return 1 - (1 - x) ^ 5
end

export type Options = { From: CFrame?, Fatal: boolean? }

function Jumpscare.Play(options: Options?)
	if Jumpscare.Playing then
		return
	end
	local opts = options or {}
	Jumpscare.Playing = true
	local camera = Workspace.CurrentCamera
	Lock.Clear()
	Movement.Frozen = true
	if opts.Fatal then
		Audio.StopAllLoops(12)
		Audio.SetHeartbeat(0, 0)
	end
	Audio.Duck(1, 50)
	GirlVisuals.SetLocallyVisible(false)

	local startCF = camera.CFrame
	local eye = startCF.Position
	local lockedCF
	if opts.From then
		local toward = Vector3.new(opts.From.Position.X, eye.Y, opts.From.Position.Z)
		if (toward - eye).Magnitude < 0.5 then
			toward = eye + startCF.LookVector * 5
		end
		lockedCF = CFrame.lookAt(eye, toward)
	else
		-- level the view: she comes from straight ahead
		local flat = startCF.LookVector * Vector3.new(1, 0, 1)
		if flat.Magnitude < 0.1 then
			flat = Vector3.new(0, 0, -1)
		end
		lockedCF = CFrame.lookAt(eye, eye + flat.Unit)
	end
	camera.CameraType = Enum.CameraType.Scriptable

	-- Local copy of her for the close-up.
	local copy = GirlRig.Build()
	GirlRig.MakeStatic(copy)
	copy.Name = "JumpscareGirl"
	local faceLight = Instance.new("PointLight")
	faceLight.Color = Color3.fromRGB(230, 235, 255)
	faceLight.Range = 8
	faceLight.Brightness = 2.4
	faceLight.Shadows = false
	faceLight.Parent = copy:FindFirstChild("Head")
	copy.Parent = camera
	local animator = RigAnimator.new(copy, { State = "Crouch" })
	animator.SpeedOverride = 0
	animator.LookOverride = eye
	local unbind = animator:Bind()

	local grade, blur, flash = PostFX.Direct()
	PostFX.Override = true
	local static = SoundLibrary.Create("Jumpscare", "Static")

	-- Put her HEAD `distance` studs in front of the lens (the pose moves the head
	-- relative to the root, so measure every frame).
	local copyRoot = copy:FindFirstChild("HumanoidRootPart") :: BasePart
	local copyHead = copy:FindFirstChild("Head") :: BasePart
	local function placeAt(distance: number, offset: Vector3)
		local facePoint = lockedCF.Position + lockedCF.LookVector * distance + offset
		local localHead = copyRoot.CFrame:PointToObjectSpace(copyHead.Position)
		local facing = (lockedCF.Position - facePoint) * Vector3.new(1, 0, 1)
		if facing.Magnitude < 0.01 then
			facing = -lockedCF.LookVector * Vector3.new(1, 0, 1)
		end
		local rotation = CFrame.lookAt(Vector3.zero, facing.Unit)
		copy:PivotTo(rotation + (facePoint - rotation:VectorToWorldSpace(localHead)))
	end
	placeAt(5, Vector3.new(0, -2.2, 0))

	local start = os.clock()
	local phase = "Crouch"
	local flashes = { CROUCH_TIME, CROUCH_TIME + LEAP_TIME, CROUCH_TIME + LEAP_TIME + 0.25, CROUCH_TIME + LEAP_TIME + 0.5 }
	local flashIndex = 1
	local done = false

	RunService:BindToRenderStep("Jumpscare", Enum.RenderPriority.Camera.Value, function()
		local t = os.clock() - start
		local base = startCF:Lerp(lockedCF, easeOutQuint(math.clamp(t / 0.1, 0, 1)))
		local shake = 0
		if t < CROUCH_TIME then
			placeAt(5, Vector3.new(0, -2.2, 0))
			shake = 0.15
		elseif t < CROUCH_TIME + LEAP_TIME then
			if phase ~= "Leap" then
				phase = "Leap"
				animator:SetState("Leap")
				SoundLibrary.Play("Jumpscare", "Scream")
				SoundLibrary.Play("Jumpscare", "ScreamLow")
				if static then
					static:Play()
				end
			end
			local a = easeOutQuint((t - CROUCH_TIME) / LEAP_TIME)
			local arc = math.sin(a * math.pi) * 0.9
			placeAt(5 - 3.9 * a, Vector3.new(0, -2.2 * (1 - a) + arc, 0))
			shake = 0.5 + a * 0.5
			camera.FieldOfView = 70 - 14 * a
		elseif t < CROUCH_TIME + LEAP_TIME + FACE_TIME then
			if phase ~= "Face" then
				phase = "Face"
				CameraFX.AddTrauma(1)
			end
			local jitter = Vector3.new(math.noise(t * 30, 1), math.noise(t * 30, 2), 0) * 0.2
			placeAt(1.1, jitter)
			shake = 1
			camera.FieldOfView = 56
		elseif not done then
			done = true
		end

		if flashIndex <= #flashes and t >= flashes[flashIndex] then
			flash.BackgroundColor3 = flashIndex % 2 == 0 and Color3.fromRGB(255, 30, 30) or Color3.new(1, 1, 1)
			flash.BackgroundTransparency = 0.2
			flashIndex += 1
		else
			flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + 0.14)
		end
		if t >= CROUCH_TIME then
			grade.Contrast = 0.6
			grade.Saturation = -0.75
			grade.TintColor = Color3.fromRGB(220, 220, 255)
			grade.Brightness = 0.05 * math.sin(t * 60)
			blur.Size = 3 + math.abs(math.sin(t * 25)) * 9
		end

		local angle = math.rad(5) * shake
		local offset = CFrame.new(math.noise(t * 40, 5) * 0.3 * shake, math.noise(t * 40, 6) * 0.3 * shake, 0)
			* CFrame.Angles(math.noise(t * 40, 7) * angle, math.noise(t * 40, 8) * angle, math.noise(t * 40, 9) * angle * 1.6)
		camera.CFrame = base * offset
	end)

	while not done do
		task.wait()
	end
	-- Hard cut.
	RunService:UnbindFromRenderStep("Jumpscare")
	flash.BackgroundColor3 = Color3.new(0, 0, 0)
	flash.BackgroundTransparency = 0
	SoundLibrary.Play("Jumpscare", "Impact")
	SoundLibrary.Play("Jumpscare", "Thud")
	if static then
		static:Destroy()
	end
	unbind()
	copy:Destroy()
	blur.Size = 0
	grade.Contrast = 0
	grade.Saturation = 0
	grade.TintColor = Color3.new(1, 1, 1)
	grade.Brightness = 0
	camera.FieldOfView = CameraFX.BaseFOV
	GirlVisuals.SetLocallyVisible(true)

	if opts.Fatal then
		task.wait(0.9)
		Jumpscare.Playing = false
		return
	end
	-- Survivable scare: a beat of black, then hand control back.
	task.wait(0.7)
	camera.CFrame = lockedCF
	camera.CameraType = Enum.CameraType.Custom
	PostFX.Override = false
	Movement.Frozen = false
	local tweenStart = os.clock()
	while os.clock() - tweenStart < 0.8 do
		flash.BackgroundTransparency = (os.clock() - tweenStart) / 0.8
		task.wait()
	end
	flash.BackgroundTransparency = 1
	Jumpscare.Playing = false
end

-- After a fatal scare, once the next screen is up: hand the screen back to PostFX.
function Jumpscare.Release()
	local _, _, flash = PostFX.Direct()
	PostFX.Override = false
	flash.BackgroundTransparency = 1
end

return Jumpscare
