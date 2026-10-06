--[[
	Animates the live Girl on this client and produces her stomps.

	  * If THIS client is looking at her she freezes locally on the same frame
	    (the server confirms a moment later) - so you never see her move.
	  * Each step of her gait is a very loud stomp that shakes the camera when near.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local RigAnimator = require(Shared.RigAnimator)
local SoundLibrary = require(Shared.SoundLibrary)

local CameraFX = require(script.Parent.CameraFX)

local GirlVisuals = {}
GirlVisuals.Animator = nil :: any
GirlVisuals.Unbind = nil :: (() -> ())?

local function attach(model: Model)
	local previous = GirlVisuals.Unbind
	if previous then
		previous()
	end
	local animator = RigAnimator.new(model, {
		OnFootstep = function(foot: BasePart?, _speed: number, _state: string)
			if not foot or model:GetAttribute("Hidden") then
				return
			end
			SoundLibrary.Play("Monster", "Stomp", foot, { PitchVariance = 0.08 })
			local camera = Workspace.CurrentCamera
			local distance = camera and (foot.Position - camera.CFrame.Position).Magnitude or 100
			if distance < 50 then
				local proximity = 1 - distance / 50
				CameraFX.AddTrauma(0.1 + proximity * proximity * 0.45)
			end
		end,
	})
	GirlVisuals.Animator = animator
	local unbindAnimator = animator:Bind()

	-- Local freeze: if I can see her, she doesn't move on my screen.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local connection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local head = model:FindFirstChild("Head") :: BasePart?
		if not camera or not head or model:GetAttribute("Hidden") or Workspace:GetAttribute("Blink") then
			animator:SetFrozen(false)
			return
		end
		local eye = camera.CFrame.Position
		local dir = head.Position - eye
		local seen = false
		if dir.Magnitude < Config.Girl.SightRange and camera.CFrame.LookVector:Dot(dir.Unit) >= Config.Girl.ViewDot then
			local exclude: { Instance } = { model, camera }
			local character = Players.LocalPlayer.Character
			if character then
				table.insert(exclude, character)
			end
			params.FilterDescendantsInstances = exclude
			local result = Workspace:Raycast(eye, dir, params)
			seen = result == nil
		end
		animator:SetFrozen(seen)
	end)
	GirlVisuals.Unbind = function()
		unbindAnimator()
		connection:Disconnect()
	end
end

function GirlVisuals.Init()
	local existing = Workspace:FindFirstChild("Girl")
	if existing then
		attach(existing :: Model)
	end
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Girl" and child:IsA("Model") then
			task.wait(0.2)
			attach(child)
		end
	end)
end

-- Hide/show the real Girl locally (jumpscares use their own copy).
function GirlVisuals.SetLocallyVisible(visible: boolean)
	local model = Workspace:FindFirstChild("Girl")
	if not model then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = visible and 0 or 1
		end
	end
	local glow = model:FindFirstChild("EyeGlow", true) :: PointLight?
	if glow then
		glow.Enabled = visible
	end
end

return GirlVisuals
