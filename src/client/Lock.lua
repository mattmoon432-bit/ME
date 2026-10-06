--[[
	Player control locks. While any lock is held the character can't move and/or the
	camera can't turn. Used whenever story text is on screen (subtitles, chapter cards,
	notes) and during scripted scares.

	Lock.Push(key, { Move = true, Camera = true })   -- both default to true
	Lock.Pop(key)
	Lock.Clear()
]]

local Workspace = game:GetService("Workspace")

local Lock = {}

type Entry = { Move: boolean, Camera: boolean }
local entries: { [string]: Entry } = {}
local cameraHeld = false

local function update()
	local cameraLocked = false
	for _, entry in entries do
		if entry.Camera then
			cameraLocked = true
		end
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if cameraLocked and not cameraHeld then
		if camera.CameraType == Enum.CameraType.Custom then
			cameraHeld = true
			camera.CameraType = Enum.CameraType.Scriptable -- holds the current view
		end
	elseif not cameraLocked and cameraHeld then
		cameraHeld = false
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
	end
end

function Lock.Push(key: string, options: { Move: boolean?, Camera: boolean? }?)
	local opts = options or {}
	entries[key] = { Move = opts.Move ~= false, Camera = opts.Camera ~= false }
	update()
end

function Lock.Pop(key: string)
	if entries[key] then
		entries[key] = nil
		update()
	end
end

-- Drops every lock without touching the camera (used when something else - a
-- jumpscare, the menu - is about to take the camera over).
function Lock.Clear()
	table.clear(entries)
	cameraHeld = false
end

function Lock.MoveLocked(): boolean
	for _, entry in entries do
		if entry.Move then
			return true
		end
	end
	return false
end

function Lock.Any(): boolean
	return next(entries) ~= nil
end

return Lock
