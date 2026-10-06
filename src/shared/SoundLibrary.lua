--[[
	Builds the sound architecture from Sounds.lua:

	SoundService
	├── Master (SoundGroup)
	│   ├── Music (SoundGroup)
	│   └── SFX (SoundGroup)
	├── Ambient/   (template Sounds)
	├── Music/
	├── Monster/
	├── Player/
	├── UI/
	└── Jumpscare/

	The server builds it once (so it replicates and server-created 3D sounds share
	the same groups); clients clone templates to play them.
]]

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Sounds = require(script.Parent.Sounds)

local SoundLibrary = {}

local CATEGORY_GROUP = {
	Ambient = "SFX",
	Music = "Music",
	Monster = "SFX",
	Player = "SFX",
	UI = "SFX",
	Jumpscare = "SFX",
}

local function resolveId(def): string?
	if def.id and def.id ~= "" then
		return def.id
	end
	return def.fallback
end

local function buildTemplate(name: string, def, group: SoundGroup?): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = resolveId(def) or ""
	sound.Volume = def.volume or 0.5
	sound.PlaybackSpeed = def.pitch or 1
	sound.Looped = def.looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = def.min or 10
	sound.RollOffMaxDistance = def.max or 120
	sound.SoundGroup = group
	sound:SetAttribute("BaseVolume", sound.Volume)
	sound:SetAttribute("BasePitch", sound.PlaybackSpeed)
	if def.effects then
		local priority = 0
		for className, props in def.effects do
			local ok, effect = pcall(Instance.new, className)
			if ok and effect then
				priority += 1
				for prop, value in props do
					pcall(function()
						(effect :: any)[prop] = value
					end)
				end
				;(effect :: any).Priority = priority
				effect.Parent = sound
			end
		end
	end
	return sound
end

function SoundLibrary.Init()
	assert(RunService:IsServer(), "SoundLibrary.Init must run on the server")
	if SoundService:FindFirstChild("Master") then
		return
	end
	local master = Instance.new("SoundGroup")
	master.Name = "Master"
	master.Volume = 1
	master.Parent = SoundService

	local groups = {}
	for _, groupName in { "Music", "SFX" } do
		local group = Instance.new("SoundGroup")
		group.Name = groupName
		group.Volume = 1
		group.Parent = master
		groups[groupName] = group
	end

	for category, defs in Sounds do
		local folder = Instance.new("Folder")
		folder.Name = category
		for name, def in defs do
			buildTemplate(name, def, groups[CATEGORY_GROUP[category] or "SFX"]).Parent = folder
		end
		folder.Parent = SoundService
	end
end

function SoundLibrary.GetGroup(name: string): SoundGroup?
	local master = SoundService:WaitForChild("Master", 10)
	if not master then
		return nil
	end
	if name == "Master" then
		return master :: SoundGroup
	end
	return master:WaitForChild(name, 10) :: SoundGroup?
end

function SoundLibrary.Template(category: string, name: string): Sound?
	local folder = SoundService:WaitForChild(category, 10)
	if not folder then
		return nil
	end
	local template = folder:FindFirstChild(name)
	if not template then
		warn(("[SoundLibrary] Missing sound %s/%s"):format(category, name))
		return nil
	end
	return template :: Sound
end

-- Clone a sound. Parent defaults to SoundService (2D / non-positional).
function SoundLibrary.Create(category: string, name: string, parent: Instance?): Sound?
	local template = SoundLibrary.Template(category, name)
	if not template then
		return nil
	end
	local sound = template:Clone()
	sound.Parent = parent or SoundService
	return sound
end

-- Fire-and-forget. `target` may be nil (2D), a BasePart/Attachment, or a world Vector3.
-- options: { Volume = multiplier, Pitch = multiplier, PitchVariance = 0.05, TimePosition }
function SoundLibrary.Play(category: string, name: string, target: any?, options: { [string]: any }?): Sound?
	local parent: Instance = SoundService
	local cleanupAttachment: Attachment? = nil
	if typeof(target) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = target
		attachment.Parent = Workspace.Terrain
		parent = attachment
		cleanupAttachment = attachment
	elseif typeof(target) == "Instance" then
		parent = target
	end

	local sound = SoundLibrary.Create(category, name, parent)
	if not sound then
		if cleanupAttachment then
			cleanupAttachment:Destroy()
		end
		return nil
	end
	options = options or {}
	local opts = options :: { [string]: any }
	sound.Volume *= opts.Volume or 1
	local variance = opts.PitchVariance or 0
	sound.PlaybackSpeed *= (opts.Pitch or 1) * (1 + (math.random() * 2 - 1) * variance)
	if opts.TimePosition then
		sound.TimePosition = opts.TimePosition
	end
	sound.Looped = false
	sound:Play()

	local lifetime = (opts.Lifetime or 8)
	Debris:AddItem(cleanupAttachment or sound, lifetime)
	sound.Ended:Connect(function()
		if cleanupAttachment then
			cleanupAttachment:Destroy()
		else
			sound:Destroy()
		end
	end)
	return sound
end

return SoundLibrary
