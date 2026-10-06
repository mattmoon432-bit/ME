--[[
	Objective / progression state for the run.

	1 FindFuse      "Find a fuse."
	2 RestorePower  "Restore the power."
	3 FindExit      "Find the exit."
	4 FindKey       "Find the basement key."      <- the Grinner starts hunting
	5 Run           "RUN."                         <- signature chase
	6 Escape        "Escape through the tunnel."
	7 Escaped

	The current stage is mirrored to Workspace:GetAttribute("Stage") for clients.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local Objectives = {}

Objectives.Stages = {
	{ Id = "FindFuse", Text = "Find a fuse." },
	{ Id = "RestorePower", Text = "Restore the power." },
	{ Id = "FindExit", Text = "Find the exit." },
	{ Id = "FindKey", Text = "Find the basement key." },
	{ Id = "Run", Text = "RUN." },
	{ Id = "Escape", Text = "Escape through the maintenance tunnel." },
	{ Id = "Escaped", Text = "" },
}

Objectives.Stage = 1
Objectives.State = {
	Power = false,
	HasFuse = false,
	KeyTaken = false,
	StartTime = os.clock(),
}

-- Fired with (newStage, oldStage, player?) after every change.
Objectives.StageChanged = Util.Signal.new()
-- Fired when the run is reset or rolled back to a checkpoint: (targetStage)
Objectives.Reset = Util.Signal.new()

function Objectives.Get(): number
	return Objectives.Stage
end

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

-- Full reset (new run).
function Objectives.ResetRun()
	Objectives.Stage = 1
	Objectives.State.Power = false
	Objectives.State.HasFuse = false
	Objectives.State.KeyTaken = false
	Objectives.State.StartTime = os.clock()
	Workspace:SetAttribute("Stage", 1)
	Workspace:SetAttribute("Power", false)
	Objectives.Reset:Fire(1)
	Objectives.Broadcast(false)
end

-- Death during the final chase rolls back to "Find the basement key".
function Objectives.RollbackTo(stage: number)
	if Objectives.Stage <= stage then
		return
	end
	Objectives.Stage = stage
	Workspace:SetAttribute("Stage", stage)
	if stage <= 4 then
		Objectives.State.KeyTaken = false
	end
	Objectives.Reset:Fire(stage)
	Objectives.Broadcast(false)
end

function Objectives.Elapsed(): number
	return os.clock() - Objectives.State.StartTime
end

function Objectives.Init()
	Workspace:SetAttribute("Stage", 1)
	Workspace:SetAttribute("Power", false)
	Players.PlayerAdded:Connect(function(player)
		task.defer(Objectives.SendTo, player)
	end)
end

return Objectives
