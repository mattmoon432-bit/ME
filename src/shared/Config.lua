--!strict
-- Central tuning table. Everything that affects pacing/feel lives here so the
-- game can be balanced without touching logic code.

local Config = {}

Config.GameTitle = "HOLLOWMERE"
Config.Subtitle = "SUBJECT 09"
Config.MonsterName = "The Grinner"
Config.Version = "1.0.0"

Config.Player = {
	WalkSpeed = 11,
	SprintSpeed = 18,
	CrouchSpeed = 6,
	ChaseBoost = 3, -- added to every speed while being chased
	StaminaMax = 100,
	StaminaDrain = 20, -- per second while sprinting
	StaminaDrainChase = 9, -- adrenaline: drains slower during a chase
	StaminaRegen = 15,
	StaminaRegenDelay = 1.1,
	ExhaustedThreshold = 25, -- must regenerate past this after running dry
	CrouchCameraOffset = -1.7,
	FlashlightRange = 46,
	FlashlightBrightness = 2.4,
}

Config.Monster = {
	PatrolSpeed = 8,
	InvestigateSpeed = 12,
	SearchSpeed = 6,
	StalkSpeed = 4,

	-- Normal (stage 4) chases: escapable by reaching the safe room or breaking line of sight.
	ChaseBaseSpeed = 20,
	ChaseRamp = 0.45, -- studs/s gained per second of chase
	ChaseMaxSpeed = 27,
	BurstSpeed = 34, -- the "launch" after the scream, and catch-up speed when far away
	BurstTime = 1.6,

	-- Final chase ("RUN."): never loses track, rubber-bands to stay on the player's heels.
	FinalBaseSpeed = 25,
	FinalMaxSpeed = 31,
	FinalBurstSpeed = 38,
	HeelDistance = 9, -- inside this range the monster matches (slightly under) the player's speed...
	HeelSlowThreshold = 14, -- ...unless the player drops under this speed, then it lunges.

	CatchDistance = 4.6,
	SightRange = 72,
	FieldOfView = 125,
	InstantDetectDistance = 9,
	SuspicionRate = 1.35,
	SuspicionDecay = 0.35,
	LoseTrackTime = 5,
	HearingMultiplier = 1,

	-- Detection sequence: HEAD TURN -> SILENCE -> SCREAM -> CHASE
	HeadTurnTime = 1.5,
	SilenceTime = 0.75,
	ScreamTime = 1.05,

	SearchTime = 7,
	StalkMinInterval = 30,
	StalkMaxInterval = 55,
	StalkMaxDuration = 14,
	RespawnAfterVanish = 18,
	DoorSmashStagger = 0.45,
	SlamDuration = 2.6,
}

Config.Noise = {
	Sprint = 42,
	Walk = 12,
	Door = 40,
	Objective = 70,
	Interact = 25,
	Scream = 0,
}

Config.Camera = {
	BaseFOV = 70,
	ChaseFOV = 82,
	MaxShake = 1,
	BobAmount = 0.12,
}

Config.Audio = {
	AmbientMinGap = 9,
	AmbientMaxGap = 24,
}

return Config
