--[[
	Procedural player animation layers, applied on top of the default R15 locomotion
	(walk/run come from the Animate script - see AnimationIds.Player).

	Runs on every client for every character, driven by replicated character
	attributes, so other players see your crouch / fear / interactions too:
	  Crouching   legs folded, torso low
	  Sprinting   forward lean, pumping arms
	  Afraid      flinch, arms raised to the face, trembling
	  Action      "Interact" | "Door" | "Pickup" (+ ActionTime) one-shot gestures
	Also gives other players a visible flashlight beam.

	Any AnimationIds.Player.<State> that is set is played as a track instead of the
	procedural layer.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AnimationIds = require(Shared.AnimationIds)

local PlayerAnimator = {}

local rad = math.rad
local function R(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

type Rig = {
	Character: Model,
	Motors: { [string]: Motor6D },
	LastWritten: { [Motor6D]: CFrame },
	LastBase: { [Motor6D]: CFrame },
	Weights: { [string]: number },
	Tracks: { [string]: AnimationTrack },
	Beam: SpotLight?,
}

local rigs: { [Model]: Rig } = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function track(rig: Rig, state: string): AnimationTrack?
	local id = AnimationIds.Player[state]
	if not id or id == "" then
		return nil
	end
	if rig.Tracks[state] then
		return rig.Tracks[state]
	end
	local humanoid = rig.Character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, loaded = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok then
		rig.Tracks[state] = loaded
		return loaded
	end
	return nil
end

local function addRig(character: Model)
	if rigs[character] then
		return
	end
	local motors = {}
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	if not motors.Root or not motors.Waist then
		return -- not R15
	end
	rigs[character] = {
		Character = character,
		Motors = motors,
		LastWritten = {},
		LastBase = {},
		Weights = { Crouch = 0, Sprint = 0, Fear = 0, Action = 0 },
		Tracks = {},
	}
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			local rig = rigs[character]
			if rig and rig.Beam then
				rig.Beam:Destroy()
			end
			rigs[character] = nil
		end
	end)
end

-- Builds additive offsets per joint.
local function layers(rig: Rig, t: number): { [string]: CFrame }
	local w = rig.Weights
	local out: { [string]: CFrame } = {}
	local function add(name: string, cf: CFrame)
		out[name] = (out[name] or CFrame.identity) * cf
	end

	-- Crouch
	local c = w.Crouch
	if c > 0.01 then
		add("Root", CFrame.new(0, -1.05 * c, 0.15 * c) * R(-12 * c, 0, 0))
		add("Waist", R(-14 * c, 0, 0))
		add("Neck", R(18 * c, 0, 0))
		add("LeftHip", R(62 * c, 0, 0))
		add("RightHip", R(62 * c, 0, 0))
		add("LeftKnee", R(-92 * c, 0, 0))
		add("RightKnee", R(-92 * c, 0, 0))
		add("LeftAnkle", R(30 * c, 0, 0))
		add("RightAnkle", R(30 * c, 0, 0))
		add("LeftShoulder", R(18 * c, 0, 0))
		add("RightShoulder", R(18 * c, 0, 0))
	end
	-- Sprint lean
	local s = w.Sprint
	if s > 0.01 then
		add("Root", R(-8 * s, 0, 0))
		add("Neck", R(6 * s, 0, 0))
		add("LeftElbow", R(25 * s, 0, 0))
		add("RightElbow", R(25 * s, 0, 0))
	end
	-- Fear: flinch, arms up to protect the face, trembling
	local f = w.Fear
	if f > 0.01 then
		local tremble = math.noise(t * 22, 1) * 4 * f
		add("Waist", R(10 * f + tremble, 0, 0))
		add("Neck", R(-10 * f, tremble * 2, 0))
		add("LeftShoulder", R(110 * f, 0, 20 * f))
		add("RightShoulder", R(110 * f, 0, -20 * f))
		add("LeftElbow", R(95 * f + tremble, 0, 0))
		add("RightElbow", R(95 * f - tremble, 0, 0))
		add("LeftHip", R(8 * f, 0, 0))
		add("RightHip", R(8 * f, 0, 0))
		add("LeftKnee", R(-15 * f, 0, 0))
		add("RightKnee", R(-15 * f, 0, 0))
	end
	-- One-shot actions
	local a = w.Action
	if a > 0.01 then
		local action = rig.Character:GetAttribute("Action")
		if action == "Door" then
			add("RightShoulder", R(85 * a, 0, -10 * a))
			add("RightElbow", R(10 * a, 0, 0))
			add("Waist", R(-8 * a, 12 * a, 0))
		elseif action == "Pickup" then
			add("Waist", R(-38 * a, 0, 0))
			add("Neck", R(-20 * a, 0, 0))
			add("RightShoulder", R(55 * a, 0, 0))
			add("LeftHip", R(25 * a, 0, 0))
			add("RightHip", R(25 * a, 0, 0))
			add("LeftKnee", R(-40 * a, 0, 0))
			add("RightKnee", R(-40 * a, 0, 0))
		else -- Interact
			add("RightShoulder", R(70 * a, 0, 0))
			add("RightElbow", R(30 * a, 0, 0))
			add("Neck", R(-10 * a, 0, 0))
		end
	end
	return out
end

local function step(dt: number)
	local now = Workspace:GetServerTimeNow()
	local t = os.clock()
	local localCharacter = Players.LocalPlayer.Character
	for character, rig in rigs do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root then
			continue
		end
		local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local actionAge = now - (character:GetAttribute("ActionTime") or 0)
		local targets = {
			Crouch = character:GetAttribute("Crouching") and 1 or 0,
			Sprint = (character:GetAttribute("Sprinting") and speed > 13) and 1 or 0,
			Fear = character:GetAttribute("Afraid") and 1 or 0,
			Action = actionAge < 0.55 and math.sin(math.clamp(actionAge / 0.55, 0, 1) * math.pi) or 0,
		}
		local stateTrack = {
			Crouch = "Crouch",
			Fear = "Fear",
		}
		for key, target in targets do
			local rate = key == "Action" and 30 or 8
			rig.Weights[key] = lerp(rig.Weights[key], target, 1 - math.exp(-rate * dt))
			local trackName = stateTrack[key]
			if trackName then
				local animTrack = track(rig, trackName)
				if animTrack then
					if target > 0.5 and not animTrack.IsPlaying then
						animTrack:Play(0.2)
					elseif target <= 0.5 and animTrack.IsPlaying then
						animTrack:Stop(0.2)
					end
					rig.Weights[key] = 0
				end
			end
		end
		local action = character:GetAttribute("Action")
		local actionTrackName = action == "Door" and "OpenDoor" or (action == "Pickup" and "Pickup" or "Interact")
		local actionTrack = track(rig, actionTrackName)
		if actionTrack then
			if actionAge < 0.1 and not actionTrack.IsPlaying then
				actionTrack:Play(0.1)
			end
			rig.Weights.Action = 0
		end

		local offsets = layers(rig, t)
		for name, motor in rig.Motors do
			local offset = offsets[name]
			local current = motor.Transform
			-- If the Animator didn't rewrite this joint since our last frame, reuse the
			-- clean base so offsets don't accumulate.
			local base = current
			if rig.LastWritten[motor] and current == rig.LastWritten[motor] then
				base = rig.LastBase[motor]
			end
			rig.LastBase[motor] = base
			local final = offset and base * offset or base
			motor.Transform = final
			rig.LastWritten[motor] = final
		end

		-- Other players' flashlights.
		if character ~= localCharacter then
			local on = character:GetAttribute("Flashlight") == true
			local head = character:FindFirstChild("Head")
			if on and head and not rig.Beam then
				local beam = Instance.new("SpotLight")
				beam.Angle = 50
				beam.Range = 40
				beam.Brightness = 2
				beam.Color = Color3.fromRGB(255, 244, 222)
				beam.Shadows = false
				beam.Face = Enum.NormalId.Front
				beam.Parent = head
				rig.Beam = beam
			elseif not on and rig.Beam then
				rig.Beam:Destroy()
				rig.Beam = nil
			end
		end
	end
end

function PlayerAnimator.Init()
	local function watch(player: Player)
		if player.Character then
			task.defer(addRig, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Humanoid", 10)
			task.wait(0.2)
			addRig(character)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	RunService.Stepped:Connect(function(_, dt)
		step(dt)
	end)
end

return PlayerAnimator
