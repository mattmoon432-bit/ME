--[[
	Builds "The Girl in White": a gaunt, too-tall figure (~6.7 studs, taller than the
	player) in a filthy white nightgown. Long black hair hangs over her face; through a
	gap you can see one pale eye and a black, too-wide mouth. Long thin arms, long
	fingers, bare grey feet.

	Real Motor6D rig (same joint names as an R15-style rig) so it can be animated
	procedurally (GirlPoses) or with uploaded keyframe animations.

	HumanoidRootPart
	└─ Root ─ LowerTorso
	          ├─ Waist ─ UpperTorso
	          │          ├─ NeckBase ─ NeckSeg ─ Neck ─ Head ─ Jaw ─ Jaw
	          │          ├─ LeftShoulder ─ LeftUpperArm ─ LeftElbow ─ LeftLowerArm ─ LeftWrist ─ LeftHand
	          │          └─ RightShoulder ─ ...
	          ├─ LeftHip ─ LeftUpperLeg ─ LeftKnee ─ LeftLowerLeg ─ LeftAnkle ─ LeftFoot
	          └─ RightHip ─ ...
]]

local GirlRig = {}

GirlRig.HipHeight = 2.25
GirlRig.RootHeight = 3.25 -- HumanoidRootPart centre above the floor when standing
GirlRig.HeadHeight = 2.8 -- head centre above the root (used for look-at pitch)

local SKIN = Color3.fromRGB(196, 196, 190)
local SKIN_DARK = Color3.fromRGB(140, 140, 136)
local GOWN = Color3.fromRGB(206, 200, 186)
local GOWN_DIRT = Color3.fromRGB(150, 140, 122)
local HAIR = Color3.fromRGB(10, 9, 9)
local BLACK = Color3.fromRGB(3, 3, 3)
local BLOOD = Color3.fromRGB(70, 6, 6)
local EYE = Color3.fromRGB(235, 232, 220)

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

local function decor(limb: BasePart, name: string, size: Vector3, color: Color3, offset: CFrame, shape: Enum.PartType?, material: Enum.Material?): Part
	local part = makePart(name, size, color, material)
	part.CanQuery = false
	part.CastShadow = size.Magnitude > 0.6
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
	local upper = makePart(prefix .. "UpperArm", Vector3.new(0.28, 1.6, 0.28), SKIN)
	upper.Parent = model
	joint(prefix .. "Shoulder", torso, upper, CFrame.new(side * 0.72, 0.62, 0), CFrame.new(0, 0.7, 0))
	-- short gown sleeve
	decor(upper, "Sleeve", Vector3.new(0.4, 0.6, 0.4), GOWN, CFrame.new(0, 0.5, 0), nil, Enum.Material.Fabric)

	local lower = makePart(prefix .. "LowerArm", Vector3.new(0.24, 1.6, 0.24), SKIN)
	lower.Parent = model
	joint(prefix .. "Elbow", upper, lower, CFrame.new(0, -0.75, 0), CFrame.new(0, 0.75, 0))
	decor(lower, "Bruise", Vector3.new(0.25, 0.35, 0.25), SKIN_DARK, CFrame.new(0, 0.3, 0))

	local hand = makePart(prefix .. "Hand", Vector3.new(0.32, 0.45, 0.12), SKIN)
	hand.Parent = model
	joint(prefix .. "Wrist", lower, hand, CFrame.new(0, -0.78, 0), CFrame.new(0, 0.22, 0))
	for i = 0, 3 do
		local length = 0.55 + (i == 1 and 0.12 or 0) + (i == 2 and 0.08 or 0)
		local finger = decor(hand, "Finger" .. i, Vector3.new(0.05, length, 0.05), SKIN, CFrame.new(-0.12 + i * 0.08, -0.22 - length / 2, -0.02) * deg(-10, 0, (i - 1.5) * 3))
		decor(finger, "Nail", Vector3.new(0.05, 0.1, 0.05), BLACK, CFrame.new(0, -length / 2 - 0.03, -0.01))
	end
	decor(hand, "Thumb", Vector3.new(0.05, 0.35, 0.05), SKIN, CFrame.new(-side * 0.18, -0.12, -0.04) * deg(-15, 0, -side * 35))
