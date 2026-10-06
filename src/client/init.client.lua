--[[
	HOLLOWMERE - client entry point.
	Initialises every client system and runs the game flow:
	  MAIN MENU -> (fade) -> PLAY -> gameplay -> death (jumpscare) -> RESTART / MAIN MENU
	                                         -> escape -> ending -> PLAY AGAIN / MAIN MENU
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Audio = require(script.Audio)
local CameraFX = require(script.CameraFX)
local ChaseFX = require(script.ChaseFX)
local Jumpscare = require(script.Jumpscare)
local LightController = require(script.LightController)
local MonsterVisuals = require(script.MonsterVisuals)
local Movement = require(script.Movement)
local PlayerAnimator = require(script.PlayerAnimator)
local PostFX = require(script.PostFX)
local Settings = require(script.Settings)

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
-- Init (order matters: Settings -> Audio -> FX -> gameplay -> UI)
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
MonsterVisuals.Init()
ChaseFX.Init()
HUD.Init()
PromptUI.Init()
NoteReader.Init()
DeathScreen.Init()
WinScreen.Init()
MainMenu.Init()

Audio.OnThunder = function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and root.Position.Y > -6 then
		PostFX.Lightning()
	end
end

---------------------------------------------------------------------------------------------
-- Flow
---------------------------------------------------------------------------------------------
local inGame = false

local function enterGameplay()
	local camera = Workspace.CurrentCamera
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 10)
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
	camera.FieldOfView = CameraFX.BaseFOV
	CameraFX.Enabled = true
	Movement.SetActive(true)
	ChaseFX.Reset()
	ChaseFX.Active = true
	HUD.SetVisible(true)
	Audio.InGame = true
	inGame = true
end

local function exitGameplay()
	inGame = false
	NoteReader.Close()
	Movement.SetActive(false)
	ChaseFX.Active = false
	ChaseFX.Reset()
	HUD.SetVisible(false)
	Audio.InGame = false
	Audio.StopAllLoops(2)
	Audio.Duck(1, 20)
end

-- Ask the server for a character and wait for it to arrive.
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
	local stage = Workspace:GetAttribute("Stage") or 1
	task.spawn(Fader.In, 2.2)
	if stage == 1 then
		HUD.Chapter("HOLLOWMERE PSYCHIATRIC ANNEX", "OCTOBER 4TH   -   02:13 AM")
		HUD.ShowHints()
		task.delay(6.5, function()
			if inGame then
				HUD.Message("Where... is everyone? It's so dark. (F)", 3.5, "Thought")
			end
		end)
	elseif stage == 4 then
		task.delay(1, function()
			if inGame then
				HUD.Message("It's still here. Get the key.", 3, "Thought")
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

---------------------------------------------------------------------------------------------
-- Server events
---------------------------------------------------------------------------------------------
Remotes.Event("ObjectiveUpdate").OnClientEvent:Connect(function(stage: number, text: string, isNew: boolean)
	HUD.SetObjective(stage, text, isNew and inGame)
end)

Remotes.Event("ShowMessage").OnClientEvent:Connect(function(text: string, duration: number?, style: string?)
	if inGame then
		HUD.Message(text, duration, style)
	end
end)

Remotes.Event("ShowNote").OnClientEvent:Connect(function(title: string, body: string)
	if inGame then
		NoteReader.Show(title, body)
	end
end)

Remotes.Event("ChaseCue").OnClientEvent:Connect(function(cue: string, data)
	-- Being hunted? Drop the note, look up.
	if cue == "HeadTurn" and type(data) == "table" and (data.Target == player.UserId or data.Final) then
		NoteReader.Close()
	end
end)

Remotes.Event("Jumpscare").OnClientEvent:Connect(function(monsterCFrame: CFrame)
	if not inGame then
		return
	end
	inGame = false
	NoteReader.Close()
	ChaseFX.Active = false
	HUD.SetVisible(false)
	Audio.InGame = false
	Jumpscare.Play(monsterCFrame)
	Movement.SetActive(false)
	ChaseFX.Reset()
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

Remotes.Event("GameWon").OnClientEvent:Connect(function(elapsed: number)
	if not inGame then
		return
	end
	inGame = false
	ChaseFX.Active = false
	ChaseFX.Reset()
	Audio.StopAllLoops(0.6)
	HUD.Message("The gate crashes down behind you.", 2.5)
	task.wait(2.2)
	Movement.SetActive(false)
	HUD.SetVisible(false)
	Audio.SetLoop("Victory", "Music", "Victory", 1, 1, 0.5)
	WinScreen.Show(elapsed)
end)

---------------------------------------------------------------------------------------------
MainMenu.Show()
