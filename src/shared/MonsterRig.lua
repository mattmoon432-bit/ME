--[[
	Builds "The Grinner": a ~12 stud tall emaciated figure with an elongated neck,
	arms that reach past its knees, clawed fingers and a grin wider than its head.

	The rig is a real Motor6D hierarchy (same idea as an R15 character) so it can be
	animated procedurally (MonsterPoses) or with uploaded keyframe animations.

	HumanoidRootPart
	└─ Root ─ LowerTorso
	          ├─ Waist ─ UpperTorso
	          │          ├─ NeckBase ─ NeckSeg ─ Neck ─ Head ─ Jaw ─ Jaw
	          │          ├─ LeftShoulder ─ LeftUpperArm ─ LeftElbow ─ LeftLowerArm ─ LeftWrist ─ LeftHand
	          │          └─ RightShoulder ─ ...
	          ├─ LeftHip ─ LeftUpperLeg ─ LeftKnee ─ LeftLowerLeg ─ LeftAnkle ─ LeftFoot
	          └─ RightHip ─ ...
]]

local MonsterRig = {}

MonsterRig.HipHeight = 4.95
MonsterRig.RootHeight = 5.95 -- HumanoidRootPart centre above the floor when standing

local SKIN = Color3.fromRGB(176, 170, 158)
local SKIN_DARK = Color3.fromRGB(110, 98, 90)
local SKIN_SHADOW = Color3.fromRGB(140, 132, 122)
local BONE = Color3.fromRGB(214, 206, 186)
local BLOOD = Color3.fromRGB(64, 5, 5)
local BLACK = Color3.fromRGB(4, 4, 4)
local CLOTH = Color3.fromRGB(46, 43, 40)
local EYE = Color3.fromRGB(235, 228, 200)

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.Massless = true
	part.CastShadow = true
	return part
end