end

local function buildLeg(model: Model, pelvis: BasePart, side: number)
	local prefix = side < 0 and "Left" or "Right"
	local thigh = makePart(prefix .. "UpperLeg", Vector3.new(0.34, 1.45, 0.34), SKIN)
	thigh.Parent = model
	joint(prefix .. "Hip", pelvis, thigh, CFrame.new(side * 0.28, -0.2, 0), CFrame.new(0, 0.7, 0))
	local shin = makePart(prefix .. "LowerLeg", Vector3.new(0.28, 1.5, 0.28), SKIN)
	shin.Parent = model
	joint(prefix .. "Knee", thigh, shin, CFrame.new(0, -0.72, 0), CFrame.new(0, 0.72, 0))
	decor(shin, "Dirt", Vector3.new(0.3, 0.6, 0.3), SKIN_DARK, CFrame.new(0, -0.45, 0))
	local foot = makePart(prefix .. "Foot", Vector3.new(0.3, 0.18, 0.62), SKIN_DARK)
	foot.Parent = model
	joint(prefix .. "Ankle", shin, foot, CFrame.new(0, -0.75, 0), CFrame.new(0, 0.07, 0.16))
end

local function buildHead(model: Model, neck: BasePart)
	local head = makePart("Head", Vector3.new(1.0, 1.15, 1.0), SKIN)
	head.Parent = model
	joint("Neck", neck, head, CFrame.new(0, 0.2, 0), CFrame.new(0, -0.55, 0.05))
	decor(head, "Skull", Vector3.new(1.08, 1.08, 1.08), SKIN, CFrame.new(0, 0.12, 0.05), Enum.PartType.Ball)

	-- The face, mostly hidden: one eye, a sunken socket, and a wide black mouth.
	decor(head, "Socket", Vector3.new(0.3, 0.3, 0.3), BLACK, CFrame.new(0.2, 0.12, -0.42), Enum.PartType.Ball)
	decor(head, "Eye", Vector3.new(0.13, 0.13, 0.13), EYE, CFrame.new(0.2, 0.12, -0.55), Enum.PartType.Ball, Enum.Material.Neon)
	decor(head, "Pupil", Vector3.new(0.04, 0.04, 0.04), BLACK, CFrame.new(0.2, 0.12, -0.615), Enum.PartType.Ball)
	decor(head, "SocketL", Vector3.new(0.28, 0.28, 0.28), BLACK, CFrame.new(-0.2, 0.1, -0.42), Enum.PartType.Ball)
	decor(head, "Mouth", Vector3.new(0.62, 0.2, 0.15), BLACK, CFrame.new(0, -0.28, -0.44))
	decor(head, "MouthTearL", Vector3.new(0.2, 0.05, 0.1), BLACK, CFrame.new(-0.36, -0.22, -0.4) * deg(0, 15, 25))
	decor(head, "MouthTearR", Vector3.new(0.2, 0.05, 0.1), BLACK, CFrame.new(0.36, -0.22, -0.4) * deg(0, -15, -25))
	decor(head, "BloodTrail", Vector3.new(0.06, 0.4, 0.05), BLOOD, CFrame.new(0.12, -0.5, -0.46))
	local glow = Instance.new("PointLight")
	glow.Name = "EyeGlow"
	glow.Color = Color3.fromRGB(230, 235, 255)
	glow.Range = 4
	glow.Brightness = 0.5
	glow.Shadows = false
	glow.Parent = head

	-- Long black hair: a curtain over the face (with a gap for the eye) and a mass down the back.
	local rng = Random.new(31)
	for i = 0, 13 do
		local x = -0.5 + i * (1 / 13)
		local front = math.abs(x - 0.2) > 0.12 -- leave a gap over the right eye
		local length = rng:NextNumber(1.6, 2.4)
		if front then
			decor(
				head,
				"HairFront" .. i,
				Vector3.new(0.09, length, 0.05),
				HAIR,
				CFrame.new(x, 0.55 - length / 2, -0.56 - math.abs(x) * 0.08) * deg(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)),
				nil,
				Enum.Material.Fabric
			)
		end
	end
	for i = 0, 11 do
		local angle = (i / 11) * math.pi - math.pi / 2
		local length = rng:NextNumber(2.4, 3.2)
		decor(
			head,
			"HairBack" .. i,
			Vector3.new(0.16, length, 0.08),
			HAIR,
			CFrame.new(math.sin(angle) * 0.55, 0.5 - length / 2, math.cos(angle) * 0.5 + 0.05) * CFrame.Angles(0, angle, 0) * deg(rng:NextNumber(4, 10), 0, 0),
			nil,
			Enum.Material.Fabric
		)
	end
	decor(head, "HairTop", Vector3.new(1.14, 0.5, 1.12), HAIR, CFrame.new(0, 0.5, 0.06), nil, Enum.Material.Fabric)

	local jaw = makePart("Jaw", Vector3.new(0.7, 0.18, 0.6), SKIN)
	jaw.Parent = model
	joint("Jaw", head, jaw, CFrame.new(0, -0.42, 0.2), CFrame.new(0, 0.05, 0.3))
	decor(jaw, "Inside", Vector3.new(0.55, 0.06, 0.4), BLACK, CFrame.new(0, 0.09, -0.08))
	return head
