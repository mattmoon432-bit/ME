--[[
	Cinematic main menu.
	  * live 3D backdrop: a slow camera dolly down a ruined corridor (MenuSet) with
	    flickering tubes, fog and dust; the Grinner stands at the far end, breathing...
	    and every so often the screen glitches and it is suddenly closer
	  * large flickering, glitching title; drifting fog layers; vignette
	  * PLAY / SETTINGS / CREDITS with hover/click animations and sounds
	  * ambient menu theme; fade in / fade out transitions
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MonsterAnimator = require(Shared.MonsterAnimator)
local MonsterRig = require(Shared.MonsterRig)
local SoundLibrary = require(Shared.SoundLibrary)
local Util = require(Shared.Util)

local Audio = require(script.Parent.Parent.Audio)
local Credits = require(script.Parent.Credits)
local Fader = require(script.Parent.Fader)
local SettingsMenu = require(script.Parent.SettingsMenu)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local MainMenu = {}
MainMenu.OnPlay = nil :: (() -> ())?
MainMenu.Visible = false

local C = Theme.Colors
local gui: ScreenGui
local root: Frame
local buttonsFrame: Frame
local title: TextLabel
local titleGlitch: TextLabel
local glitchFrame: Frame
local fogLayers = {} :: { Frame }
local settingsPanel
local creditsPanel
local figure: Model? = nil
local figureUnbind: (() -> ())? = nil
local figureAnimator = nil
local renderConnection: RBXScriptConnection? = nil
local busy = false

local function markers()
	local map = Workspace:WaitForChild("Map")
	local set = map:WaitForChild("MenuSet")
	return {
		Start = (set:WaitForChild("CameraStart") :: BasePart).CFrame,
		End = (set:WaitForChild("CameraEnd") :: BasePart).CFrame,
		Far = (set:WaitForChild("FigureFar") :: BasePart).CFrame,
		Near = (set:WaitForChild("FigureNear") :: BasePart).CFrame,
	}
end

local function fogLayer(parent: Instance, y: number, height: number, transparency: number, speed: number)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.ClipsDescendants = true
	holder.Size = UDim2.new(1, 0, height, 0)
	holder.Position = UDim2.new(0, 0, y, 0)
	holder.Parent = parent
	for i = 0, 1 do
		local band = Instance.new("Frame")
		band.BorderSizePixel = 0
		band.BackgroundColor3 = Color3.fromRGB(150, 150, 160)
		band.Size = UDim2.fromScale(1, 1)
		band.Position = UDim2.fromScale(i, 0)
		band.Parent = holder
		-- Mostly-vertical soft falloff with uneven density; tilted so horizontal drift reads.
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 78
		local keys = {}
		local rng = Random.new(math.floor(y * 100) + i)
		for k = 0, 10 do
			local edge = math.sin(k / 10 * math.pi) -- 0 at the edges, 1 in the middle
			local value = 1 - (1 - transparency) * edge * rng:NextNumber(0.5, 1.4)
			table.insert(keys, NumberSequenceKeypoint.new(k / 10, math.clamp(value, 0, 1)))
		end
		gradient.Transparency = NumberSequence.new(keys)
		gradient.Parent = band
	end
	holder:SetAttribute("Speed", speed)
	table.insert(fogLayers, holder)
	return holder
end

local function build()
	local player = Players.LocalPlayer
	gui = Theme.Screen("MainMenu", 10, player:WaitForChild("PlayerGui"))
	gui.Enabled = false

	root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	-- Fog bands drifting across the screen.
	fogLayer(root, 0.55, 0.45, 0.9, 0.012)
	fogLayer(root, 0.7, 0.3, 0.86, -0.02)
	fogLayer(root, 0.25, 0.4, 0.95, 0.008)

	-- Left-side darkening for readability.
	local shade = Instance.new("Frame")
	shade.BorderSizePixel = 0
	shade.BackgroundColor3 = C.Background
	shade.Size = UDim2.fromScale(0.62, 1)
	shade.Parent = root
	local shadeGradient = Instance.new("UIGradient")
	shadeGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.6, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	shadeGradient.Parent = shade

	-- Title with a red glitch shadow.
	titleGlitch = Theme.Label(root, Config.GameTitle, Theme.Fonts.Title, 120, C.BloodBright, {
		Size = UDim2.new(0.6, 0, 0, 130),
		Position = UDim2.new(0.06, 0, 0.14, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 1,
	})
	title = Theme.Label(root, Config.GameTitle, Theme.Fonts.Title, 120, C.Text, {
		Size = UDim2.new(0.6, 0, 0, 130),
		Position = UDim2.new(0.06, 0, 0.14, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(40, 0, 0)
	titleStroke.Thickness = 2
	titleStroke.Parent = title
	local subtitle = Theme.Label(root, Config.Subtitle .. "  //  " .. string.upper(Config.MonsterName), Theme.Fonts.Heading, 22, C.Blood, {
		Size = UDim2.new(0.5, 0, 0, 30),
		Position = UDim2.new(0.065, 0, 0.14, 132),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	subtitle.Name = "Subtitle"

	buttonsFrame = Instance.new("Frame")
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.Size = UDim2.new(0.3, 0, 0, 240)
	buttonsFrame.Position = UDim2.new(0.08, 0, 0.46, 0)
	buttonsFrame.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 18)
	layout.Parent = buttonsFrame

	Widgets.Button(buttonsFrame, "PLAY", UDim2.new(1, 0, 0, 52), function()
		MainMenu._play()
	end, { TextSize = 42 })
	Widgets.Button(buttonsFrame, "SETTINGS", UDim2.new(1, 0, 0, 44), function()
		if busy then
			return
		end
		creditsPanel.Hide()
		settingsPanel.Show()
	end)
	Widgets.Button(buttonsFrame, "CREDITS", UDim2.new(1, 0, 0, 44), function()
		if busy then
			return
		end
		settingsPanel.Hide()
		creditsPanel.Show()
	end)

	Theme.Label(root, "v" .. Config.Version .. "   -   headphones recommended", Theme.Fonts.Mono, 14, C.TextDim, {
		Size = UDim2.new(0.5, 0, 0, 20),
		Position = UDim2.new(0.02, 0, 1, -30),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Full-screen glitch flash used when the figure "moves".
	glitchFrame = Instance.new("Frame")
	glitchFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	glitchFrame.BorderSizePixel = 0
	glitchFrame.Size = UDim2.fromScale(1, 1)
	glitchFrame.BackgroundTransparency = 1
	glitchFrame.ZIndex = 20
	glitchFrame.Parent = root

	-- Modal button keeps the mouse free in the menu.
	local modal = Instance.new("TextButton")
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Size = UDim2.fromScale(0, 0)
	modal.Modal = true
	modal.Parent = root

	settingsPanel = SettingsMenu.Create(root)
	creditsPanel = Credits.Create(root)
end

local function spawnFigure(cf: CFrame)
	if figure then
		figure:PivotTo(cf + Vector3.new(0, MonsterRig.RootHeight, 0))
		return
	end
	local model = MonsterRig.Build()
	MonsterRig.MakeStatic(model)
	model.Name = "MenuGrinner"
	model:PivotTo(cf + Vector3.new(0, MonsterRig.RootHeight, 0))
	model.Parent = Workspace
	figure = model
	figureAnimator = MonsterAnimator.new(model, { State = "Breathing" })
	figureAnimator.SpeedOverride = 0
	figureUnbind = figureAnimator:Bind()
end

local function removeFigure()
	if figureUnbind then
		figureUnbind()
		figureUnbind = nil
	end
	if figure then
		figure:Destroy()
		figure = nil
	end
end

local function startScene()
	local m = markers()
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 62
	spawnFigure(m.Far)
	local near = false
	local nextShift = os.clock() + 14
	local start = os.clock()
	local seed = math.random() * 50
	renderConnection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		-- ping-pong dolly over 70s
		local alpha = (math.sin(t / 70 * math.pi * 2 - math.pi / 2) + 1) / 2
		local base = m.Start:Lerp(m.End, alpha * 0.55)
		local sway = CFrame.Angles(math.noise(t * 0.15, seed) * 0.03, math.noise(t * 0.12, seed + 1) * 0.04, math.noise(t * 0.1, seed + 2) * 0.02)
		local breath = CFrame.new(0, math.sin(t * 0.9) * 0.06, 0)
		camera.CFrame = base * breath * sway
		if figureAnimator then
			figureAnimator.LookOverride = camera.CFrame.Position
		end

		-- Title flicker
		local flicker = math.noise(t * 6, 3)
		title.TextTransparency = flicker > 0.55 and 0.6 or 0
		if math.noise(t * 4, 9) > 0.6 then
			titleGlitch.TextTransparency = 0.35
			titleGlitch.Position = UDim2.new(0.06, math.random(-6, 6), 0.14, math.random(-3, 3))
		else
			titleGlitch.TextTransparency = 1
		end

		-- Fog drift
		for _, layer in fogLayers do
			local speed = layer:GetAttribute("Speed") :: number
			local offset = (t * speed) % 1
			local bands = layer:GetChildren()
			for i, band in bands do
				(band :: Frame).Position = UDim2.fromScale(i - 1 - offset, 0)
			end
		end

		-- Every so often: a glitch... and it has moved.
		if os.clock() > nextShift then
			nextShift = os.clock() + 12 + math.random() * 10
			near = not near
			task.spawn(function()
				glitchFrame.BackgroundTransparency = 0
				SoundLibrary.Play("Music", "Stinger", nil, { Volume = 0.25, Pitch = 1.3 })
				task.wait(0.12)
				spawnFigure(near and m.Near or m.Far)
				glitchFrame.BackgroundTransparency = 0.4
				task.wait(0.05)
				glitchFrame.BackgroundTransparency = 0
				task.wait(0.06)
				Util.tween(glitchFrame, 0.4, { BackgroundTransparency = 1 })
			end)
		end
	end)
end

local function stopScene()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	removeFigure()
end

function MainMenu.Init()
	build()
end

function MainMenu.Show()
	busy = false
	MainMenu.Visible = true
	settingsPanel.Hide(true)
	creditsPanel.Hide(true)
	gui.Enabled = true
	Audio.InGame = false
	Audio.SetLoop("Menu", "Music", "MenuTheme", 1, 1, 0.6)
	Audio.SetLoop("MenuWind", "Ambient", "Wind", 0.7, 1, 0.6)
	startScene()
	-- intro animation
	title.Position = UDim2.new(0.06, 0, 0.12, 0)
	Util.tween(title, 3, { Position = UDim2.new(0.06, 0, 0.14, 0) }, Enum.EasingStyle.Sine)
	for i, child in buttonsFrame:GetChildren() do
		if child:IsA("GuiObject") then
			local finalPos = child.Position
			child.Position = finalPos + UDim2.fromOffset(-40, 0)
			local label = child:FindFirstChild("Label") :: TextLabel?
			if label then
				label.TextTransparency = 1
				Util.tween(label, 0.8, { TextTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 1 + i * 0.15)
			end
			Util.tween(child, 0.8, { Position = finalPos }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, 1 + i * 0.15)
		end
	end
	Fader.In(2.2)
end

function MainMenu.Hide()
	MainMenu.Visible = false
	gui.Enabled = false
	stopScene()
	Audio.StopLoop("Menu", 1.5)
	Audio.StopLoop("MenuWind", 1.5)
end

function MainMenu._play()
	if busy then
		return
	end
	busy = true
	settingsPanel.Hide()
	creditsPanel.Hide()
	SoundLibrary.Play("UI", "Whoosh")
	Audio.SetHeartbeat(60, 0.7)
	Audio.StopLoop("Menu", 0.8)
	Fader.Out(1.8)
	Audio.SetHeartbeat(0, 0)
	MainMenu.Hide()
	if MainMenu.OnPlay then
		MainMenu.OnPlay()
	end
end

return MainMenu
