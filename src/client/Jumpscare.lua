--[[
	A real animated jumpscare (no static image):
	  1. controls freeze, the camera locks and whips toward the monster
	  2. a local copy of the Grinner lunges from ~9 studs, arms raised (Attack pose)
	  3. its face rushes into the lens, jaw unhinged, head shaking (Jumpscare pose)
	  4. white/red flashes, distorted scream + static, violent shake, colour crush,
	     blur pulses, FOV squeeze
	  5. hard cut to black + impact, then "YOU DIED"
	Total ~1.6 s.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MonsterAnimator = require(Shared.MonsterAnimator)
local MonsterRig = require(Shared.MonsterRig)
local SoundLibrary = require(Shared.SoundLibrary)

local Audio = require(script.Parent.Audio)
local CameraFX = require(script.Parent.CameraFX)
local MonsterVisuals = require(script.Parent.MonsterVisuals)
local Movement = require(script.Parent.Movement)
local PostFX = require(script.Parent.PostFX)

local Jumpscare = {}
Jumpscare.Playing = false

local LUNGE_TIME = 0.24
local FACE_TIME = 0.95
local function easeOutQuint(x: number): number
	return 1 - (1 - x) ^ 5
end

-- monsterCFrame: the real monster's root CFrame when it caught us.
-- Yields until the scare has finished (screen is black).
function Jumpscare.Play(monsterCFrame: CFrame)
	if Jumpscare.Playing then
		return
	end
	Jumpscare.Playing = true
	local camera = Workspace.CurrentCamera
	Movement.Frozen = true
	Audio.StopAllLoops(12)
	Audio.SetHeartbeat(0, 0)
	Audio.Duck(1, 50)
	MonsterVisuals.SetLocallyVisible(false)

	local startCF = camera.CFrame
	local eye = startCF.Position
	local toward = Vector3.new(monsterCFrame.Position.X, eye.Y, monsterCFrame.Position.Z)
	if (toward - eye).Magnitude < 0.5 then
		toward = eye + startCF.LookVector * 5
	end
	local lockedCF = CFrame.lookAt(eye, toward) * CFrame.Angles(math.rad(4), 0, 0)
	camera.CameraType = Enum.CameraType.Scriptable

	-- Local copy of the monster for the close-up.
	local copy = MonsterRig.Build()
	MonsterRig.MakeStatic(copy)
	copy.Name = "JumpscareGrinner"
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			part.CastShadow = false
		end
	end
	local headLight = Instance.new("PointLight")
	headLight.Color = Color3.fromRGB(255, 210, 190)
	headLight.Range = 9
	headLight.Brightness = 2.2
	headLight.Shadows = false
	headLight.Parent = copy:FindFirstChild("Head")
	copy.Parent = camera
	local animator = MonsterAnimator.new(copy, { State = "Attack" })
	animator.SpeedOverride = 0
	local unbind = animator:Bind()

	local grade, blur, flash = PostFX.Direct()
	PostFX.Override = true
	local static = SoundLibrary.Create("Jumpscare", "Static")

	-- Place the copy so its HEAD sits `distance` studs in front of the lens. The pose
	-- moves the head relative to the root, so measure it every frame.
	local copyRoot = copy:FindFirstChild("HumanoidRootPart") :: BasePart
	local copyHead = copy:FindFirstChild("Head") :: BasePart
	local function placeAt(distance: number, sway: Vector3)
		local facePoint = lockedCF.Position + lockedCF.LookVector * distance + sway - Vector3.new(0, 0.25, 0)
		local localHead = copyRoot.CFrame:PointToObjectSpace(copyHead.Position)
		local facing = (lockedCF.Position - facePoint) * Vector3.new(1, 0, 1)
		if facing.Magnitude < 0.01 then
			facing = -lockedCF.LookVector * Vector3.new(1, 0, 1)
		end
		local rotation = CFrame.lookAt(Vector3.zero, facing.Unit)
		local rootPos = facePoint - rotation:VectorToWorldSpace(localHead)
		copy:PivotTo(rotation + rootPos)
	end
	placeAt(9, Vector3.zero)

	local start = os.clock()
	local phase = "Turn"
	local flashes = { 0.02, LUNGE_TIME, LUNGE_TIME + 0.28, LUNGE_TIME + 0.55 }
	local flashIndex = 1
	local done = false

	SoundLibrary.Play("Jumpscare", "Sting")
	RunService:BindToRenderStep("Jumpscare", Enum.RenderPriority.Camera.Value, function()
		local t = os.clock() - start
		-- camera whip toward the monster during the first 0.1s
		local whip = math.clamp(t / 0.1, 0, 1)
		local base = startCF:Lerp(lockedCF, easeOutQuint(whip))
		local shake = 0
		if t < LUNGE_TIME then
			if phase ~= "Lunge" then
				phase = "Lunge"
				SoundLibrary.Play("Jumpscare", "Scream")
				if static then
					static:Play()
				end
			end
			local a = easeOutQuint(t / LUNGE_TIME)
			placeAt(9 - 6.2 * a, Vector3.zero)
			shake = 0.5 + a * 0.5
			camera.FieldOfView = 70 - 12 * a
		elseif t < LUNGE_TIME + FACE_TIME then
			if phase ~= "Face" then
				phase = "Face"
				animator:SetState("Jumpscare")
				CameraFX.AddTrauma(1)
			end
			local b = (t - LUNGE_TIME) / FACE_TIME
			local jitter = Vector3.new(math.noise(t * 30, 1), math.noise(t * 30, 2), 0) * 0.25
			placeAt(2.8 - 1.4 * easeOutQuint(math.min(b * 2.2, 1)), jitter)
			shake = 1
			camera.FieldOfView = 58 - 8 * b
		elseif not done then
			done = true
		end

		-- Screen treatment
		if flashIndex <= #flashes and t >= flashes[flashIndex] then
			flash.BackgroundColor3 = flashIndex % 2 == 0 and Color3.fromRGB(255, 30, 30) or Color3.new(1, 1, 1)
			flash.BackgroundTransparency = 0.15
			flashIndex += 1
		else
			flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + 0.12)
		end
		grade.Contrast = 0.6
		grade.Saturation = -0.7
		grade.TintColor = Color3.fromRGB(255, 170, 170)
		grade.Brightness = 0.05 * math.sin(t * 60)
		blur.Size = 4 + math.abs(math.sin(t * 25)) * 10

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
	camera.FieldOfView = 70
	MonsterVisuals.SetLocallyVisible(true)
	task.wait(0.9)
	Jumpscare.Playing = false
end

-- Called once the death screen is up, to hand the screen back to PostFX.
function Jumpscare.Release()
	local _, _, flash = PostFX.Direct()
	PostFX.Override = false
	flash.BackgroundTransparency = 1
end

return Jumpscare