end

function GirlRig.Build(): Model
	local model = Instance.new("Model")
	model.Name = "Girl"

	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), SKIN)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.CanQuery = false
	root.CFrame = CFrame.new(0, GirlRig.RootHeight, 0)
	root.Parent = model
	model.PrimaryPart = root

	local pelvis = makePart("LowerTorso", Vector3.new(0.95, 0.5, 0.55), GOWN, Enum.Material.Fabric)
	pelvis.Parent = model
	joint("Root", root, pelvis, CFrame.new(), CFrame.new())
	-- Nightgown skirt: overlapping panels hanging to the shins, ragged at the hem.
	local rng = Random.new(12)
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		local length = rng:NextNumber(1.9, 2.4)
		local color = rng:NextNumber() < 0.35 and GOWN_DIRT or GOWN
		decor(
			pelvis,
			"Skirt" .. i,
			Vector3.new(0.42, length, 0.05),
			color,
			CFrame.new(math.sin(angle) * 0.5, 0.15 - length / 2, math.cos(angle) * 0.36) * CFrame.Angles(0, angle, 0) * deg(-7, 0, 0),
			nil,
			Enum.Material.Fabric
		)
	end
	decor(pelvis, "Stain", Vector3.new(0.4, 0.5, 0.06), BLOOD, CFrame.new(0.15, -0.6, -0.4) * deg(-7, 0, 10))

	local torso = makePart("UpperTorso", Vector3.new(1.05, 1.6, 0.55), GOWN, Enum.Material.Fabric)
	torso.Parent = model
	joint("Waist", pelvis, torso, CFrame.new(0, 0.25, 0), CFrame.new(0, -0.8, 0))
	decor(torso, "Collar", Vector3.new(0.7, 0.12, 0.6), SKIN, CFrame.new(0, 0.78, -0.02))
	decor(torso, "Dirt", Vector3.new(0.5, 0.7, 0.06), GOWN_DIRT, CFrame.new(-0.2, -0.2, -0.28) * deg(0, 0, 15))
	decor(torso, "Blood", Vector3.new(0.3, 0.45, 0.06), BLOOD, CFrame.new(0.2, 0.25, -0.29) * deg(0, 0, -10))

	local neck = makePart("NeckSeg", Vector3.new(0.24, 0.45, 0.24), SKIN)
	neck.Parent = model
	joint("NeckBase", torso, neck, CFrame.new(0, 0.8, 0), CFrame.new(0, -0.2, 0))

	buildHead(model, neck)
	buildArm(model, torso, -1)
	buildArm(model, torso, 1)
	buildLeg(model, pelvis, -1)
	buildLeg(model, pelvis, 1)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = GirlRig.HipHeight
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.AutomaticScalingEnabled = false
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.WalkSpeed = 0
	humanoid.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
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

	model:SetAttribute("AnimState", "Stand")
	model:SetAttribute("LookTarget", Vector3.zero)
	return model
end

-- Anchors / de-collides every part (for display copies: menu figure, jumpscares).
function GirlRig.MakeStatic(model: Model)
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

return GirlRig
