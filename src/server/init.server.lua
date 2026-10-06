--[[
	HOLLOWMERE - server entry point.
	Builds the world, then wires objectives, the monster AI, chases and players together.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local SoundLibrary = require(Shared.SoundLibrary)

local ChaseDirector = require(script.ChaseDirector)
local Decorator = require(script.Decorator)
local Doors = require(script.Doors)
local Interactions = require(script.Interactions)
local MapBuilder = require(script.MapBuilder)
local MonsterAI = require(script.MonsterAI)
local Noise = require(script.Noise)
local Objectives = require(script.Objectives)
local PlayerService = require(script.PlayerService)

---------------------------------------------------------------------------------------------
-- Lighting baseline (clients layer their own chase/jumpscare effects on top)
---------------------------------------------------------------------------------------------
local function setupLighting()
	-- (Lighting.Technology = Future is set in default.project.json; it is not scriptable.)
	Lighting.ClockTime = 0.5
	Lighting.Brightness = 0.4
	Lighting.Ambient = Color3.fromRGB(5, 5, 8)
	Lighting.OutdoorAmbient = Color3.fromRGB(16, 18, 26)
	Lighting.EnvironmentDiffuseScale = 0.15
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 100000

	local cc = Lighting:FindFirstChild("BaseGrade") or Instance.new("ColorCorrectionEffect")
	cc.Name = "BaseGrade"
	;(cc :: ColorCorrectionEffect).Contrast = 0.12
	;(cc :: ColorCorrectionEffect).Saturation = -0.35
	;(cc :: ColorCorrectionEffect).TintColor = Color3.fromRGB(222, 228, 240)
	;(cc :: ColorCorrectionEffect).Brightness = -0.02
	cc.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = 1500
	sky.MoonAngularSize = 14
	sky.SunAngularSize = 0
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting
end

setupLighting()
SoundLibrary.Init()

---------------------------------------------------------------------------------------------
-- World
---------------------------------------------------------------------------------------------
local map = MapBuilder.Build()
Decorator.Decorate(map)
ChaseDirector.Init(map)
Objectives.Init()
Doors.StartAutoOpen()
Noise.StartMovementNoise()
PlayerService.Init(map)

-- Door sounds draw the monster in.
Doors.Opened:Connect(function(door, player)
	if player then
		Noise.Emit(door.Position, 40, player, "Door")
	end
end)

---------------------------------------------------------------------------------------------
-- Monster
---------------------------------------------------------------------------------------------
local monster = MonsterAI.new(map, {
	Kill = PlayerService.Kill,
	IsInSafeZone = ChaseDirector.IsInSafeZone,
	SealSafeRoom = ChaseDirector.SealSafeRoom,
	ReleaseSafeRoom = ChaseDirector.ReleaseSafeRoom,
	GetLook = PlayerService.GetLook,
	IsPlaying = PlayerService.IsPlaying,
	OnChaseStart = ChaseDirector.OnChaseStart,
	OnChaseEnd = ChaseDirector.OnChaseEnd,
})

Interactions.Init(map, {
	Stalk = function(pointName: string?, player: Player, scripted: boolean?)
		-- Scripted glimpses wait (up to 20s) for a moment the point is actually usable.
		task.spawn(function()
			for _ = 1, 40 do
				if monster:Stalk(pointName, player, scripted) then
					return
				end
				task.wait(0.5)
			end
		end)
	end,
	MonsterScream = function(position: Vector3)
		SoundLibrary.Play("Monster", "Scream", position, { Volume = 0.8, Pitch = 0.85 })
	end,
})

---------------------------------------------------------------------------------------------
-- Progression
---------------------------------------------------------------------------------------------
Objectives.StageChanged:Connect(function(stage: number, _old: number, player: Player?)
	if stage == 4 then
		-- The lights die for a few seconds... and when they come back, it is loose.
		task.delay(2, function()
			Workspace:SetAttribute("Blackout", true)
			Remotes.Event("ScareEvent"):FireAllClients("Blackout")
			task.wait(2.8)
			Workspace:SetAttribute("Blackout", false)
			Remotes.Event("ShowMessage"):FireAllClients("Something is moving on this floor.", 3.5, "Thought")
			monster:SetEnabled(true)
		end)
	elseif stage == 5 then
		PlayerService.RetryChase = false
		local runner = player
		if not runner then
			runner = PlayerService.ActivePlayers()[1]
		end
		if runner then
			ChaseDirector.StartFinal(runner, monster)
		end
	elseif stage == 6 then
		Remotes.Event("ShowMessage"):FireAllClients("The tunnel. Don't stop.", 2.5, "Thought")
	elseif stage == 7 then
		Interactions.CloseGate()
		monster:SlamAtGate(map.ExitGateSlamPosition)
		ChaseDirector.EndFinal()
		PlayerService.MarkWon()
		Remotes.Event("GameWon"):FireAllClients(Objectives.Elapsed())
	end
end)

Objectives.Reset:Connect(function(stage: number)
	ChaseDirector.EndFinal()
	Workspace:SetAttribute("Blackout", false)
	if stage <= 1 then
		PlayerService.RetryChase = false
		Workspace:SetAttribute("Power", false)
	end
	monster:Reset(stage >= 4)
end)

-- Reaching the sub-level during the final chase advances to "Escape".
RunService.Heartbeat:Connect(function()
	if Objectives.Stage ~= 5 then
		return
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and root.Position.Y < -10 and not player:GetAttribute("Dead") then
			Objectives.Advance(5, player)
			return
		end
	end
end)

-- If everyone leaves to the menu mid-hunt, put the monster back to sleep.
task.spawn(function()
	while true do
		task.wait(5)
		if #PlayerService.ActivePlayers() == 0 and monster.State ~= "Dormant" and monster.State ~= "Hidden" then
			monster:Reset(Objectives.Stage >= 4)
		end
	end
end)

print("[Hollowmere] Server ready.")
