--[[
	HOLLOWMERE - client entry point.
	Initialises every client system and runs the game flow:

	  MAIN MENU -> PLAY -> lit office -> lights die -> grab the glowing flashlight
	  -> turn around: she LEAPS at you -> find the key -> storage -> exit key
	  -> the exit is a brick wall -> turn around... -> THE END
	  (caught by her at any point -> jumpscare -> RESTART / MAIN MENU)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local SoundLibrary = require(Shared.SoundLibrary)

local Audio = require(script.Audio)
local CameraFX = require(script.CameraFX)
local GirlVisuals = require(script.GirlVisuals)
local Jumpscare = require(script.Jumpscare)
local LightController = require(script.LightController)
local Lock = require(script.Lock)
local Movement = require(script.Movement)
local PlayerAnimator = require(script.PlayerAnimator)
local PostFX = require(script.PostFX)
local Settings = require(script.Settings)
local TensionFX = require(script.TensionFX)

local UI = script.UI
local DeathScreen = require(UI.DeathScreen)
local Fader = require(UI.Fader)
local HUD = require(UI.HUD)
local MainMenu = require(UI.MainMenu)
local NoteReader = require(UI.NoteReader)
local PromptUI = require(UI.PromptUI)
local WinScreen = require(UI.WinScreen)

local player = Players.LocalPlayer

---------------------------------------------------------------------------------------------
-- Core GUI: strip everything that breaks immersion.
---------------------------------------------------------------------------------------------
for _, coreType in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.EmotesMenu } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(coreType, false)
	end)
end
task.spawn(function()
	for _ = 1, 20 do
		if pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end) then
			break
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------------------------
Settings.Init()
Fader.Init()
Audio.Init()
PostFX.Init()
CameraFX.Init()
Workspace:WaitForChild("Map")
LightController.Init()
Movement.Init()
PlayerAnimator.Init()
GirlVisuals.Init()
TensionFX.Init()
HUD.Init()
PromptUI.Init()
NoteReader.Init()
DeathScreen.Init()
WinScreen.Init()
MainMenu.Init()

Audio.OnThunder = function()
	PostFX.Lightning()
end

---------------------------------------------------------------------------------------------
-- Flow
---------------------------------------------------------------------------------------------
local inGame = false
local playStart = os.clock()
local scriptedScare = false -- the turn-around scares own the screen while running

local function enterGameplay()
	local camera = Workspace.CurrentCamera
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 10)
	Lock.Clear()
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
	camera.FieldOfView = CameraFX.BaseFOV
	CameraFX.Enabled = true
	Movement.SetActive(true)
	if Workspace:GetAttribute("FlashlightTaken") then
		Movement.SetFlashlight(true)
	end
	TensionFX.Reset()
	TensionFX.Active = true
	HUD.SetVisible(true)
	Audio.InGame = true
	inGame = true
end

local function exitGameplay()
	inGame = false
	NoteReader.Close()
	HUD.ClearMessages()
	Lock.Clear()
	Movement.SetActive(false)
	TensionFX.Active = false
	TensionFX.Reset()
	HUD.SetVisible(false)
	Audio.InGame = false
	Audio.StopAllLoops(2)
	Audio.Duck(1, 20)
end

local function requestSpawn(remoteName: string): boolean
	local spawned = false
	local connection = Remotes.Event("Spawned").OnClientEvent:Connect(function()
		spawned = true
	end)
	Remotes.Event(remoteName):FireServer()
	local start = os.clock()
	while not spawned and os.clock() - start < 12 do
		task.wait(0.05)
	end
	connection:Disconnect()
	return spawned
end

local function startPlaying(remoteName: string)
	if not requestSpawn(remoteName) then
		warn("[Hollowmere] Spawn timed out")
	end
	enterGameplay()
	task.wait(0.3)
	local stage = Workspace:GetAttribute("Stage") or 0
	task.spawn(Fader.In, 2)
	if stage == 0 then
		playStart = os.clock()
		HUD.Chapter("HOLLOWMERE PSYCHIATRIC ANNEX", "NIGHT SHIFT   -   02:13 AM")
		HUD.ShowHints()
		task.delay(6.5, function()
			if inGame and (Workspace:GetAttribute("Stage") or 0) == 0 then
				HUD.Message("Another quiet night shift. Just finish the log and go home.", 2.6, "Thought")
			end
		end)
	elseif stage == 1 then
		task.delay(1, function()
			if inGame then
				HUD.Message("My flashlight... it's on the desk.", 2.5, "Thought")
			end
		end)
	end
end

local function toMenu()
	Fader.Out(0.9)
	DeathScreen.Hide()
	WinScreen.Hide()
	exitGameplay()
	Remotes.Event("RequestMenu"):FireServer()
	MainMenu.Show()
end

MainMenu.OnPlay = function()
	startPlaying("RequestPlay")
end
DeathScreen.OnRestart = function()
	Fader.Out(0.8)
	DeathScreen.Hide()
	startPlaying("RequestRestart")
end
DeathScreen.OnMenu = toMenu
WinScreen.OnPlayAgain = function()
	Fader.Out(1)
	WinScreen.Hide()
	exitGameplay()
	startPlaying("RequestRestart")
