--[[
	ANIMATION IDS
	=============
	All monster and player animations ship as *procedural* animations (see
	MonsterPoses.lua / client PlayerAnimator.lua). They drive Motor6D.Transform every
	frame, so they work without any uploaded assets.

	If you author keyframe animations (Moon Animator / Roblox Animation Editor) you can
	plug them in here. A non-empty id REPLACES the procedural version for that state:
	the animator loads it as an AnimationTrack and stops writing procedural transforms
	while it plays.

	Monster animations must be authored on the rig produced by MonsterRig.Build()
	(run `require(game.ReplicatedStorage.Shared.MonsterRig).Build().Parent = workspace`
	in the Studio command bar to get an editable copy). Joint names:
	  Root, Waist, NeckBase, Neck, Jaw,
	  LeftShoulder, LeftElbow, LeftWrist, RightShoulder, RightElbow, RightWrist,
	  LeftHip, LeftKnee, LeftAnkle, RightHip, RightKnee, RightAnkle
]]

local AnimationIds = {
	Monster = {
		Idle = "", -- hunched, twitching, slow breathing
		Breathing = "", -- staring, heavy chest heave (used while stalking)
		LookAround = "", -- head jerks between random directions
		Search = "", -- slow walk + scanning head
		SlowWalk = "", -- stalking walk, head locked on target
		Walk = "", -- patrol walk with a limp
		Sprint = "", -- fast run
		AggressiveSprint = "", -- final chase: arms swept back, head tilted, jaw open
		HeadTurn = "", -- body frozen, head slowly rotates (up to 175 degrees) toward the player
		Scream = "", -- arms flung wide, head thrown back
		Attack = "", -- wind-up and downward strike
		Grab = "", -- arms reach forward and clamp
		Jumpscare = "", -- face-to-camera lunge with violent shaking
		Stagger = "", -- recoil after smashing a door / death stagger
		DoorOpen = "", -- reaches out and pushes a door
		DoorSlam = "", -- pounds on the safe-room door
	},

	-- Player walk/run use Roblox's default R15 animations (these are the stock ids that
	-- the default Animate script uses). Replace them to restyle locomotion.
	-- The remaining states are procedural layers applied on top of locomotion.
	Player = {
		Walk = "rbxassetid://507777826",
		Run = "rbxassetid://507767714",
		Crouch = "", -- procedural if empty
		Interact = "",
		OpenDoor = "",
		Pickup = "",
		Fear = "",
	},
}

return AnimationIds
