--!strict
-- Central tuning table. Everything that affects pacing/feel lives here so the
-- game can be balanced without touching logic code.

local Config = {}

Config.GameTitle = "HOLLOWMERE"
Config.Subtitle = "DON'T LOOK AWAY"
Config.MonsterName = "The Girl in White"
Config.Version = "2.0.0"

Config.Player = {
	WalkSpeed = 11,
	SprintSpeed = 18,
	CrouchSpeed = 6,
	StaminaMax = 100,
	StaminaDrain = 16, -- per second while sprinting
	StaminaRegen = 15,
	StaminaRegenDelay = 1.1,
	ExhaustedThreshold = 25, -- must regenerate past this after running dry
	CrouchCameraOffset = -1.7,
	FlashlightRange = 55,
	FlashlightBrightness = 2.6,
}

-- The Girl in White: she only moves while nobody is looking at her.
Config.Girl = {
	Speed = 17, -- studs/s while unobserved (player walk 11 / sprint 18)
	CatchDistance = 3.6,
	SightRange = 250, -- a player farther than this can't "hold" her with their gaze
	-- She is frozen whenever she is anywhere in the front half of your view (even
	-- behind a wall). She only moves once she is BEHIND you. Value is the cosine of the
	-- angle between where you look and where she is: 0 = exactly 90 degrees to the
	-- side; -0.15 adds a small safety margin (~99 degrees).
	ViewDot = -0.15,
	ActivateDelay = 14, -- seconds after the flashlight scare before she starts hunting
	MinSpawnDistance = 45,
	RespawnDelay = 6, -- after she catches someone
}

Config.Timing = {
	IntroBlackout = 10, -- seconds after first spawn before the lights die
	TurnScareTimeout = 14, -- if you never turn around, she comes anyway
	FinalTurnTimeout = 8,
}

Config.Lighting = {
	-- "Not too dark": a dim base level so rooms read even without the flashlight.
	Ambient = Color3.fromRGB(30, 30, 38),
	OutdoorAmbient = Color3.fromRGB(40, 44, 58),
	LowPowerLevel = 0.3, -- room lights after the blackout run at this fraction
}

Config.Camera = {
	BaseFOV = 70,
	MaxShake = 1,
	BobAmount = 0.12,
}

Config.Audio = {
	AmbientMinGap = 10,
	AmbientMaxGap = 26,
}

return Config
