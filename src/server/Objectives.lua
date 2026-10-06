--[[
	Objective / progression state for the run.

	0 Intro        ""                                 lights on, night shift begins
	1 Flashlight   "Get your flashlight."             after the lights die
	2 FindKey      "Find a key."                      she is hunting you now
	3 OpenStorage  "Unlock the storage room."
	4 Escape       "Get out through the main exit."
	5 End          ""                                 bricks... behind you

	The current stage is mirrored to Workspace:GetAttribute("Stage") for clients.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local Objectives = {}

Objectives.Stages = {
	[0] = { Id = "Intro", Text = "" },
	[1] = { Id = "Flashlight", Text = "Get your flashlight." },
	[2] = { Id = "FindKey", Text = "Find a key." },
	[3] = { Id = "OpenStorage", Text = "Unlock the storage room." },
	[4] = { Id = "Escape", Text = "Get out through the main exit." },
	[5] = { Id = "End", Text = "" },
}

Objectives.Stage = 0
Objectives.State = {
	IntroStarted = false,
	FlashlightTaken = false,
	StorageKey = false,
	ExitKey = false,
	StartTime = os.clock(),
}

-- Fired with (newStage, oldStage, player?) after every change.
Objectives.StageChanged = Util.Signal.new()
-- Fired when the run is reset.
Objectives.Reset = Util.Signal.new()

function Objectives.Text(stage: number?): string
	local def = Objectives.Stages[stage or Objectives.Stage]
	return def and def.Text or ""
end

function Objectives.Broadcast(isNew: boolean)
	Remotes.Event("ObjectiveUpdate"):FireAllClients(Objectives.Stage, Objectives.Text(), isNew)
end

function Objectives.SendTo(player: Player)
	Remotes.Event("ObjectiveUpdate"):FireClient(player, Objectives.Stage, Objectives.Text(), false)
end

function Objectives.Set(stage: number, player: Player?)
	if stage == Objectives.Stage then
		return
	end
	local old = Objectives.Stage
	Objectives.Stage = stage
	Workspace:SetAttribute("Stage", stage)
	Objectives.Broadcast(true)
	Objectives.StageChanged:Fire(stage, old, player)
end

-- Move forward only (ignores stale triggers).
function Objectives.Advance(fromStage: number, player: Player?)
	if Objectives.Stage == fromStage then
		Objectives.Set(fromStage + 1, player)
	end
end

function Objectives.ResetRun()
	Objectives.Stage = 0
	Objectives.State.IntroStarted = false
	Objectives.State.FlashlightTaken = false
	Objectives.State.StorageKey = false
	Objectives.State.ExitKey = false
	Objectives.State.StartTime = os.clock()
	Workspace:SetAttribute("Stage", 0)
	Workspace:SetAttribute("Power", true)
	Workspace:SetAttribute("LowPower", false)
	Workspace:SetAttribute("FlashlightTaken", false)
	Objectives.Reset:Fire()
	Objectives.Broadcast(false)
end

function Objectives.Elapsed(): number
	return os.clock() - Objectives.State.StartTime
end

function Objectives.Init()
	Workspace:SetAttribute("Stage", 0)
	Workspace:SetAttribute("Power", true)
	Workspace:SetAttribute("LowPower", false)
	Workspace:SetAttribute("FlashlightTaken", false)
	Players.PlayerAdded:Connect(function(player)
		task.defer(Objectives.SendTo, player)
	end)
end

return Objectives