end
WinScreen.OnMenu = toMenu

-- Yields until the player has turned their view away from `direction` (flat), or
-- until `timeout` passes. Returns true if they turned.
local function waitForTurn(direction: Vector3, threshold: number, timeout: number): boolean
	local flatDir = (direction * Vector3.new(1, 0, 1)).Unit
	local start = os.clock()
	while os.clock() - start < timeout do
		local camera = Workspace.CurrentCamera
		local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.1 and look.Unit:Dot(flatDir) < threshold then
			return true
		end
		if not inGame then
			return false
		end
		RunService.RenderStepped:Wait()
	end
	return false
end

---------------------------------------------------------------------------------------------
-- Story events
---------------------------------------------------------------------------------------------
Remotes.Event("ScareEvent").OnClientEvent:Connect(function(name: string)
	if not inGame then
		return
	end
	if name == "Blackout" then
		task.wait(1.2)
		if inGame then
			HUD.Sequence({
				{ "Huh? What was that...?", 2.4, "Thought" },
				{ "The power's out. I need my flashlight - it's on the desk.", 3, "Thought" },
			})
		end
	end
end)

-- Flashlight picked up. She is now standing right behind you. Turn around.
Remotes.Event("TurnScare").OnClientEvent:Connect(function()
	if not inGame or scriptedScare then
		return
	end
	scriptedScare = true
	Movement.SetFlashlight(true)
	Audio.Play("Player", "Flashlight")
	local camera = Workspace.CurrentCamera
	waitForTurn(camera.CFrame.LookVector, -0.2, Config.Timing.TurnScareTimeout)
	if inGame then
		Jumpscare.Play({ Fatal = false })
		if inGame then
			HUD.Sequence({
				{ "W-WHAT WAS THAT?!", 2.2 },
				{ "I need to get out of here. There has to be a key somewhere.", 3, "Thought" },
			})
		end
	end
	scriptedScare = false
end)

-- The exit opens onto bricks. Then she's behind you.
Remotes.Event("FinalScare").OnClientEvent:Connect(function(doorCFrame: CFrame)
	if not inGame then
		return
	end
	scriptedScare = true
	NoteReader.Close()
	Lock.Push("Final", { Move = true, Camera = false })
	task.wait(0.8)
	HUD.Sequence({
		{ "...bricks?", 2 },
		{ "It's bricked up. It was never a way out.", 2.8, "Thought" },
	})
	-- Let them look around (but not walk). The moment they turn their back on the wall...
	local turned = waitForTurn(doorCFrame.LookVector, 0, Config.Timing.FinalTurnTimeout)
	if not inGame then
		return
	end
	local camera = Workspace.CurrentCamera
	if not turned then
		-- ...or something turns them.
		SoundLibrary.Play("Ambient", "Giggle", camera.CFrame.Position - camera.CFrame.LookVector * 4)
		task.wait(0.6)
		camera.CameraType = Enum.CameraType.Scriptable
		local from = camera.CFrame
		local to = from * CFrame.Angles(0, math.pi, 0)
		local start = os.clock()
		while os.clock() - start < 0.5 do
			camera.CFrame = from:Lerp(to, (os.clock() - start) / 0.5)
			RunService.RenderStepped:Wait()
		end
	end
	inGame = false
	HUD.SetVisible(false)
	TensionFX.Active = false
	Jumpscare.Play({ Fatal = true })
	Movement.SetActive(false)
	TensionFX.Reset()
	Audio.SetLoop("Ending", "Music", "Ending", 1, 1, 0.5)
	WinScreen.Show(os.clock() - playStart)
	Jumpscare.Release()
	Lock.Clear()
	scriptedScare = false
end)

---------------------------------------------------------------------------------------------
-- Server events
---------------------------------------------------------------------------------------------
Remotes.Event("ObjectiveUpdate").OnClientEvent:Connect(function(stage: number, text: string, isNew: boolean)
	HUD.SetObjective(stage, text, isNew and inGame)
end)

Remotes.Event("ShowMessage").OnClientEvent:Connect(function(text: string, duration: number?, style: string?)
	if inGame and not scriptedScare then
		HUD.Message(text, duration, style)
	end
end)

Remotes.Event("ShowNote").OnClientEvent:Connect(function(title: string, body: string)
	if inGame then
		NoteReader.Show(title, body)
	end
end)

-- She caught you.
Remotes.Event("Jumpscare").OnClientEvent:Connect(function(girlCFrame: CFrame)
	if not inGame then
		return
	end
	inGame = false
	NoteReader.Close()
	HUD.ClearMessages()
	TensionFX.Active = false
	HUD.SetVisible(false)
	Audio.InGame = false
	Jumpscare.Play({ From = girlCFrame, Fatal = true })
	Movement.SetActive(false)
	TensionFX.Reset()
	DeathScreen.Show()
	Jumpscare.Release()
end)

Remotes.Event("PlayerDied").OnClientEvent:Connect(function()
	if not inGame then
		return
	end
	inGame = false
	Fader.Out(0.6)
	exitGameplay()
	DeathScreen.Show("Something in the dark found you.")
	Fader.In(0.1)
end)

---------------------------------------------------------------------------------------------
MainMenu.Show()
