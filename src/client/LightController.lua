--[[
	Animates every light tagged "HorrorLight" locally (smooth, no network cost).
	  Normal    on when the power is on
	  Flicker   stutters, buzzes, occasionally drops out
	  Broken    mostly dead, sparks to life in short bursts
	  Dead      never on
	  Emergency red battery lamps - on while the power is out / during the alarm
	World state: Workspace attributes Power (full), LowPower (dim backup after the
	blackout), Blink (everything off for a split second - when she moves).
	Lights near the Girl stutter and die.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local SoundLibrary = require(Shared.SoundLibrary)

local Settings = require(script.Parent.Settings)

local LightController = {}

type Record = {
	Model: Instance,
	Panel: BasePart?,
	Light: Light?,
	Mode: string,
	Base: number,
	Color: Color3,
	LightColor: Color3,
	Seed: number,
	NoPower: boolean,
	Menu: boolean,
	KeepMaterial: boolean,
	Level: number,
	Lit: boolean?,
	Buzz: Sound?,
	Position: Vector3,
}

local records: { Record } = {}
local DARK_PANEL = Color3.fromRGB(40, 42, 44)
local ALARM_RED = Color3.fromRGB(255, 30, 20)

local function register(model: Instance)
	local panel = model:FindFirstChild("Panel", true) :: BasePart?
	local light = panel and panel:FindFirstChildWhichIsA("Light") or nil
	if not panel then
		return
	end
	local menuSet = Workspace:FindFirstChild("Map") and (Workspace.Map :: Instance):FindFirstChild("MenuSet")
	local record: Record = {
		Model = model,
		Panel = panel,
		Light = light,
		Mode = model:GetAttribute("Mode") or "Normal",
		Base = model:GetAttribute("Brightness") or 1,
		Color = model:GetAttribute("LitColor") or Color3.new(1, 1, 1),
		LightColor = light and light.Color or Color3.new(1, 1, 1),
		Seed = model:GetAttribute("Seed") or math.random() * 1000,
		NoPower = model:GetAttribute("NoPower") == true,
		Menu = menuSet ~= nil and model:IsDescendantOf(menuSet),
		KeepMaterial = model:GetAttribute("KeepMaterial") == true,
		Level = 0,
		Position = panel.Position,
	}
	if light then
		light.Enabled = true
		light.Brightness = 0
	end
	table.insert(records, record)
end

local function flicker(t: number, seed: number): number
	local level = math.noise(t * 7, seed) > -0.3 and 1 or 0.05
	if math.noise(t * 0.6, seed + 13) > 0.42 then
		level = math.noise(t * 28, seed + 3) > 0.05 and 0.75 or 0
	end
	return level
end

local function broken(t: number, seed: number): number
	if math.noise(t * 0.8, seed + 7) > 0.35 then
		return math.noise(t * 35, seed) > 0.1 and 0.9 or 0
	end
	return 0
end

function LightController.Init()
	for _, model in CollectionService:GetTagged("HorrorLight") do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal("HorrorLight"):Connect(register)

	local function applyQuality()
		local shadows = Settings.Get("Graphics") ~= "Low"
		for _, record in records do
			if record.Light then
				record.Light.Shadows = shadows and record.Light:IsA("SurfaceLight")
			end
		end
		local particles = Settings.Get("Graphics")
		for _, emitter in CollectionService:GetTagged("AmbientParticles") do
			if emitter:IsA("ParticleEmitter") then
				emitter.Enabled = particles ~= "Low"
			end
		end
	end
	applyQuality()
	Settings.Changed:Connect(function(key)
		if key == "Graphics" then
			applyQuality()
		end
	end)

	local slowIndex = 1
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local t = os.clock()
		local camPos = camera.CFrame.Position
		local power = Workspace:GetAttribute("Power") == true
		local lowPower = Workspace:GetAttribute("LowPower") == true
		local blackout = Workspace:GetAttribute("Blink") == true
		local alarm = false
		local monster = Workspace:FindFirstChild("Girl")
		local monsterHead = monster and not monster:GetAttribute("Hidden") and monster:FindFirstChild("Head") :: BasePart?
		local monsterPos = monsterHead and monsterHead.Position or nil
		local alarmPulse = (math.sin(t * 5) + 1) / 2

		-- Far lights update a few per frame; near ones every frame.
		local count = #records
		local slowBudget = 12
		for i, record in records do
			local panel = record.Panel
			if not panel then
				continue
			end
			local distance = (record.Position - camPos).Magnitude
			local near = distance < 160
			if not near then
				local inSlice = (i - slowIndex) % count < slowBudget
				if not inSlice then
					continue
				end
			end

			local powered = power or lowPower or record.NoPower
			local level = 0
			local mode = record.Mode
			if mode == "Normal" then
				level = powered and 1 or 0
			elseif mode == "Flicker" then
				level = powered and flicker(t, record.Seed) or 0
			elseif mode == "Broken" then
				level = powered and broken(t, record.Seed) or 0
			elseif mode == "Emergency" then
				if alarm then
					level = alarmPulse
				elseif not power then
					level = 0.75 + math.noise(t * 3, record.Seed) * 0.15
				else
					level = 0.12
				end
			end

			if not record.Menu then
				-- backup power after the blackout: everything runs dim
				if lowPower and not power and not record.NoPower and mode ~= "Emergency" then
					level *= Config.Lighting.LowPowerLevel
				end
				if blackout then
					level = 0
				end
				-- The monster drains the lights around it.
				if monsterPos and mode ~= "Emergency" and level > 0 then
					local d = (record.Position - monsterPos).Magnitude
					if d < 12 then
						level *= math.noise(t * 30, record.Seed) > 0.35 and 0.6 or 0
					elseif d < 32 then
						level *= math.noise(t * 18, record.Seed) > -0.1 and 1 or 0.05
					end
				end
				if alarm and mode ~= "Emergency" then
					level *= 0.35 + alarmPulse * 0.25
				end
			end

			record.Level = level
			local light = record.Light
			if light then
				light.Brightness = record.Base * level
				if alarm and not record.Menu then
					light.Color = record.LightColor:Lerp(ALARM_RED, mode == "Emergency" and 0 or 0.7)
				else
					light.Color = record.LightColor
				end
			end
			local lit = level > 0.3
			if lit ~= record.Lit then
				record.Lit = lit
				if not record.KeepMaterial then
					panel.Material = lit and Enum.Material.Neon or Enum.Material.SmoothPlastic
				end
			end
			if lit then
				local color = record.Color
				if alarm and not record.Menu and mode ~= "Emergency" then
					color = color:Lerp(ALARM_RED, 0.7)
				end
				panel.Color = DARK_PANEL:Lerp(color, math.clamp(level, 0, 1))
			else
				panel.Color = DARK_PANEL
			end

			-- Electrical buzz on flickering tubes you're close to.
			if mode == "Flicker" and distance < 22 and powered then
				if not record.Buzz then
					record.Buzz = SoundLibrary.Create("Ambient", "LightBuzz", panel)
					if record.Buzz then
						record.Buzz.Looped = true
						record.Buzz:Play()
					end
				end
				if record.Buzz then
					record.Buzz.Volume = (record.Buzz:GetAttribute("BaseVolume") or 0.05) * (lit and 1.2 or 0.3)
				end
			elseif record.Buzz then
				record.Buzz:Destroy()
				record.Buzz = nil
			end
		end
		slowIndex = (slowIndex + slowBudget - 1) % math.max(count, 1) + 1
	end)
end

return LightController
