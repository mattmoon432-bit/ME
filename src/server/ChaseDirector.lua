--[[
	Owns the world-state side of chases:
	  * Workspace attributes ChaseActive / FinalChase / Alarm (clients drive music,
	    heartbeat, FOV, vignette, red lighting and speed boost from these)
	  * the safe room: sealing the steel door behind a chased player, releasing it after
	  * starting the scripted final chase ("RUN.")
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local ChaseDirector = {}

function ChaseDirector.Init(map)
	ChaseDirector.Map = map
	ChaseDirector.SafeDoor = map.DoorsByType.SafeDoor and map.DoorsByType.SafeDoor[1]
	local minV, maxV = map:Bounds("SafeRoom")
	ChaseDirector.SafeMin = minV + Vector3.new(0.5, -2, 0.5)
	ChaseDirector.SafeMax = maxV - Vector3.new(0.5, 0, 0.5)
	Workspace:SetAttribute("ChaseActive", false)
	Workspace:SetAttribute("FinalChase", false)
	Workspace:SetAttribute("Alarm", false)
	Workspace:SetAttribute("Blackout", false)
end

function ChaseDirector.IsInSafeZone(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local p = root.Position
	local a, b = ChaseDirector.SafeMin, ChaseDirector.SafeMax
	return p.X > a.X and p.X < b.X and p.Y > a.Y and p.Y < b.Y and p.Z > a.Z and p.Z < b.Z
end

function ChaseDirector.SealSafeRoom(player: Player)
	local door = ChaseDirector.SafeDoor
	if not door then
		return nil
	end
	door:Close(true)
	door:SetLocked(true)
	door.LockedMessage = "Don't open it. Not yet."
	Remotes.Event("ShowMessage"):FireClient(player, "The steel door slams shut behind you.", 3)
	Remotes.Event("ScareEvent"):FireClient(player, "SafeSealed")
	return door
end

function ChaseDirector.ReleaseSafeRoom()
	local door = ChaseDirector.SafeDoor
	if door and not Workspace:GetAttribute("FinalChase") then
		door:SetLocked(false)
		door.LockedMessage = "Locked."
		for _, player in Players:GetPlayers() do
			if ChaseDirector.IsInSafeZone(player) then
				Remotes.Event("ShowMessage"):FireClient(player, "...it's quiet. It's gone. For now.", 3.5, "Thought")
			end
		end
	end
end

function ChaseDirector.OnChaseStart(player: Player, final: boolean)
	Workspace:SetAttribute("ChaseActive", true)
	if final then
		Workspace:SetAttribute("FinalChase", true)
	end
	local character = player.Character
	if character then
		character:SetAttribute("Chased", true)
	end
end

function ChaseDirector.OnChaseEnd(_reason: string)
	Workspace:SetAttribute("ChaseActive", false)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			character:SetAttribute("Chased", false)
		end
	end
end

-- Key taken: alarms, the safe room jams, and it appears at the far end of the corridor.
function ChaseDirector.StartFinal(player: Player, monster)
	local map = ChaseDirector.Map
	Workspace:SetAttribute("FinalChase", true)
	Workspace:SetAttribute("Alarm", true)
	local door = ChaseDirector.SafeDoor
	if door then
		door:Close(true)
		door:SetLocked(true)
		door.LockedMessage = "It's jammed! It won't open!"
	end
	Remotes.Event("ScareEvent"):FireAllClients("Alarm")
	local spawn
	for _, point in map.StalkPoints do
		if point.Name == "HallWestEnd" then
			spawn = point.Position
		end
	end
	task.delay(1.2, function()
		if Workspace:GetAttribute("FinalChase") then
			monster:StartFinalChase(player, spawn or map.Anchors.HallWest.Position)
		end
	end)
end

function ChaseDirector.EndFinal()
	Workspace:SetAttribute("FinalChase", false)
	Workspace:SetAttribute("Alarm", false)
	Workspace:SetAttribute("ChaseActive", false)
	local door = ChaseDirector.SafeDoor
	if door then
		door:SetLocked(false)
		door.LockedMessage = "Locked."
	end
end

return ChaseDirector
