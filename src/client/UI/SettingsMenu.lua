-- Settings panel: volumes, graphics quality, camera shake, view, mouse sensitivity.

local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util = require(Shared.Util)

local Settings = require(script.Parent.Parent.Settings)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local SettingsMenu = {}

local C = Theme.Colors

local function panelFrame(parent: Instance, titleText: string): (Frame, Frame)
	local panel = Instance.new("Frame")
	panel.Name = titleText
	panel.BackgroundColor3 = C.Panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Size = UDim2.new(0.42, 0, 0.72, 0)
	panel.Position = UDim2.new(1.5, 0, 0.5, 0)
	panel.Visible = false
	panel.ZIndex = 5
	panel.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 14, 14)
	stroke.Thickness = 1.5
	stroke.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 36)
	padding.PaddingRight = UDim.new(0, 36)
	padding.PaddingTop = UDim.new(0, 26)
	padding.Parent = panel
	local heading = Theme.Label(panel, titleText, Theme.Fonts.Heading, 34, C.Text, {
		Size = UDim2.new(1, 0, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.BackgroundColor3 = C.Blood
	line.Size = UDim2.new(0.3, 0, 0, 2)
	line.Position = UDim2.new(0, 0, 0, 46)
	line.Parent = heading
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, 0, 1, -130)
	content.Position = UDim2.new(0, 0, 0, 64)
	content.Parent = panel
	return panel, content
end
SettingsMenu.PanelFrame = panelFrame

-- Returns { Show(), Hide(instant?) }
function SettingsMenu.Create(parent: Instance)
	local panel, content = panelFrame(parent, "SETTINGS")
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.ScrollBarThickness = 3
	scroller.ScrollBarImageColor3 = C.Blood
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.CanvasSize = UDim2.new()
	scroller.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = scroller

	local setters = {}
	local function section(text: string)
		Theme.Label(scroller, text, Theme.Fonts.Heading, 18, C.Blood, {
			Size = UDim2.new(1, 0, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	section("AUDIO")
	for _, key in { "Master", "Music", "SFX" } do
		local label = key == "SFX" and "SFX Volume" or (key .. " Volume")
		local _, set = Widgets.Slider(scroller, label, Settings.Get(key), function(value)
			Settings.Set(key, value)
		end)
		setters[key] = set
	end
	section("VIDEO")
	local _, setGraphics = Widgets.Selector(scroller, "Graphics Quality", { "Low", "Medium", "High" }, Settings.Get("Graphics"), function(value)
		Settings.Set("Graphics", value)
	end)
	setters.Graphics = setGraphics
	local _, setShake = Widgets.Toggle(scroller, "Camera Shake", Settings.Get("CameraShake"), function(value)
		Settings.Set("CameraShake", value)
	end)
	setters.CameraShake = setShake
	local _, setView = Widgets.Selector(scroller, "Camera View", { "First", "Third" }, Settings.Get("View"), function(value)
		Settings.Set("View", value)
	end)
	setters.View = setView
	section("CONTROLS")
	local _, setSensitivity = Widgets.Slider(scroller, "Mouse Sensitivity", Settings.Get("Sensitivity") / 2, function(value)
		Settings.Set("Sensitivity", math.max(0.05, value * 2))
	end)
	setters.Sensitivity = function(v)
		setSensitivity(v / 2)
	end
	Theme.Label(scroller, "[SHIFT] Run    [C] Crouch    [F] Flashlight    [E] Interact", Theme.Fonts.Mono, 15, C.TextDim, {
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	Settings.Changed:Connect(function(key, value)
		local setter = setters[key]
		if setter then
			setter(value)
		end
		if key == "Sensitivity" then
			pcall(function()
				UserInputService.MouseDeltaSensitivity = value
			end)
		end
	end)
	pcall(function()
		UserInputService.MouseDeltaSensitivity = Settings.Get("Sensitivity")
	end)

	local api: any = {}
	local closeButton = Widgets.Button(panel, "BACK", UDim2.new(0, 160, 0, 40), function()
		api.Hide()
	end, { TextSize = 26 })
	closeButton.Position = UDim2.new(0, 0, 1, -64)

	local open = false
	function api.Show()
		if open then
			return
		end
		open = true
		panel.Visible = true
		panel.Position = UDim2.new(1.5, 0, 0.5, 0)
		Util.tween(panel, 0.45, { Position = UDim2.new(0.95, 0, 0.5, 0) }, Enum.EasingStyle.Quart)
	end
	function api.Hide(instant: boolean?)
		if not open and not instant then
			return
		end
		open = false
		if instant then
			panel.Visible = false
			panel.Position = UDim2.new(1.5, 0, 0.5, 0)
			return
		end
		local tween = Util.tween(panel, 0.35, { Position = UDim2.new(1.5, 0, 0.5, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		tween.Completed:Once(function()
			if not open then
				panel.Visible = false
			end
		end)
	end
	return api
end

return SettingsMenu
