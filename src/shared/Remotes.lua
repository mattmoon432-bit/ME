-- Creates (server) or waits for (client) every RemoteEvent the game uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- client -> server
	"RequestPlay",
	"RequestRestart",
	"RequestMenu",
	"SetMoveState", -- { Crouching, Sprinting, Flashlight, Afraid }
	"CameraLook", -- Vector3 look direction: the Girl only moves while nobody is looking

	"SaveSettings",

	-- server -> client
	"ObjectiveUpdate", -- (stageIndex, text, isNew)
	"ShowMessage", -- (text, duration, style)  shown as a subtitle; freezes the player while visible
	"ShowNote", -- (title, body)
	"ScareEvent", -- (name, data) Blackout, Blink, Stinger, Unlock...
	"TurnScare", -- you picked up the flashlight; she's waiting for you to turn around
	"FinalScare", -- (doorCFrame) the exit is a brick wall... turn around
	"Jumpscare", -- (girlCFrame) she caught you
	"PlayerDied", -- (reason) non-girl deaths
	"Spawned", -- confirms a character spawn after PLAY / RESTART
	"LoadSettings", -- (settingsTable)
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
