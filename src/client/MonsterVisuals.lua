--[[
	Animates the live monster on this client (Motor6D.Transform is not replicated)
	and produces its heavy footsteps. Footsteps are tied to the procedural gait, so
	they speed up as it accelerates, get louder and shake the camera as it closes in.
]]

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MonsterAnimator = require(Shared.MonsterAnimator)
local SoundLibrary = require(Shared.SoundLibrary)

local CameraFX = require(script.Parent.CameraFX)

local MonsterVisuals = {}
MonsterVisuals.Animator = nil :: any
MonsterVisuals.Unbind = nil :: (() -> ())?

local function attach(model: Model)
	local previous = MonsterVisuals.Unbind
	if previous then
		previous()
	end
	local animator = MonsterAnimator.new(model, {
		OnFootstep = function(foot: BasePart?, speed: number, state: string)
			if not foot or model:GetAttribute("Hidden") then
				return
			end
			local camera = Workspace.CurrentCamera
			local distance = camera and (foot.Position - camera.CFrame.Position).Magnitude or 100
			local running = state == "Sprint" or state == "AggressiveSprint"
			local volume = running and 1.4 or 0.7
			if state == "SlowWalk" then
				volume = 0.35
			end
			SoundLibrary.Play("Monster", "Footstep", foot, {
				Volume = volume,
				Pitch = running and (0.9 + math.min(speed, 40) / 100) or 0.85,
				PitchVariance = 0.08,
			})
			if running and distance < 45 then
				local proximity = 1 - distance / 45
				CameraFX.AddTrauma(0.08 + proximity * proximity * 0.35)
			end
		end,
	})
	MonsterVisuals.Animator = animator
	MonsterVisuals.Unbind = animator:Bind()
end

function MonsterVisuals.Init()
	local existing = Workspace:FindFirstChild("Grinner")
	if existing then
		attach(existing :: Model)
	end
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Grinner" and child:IsA("Model") then
			task.wait(0.2)
			attach(child)
		end
	end)
end

-- Hide/show the real monster locally (the jumpscare uses its own copy).
function MonsterVisuals.SetLocallyVisible(visible: boolean)
	local model = Workspace:FindFirstChild("Grinner")
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

return MonsterVisuals
