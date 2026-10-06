--[[
	ANIMATION IDS
	=============
	All animations ship as *procedural* animations (GirlPoses.lua and client
	PlayerAnimator.lua) that drive Motor6D.Transform every frame, so they work with no
	uploaded assets.

	If you author keyframe animations (Moon Animator / Roblox Animation Editor) you can
	plug them in here. A non-empty id REPLACES the procedural version for that state.

	Girl animations must be authored on the rig from GirlRig.Build():
	  require(game.ReplicatedStorage.Shared.GirlRig).Build().Parent = workspace
	Joint names: Root, Waist, NeckBase, Neck, Jaw,
	  LeftShoulder, LeftElbow, LeftWrist, RightShoulder, RightElbow, RightWrist,
	  LeftHip, LeftKnee, LeftAnkle, RightHip, RightKnee, RightAnkle
]]

local AnimationIds = {
	Girl = {
		Stand = "", -- head lolled, arms limp, faint sway
		Run = "", -- stop-motion lurching run, arms reaching forward
		Crouch = "", -- coiled before the leap
		Leap = "", -- the jumpscare leap: arms flung wide, mouth torn open
		Scream = "",
		-- "Frozen" is not an animation: she simply stops wherever she is.
	},

	-- Player walk/run use Roblox's stock R15 animations. Replace to restyle locomotion.
	-- The remaining states are procedural layers applied on top of locomotion.
	Player = {
		Walk = "rbxassetid://507777826",
		Run = "rbxassetid://507767714",
		Crouch = "",
		Interact = "",
		OpenDoor = "",
		Pickup = "",
		Fear = "",
	},
}

return AnimationIds
