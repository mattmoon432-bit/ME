--[[
	SOUND DEFINITIONS
	=================
	Every sound in the game is declared here, grouped by the folder it lives in under
	SoundService (Ambient / Music / Monster / Player / UI / Jumpscare).

	  id        -> PUT YOUR OWN AUDIO ASSET HERE ("rbxassetid://123456").
	               Leave "" to use the fallback.
	  fallback  -> A sound that ships with every Roblox client (rbxasset://sounds/...).
	               These are reshaped with pitch + effects so the game is playable and
	               atmospheric out of the box, but real horror assets will sound far better.
	  volume, pitch, looped
	  min/max   -> 3D roll-off distances (only used when the sound is parented to a part)
	  effects   -> { ClassName = { Property = value } } SoundEffects created as children

	Recommended replacements are described in README.md ("Audio").
]]

export type SoundDef = {
	id: string,
	fallback: string?,
	volume: number?,
	pitch: number?,
	looped: boolean?,
	min: number?,
	max: number?,
	effects: { [string]: { [string]: any } }?,
}

local BUILTIN = {
	Falling = "rbxasset://sounds/action_falling.mp3", -- airy whoosh loop: pitched down = drones/breath
	Footsteps = "rbxasset://sounds/action_footsteps_plastic.mp3",
	JumpLand = "rbxasset://sounds/action_jump_land.mp3", -- dull thud: heartbeats, heavy steps
	GetUp = "rbxasset://sounds/action_get_up.mp3", -- rustle: pitched down = creaks
	Swim = "rbxasset://sounds/action_swim.mp3",
	Water = "rbxasset://sounds/impact_water.mp3",
	Uuhhh = "rbxasset://sounds/uuhhh.mp3", -- vocal: pitched down + distorted = screams
	Ping = "rbxasset://sounds/electronicpingshort.wav",
	Swoosh = "rbxasset://sounds/swoosh.wav",
	Button = "rbxasset://sounds/button.wav",
	Click = "rbxasset://sounds/clickfast.wav",
	Hit = "rbxasset://sounds/hit.wav",
}

local REVERB_BIG = { ReverbSoundEffect = { DecayTime = 4.5, Density = 1, Diffusion = 1, DryLevel = -2, WetLevel = -4 } }

local Sounds: { [string]: { [string]: SoundDef } } = {
	Ambient = {
		Drone = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 0.55,
			pitch = 0.16,
			looped = true,
			effects = {
				EqualizerSoundEffect = { LowGain = 8, MidGain = -4, HighGain = -30 },
				ReverbSoundEffect = { DecayTime = 6, WetLevel = 0, DryLevel = -6 },
			},
		},
		Wind = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 0.18,
			pitch = 0.45,
			looped = true,
			effects = { EqualizerSoundEffect = { LowGain = 2, MidGain = -6, HighGain = -18 } },
		},
		Rain = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 0.12,
			pitch = 1.6,
			looped = true,
			min = 8,
			max = 60,
			effects = { EqualizerSoundEffect = { LowGain = -20, MidGain = -3, HighGain = 2 } },
		},
		GeneratorHum = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 0.7,
			pitch = 0.09,
			looped = true,
			min = 6,
			max = 70,
			effects = { TremoloSoundEffect = { Depth = 0.35, Frequency = 12, Duty = 0.5 } },
		},
		LightBuzz = {
			id = "",
			fallback = BUILTIN.Ping,
			volume = 0.05,
			pitch = 0.22,
			looped = true,
			min = 3,
			max = 18,
		},
		DistantBang = {
			id = "",
			fallback = BUILTIN.Hit,
			volume = 0.6,
			pitch = 0.32,
			min = 20,
			max = 260,
			effects = REVERB_BIG,
		},
		MetalCreak = {
			id = "",
			fallback = BUILTIN.GetUp,
			volume = 0.7,
			pitch = 0.3,
			min = 15,
			max = 200,
			effects = REVERB_BIG,
		},
		Whisper = {
			id = "",
			fallback = BUILTIN.Swim,
			volume = 0.25,
			pitch = 1.9,
			min = 6,
			max = 80,
			effects = { ReverbSoundEffect = { DecayTime = 3, WetLevel = 0, DryLevel = -10 } },
		},
		FootstepsAbove = {
			id = "",
			fallback = BUILTIN.Footsteps,
			volume = 0.45,
			pitch = 0.55,
			min = 20,
			max = 200,
			effects = { EqualizerSoundEffect = { LowGain = 6, MidGain = -6, HighGain = -25 } },
		},
		Drip = {
			id = "",
			fallback = BUILTIN.Water,
			volume = 0.25,
			pitch = 2.2,
			min = 4,
			max = 50,
			effects = { ReverbSoundEffect = { DecayTime = 2.5, WetLevel = -2 } },
		},
		Thunder = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 1.2,
			pitch = 0.1,
			effects = {
				EqualizerSoundEffect = { LowGain = 10, MidGain = 0, HighGain = -30 },
				DistortionSoundEffect = { Level = 0.35 },
			},
		},
		PowerOn = {
			id = "",
			fallback = BUILTIN.Hit,
			volume = 1.4,
			pitch = 0.22,
			effects = REVERB_BIG,
		},
		Static = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 0.5,
			pitch = 3.2,
			looped = true,
			min = 4,
			max = 40,
			effects = { DistortionSoundEffect = { Level = 0.85 } },
		},
		PhoneRing = {
			id = "",
			fallback = BUILTIN.Ping,
			volume = 0.9,
			pitch = 0.75,
			looped = true,
			min = 8,
			max = 140,
			effects = { TremoloSoundEffect = { Depth = 1, Frequency = 22, Duty = 0.5 } },
		},
	},

	Music = {
		MenuTheme = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 0.6,
			pitch = 0.12,
			looped = true,
			effects = {
				ChorusSoundEffect = { Depth = 0.4, Mix = 0.6, Rate = 0.3 },
				ReverbSoundEffect = { DecayTime = 8, WetLevel = 0 },
				EqualizerSoundEffect = { LowGain = 6, MidGain = 0, HighGain = -24 },
			},
		},
		Tension = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 0.5,
			pitch = 0.27,
			looped = true,
			effects = {
				TremoloSoundEffect = { Depth = 0.6, Frequency = 4, Duty = 0.6 },
				EqualizerSoundEffect = { LowGain = 4, MidGain = 0, HighGain = -20 },
			},
		},
		ChaseLoop = {
			id = "",
			fallback = BUILTIN.Footsteps,
			volume = 0.9,
			pitch = 0.42,
			looped = true,
			effects = {
				DistortionSoundEffect = { Level = 0.55 },
				EqualizerSoundEffect = { LowGain = 9, MidGain = 2, HighGain = -10 },
			},
		},
		ChaseDrone = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 0.7,
			pitch = 0.33,
			looped = true,
			effects = {
				TremoloSoundEffect = { Depth = 0.8, Frequency = 9, Duty = 0.4 },
				DistortionSoundEffect = { Level = 0.4 },
			},
		},
		Stinger = {
			id = "",
			fallback = BUILTIN.Hit,
			volume = 1.6,
			pitch = 0.2,
			effects = {
				DistortionSoundEffect = { Level = 0.7 },
				ReverbSoundEffect = { DecayTime = 6, WetLevel = 0 },
			},
		},
		Victory = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 0.4,
			pitch = 0.6,
			looped = true,
			effects = { ChorusSoundEffect = { Depth = 0.5, Mix = 0.7, Rate = 0.2 } },
		},
	},

	Monster = {
		Footstep = {
			id = "",
			fallback = BUILTIN.JumpLand,
			volume = 1.4,
			pitch = 0.5,
			min = 6,
			max = 140,
			effects = { EqualizerSoundEffect = { LowGain = 8, MidGain = 0, HighGain = -8 } },
		},
		Breath = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 0.9,
			pitch = 0.32,
			looped = true,
			min = 4,
			max = 45,
			effects = { TremoloSoundEffect = { Depth = 0.9, Frequency = 1.4, Duty = 0.55 } },
		},
		Scream = {
			id = "",
			fallback = BUILTIN.Uuhhh,
			volume = 3,
			pitch = 0.42,
			min = 30,
			max = 400,
			effects = {
				DistortionSoundEffect = { Level = 0.8 },
				PitchShiftSoundEffect = { Octave = 0.85 },
				ReverbSoundEffect = { DecayTime = 3.5, WetLevel = -2 },
			},
		},
		Growl = {
			id = "",
			fallback = BUILTIN.Uuhhh,
			volume = 1.6,
			pitch = 0.24,
			min = 8,
			max = 90,
			effects = { DistortionSoundEffect = { Level = 0.6 } },
		},
		Chatter = {
			id = "",
			fallback = BUILTIN.Click,
			volume = 0.8,
			pitch = 0.55,
			min = 5,
			max = 50,
		},
		Slam = {
			id = "",
			fallback = BUILTIN.Hit,
			volume = 2.6,
			pitch = 0.36,
			min = 15,
			max = 260,
			effects = {
				EqualizerSoundEffect = { LowGain = 10, MidGain = 2, HighGain = -6 },
				ReverbSoundEffect = { DecayTime = 2.5, WetLevel = -3 },
			},
		},
		DoorSmash = {
			id = "",
			fallback = BUILTIN.Hit,
			volume = 2.4,
			pitch = 0.55,
			min = 12,
			max = 220,
			effects = { DistortionSoundEffect = { Level = 0.4 }, ReverbSoundEffect = { DecayTime = 2, WetLevel = -4 } },
		},
	},

	Player = {
		Heartbeat = {
			id = "",
			fallback = BUILTIN.JumpLand,
			volume = 1.1,
			pitch = 0.38,
			effects = { EqualizerSoundEffect = { LowGain = 10, MidGain = -8, HighGain = -40 } },
		},
		Breathing = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 0.55,
			pitch = 0.85,
			looped = true,
			effects = {
				TremoloSoundEffect = { Depth = 1, Frequency = 2.2, Duty = 0.5 },
				EqualizerSoundEffect = { LowGain = -8, MidGain = 2, HighGain = -6 },
			},
		},
		Gasp = {
			id = "",
			fallback = BUILTIN.Uuhhh,
			volume = 0.7,
			pitch = 1.45,
		},
		Pickup = { id = "", fallback = BUILTIN.Swoosh, volume = 0.6, pitch = 1.25 },
		Paper = { id = "", fallback = BUILTIN.Swoosh, volume = 0.5, pitch = 1.8 },
		Flashlight = { id = "", fallback = BUILTIN.Click, volume = 0.5, pitch = 1.3 },
		DoorOpen = {
			id = "",
			fallback = BUILTIN.GetUp,
			volume = 1,
			pitch = 0.42,
			min = 6,
			max = 90,
			effects = { ReverbSoundEffect = { DecayTime = 1.5, WetLevel = -6 } },
		},
		DoorClose = { id = "", fallback = BUILTIN.Hit, volume = 0.9, pitch = 0.75, min = 6, max = 90 },
		DoorLocked = { id = "", fallback = BUILTIN.Button, volume = 0.8, pitch = 0.5, min = 4, max = 40 },
		FuseInsert = { id = "", fallback = BUILTIN.Hit, volume = 1, pitch = 1.4, min = 5, max = 50 },
		Lever = { id = "", fallback = BUILTIN.Hit, volume = 1.2, pitch = 0.9, min = 5, max = 60 },
		KeyJingle = { id = "", fallback = BUILTIN.Click, volume = 0.8, pitch = 1.6 },
		Drawer = { id = "", fallback = BUILTIN.GetUp, volume = 0.7, pitch = 0.9, min = 4, max = 40 },
	},

	UI = {
		Hover = { id = "", fallback = BUILTIN.Button, volume = 0.18, pitch = 1.7 },
		Click = {
			id = "",
			fallback = BUILTIN.Button,
			volume = 0.5,
			pitch = 0.75,
			effects = { ReverbSoundEffect = { DecayTime = 1.2, WetLevel = -6 } },
		},
		Back = { id = "", fallback = BUILTIN.Button, volume = 0.4, pitch = 0.6 },
		Objective = {
			id = "",
			fallback = BUILTIN.Ping,
			volume = 0.45,
			pitch = 0.45,
			effects = { ReverbSoundEffect = { DecayTime = 3, WetLevel = 0 } },
		},
		Whoosh = { id = "", fallback = BUILTIN.Swoosh, volume = 0.5, pitch = 0.45 },
		Slider = { id = "", fallback = BUILTIN.Click, volume = 0.15, pitch = 1.5 },
	},

	Jumpscare = {
		Scream = {
			id = "",
			fallback = BUILTIN.Uuhhh,
			volume = 4,
			pitch = 0.55,
			effects = {
				DistortionSoundEffect = { Level = 0.95 },
				PitchShiftSoundEffect = { Octave = 0.8 },
				EqualizerSoundEffect = { LowGain = 6, MidGain = 6, HighGain = 4 },
			},
		},
		Impact = {
			id = "",
			fallback = BUILTIN.Hit,
			volume = 3,
			pitch = 0.28,
			effects = { DistortionSoundEffect = { Level = 0.9 }, EqualizerSoundEffect = { LowGain = 10, MidGain = 0, HighGain = 0 } },
		},
		Static = {
			id = "",
			fallback = BUILTIN.Falling,
			volume = 1.6,
			pitch = 3.5,
			looped = true,
			effects = { DistortionSoundEffect = { Level = 1 } },
		},
		Sting = {
			id = "",
			fallback = BUILTIN.Ping,
			volume = 2,
			pitch = 0.32,
			effects = { DistortionSoundEffect = { Level = 0.9 } },
		},
		Thud = {
			id = "",
			fallback = BUILTIN.JumpLand,
			volume = 2,
			pitch = 0.3,
			effects = { EqualizerSoundEffect = { LowGain = 10, MidGain = -6, HighGain = -30 } },
		},
	},
}

return Sounds
