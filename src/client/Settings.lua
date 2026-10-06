-- Client-side settings store. Loaded from the server (DataStore) on join, saved on change.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local Settings = {}

Settings.Values = {
	Master = 1,
	Music = 0.8,
	SFX = 1,
	Graphics = "High", -- Low | Medium | High
	CameraShake = true,
	View = "First", -- First | Third
	Sensitivity = 1,
}

-- Fired with (key, value) whenever a setting changes (also once per key on load).
Settings.Changed = Util.Signal.new()

function Settings.Get(key: string): any
	return Settings.Values[key]
end

local pendingSave = false
function Settings.Set(key: string, value: any)
	if Settings.Values[key] == value then
		return
	end
	Settings.Values[key] = value
	Settings.Changed:Fire(key, value)
	if not pendingSave then
		pendingSave = true
		task.delay(2, function()
			pendingSave = false
			Remotes.Event("SaveSettings"):FireServer(Settings.Values)
		end)
	end
end

function Settings.Init()
	Remotes.Event("LoadSettings").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		for key, value in data do
			if Settings.Values[key] ~= nil and type(value) == type(Settings.Values[key]) then
				Settings.Values[key] = value
				Settings.Changed:Fire(key, value)
			end
		end
	end)
end

return Settings
