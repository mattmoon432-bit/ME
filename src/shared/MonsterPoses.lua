--[[
	Procedural animation library for The Grinner.

	Each pose is a function(ctx) -> { [jointName] = CFrame } evaluated every frame.
	MonsterAnimator blends between them and writes Motor6D.Transform.

	ctx = {
		t      : global clock (seconds)
		st     : seconds since this state started
		phase  : gait phase in radians (advances with ground speed)
		move   : 0..~1.2 gait amplitude (0 when standing still)
		speed  : horizontal speed (studs/s)
		lookYaw, lookPitch : degrees, smoothed head target relative to the body
		seed   : per-instance random offset
	}

	Rotation conventions (rig joints are pure translations at rest):
	  +X at a hip/shoulder swings the limb forward; -X at waist/root leans forward;
	  -X at a knee bends it; -X on the jaw opens the mouth; +Y turns left.
]]

local MonsterPoses = {}

local rad = math.rad
local sin = math.sin
local cos = math.cos
local max = math.max
local clamp = math.clamp

local function R(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

local function hash(n: number): number
	local x = sin(n * 127.1 + 311.7) * 43758.5453
	return x - math.floor(x)
end

-- Occasional sharp jerk in [-1, 1]; mostly 0.
local function twitch(t: number, period: number, seed: number): number
	local k = t / period + seed
	local bucket = math.floor(k)
	local frac = k - bucket
	if hash(bucket) < 0.55 then
		return 0
	end
	local width = 0.09
	if frac >= width then
		return 0
	end
	return sin(frac / width * math.pi) * (hash(bucket + 17) * 2 - 1)
end

-- High-frequency layered noise in roughly [-1, 1].
local function jitter(t: number, freq: number, seed: number): number
	return math.noise(t * freq, seed, 0.5) * 1.8
end

-- Values picked from a deterministic sequence that change every `period` seconds.
local function stepped(t: number, period: number, seed: number): number
	return hash(math.floor(t / period + seed)) * 2 - 1
end

type GaitParams = {
	lean: number,
	hunch: number,
	hip: number,
	knee: number,
	kneeBase: number,
	bob: number,
	twist: number,
	drop: number,
	roll: number?,
	sway: number?,
	limp: number?,
}

-- Shared lower-body locomotion. Upper body is filled in by each pose.
local function gait(ctx, p: GaitParams)
	local ph = ctx.phase
	local s, c = sin(ph), cos(ph)
	local m = ctx.move
	local limp = p.limp or 0
	local pose = {}
	local bob = -math.abs(s) * p.bob * m
	local roll = (p.roll or 0) * s * m
	local sway = (p.sway or 0) * s * m
	pose.Root = CFrame.new(sway, p.drop + bob, 0) * R(-p.lean, s * p.twist * m, roll)
	pose.Waist = R(-p.hunch, -s * p.twist * 0.7 * m, -roll * 0.6)
	local hipBase = p.lean * 0.85
	pose.LeftHip = R(hipBase + s * p.hip * m, 0, -3)
	pose.RightHip = R(hipBase - s * p.hip * m, 0, 3)
	pose.LeftKnee = R(-(p.kneeBase + max(0, c) * p.knee * m), 0, 0)
	pose.RightKnee = R(-(p.kneeBase + limp + max(0, -c) * p.knee * m), 0, 0)
	pose.LeftAnkle = R(p.kneeBase * 0.4 + max(0, c) * p.knee * 0.35 * m - s * 10 * m, 0, 0)
	pose.RightAnkle = R(p.kneeBase * 0.4 + max(0, -c) * p.knee * 0.35 * m + s * 10 * m, 0, 0)
	return pose, s, c
end

---------------------------------------------------------------------------------------------
-- IDLE: hunched, head cocked unnaturally, slow breathing, random jerks.
---------------------------------------------------------------------------------------------
function MonsterPoses.Idle(ctx)
	local t = ctx.t
	local b = sin(t * 1.5)
	local tw = twitch(t, 2.7, ctx.seed)
	local tw2 = twitch(t, 4.1, ctx.seed + 3)
	local lean, hunch = 8, 24
	return {
		Root = CFrame.new(0, -0.3 + b * 0.03, 0) * R(-lean, 0, 0),
		Waist = R(-hunch + b * 2.5, tw2 * 6, 5),
		NeckBase = R(24, 0, 0),
		Neck = R(8 + tw * 10 + ctx.lookPitch * 0.5, tw * 32 + ctx.lookYaw, 26 + tw * 14),
		Jaw = R(-5 - (b + 1) * 3, 0, 0),
		LeftShoulder = R(lean + hunch - 4 + b * 1.5, 0, -5),
		RightShoulder = R(lean + hunch + 2 + b * 1.5 + tw2 * 10, 0, 7),
		LeftElbow = R(-14, 0, 0),
		RightElbow = R(-22, 0, 0),
		LeftWrist = R(-12, 0, 0),
		RightWrist = R(-18 + tw2 * 25, 0, 0),
		LeftHip = R(lean + 12, 0, -5),
		RightHip = R(lean + 16, 0, 6),
		LeftKnee = R(-26, 0, 0),
		RightKnee = R(-32, 0, 0),
		LeftAnkle = R(12, 0, 0),
		RightAnkle = R(14, 0, 0),
	}
end

---------------------------------------------------------------------------------------------
-- BREATHING: used while stalking/watching. Dead stare at the player, heaving chest.
---------------------------------------------------------------------------------------------
function MonsterPoses.Breathing(ctx)
	local t = ctx.t
	local breath = sin(t * 2.1)
	local heave = max(0, breath)
	local lean, hunch = 6, 20 + heave * 6
	local tilt = 14 + sin(t * 0.35) * 18
	return {
		Root = CFrame.new(0, -0.25 + heave * 0.08, 0) * R(-lean, 0, 0),
		Waist = R(-hunch, 0, 2),
		NeckBase = R(lean + hunch - 6, 0, 0),
		Neck = R(ctx.lookPitch, ctx.lookYaw, tilt),
		Jaw = R(-4 - heave * 14, 0, 0),
		LeftShoulder = R(lean + hunch - heave * 4, 0, -4 - heave * 3),
		RightShoulder = R(lean + hunch - heave * 4, 0, 4 + heave * 3),
		LeftElbow = R(-8, 0, 0),
		RightElbow = R(-10, 0, 0),
		LeftWrist = R(-20, 0, 0),
		RightWrist = R(-24, 0, 0),
		LeftHip = R(lean + 8, 0, -4),
		RightHip = R(lean + 10, 0, 4),
		LeftKnee = R(-18, 0, 0),
		RightKnee = R(-20, 0, 0),
		LeftAnkle = R(10, 0, 0),
		RightAnkle = R(10, 0, 0),
	}
end

---------------------------------------------------------------------------------------------
-- LOOK AROUND: head snaps between random directions; torso follows a little.
---------------------------------------------------------------------------------------------
function MonsterPoses.LookAround(ctx)
	local pose = MonsterPoses.Idle(ctx)
	local yaw = stepped(ctx.t, 1.15, ctx.seed) * 85
	local pitch = stepped(ctx.t, 1.15, ctx.seed + 9) * 18
	pose.Neck = R(10 + pitch, yaw, 20 + stepped(ctx.t, 1.15, ctx.seed + 4) * 20)
	pose.Waist = R(-22, yaw * 0.25, 4)
	return pose
end

---------------------------------------------------------------------------------------------
-- WALK: patrol walk with a dragging limp and a lolling head.
---------------------------------------------------------------------------------------------
function MonsterPoses.Walk(ctx)
	local p = { lean = 10, hunch = 22, hip = 30, knee = 44, kneeBase = 10, bob = 0.25, twist = 8, drop = -0.25, limp = 10, roll = 4 }
	local pose, s = gait(ctx, p)
	local m = ctx.move
	local tw = twitch(ctx.t, 3.2, ctx.seed)
	local hang = p.lean + p.hunch
	pose.NeckBase = R(hang * 0.7, 0, 0)
	pose.Neck = R(4 + ctx.lookPitch * 0.4, ctx.lookYaw * 0.6 + tw * 25, 22 + sin(ctx.phase * 0.5) * 6 + tw * 10)
	pose.Jaw = R(-6, 0, 0)
	pose.LeftShoulder = R(hang - 6 - s * 14 * m, 0, -5)
	pose.RightShoulder = R(hang - 6 + s * 14 * m, 0, 6)
	pose.LeftElbow = R(-16, 0, 0)
	pose.RightElbow = R(-20, 0, 0)
	pose.LeftWrist = R(-14 + s * 8, 0, 0)
	pose.RightWrist = R(-14 - s * 8, 0, 0)
	return pose
end

---------------------------------------------------------------------------------------------
-- SLOW WALK: stalking. Body crept forward, arms dangling, head LOCKED on the player.
---------------------------------------------------------------------------------------------
function MonsterPoses.SlowWalk(ctx)
	local p = { lean = 8, hunch = 30, hip = 20, knee = 30, kneeBase = 14, bob = 0.15, twist = 4, drop = -0.4 }
	local pose, s = gait(ctx, p)
	local m = ctx.move
	local hang = p.lean + p.hunch
	pose.NeckBase = R(hang * 0.6, 0, 0)
	pose.Neck = R(hang * 0.35 + ctx.lookPitch, ctx.lookYaw, 10 + sin(ctx.t * 0.4) * 6)
	pose.Jaw = R(-3, 0, 0)
	pose.LeftShoulder = R(hang - s * 6 * m, 0, -3)
	pose.RightShoulder = R(hang + s * 6 * m, 0, 3)
	pose.LeftElbow = R(-6, 0, 0)
	pose.RightElbow = R(-6, 0, 0)
	pose.LeftWrist = R(-10, 0, 0)
	pose.RightWrist = R(-10, 0, 0)
	return pose
end

---------------------------------------------------------------------------------------------
-- SEARCH: slow walk with a scanning head.
---------------------------------------------------------------------------------------------
function MonsterPoses.Search(ctx)
	local pose
	if ctx.move > 0.15 then
		pose = MonsterPoses.SlowWalk(ctx)
	else
		pose = MonsterPoses.Idle(ctx)
	end
	local yaw = sin(ctx.t * 0.9) * 70 + stepped(ctx.t, 0.9, ctx.seed) * 12
	pose.Neck = R(14 + stepped(ctx.t, 1.3, ctx.seed + 2) * 12, yaw, 18)
	pose.Waist = (pose.Waist :: CFrame) * R(0, yaw * 0.2, 0)
	return pose
end

---------------------------------------------------------------------------------------------
-- SPRINT: fast, forward-leaning run with pumping arms.
---------------------------------------------------------------------------------------------
function MonsterPoses.Sprint(ctx)
	local p = { lean = 28, hunch = 12, hip = 52, knee = 82, kneeBase = 14, bob = 0.5, twist = 10, drop = -0.35, roll = 5 }
	local pose, s = gait(ctx, p)
	local m = ctx.move
	local hang = p.lean + p.hunch
	pose.NeckBase = R(hang * 0.55, 0, 0)
	pose.Neck = R(hang * 0.4 + jitter(ctx.t, 6, ctx.seed) * 4, ctx.lookYaw * 0.5, 18)
	pose.Jaw = R(-22, 0, 0)
	pose.LeftShoulder = R(hang * 0.6 - s * 60 * m, 0, -8)
	pose.RightShoulder = R(hang * 0.6 + s * 60 * m, 0, 8)
	pose.LeftElbow = R(-80, 0, 0)
	pose.RightElbow = R(-80, 0, 0)
	pose.LeftWrist = R(-20, 0, 0)
	pose.RightWrist = R(-20, 0, 0)
	return pose
end

---------------------------------------------------------------------------------------------
-- AGGRESSIVE SPRINT: the signature chase run. Torso almost horizontal, arms swept back
-- and flapping limply, head cocked 50+ degrees sideways but locked on you, jaw hanging
-- open and shaking, whole body lurching side to side.
---------------------------------------------------------------------------------------------
function MonsterPoses.AggressiveSprint(ctx)
	local p = { lean = 42, hunch = 18, hip = 64, knee = 108, kneeBase = 18, bob = 0.7, twist = 6, drop = -0.65, roll = 8, sway = 0.3 }
	local pose, s = gait(ctx, p)
	local t = ctx.t
	local m = clamp(ctx.move, 0.3, 1.3)
	local hang = p.lean + p.hunch
	local j = jitter(t, 11, ctx.seed)
	local j2 = jitter(t, 17, ctx.seed + 5)
	pose.NeckBase = R(hang * 0.45, 0, 0)
	pose.Neck = R(hang * 0.5 + j * 6 + ctx.lookPitch * 0.5, ctx.lookYaw * 0.6 + j2 * 9, 52 + j * 12 + sin(t * 7) * 6)
	pose.Jaw = R(-40 + sin(t * 31) * 7, 0, j2 * 4)
	pose.LeftShoulder = R(-62 + s * 14 * m + j * 6, 0, -14 - j2 * 6)
	pose.RightShoulder = R(-62 - s * 14 * m - j * 6, 0, 14 + j * 6)
	pose.LeftElbow = R(-8 + j2 * 8, 0, 0)
	pose.RightElbow = R(-8 - j * 8, 0, 0)
	pose.LeftWrist = R(sin(t * 22) * 32, 0, sin(t * 17) * 10)
	pose.RightWrist = R(sin(t * 22 + 1.7) * 32, 0, sin(t * 19) * 10)
	return pose
end

---------------------------------------------------------------------------------------------
-- HEAD TURN (detection beat 1): body perfectly still. Only the head rotates - slowly,
-- and much further than any human neck should allow (MonsterAnimator lets lookYaw
-- reach 175 degrees in this state and limits its speed).
---------------------------------------------------------------------------------------------
function MonsterPoses.HeadTurn(ctx)
	local yaw = ctx.lookYaw
	local overRotate = clamp(math.abs(yaw) / 175, 0, 1)
	local lean, hunch = 6, 20
	return {
		Root = CFrame.new(0, -0.25, 0) * R(-lean, 0, 0),
		Waist = R(-hunch, clamp(yaw * 0.08, -12, 12), 2),
		NeckBase = R(lean + hunch - 8, 0, 0),
		Neck = R(ctx.lookPitch, yaw, 8 + overRotate * 34 * math.sign(yaw + 0.001)),
		Jaw = R(-2, 0, 0),
		LeftShoulder = R(lean + hunch, 0, -4),
		RightShoulder = R(lean + hunch, 0, 4),
		LeftElbow = R(-8, 0, 0),
		RightElbow = R(-8, 0, 0),
		LeftWrist = R(-14, 0, 0),
		RightWrist = R(-14, 0, 0),
		LeftHip = R(lean + 8, 0, -4),
		RightHip = R(lean + 10, 0, 4),
		LeftKnee = R(-18, 0, 0),
		RightKnee = R(-20, 0, 0),
		LeftAnkle = R(10, 0, 0),
		RightAnkle = R(10, 0, 0),
	}
end

---------------------------------------------------------------------------------------------
-- SCREAM (detection beat 3): body snaps into an unnatural spread posture, head thrown
-- back, then whips forward at the player as it drops into a sprint crouch.
---------------------------------------------------------------------------------------------
function MonsterPoses.Scream(ctx)
	local t, st = ctx.t, ctx.st
	local j = jitter(t, 38, ctx.seed)
	local j2 = jitter(t, 44, ctx.seed + 2)
	local thrown = st < 0.45 and 1 or clamp(1 - (st - 0.45) / 0.35, 0, 1)
	local crouch = 1 - thrown
	return {
		Root = CFrame.new(0, -0.6 - crouch * 0.4, 0.2) * R(6 - crouch * 30, 0, j * 2),
		Waist = R(22 * thrown - 18 * crouch + j * 4, 0, j2 * 3),
		NeckBase = R(26, 0, 0),
		Neck = R(38 * thrown - 10 * crouch + j * 9, ctx.lookYaw * 0.3 + j2 * 10, j * 12),
		Jaw = R(-58 + j2 * 6, 0, j * 3),
		LeftShoulder = R(-18 + crouch * 10, 0, -105 + j * 12),
		RightShoulder = R(-18 + crouch * 10, 0, 105 - j2 * 12),
		LeftElbow = R(-12 + j * 10, 0, 0),
		RightElbow = R(-12 - j2 * 10, 0, 0),
		LeftWrist = R(30 + j * 25, 0, 0),
		RightWrist = R(30 - j2 * 25, 0, 0),
		LeftHip = R(26 + crouch * 25, 0, -14),
		RightHip = R(26 + crouch * 25, 0, 14),
		LeftKnee = R(-48 - crouch * 30, 0, 0),
		RightKnee = R(-48 - crouch * 30, 0, 0),
		LeftAnkle = R(20, 0, 0),
		RightAnkle = R(20, 0, 0),
	}
end

---------------------------------------------------------------------------------------------
-- ATTACK: wind up both arms overhead, then strike down.
---------------------------------------------------------------------------------------------
function MonsterPoses.Attack(ctx)
	local st = ctx.st
	local a = clamp(st / 0.2, 0, 1)
	local b = clamp((st - 0.2) / 0.14, 0, 1)
	local shoulder = (30 + (165 - 30) * a) + (55 - 165) * b
	local waist = (-20 + 30 * a) - 55 * b
	local j = jitter(ctx.t, 30, ctx.seed)
	return {
		Root = CFrame.new(0, -0.5, -0.3 * b) * R(-10 - 15 * b, 0, 0),
		Waist = R(waist, 0, 0),
		NeckBase = R(20, 0, 0),
		Neck = R(10 + 25 * b, ctx.lookYaw * 0.4, 18 + j * 8),
		Jaw = R(-50 - j * 6, 0, 0),
		LeftShoulder = R(shoulder, 0, -18),
		RightShoulder = R(shoulder, 0, 18),
		LeftElbow = R(-25, 0, 0),
		RightElbow = R(-25, 0, 0),
		LeftWrist = R(-30, 0, 0),
		RightWrist = R(-30, 0, 0),
		LeftHip = R(30, 0, -8),
		RightHip = R(10, 0, 8),
		LeftKnee = R(-45, 0, 0),
		RightKnee = R(-30, 0, 0),
		LeftAnkle = R(15, 0, 0),
		RightAnkle = R(15, 0, 0),
	}
end

---------------------------------------------------------------------------------------------
-- GRAB: arms clamp forward, claws curl, jaw chattering.
---------------------------------------------------------------------------------------------
function MonsterPoses.Grab(ctx)
	local t = ctx.t
	local chatter = sin(t * 40) * 6
	local j = jitter(t, 20, ctx.seed)
	return {
		Root = CFrame.new(0, -0.6, 0) * R(-14, 0, 0),
		Waist = R(-28, 0, j * 3),
		NeckBase = R(30, 0, 0),
		Neck = R(14 + j * 5, ctx.lookYaw * 0.5, 24 + j * 10),
		Jaw = R(-42 + chatter, 0, 0),
		LeftShoulder = R(88, 0, 22),
		RightShoulder = R(88, 0, -22),
		LeftElbow = R(-38, 0, 0),
		RightElbow = R(-38, 0, 0),
		LeftWrist = R(-35 + j * 10, 0, 0),
		RightWrist = R(-35 - j * 10, 0, 0),
		LeftHip = R(26, 0, -8),
		RightHip = R(26, 0, 8),
		LeftKnee = R(-40, 0, 0),
		RightKnee = R(-40, 0, 0),
		LeftAnkle = R(14, 0, 0),
		RightAnkle = R(14, 0, 0),
	}
end

---------------------------------------------------------------------------------------------
-- JUMPSCARE: face pushed at the camera, jaw unhinged, violent shaking.
---------------------------------------------------------------------------------------------
function MonsterPoses.Jumpscare(ctx)
	local t = ctx.t
	local j = jitter(t, 26, ctx.seed)
	local j2 = jitter(t, 33, ctx.seed + 7)
	return {
		Root = CFrame.new(0, -0.4, 0) * R(-8, 0, j * 2),
		Waist = R(-34 + j * 4, j2 * 4, 0),
		NeckBase = R(26, 0, 0),
		Neck = R(18 + sin(t * 31) * 9, sin(t * 23) * 14 + j * 6, 22 + sin(t * 41) * 18),
		Jaw = R(-66 + sin(t * 50) * 8, 0, j2 * 5),
		LeftShoulder = R(108 + j * 8, 0, 38),
		RightShoulder = R(108 - j2 * 8, 0, -38),
		LeftElbow = R(-48, 0, 0),
		RightElbow = R(-48, 0, 0),
		LeftWrist = R(-40 + j2 * 20, 0, 0),
		RightWrist = R(-40 + j * 20, 0, 0),
		LeftHip = R(22, 0, -6),
		RightHip = R(22, 0, 6),
		LeftKnee = R(-36, 0, 0),
		RightKnee = R(-36, 0, 0),
		LeftAnkle = R(14, 0, 0),
		RightAnkle = R(14, 0, 0),
	}
end

---------------------------------------------------------------------------------------------
-- STAGGER: recoil after smashing through a door (also used as the "death" reaction).
---------------------------------------------------------------------------------------------
function MonsterPoses.Stagger(ctx)
	local st = ctx.st
	local k = math.exp(-st * 4)
	local flail = sin(st * 15) * 38 * k
	return {
		Root = CFrame.new(0, -0.45, 0.6 * k) * R(6 * k, 0, 10 * k * sin(st * 9)),
		Waist = R(26 * k - 12, 0, 16 * k * sin(st * 12)),
		NeckBase = R(20, 0, 0),
		Neck = R(-22 * k + 10, 32 * k * sin(st * 9), 46 * k + 12),
		Jaw = R(-30 * k - 6, 0, 0),
		LeftShoulder = R(30 + flail, 0, -30 * k - 6),
		RightShoulder = R(30 - flail, 0, 30 * k + 6),
		LeftElbow = R(-30, 0, 0),
		RightElbow = R(-30, 0, 0),
		LeftWrist = R(flail * 0.5, 0, 0),
		RightWrist = R(-flail * 0.5, 0, 0),
		LeftHip = R(22, 0, -8),
		RightHip = R(14, 0, 8),
		LeftKnee = R(-36, 0, 0),
		RightKnee = R(-28, 0, 0),
		LeftAnkle = R(12, 0, 0),
		RightAnkle = R(12, 0, 0),
	}
end

---------------------------------------------------------------------------------------------
-- DOOR OPEN: long arm reaches out and pushes; head tilts to peer through the gap.
---------------------------------------------------------------------------------------------
function MonsterPoses.DoorOpen(ctx)
	local pose = MonsterPoses.Idle(ctx)
	local push = clamp(ctx.st / 0.4, 0, 1)
	pose.RightShoulder = R(30 + 62 * push, 0, 10)
	pose.RightElbow = R(-30 + 20 * push, 0, 0)
	pose.RightWrist = R(-40 * push, 0, 0)
	pose.Neck = R(14, 0, 34)
	pose.Waist = R(-24, 10 * push, 0)
	return pose
end

---------------------------------------------------------------------------------------------
-- DOOR SLAM: pounding on the safe-room door with both fists.
---------------------------------------------------------------------------------------------
function MonsterPoses.DoorSlam(ctx)
	local t = ctx.t
	local pound = sin(t * 15)
	local hit = max(0, pound)
	local j = jitter(t, 24, ctx.seed)
	return {
		Root = CFrame.new(0, -0.35, pound * 0.25) * R(-12, 0, j * 3),
		Waist = R(-14 - hit * 8, 0, j * 4),
		NeckBase = R(22, 0, 0),
		Neck = R(14 + j * 6, 0, 22 + hit * 8),
		Jaw = R(-44 - hit * 10, 0, 0),
		LeftShoulder = R(112 + pound * 32, 0, -10),
		RightShoulder = R(112 - pound * 32, 0, 10),
		LeftElbow = R(-30 - hit * 22, 0, 0),
		RightElbow = R(-30 - max(0, -pound) * 22, 0, 0),
		LeftWrist = R(-20, 0, 0),
		RightWrist = R(-20, 0, 0),
		LeftHip = R(24, 0, -8),
		RightHip = R(18, 0, 8),
		LeftKnee = R(-34, 0, 0),
		RightKnee = R(-30, 0, 0),
		LeftAnkle = R(12, 0, 0),
		RightAnkle = R(12, 0, 0),
	}
end

return MonsterPoses
