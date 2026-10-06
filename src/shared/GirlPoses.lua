--[[
	Procedural animation library for The Girl in White.

	Each pose is a function(ctx) -> { [jointName] = CFrame }. RigAnimator blends between
	them and writes Motor6D.Transform every frame.

	ctx = { t, st (time in state), phase (gait), move (0..1 gait amount), speed,
	        lookYaw, lookPitch (degrees), seed }

	Conventions: +X at a hip/shoulder swings the limb forward; -X at waist/root leans
	forward; -X at a knee bends it; -X on the jaw opens the mouth; +Y turns left.

	Her movement is deliberately "stop-motion": the run pose is evaluated on a stepped
	clock so she lurches between poses instead of moving smoothly. When someone looks
	at her the animator stops entirely (state "Frozen") - she is caught mid-pose.
]]

local GirlPoses = {}

local rad = math.rad
local sin = math.sin
local cos = math.cos
local max = math.max

local function R(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

local function jitter(t: number, freq: number, seed: number): number
	return math.noise(t * freq, seed, 0.5) * 1.8
end

-- Standing still: head lolled to one side, arms limp, the faintest sway.
function GirlPoses.Stand(ctx)
	local t = ctx.t
	local sway = sin(t * 0.7) * 2
	return {
		Root = CFrame.new(0, -0.05, 0) * R(-4, 0, sway * 0.4),
		Waist = R(-8, 0, sway * 0.5),
		NeckBase = R(6, 0, 0),
		Neck = R(-6 + ctx.lookPitch * 0.5, ctx.lookYaw, 34 + sin(t * 0.4) * 4),
		Jaw = R(-4, 0, 0),
		LeftShoulder = R(10, 0, -4),
		RightShoulder = R(12, 0, 5),
		LeftElbow = R(-6, 0, 0),
		RightElbow = R(-10, 0, 0),
		LeftWrist = R(-10, 0, 0),
		RightWrist = R(-14, 0, 0),
		LeftHip = R(4, 0, -2),
		RightHip = R(2, 0, 3),
		LeftKnee = R(-6, 0, 0),
		RightKnee = R(-4, 0, 0),
		LeftAnkle = R(3, 0, 0),
		RightAnkle = R(2, 0, 0),
	}
end

-- Moving while nobody watches: lurching, arms reaching out in front, head cocked.
function GirlPoses.Run(ctx)
	-- stop-motion: snap the gait phase to eighths of a cycle
	local step = math.pi / 4
	local ph = math.floor(ctx.phase / step) * step
	local s, c = sin(ph), cos(ph)
	local m = math.clamp(ctx.move, 0.4, 1.2)
	local t = math.floor(ctx.t * 10) / 10
	local j = jitter(t, 3, ctx.seed)
	local lean = 24
	return {
		Root = CFrame.new(0, -0.2 - math.abs(s) * 0.15 * m, 0) * R(-lean, s * 6 * m, s * 5 * m),
		Waist = R(-10, -s * 8 * m, 0),
		NeckBase = R(lean * 0.6, 0, 0),
		Neck = R(lean * 0.4 + ctx.lookPitch * 0.4 + j * 6, ctx.lookYaw * 0.6, 38 + j * 10),
		Jaw = R(-18 + j * 6, 0, 0),
		LeftShoulder = R(lean + 62 + s * 10 * m, 0, 8),
		RightShoulder = R(lean + 66 - s * 10 * m, 0, -8),
		LeftElbow = R(-14, 0, 0),
		RightElbow = R(-10, 0, 0),
		LeftWrist = R(-20, 0, 0),
		RightWrist = R(-24, 0, 0),
		LeftHip = R(lean * 0.8 + s * 46 * m, 0, -3),
		RightHip = R(lean * 0.8 - s * 46 * m, 0, 3),
		LeftKnee = R(-(14 + max(0, c) * 70 * m), 0, 0),
		RightKnee = R(-(14 + max(0, -c) * 70 * m), 0, 0),
		LeftAnkle = R(10 + max(0, c) * 20 * m, 0, 0),
		RightAnkle = R(10 + max(0, -c) * 20 * m, 0, 0),
	}
end

-- Coiled to spring: crouched low, arms drawn back, face up at you.
function GirlPoses.Crouch(ctx)
	local j = jitter(ctx.t, 18, ctx.seed)
	return {
		Root = CFrame.new(0, -1.1, 0.2) * R(-28, 0, j * 2),
		Waist = R(-22, 0, 0),
		NeckBase = R(38, 0, 0),
		Neck = R(20 + j * 4, ctx.lookYaw * 0.5, 22),
		Jaw = R(-30, 0, 0),
		LeftShoulder = R(-30, 0, -30),
		RightShoulder = R(-30, 0, 30),
		LeftElbow = R(-60, 0, 0),
		RightElbow = R(-60, 0, 0),
		LeftWrist = R(-30, 0, 0),
		RightWrist = R(-30, 0, 0),
		LeftHip = R(85, 0, -10),
		RightHip = R(85, 0, 10),
		LeftKnee = R(-120, 0, 0),
		RightKnee = R(-120, 0, 0),
		LeftAnkle = R(40, 0, 0),
		RightAnkle = R(40, 0, 0),
	}
end

-- Mid-leap: arms flung wide toward you, legs trailing, mouth torn open, shaking.
function GirlPoses.Leap(ctx)
	local t = ctx.t
	local j = jitter(t, 28, ctx.seed)
	local j2 = jitter(t, 35, ctx.seed + 3)
	return {
		Root = CFrame.new(0, 0, 0) * R(-22 + j * 3, j2 * 3, j * 3),
		Waist = R(-12, 0, 0),
		NeckBase = R(26, 0, 0),
		Neck = R(14 + sin(t * 37) * 8, sin(t * 29) * 12 + j2 * 5, 18 + sin(t * 43) * 16),
		Jaw = R(-62 + sin(t * 55) * 8, 0, j * 4),
		LeftShoulder = R(108 + j * 8, 0, 48),
		RightShoulder = R(108 - j2 * 8, 0, -48),
		LeftElbow = R(-25, 0, 0),
		RightElbow = R(-25, 0, 0),
		LeftWrist = R(-35 + j2 * 25, 0, 0),
		RightWrist = R(-35 + j * 25, 0, 0),
		LeftHip = R(-25, 0, -12),
		RightHip = R(-10, 0, 12),
		LeftKnee = R(-70, 0, 0),
		RightKnee = R(-50, 0, 0),
		LeftAnkle = R(-20, 0, 0),
		RightAnkle = R(-20, 0, 0),
	}
end

-- Standing scream: head whips back then forward, arms out.
function GirlPoses.Scream(ctx)
	local t, st = ctx.t, ctx.st
	local j = jitter(t, 34, ctx.seed)
	local back = st < 0.3 and 1 or math.clamp(1 - (st - 0.3) / 0.25, 0, 1)
	return {
		Root = CFrame.new(0, -0.2, 0) * R(6 * back - 10, 0, j * 2),
		Waist = R(16 * back - 10, 0, j * 2),
		NeckBase = R(10, 0, 0),
		Neck = R(40 * back - 10 + j * 8, j * 8, j * 10),
		Jaw = R(-60 + j * 6, 0, 0),
		LeftShoulder = R(-10, 0, -95 + j * 10),
		RightShoulder = R(-10, 0, 95 - j * 10),
		LeftElbow = R(-10, 0, 0),
		RightElbow = R(-10, 0, 0),
		LeftWrist = R(20, 0, 0),
		RightWrist = R(20, 0, 0),
		LeftHip = R(10, 0, -10),
		RightHip = R(10, 0, 10),
		LeftKnee = R(-14, 0, 0),
		RightKnee = R(-14, 0, 0),
		LeftAnkle = R(4, 0, 0),
		RightAnkle = R(4, 0, 0),
	}
end

return GirlPoses
