--[[
	Client-side animator for any Grinner rig (the live monster, the main-menu figure
	and the jumpscare copy).

	Motor6D.Transform does not replicate, so the server only publishes intent through
	attributes on the model:
	  AnimState  : name of a pose in MonsterPoses
	  LookTarget : world position the head should track (Vector3.zero = none)
	and every client animates locally at full frame rate.

	If AnimationIds.Monster[state] is set, that keyframe animation plays instead of the
	procedural pose for that state.
]]

local RunService = game:GetService("RunService")

local AnimationIds = require(script.Parent.AnimationIds)
local MonsterPoses = require(script.Parent.MonsterPoses)

local MonsterAnimator = {}
MonsterAnimator.__index = MonsterAnimator

-- How quickly joints blend toward each state's pose (higher = snappier).
local BLEND = {
	Scream = 30,
	Attack = 32,
	Stagger = 26,
	Jumpscare = 40,
	Grab = 22,
	HeadTurn = 7,
	AggressiveSprint = 16,
	Sprint = 14,
	DoorSlam = 18,
}
-- Distance covered by one full gait cycle (two steps).
local STRIDE = { Walk = 6.5, SlowWalk = 4.6, Search = 5, Sprint = 10, AggressiveSprint = 12.5 }
-- Speed at which the gait reaches full amplitude.
local GAIT_SPEED = { Walk = 8, SlowWalk = 4, Search = 6, Sprint = 18, AggressiveSprint = 26 }
-- Max head yaw per state (degrees). HeadTurn deliberately exceeds human limits.
local LOOK_LIMIT = { HeadTurn = 175, Breathing = 85, SlowWalk = 75, Idle = 60, Walk = 45, Sprint = 35, AggressiveSprint = 40 }
-- HeadTurn rotates at a constant, slow angular speed for maximum dread.
local HEAD_TURN_SPEED = 95

export type Options = {
	State: string?, -- force a state instead of reading the AnimState attribute
	OnFootstep: ((foot: BasePart?, speed: number, state: string) -> ())?,
}

function MonsterAnimator.new(model: Model, options: Options?)
	local self = setmetatable({}, MonsterAnimator)
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
	self.Tracks = {} :: { [string]: AnimationTrack }
	self.ActiveTrack = nil :: AnimationTrack?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	self.AnimatorInstance = humanoid and humanoid:FindFirstChildOfClass("Animator") or nil
	self.LastPosition = self.Root.Position
	return self
end

function MonsterAnimator:SetState(state: string?)
	self.StateOverride = state
end

function MonsterAnimator:_trackFor(state: string): AnimationTrack?
	local id = AnimationIds.Monster[state]
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
			warn("[MonsterAnimator] Could not load animation for " .. state .. ": " .. tostring(track))
			return nil
		end
		track.Looped = not (state == "Attack" or state == "Scream" or state == "Stagger")
		self.Tracks[state] = track
	end
	return self.Tracks[state]
end

function MonsterAnimator:_enterState(state: string)
	self.StateName = state
	self.StateStart = os.clock()
	if self.ActiveTrack then
		self.ActiveTrack:Stop(0.15)
		self.ActiveTrack = nil
	end
	local track = self:_trackFor(state)
	if track then
		track:Play(0.15)
		self.ActiveTrack = track
	end
end

function MonsterAnimator:Step(dt: number)
	local root = self.Root
	if not root.Parent then
		return
	end
	local state = self.StateOverride or self.Model:GetAttribute("AnimState") or "Idle"
	if state ~= self.StateName then
		self:_enterState(state)
	end
	if self.ActiveTrack then
		return
	end

	-- Ground speed. Anchored rigs moved by CFrame have no velocity, so measure displacement.
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
			-- cos crossing zero == leg at full extension == heel strike
			local foot = current <= 0 and self.LeftFoot or self.RightFoot
			self.Options.OnFootstep(foot, walkSpeed, state)
		end
		move = math.clamp(walkSpeed / GAIT_SPEED[state], 0, 1.25)
	end

	-- Head tracking.
	local targetYaw, targetPitch = 0, 0
	local look = self.LookOverride or self.Model:GetAttribute("LookTarget")
	if typeof(look) == "Vector3" and look ~= Vector3.zero then
		local rel = root.CFrame:PointToObjectSpace(look)
		targetYaw = math.deg(math.atan2(-rel.X, -rel.Z))
		local horizontal = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
		targetPitch = math.deg(math.atan2(rel.Y - 5, horizontal))
	end
	local limit = LOOK_LIMIT[state] or 60
	targetYaw = math.clamp(targetYaw, -limit, limit)
	targetPitch = math.clamp(targetPitch, -35, 35)
	if state == "HeadTurn" then
		local maxStep = HEAD_TURN_SPEED * dt
		self.LookYaw += math.clamp(targetYaw - self.LookYaw, -maxStep, maxStep)
		self.LookPitch += math.clamp(targetPitch - self.LookPitch, -maxStep, maxStep)
	else
		local a = 1 - math.exp(-7 * dt)
		self.LookYaw += (targetYaw - self.LookYaw) * a
		self.LookPitch += (targetPitch - self.LookPitch) * a
	end

	local poseFn = MonsterPoses[state] or MonsterPoses.Idle
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

-- Hooks the animator to the frame loop. Returns a disconnect function.
function MonsterAnimator:Bind(): () -> ()
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

return MonsterAnimator
