--[[
	Screen-space horror effects:
	  * dark vignette (always, subtle) + red pulse vignette (chase)
	  * fake chromatic aberration fringes, film grain, scanlines
	  * colour grading, blur and depth of field (client-local Lighting effects)
	  * flashes (white / red), lightning
	Built from gradients so no image assets are needed.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util = require(Shared.Util)

local Settings = require(script.Parent.Settings)

local PostFX = {}

local gui: ScreenGui
local darkEdges = {} :: { Frame }
local redEdges = {} :: { Frame }
local fringeL: Frame, fringeR: Frame
local flashFrame: Frame
local grainFrames = {} :: { Frame }
local scanlines: Frame
local grade: ColorCorrectionEffect
local blur: BlurEffect
local dof: DepthOfFieldEffect

local state = {
	Dark = 0.35,
	Red = 0,
	Chromatic = 0,
	Grain = 0.25,
	Contrast = 0,
	Saturation = 0,
	Tint = Color3.new(1, 1, 1),
	Brightness = 0,
	Blur = 0,
}
local current = table.clone(state)
PostFX.Override = false -- jumpscare takes direct control

local function edgeSet(parent: Instance, color: Color3, depth: number, zIndex: number): { Frame }
	local frames = {}
	local specs = {
		{ Size = UDim2.new(1, 0, depth, 0), Position = UDim2.fromScale(0, 0), Rotation = 90 },
		{ Size = UDim2.new(1, 0, depth, 0), Position = UDim2.new(0, 0, 1 - depth, 0), Rotation = -90 },
		{ Size = UDim2.new(depth * 0.75, 0, 1, 0), Position = UDim2.fromScale(0, 0), Rotation = 0 },
		{ Size = UDim2.new(depth * 0.75, 0, 1, 0), Position = UDim2.new(1 - depth * 0.75, 0, 0, 0), Rotation = 180 },
	}
	for _, spec in specs do
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		frame.Size = spec.Size
		frame.Position = spec.Position
		frame.ZIndex = zIndex
		frame.BackgroundTransparency = 1
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec.Rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.45, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		frame.Parent = parent
		table.insert(frames, frame)
	end
	return frames
end

function PostFX.Init()
	local player = Players.LocalPlayer
	gui = Instance.new("ScreenGui")
	gui.Name = "HorrorEffects"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	darkEdges = edgeSet(gui, Color3.new(0, 0, 0), 0.42, 1)
	redEdges = edgeSet(gui, Color3.fromRGB(120, 0, 0), 0.5, 2)

	local function fringe(color: Color3, left: boolean): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(0.08, 0, 1, 0)
		frame.Position = left and UDim2.fromScale(0, 0) or UDim2.fromScale(0.92, 0)
		frame.BackgroundTransparency = 1
		frame.ZIndex = 3
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = left and 0 or 180
		gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		gradient.Parent = frame
		frame.Parent = gui
		return frame
	end
	fringeL = fringe(Color3.fromRGB(255, 0, 40), true)
	fringeR = fringe(Color3.fromRGB(0, 220, 255), false)

	scanlines = Instance.new("Frame")
	scanlines.Size = UDim2.fromScale(1, 1)
	scanlines.BackgroundTransparency = 1
	scanlines.ZIndex = 4
	scanlines.Parent = gui
	for i = 0, 59 do
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BackgroundTransparency = 0.94
		line.Size = UDim2.new(1, 0, 0, 1)
		line.Position = UDim2.fromScale(0, i / 60)
		line.Parent = scanlines
	end

	for _ = 1, 70 do
		local speck = Instance.new("Frame")
		speck.BorderSizePixel = 0
		speck.Size = UDim2.fromOffset(2, 2)
		speck.ZIndex = 5
		speck.BackgroundTransparency = 1
		speck.Parent = gui
		table.insert(grainFrames, speck)
	end

	flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.ZIndex = 10
	flashFrame.Parent = gui

	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "HorrorGrade"
	grade.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "HorrorBlur"
	blur.Size = 0
	blur.Parent = Lighting
	dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "HorrorDOF"
	dof.FarIntensity = 0.25
	dof.FocusDistance = 12
	dof.InFocusRadius = 30
	dof.NearIntensity = 0
	dof.Parent = Lighting

	local function applyQuality()
		local quality = Settings.Get("Graphics")
		dof.Enabled = quality == "High"
		scanlines.Visible = quality ~= "Low"
		for _, speck in grainFrames do
			speck.Visible = quality ~= "Low"
		end
	end
	applyQuality()
	Settings.Changed:Connect(function(key)
		if key == "Graphics" then
			applyQuality()
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if PostFX.Override then
			return
		end
		local t = os.clock()
		for key, value in state do
			if type(value) == "number" then
				current[key] = Util.damp(current[key], value, 4, dt)
			end
		end
		current.Tint = (current.Tint :: Color3):Lerp(state.Tint, 1 - math.exp(-4 * dt))

		for _, frame in darkEdges do
			frame.BackgroundTransparency = 1 - math.clamp(current.Dark, 0, 1)
		end
		local pulse = 0.75 + math.sin(t * 7) * 0.25
		for _, frame in redEdges do
			frame.BackgroundTransparency = 1 - math.clamp(current.Red * pulse, 0, 1)
		end
		local chroma = current.Chromatic
		fringeL.BackgroundTransparency = 1 - math.clamp(chroma * 0.5, 0, 0.6)
		fringeR.BackgroundTransparency = 1 - math.clamp(chroma * 0.5, 0, 0.6)
		fringeL.Position = UDim2.new(math.noise(t * 8, 1) * 0.01 * chroma, 0, 0, 0)
		fringeR.Position = UDim2.new(0.92 + math.noise(t * 8, 2) * 0.01 * chroma, 0, 0, 0)

		if scanlines.Visible then
			scanlines.Position = UDim2.new(0, 0, (t * 0.02) % (1 / 60), 0)
			local grain = current.Grain
			for _, speck in grainFrames do
				speck.Position = UDim2.fromScale(math.random(), math.random())
				local v = math.random()
				speck.BackgroundColor3 = Color3.new(v, v, v)
				speck.BackgroundTransparency = 1 - grain * 0.6 * math.random()
			end
		end

		grade.Contrast = current.Contrast
		grade.Saturation = current.Saturation
		grade.Brightness = current.Brightness
		grade.TintColor = current.Tint
		blur.Size = current.Blur
	end)
end

-- Values are targets; PostFX eases toward them.
function PostFX.Set(values: { [string]: any })
	for key, value in values do
		state[key] = value
	end
end

function PostFX.Flash(color: Color3?, strength: number?, duration: number?)
	flashFrame.BackgroundColor3 = color or Color3.new(1, 1, 1)
	flashFrame.BackgroundTransparency = 1 - (strength or 0.8)
	Util.tween(flashFrame, duration or 0.35, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

function PostFX.Lightning()
	local original = Lighting.OutdoorAmbient
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 190)
	PostFX.Flash(Color3.fromRGB(200, 210, 255), 0.18, 0.25)
	task.delay(0.08, function()
		Lighting.OutdoorAmbient = original
		task.wait(0.12)
		Lighting.OutdoorAmbient = Color3.fromRGB(120, 130, 160)
		task.wait(0.06)
		Lighting.OutdoorAmbient = original
	end)
end

function PostFX.Direct(): (ColorCorrectionEffect, BlurEffect, Frame)
	return grade, blur, flashFrame
end

return PostFX
