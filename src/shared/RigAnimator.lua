--[[
	Client-side procedural animator for the Girl rig (the live antagonist, the main
	menu figure and the jumpscare copies).

	Motor6D.Transform does not replicate, so the server only publishes intent through
	model attributes:
	  AnimState  : a pose name in GirlPoses, or "Frozen"
	  LookTarget : world position the head tracks (Vector3.zero = none)

	"Frozen" (or :SetFrozen(true)) stops all updates, so she is caught mid-pose exactly
	as she was when you looked at her.

	If AnimationIds.Girl[state] is set, that keyframe animation plays instead of the
	procedural pose for that state.
]]

local RunService = game:GetService("RunService")

local AnimationIds = require(script.Parent.AnimationIds)
local GirlPoses = require(script.Parent.GirlPoses)
local GirlRig = require(script.Parent.GirlRig)

local RigAnimator = {}
RigAnimator.__index = RigAnimator

local BLEND = { Crouch = 30, Leap = 40, Scream = 30, Run = 60 }
local STRIDE = { Run = 6 } -- studs per full gait cycle
local GAIT_SPEED = { Run = 16 }
local LOOK_LIMIT = 70

export type Options = {
	State: string?,
	OnFootstep: ((foot: BasePart?, speed: number, state: string) -> ())?,
}

function RigAnimator.new(model: Model, options: Options?)
	local self = setmetatable({}, RigAnimator)
	self.Model = model
	self.Root = model:WaitForChild("HumanoidRootPart") :: BasePart
	self.Options = options or {}
	self.Motors = {} :: { [string]: Motor6D }
	self.Current = {} :: { [string]: CFrame }
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			self.Motors[d.Name] = d
			self.Current[d.Name] = CFrame.identity
		end
	end
	self.LeftFoot = model:FindFirstChild("LeftFoot")
	self.RightFoot = model:FindFirstChild("RightFoot")
	self.Phase = 0
	self.StateName = ""
	self.StateStart = os.clock()
	self.LookYaw = 0
	self.LookPitch = 0
	self.Seed = math.random() * 100
	self.StateOverride = self.Options.State
	self.LookOverride = nil :: Vector3?
	self.SpeedOverride = nil :: number?
	self.LocalFrozen = false
	self.Tracks = {} :: { [string]: AnimationTrack }
	self.ActiveTrack = nil :: AnimationTrack?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	self.AnimatorInstance = humanoid and humanoid:FindFirstChildOfClass("Animator") or nil
	self.LastPosition = self.Root.Position
	return self
end

function RigAnimator:SetState(state: string?)
	self.StateOverride = state
end

-- Local freeze (this client is looking at her) - applied instantly, before the server knows.
function RigAnimator:SetFrozen(frozen: boolean)
	self.LocalFrozen = frozen
end

function RigAnimator:_trackFor(state: string): AnimationTrack?
	local id = AnimationIds.Girl[state]
	if not id or id == "" or not self.AnimatorInstance then
		return nil
	end
	if not self.Tracks[state] then
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return self.AnimatorInstance:LoadAnimation(animation)
		end)
		if not ok then
			warn("[RigAnimator] Could not load animation for " .. state .. ": " .. tostring(track))
			return nil
		end
		track.Looped = state == "Run" or state == "Stand"
		self.Tracks[state] = track
	end
	return self.Tracks[state]
end

function RigAnimator:_enterState(state: string)
	self.StateName = state
	self.StateStart = os.clock()
	if self.ActiveTrack then
		self.ActiveTrack:Stop(0.05)
		self.ActiveTrack = nil
	end
	local track = self:_trackFor(state)
	if track then
		track:Play(0.05)
		self.ActiveTrack = track
	end
end

function RigAnimator:Step(dt: number)
	local root = self.Root
	if not root.Parent then
		return
	end
	local state = self.StateOverride or self.Model:GetAttribute("AnimState") or "Stand"
	local frozen = state == "Frozen" or self.LocalFrozen
	if frozen then
		if self.ActiveTrack then
			self.ActiveTrack:AdjustSpeed(0)
		end
		self.LastPosition = root.Position
		return -- caught mid-pose: write nothing
	end
	if state ~= self.StateName then
		self:_enterState(state)
	end
	if self.ActiveTrack then
		self.ActiveTrack:AdjustSpeed(1)
		return
	end

	local speed = self.SpeedOverride
	if not speed then
		local pos = root.Position
		local delta = (pos - self.LastPosition) * Vector3.new(1, 0, 1)
		self.LastPosition = pos
		local measured = dt > 0 and delta.Magnitude / dt or 0
		local physical = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		speed = math.max(physical, measured < 80 and measured or 0)
	end
	local walkSpeed: number = speed :: number

	local stride = STRIDE[state]
	local move = 0
	if stride then
		local previous = math.cos(self.Phase)
		self.Phase += dt * math.pi * 2 * walkSpeed / stride
		local current = math.cos(self.Phase)
		if (previous > 0) ~= (current > 0) and walkSpeed > 1 and self.Options.OnFootstep then
			local foot = current <= 0 and self.LeftFoot or self.RightFoot
			self.Options.OnFootstep(foot, walkSpeed, state)
		end
		move = math.clamp(walkSpeed / GAIT_SPEED[state], 0, 1.25)
	end

	local targetYaw, targetPitch = 0, 0
	local look = self.LookOverride or self.Model:GetAttribute("LookTarget")
	if typeof(look) == "Vector3" and look ~= Vector3.zero then
		local rel = root.CFrame:PointToObjectSpace(look)
		targetYaw = math.deg(math.atan2(-rel.X, -rel.Z))
		local horizontal = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
		targetPitch = math.deg(math.atan2(rel.Y - GirlRig.HeadHeight, horizontal))
	end
	targetYaw = math.clamp(targetYaw, -LOOK_LIMIT, LOOK_LIMIT)
	targetPitch = math.clamp(targetPitch, -35, 35)
	local a = 1 - math.exp(-7 * dt)
	self.LookYaw += (targetYaw - self.LookYaw) * a
	self.LookPitch += (targetPitch - self.LookPitch) * a

	local poseFn = GirlPoses[state] or GirlPoses.Stand
	local pose = poseFn({
		t = os.clock(),
		st = os.clock() - self.StateStart,
		phase = self.Phase,
		move = move,
		speed = walkSpeed,
		lookYaw = self.LookYaw,
		lookPitch = self.LookPitch,
		seed = self.Seed,
	})

	local alpha = 1 - math.exp(-(BLEND[state] or 10) * dt)
	for name, motor in self.Motors do
		local target = pose[name] or CFrame.identity
		local blended = self.Current[name]:Lerp(target, alpha)
		self.Current[name] = blended
		motor.Transform = blended
	end
end

function RigAnimator:Bind(): () -> ()
	local connection = RunService.Stepped:Connect(function(_, dt)
		self:Step(dt)
	end)
	return function()
		connection:Disconnect()
		if self.ActiveTrack then
			self.ActiveTrack:Stop()
		end
	end
end

return RigAnimator
