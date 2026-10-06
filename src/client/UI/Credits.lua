-- Credits panel with slowly scrolling text.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local SettingsMenu = require(script.Parent.SettingsMenu)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Credits = {}

local LINES = {
	{ Config.GameTitle, 40, Theme.Fonts.Title },
	{ "A procedural horror experience", 18 },
	{ "", 18 },
	{ "DESIGN, CODE & PROCEDURAL ART", 16, nil, true },
	{ "Your Studio Name", 22 },
	{ "", 18 },
	{ "THE GRINNER", 16, nil, true },
	{ "Procedurally rigged & animated in Luau", 20 },
	{ "", 18 },
	{ "AUDIO", 16, nil, true },
	{ "Roblox built-in sounds, reshaped with SoundEffects", 20 },
	{ "(replace with your own in Shared/Sounds.lua)", 16 },
	{ "", 18 },
	{ "BUILT WITH", 16, nil, true },
	{ "Roblox Studio  /  Rojo  /  Luau", 20 },
	{ "", 18 },
	{ "SPECIAL THANKS", 16, nil, true },
	{ "Everyone who played with the lights off", 20 },
	{ "", 30 },
	{ "Don't let it see you run.", 22 },
}

function Credits.Create(parent: Instance)
	local panel, content = SettingsMenu.PanelFrame(parent, "CREDITS")
	content.ClipsDescendants = true
	local scroll = Instance.new("Frame")
	scroll.BackgroundTransparency = 1
	scroll.Size = UDim2.new(1, 0, 0, 0)
	scroll.AutomaticSize = Enum.AutomaticSize.Y
	scroll.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = scroll
	for _, line in LINES do
		Theme.Label(scroll, line[1], line[3] or Theme.Fonts.Body, line[2], line[4] and Theme.Colors.Blood or Theme.Colors.Text, {
			Size = UDim2.new(1, 0, 0, line[2] + 10),
		})
	end

	local api: any = {}
	local open = false
	local connection: RBXScriptConnection? = nil
	local closeButton = Widgets.Button(panel, "BACK", UDim2.new(0, 160, 0, 40), function()
		api.Hide()
	end, { TextSize = 26 })
	closeButton.Position = UDim2.new(0, 0, 1, -64)

	function api.Show()
		if open then
			return
		end
		open = true
		panel.Visible = true
		panel.Position = UDim2.new(1.5, 0, 0.5, 0)
		Util.tween(panel, 0.45, { Position = UDim2.new(0.95, 0, 0.5, 0) }, Enum.EasingStyle.Quart)
		local y = content.AbsoluteSize.Y
		connection = RunService.RenderStepped:Connect(function(dt)
			y -= dt * 28
			if y < -scroll.AbsoluteSize.Y then
				y = content.AbsoluteSize.Y
			end
			scroll.Position = UDim2.fromOffset(0, y)
		end)
	end
	function api.Hide(instant: boolean?)
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if not open and not instant then
			return
		end
		open = false
		if instant then
			panel.Visible = false
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

return Credits
