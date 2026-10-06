--[[
	HOLLOWMERE - server entry point.
	Builds the world, then wires the story beats, the Girl and the players together.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local SoundLibrary = require(Shared.SoundLibrary)

local Decorator = require(script.Decorator)
local GirlAI = require(script.GirlAI)
local Interactions = require(script.Interactions)
local MapBuilder = require(script.MapBuilder)
local Objectives = require(script.Objectives)
local PlayerService = require(script.PlayerService)

---------------------------------------------------------------------------------------------
-- Lighting: dark and moody, but readable (clients layer their own effects on top).
-- (Lighting.Technology = Future is set in default.project.json; it is not scriptable.)
---------------------------------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 0.5
	Lighting.Brightness = 0.6
	Lighting.Ambient = Config.Lighting.Ambient
	Lighting.OutdoorAmbient = Config.Lighting.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0.25
	Lighting.FogEnd = 100000

	local cc = Lighting:FindFirstChild("BaseGrade") or Instance.new("ColorCorrectionEffect")
	cc.Name = "BaseGrade"
	;(cc :: ColorCorrectionEffect).Contrast = 0.1
	;(cc :: ColorCorrectionEffect).Saturation = -0.3
	;(cc :: ColorCorrectionEffect).TintColor = Color3.fromRGB(226, 230, 240)
	cc.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = 1500
	sky.MoonAngularSize = 14
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
Objectives.Init()
PlayerService.Init(map)
Interactions.Init(map)

local girl = GirlAI.new(map, {
	Kill = PlayerService.Kill,
	GetLook = PlayerService.GetLook,
	IsPlaying = PlayerService.IsPlaying,
})

PlayerService.LookChanged:Connect(function()
	girl:OnLook()
end)

---------------------------------------------------------------------------------------------
-- Story beats
---------------------------------------------------------------------------------------------

-- 0 -> 1: a quiet minute in the lit office... then the lights die.
local function startIntro()
	if Objectives.State.IntroStarted then
		return
	end
	Objectives.State.IntroStarted = true
	task.delay(Config.Timing.IntroBlackout, function()
		if Objectives.Stage ~= 0 then
			return
		end
		Workspace:SetAttribute("Power", false)
		Workspace:SetAttribute("LowPower", true)
		Remotes.Event("ScareEvent"):FireAllClients("Blackout")
		task.wait(0.8)
		Interactions.StartFlashlightGlow()
		Objectives.Set(1)
	end)
end

PlayerService.Spawned:Connect(function()
	if Objectives.Stage == 0 then
		startIntro()
	end
end)

Objectives.StageChanged:Connect(function(stage: number)
	if stage == 2 then
		-- Right after the turn-around scare she begins hunting.
		girl:Reset(true, Config.Girl.ActivateDelay)
	elseif stage == 5 then
		-- The exit is bricked up. She stops hunting: the client plays the final scare.
		girl:Reset(false)
		PlayerService.MarkWon()
		local doorCFrame = map.FinalDoorCFrame or CFrame.new()
		Remotes.Event("FinalScare"):FireAllClients(doorCFrame)
	end
end)

Objectives.Reset:Connect(function()
	girl:Reset(false)
end)

-- Nobody playing? Put her back to sleep until someone returns.
task.spawn(function()
	while true do
		task.wait(5)
		if #PlayerService.ActivePlayers() == 0 and girl.Active and not girl.Hidden then
			girl:Reset(Objectives.Stage >= 2 and Objectives.Stage < 5, 8)
		end
	end
end)

print("[Hollowmere] Server ready.")