local function deg(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local function joint(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	part1.CFrame = part0.CFrame * c0 * c1:Inverse()
	motor.Parent = part1
	return motor
end

-- Decorative geometry welded to a limb.
local function decor(
	limb: BasePart,
	name: string,
	size: Vector3,
	color: Color3,
	offset: CFrame,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local part = makePart(name, size, color, material)
	part.CanQuery = false
	if shape then
		part.Shape = shape
	end
	part.CFrame = limb.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = part
	weld.Parent = part
	part.Parent = limb
	return part
end

local function buildArm(model: Model, torso: BasePart, side: number)
	local prefix = side < 0 and "Left" or "Right"
	local upper = makePart(prefix .. "UpperArm", Vector3.new(0.42, 2.9, 0.42), SKIN)
	upper.Parent = model
	joint(prefix .. "Shoulder", torso, upper, CFrame.new(side * 1.0, 1.15, 0), CFrame.new(0, 1.3, 0))
	decor(upper, "ShoulderKnob", Vector3.new(0.62, 0.62, 0.62), SKIN_SHADOW, CFrame.new(0, 1.2, 0), Enum.PartType.Ball)

	local lower = makePart(prefix .. "LowerArm", Vector3.new(0.36, 3.0, 0.36), SKIN)
	lower.Parent = model
	joint(prefix .. "Elbow", upper, lower, CFrame.new(0, -1.4, 0), CFrame.new(0, 1.45, 0))
	decor(lower, "ElbowKnob", Vector3.new(0.48, 0.48, 0.48), SKIN_SHADOW, CFrame.new(0, 1.42, 0.04), Enum.PartType.Ball)
	-- Veins / sinew
	decor(lower, "Sinew", Vector3.new(0.08, 2.4, 0.08), SKIN_DARK, CFrame.new(side * 0.12, 0.1, -0.15) * deg(0, 0, side * 3))

	local hand = makePart(prefix .. "Hand", Vector3.new(0.55, 0.7, 0.22), SKIN_DARK)
	hand.Parent = model
	joint(prefix .. "Wrist", lower, hand, CFrame.new(0, -1.5, 0), CFrame.new(0, 0.35, 0))

	-- Four long fingers with black, blood-tipped claws, curling slightly forward.
	for i = 0, 3 do
		local x = -0.2 + i * 0.13
		local length = 1.0 + (i == 1 and 0.25 or 0) + (i == 2 and 0.15 or 0)
		local finger = decor(
			hand,
			"Finger" .. i,
			Vector3.new(0.08, length, 0.08),
			SKIN_DARK,
			CFrame.new(x, -0.3 - length / 2, -0.04) * deg(-8, 0, (i - 1.5) * 2)
		)
		decor(finger, "Claw", Vector3.new(0.07, 0.32, 0.07), BLACK, CFrame.new(0, -length / 2 - 0.12, -0.05) * deg(-22, 0, 0))
		if i % 2 == 0 then
			decor(finger, "Blood", Vector3.new(0.09, 0.3, 0.09), BLOOD, CFrame.new(0, -length / 2 + 0.1, 0))
		end
	end
	decor(hand, "Thumb", Vector3.new(0.08, 0.6, 0.08), SKIN_DARK, CFrame.new(-side * 0.3, -0.25, -0.05) * deg(-15, 0, -side * 35))
end

local function buildLeg(model: Model, pelvis: BasePart, side: number)
	local prefix = side < 0 and "Left" or "Right"
	local thigh = makePart(prefix .. "UpperLeg", Vector3.new(0.55, 2.7, 0.55), SKIN)
	thigh.Parent = model
	joint(prefix .. "Hip", pelvis, thigh, CFrame.new(side * 0.5, -0.3, 0), CFrame.new(0, 1.25, 0))

	local shin = makePart(prefix .. "LowerLeg", Vector3.new(0.45, 2.9, 0.45), SKIN)
	shin.Parent = model
	joint(prefix .. "Knee", thigh, shin, CFrame.new(0, -1.3, 0), CFrame.new(0, 1.4, 0))
	decor(shin, "KneeKnob", Vector3.new(0.62, 0.62, 0.62), SKIN_SHADOW, CFrame.new(0, 1.35, -0.08), Enum.PartType.Ball)
	decor(shin, "Shinbone", Vector3.new(0.12, 2.2, 0.12), SKIN_SHADOW, CFrame.new(0, 0.1, -0.2))

	local foot = makePart(prefix .. "Foot", Vector3.new(0.5, 0.3, 1.1), SKIN_DARK)
	foot.Parent = model
	joint(prefix .. "Ankle", shin, foot, CFrame.new(0, -1.45, 0), CFrame.new(0, 0.1, 0.3))
	for i = 0, 2 do
		decor(foot, "Toe" .. i, Vector3.new(0.1, 0.1, 0.35), SKIN_DARK, CFrame.new(-0.15 + i * 0.15, -0.08, -0.65) * deg(-10, 0, 0))
	end
end

local function buildHead(model: Model, neck: BasePart): BasePart
	local head = makePart("Head", Vector3.new(1.2, 1.6, 1.25), SKIN)
	head.Parent = model
	joint("Neck", neck, head, CFrame.new(0, 0.65, 0), CFrame.new(0, -0.7, 0.1))

	-- Elongated skull and brow.
	decor(head, "Cranium", Vector3.new(1.35, 1.35, 1.35), SKIN, CFrame.new(0, 0.38, 0.22), Enum.PartType.Ball)
	decor(head, "Brow", Vector3.new(1.12, 0.17, 0.25), SKIN_SHADOW, CFrame.new(0, 0.44, -0.55) * deg(8, 0, 0))
	decor(head, "CheekL", Vector3.new(0.3, 0.5, 0.3), SKIN_SHADOW, CFrame.new(-0.5, -0.05, -0.45), Enum.PartType.Ball)
	decor(head, "CheekR", Vector3.new(0.3, 0.5, 0.3), SKIN_SHADOW, CFrame.new(0.5, -0.05, -0.45), Enum.PartType.Ball)

	-- Deep, slightly asymmetric eye sockets with tiny pale pupils.
	decor(head, "SocketL", Vector3.new(0.44, 0.44, 0.44), BLACK, CFrame.new(-0.27, 0.2, -0.5), Enum.PartType.Ball)
	decor(head, "SocketR", Vector3.new(0.4, 0.4, 0.4), BLACK, CFrame.new(0.29, 0.27, -0.5), Enum.PartType.Ball)
	decor(head, "PupilL", Vector3.new(0.09, 0.09, 0.09), EYE, CFrame.new(-0.26, 0.2, -0.71), Enum.PartType.Ball, Enum.Material.Neon)
	decor(head, "PupilR", Vector3.new(0.07, 0.07, 0.07), EYE, CFrame.new(0.3, 0.28, -0.69), Enum.PartType.Ball, Enum.Material.Neon)
	local eyeGlow = Instance.new("PointLight")
	eyeGlow.Name = "EyeGlow"
	eyeGlow.Color = Color3.fromRGB(255, 236, 200)
	eyeGlow.Range = 5
	eyeGlow.Brightness = 0.6
	eyeGlow.Shadows = false
	eyeGlow.Parent = head

	-- The grin: a black cavity wider than the skull, splitting into the cheeks.
	decor(head, "Mouth", Vector3.new(1.18, 0.34, 0.2), BLACK, CFrame.new(0, -0.32, -0.55))
	decor(head, "GrinL", Vector3.new(0.34, 0.08, 0.16), BLACK, CFrame.new(-0.66, -0.18, -0.46) * deg(0, 20, 28))
	decor(head, "GrinR", Vector3.new(0.34, 0.08, 0.16), BLACK, CFrame.new(0.66, -0.18, -0.46) * deg(0, -20, -28))
	local rng = Random.new(9)
	for i = 0, 10 do
		local x = -0.5 + i * 0.1
		local height = 0.16 + rng:NextNumber(0, 0.08)
		decor(head, "ToothU" .. i, Vector3.new(0.075, height, 0.05), BONE, CFrame.new(x, -0.17 - height / 2, -0.66) * deg(0, 0, rng:NextNumber(-6, 6)))
	end

	-- Sparse hanging hair.
	for i = 1, 8 do
		local length = rng:NextNumber(0.9, 1.8)
		local x = rng:NextNumber(-0.55, 0.55)
		local z = rng:NextNumber(-0.1, 0.6)
		decor(head, "Hair" .. i, Vector3.new(0.05, length, 0.05), BLACK, CFrame.new(x, 0.95 - length / 2, z) * deg(rng:NextNumber(-12, 12), 0, rng:NextNumber(-10, 10)))
	end

	-- Hinged jaw with its own teeth, stained with blood.
	local jaw = makePart("Jaw", Vector3.new(1.05, 0.32, 1.0), SKIN)
	jaw.Parent = model
	joint("Jaw", head, jaw, CFrame.new(0, -0.6, 0.35), CFrame.new(0, 0.12, 0.42))
	for i = 0, 9 do
		local x = -0.45 + i * 0.1
		local height = 0.14 + rng:NextNumber(0, 0.07)
		decor(jaw, "ToothL" .. i, Vector3.new(0.07, height, 0.05), BONE, CFrame.new(x, 0.12 + height / 2, -0.45))
	end
	decor(jaw, "Blood", Vector3.new(0.7, 0.06, 0.25), BLOOD, CFrame.new(0, -0.13, -0.4))
	decor(jaw, "Tongue", Vector3.new(0.5, 0.06, 0.55), Color3.fromRGB(60, 22, 26), CFrame.new(0, 0.1, -0.15))

	return head
end

function MonsterRig.Build(): Model
	local model = Instance.new("Model")
	model.Name = "Grinner"

	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1.2), SKIN)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.CanQuery = false
	root.CFrame = CFrame.new(0, MonsterRig.RootHeight, 0)
	root.Parent = model
	model.PrimaryPart = root

	local pelvis = makePart("LowerTorso", Vector3.new(1.5, 0.8, 0.8), CLOTH, Enum.Material.Fabric)
	pelvis.Parent = model
	joint("Root", root, pelvis, CFrame.new(), CFrame.new())
	-- Tattered gown strips hanging from the hips.
	local rng = Random.new(4)
	for i = 0, 6 do
		local angle = i / 7 * math.pi * 2
		local length = rng:NextNumber(1.1, 2)
		decor(
			pelvis,
			"Rag" .. i,
			Vector3.new(0.4, length, 0.05),
			CLOTH,
			CFrame.new(math.sin(angle) * 0.7, -0.3 - length / 2, math.cos(angle) * 0.42) * CFrame.Angles(0, angle, 0) * deg(rng:NextNumber(-8, 8), 0, 0),
			nil,
			Enum.Material.Fabric
		)
	end

	local torso = makePart("UpperTorso", Vector3.new(1.7, 2.8, 0.85), SKIN)
	torso.Parent = model
	joint("Waist", pelvis, torso, CFrame.new(0, 0.4, 0), CFrame.new(0, -1.4, 0))
	decor(torso, "Gown", Vector3.new(1.76, 1.0, 0.92), CLOTH, CFrame.new(0, -0.95, 0), nil, Enum.Material.Fabric)
	decor(torso, "GownTorn", Vector3.new(0.9, 0.9, 0.05), CLOTH, CFrame.new(0.3, -0.1, 0.47) * deg(0, 0, 12), nil, Enum.Material.Fabric)
	for i = 0, 3 do
		decor(torso, "Rib" .. i, Vector3.new(1.45 - i * 0.12, 0.07, 0.1), SKIN_SHADOW, CFrame.new(0, 0.75 - i * 0.32, -0.44) * deg(0, 0, (i % 2 == 0) and 2 or -2))
	end
	for i = 0, 6 do
		decor(torso, "Spine" .. i, Vector3.new(0.26, 0.26, 0.26), SKIN_SHADOW, CFrame.new(0, 1.15 - i * 0.4, 0.42), Enum.PartType.Ball)
	end
	decor(torso, "CollarL", Vector3.new(0.8, 0.1, 0.12), SKIN_SHADOW, CFrame.new(-0.42, 1.25, -0.4) * deg(0, 0, -12))
	decor(torso, "CollarR", Vector3.new(0.8, 0.1, 0.12), SKIN_SHADOW, CFrame.new(0.42, 1.25, -0.4) * deg(0, 0, 12))
	decor(torso, "Wound", Vector3.new(0.35, 0.6, 0.05), BLOOD, CFrame.new(-0.35, 0.2, -0.44) * deg(0, 0, 20))

	local neck = makePart("NeckSeg", Vector3.new(0.45, 1.3, 0.45), SKIN)
	neck.Parent = model
	joint("NeckBase", torso, neck, CFrame.new(0, 1.4, -0.1), CFrame.new(0, -0.65, 0))
	decor(neck, "Tendon", Vector3.new(0.1, 1.2, 0.1), SKIN_SHADOW, CFrame.new(0.13, 0, -0.18) * deg(0, 0, -6))
	decor(neck, "Tendon2", Vector3.new(0.1, 1.2, 0.1), SKIN_SHADOW, CFrame.new(-0.13, 0, -0.18) * deg(0, 0, 6))

	buildHead(model, neck)
	buildArm(model, torso, -1)
	buildArm(model, torso, 1)
	buildLeg(model, pelvis, -1)
	buildLeg(model, pelvis, 1)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = MonsterRig.HipHeight
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.AutomaticScalingEnabled = false
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.WalkSpeed = 8
	humanoid.MaxSlopeAngle = 60
	humanoid.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge

	-- Disable states that would make a scripted monster flop around.
	for _, state in
		{
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Seated,
			Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.Jumping,
			Enum.HumanoidStateType.Dead,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end

	model:SetAttribute("AnimState", "Idle")
	model:SetAttribute("LookTarget", Vector3.zero)
	return model
end

-- Anchors every part (for static display copies such as the menu and jumpscare).
function MonsterRig.MakeStatic(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		humanoid.EvaluateStateMachine = false
	end
end

return MonsterRig
