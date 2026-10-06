--[[
	"YOU DIED": glitching, trembling title over black with a red bleed, a tip, and
	RESTART / MAIN MENU.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util = require(Shared.Util)

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local DeathScreen = {}
DeathScreen.OnRestart = nil :: (() -> ())?
DeathScreen.OnMenu = nil :: (() -> ())?

local C = Theme.Colors
local TIPS = {
	"It hears you when you run.",
	"Crouching makes you harder to see.",
	"The break room door is steel. It can't get through steel.",
	"When it freezes and turns its head... you have seconds.",
	"Break its line of sight and it may lose you.",
	"Stopping during the final chase is death. Keep moving.",
	"Your flashlight helps you see. It also helps it see you.",
}

local gui: ScreenGui
local bg: Frame
local bleed: Frame
local title: TextLabel
local ghostR: TextLabel
local ghostC: TextLabel
local tip: TextLabel
local buttons: Frame
local connection: RBXScriptConnection? = nil
local busy = false

function DeathScreen.Init()
	gui = Theme.Screen("DeathScreen", 20, Players.LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false

	bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = gui

	bleed = Instance.new("Frame")
	bleed.BackgroundColor3 = Color3.fromRGB(90, 0, 0)
	bleed.BorderSizePixel = 0
	bleed.Size = UDim2.fromScale(1, 1)
	bleed.BackgroundTransparency = 1
	bleed.Parent = gui
	local bleedGradient = Instance.new("UIGradient")
	bleedGradient.Rotation = 90
	bleedGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	bleedGradient.Parent = bleed

	local function titleLabel(color: Color3): TextLabel
		return Theme.Label(gui, "YOU DIED", Theme.Fonts.Title, 140, color, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.38),
			Size = UDim2.new(1, 0, 0, 160),
			TextTransparency = 1,
		})
	end
	ghostR = titleLabel(Color3.fromRGB(255, 0, 30))
	ghostC = titleLabel(Color3.fromRGB(0, 200, 255))
	title = titleLabel(C.BloodBright)

	tip = Theme.Label(gui, "", Theme.Fonts.Body, 22, C.TextDim, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.8, 0, 0, 30),
		TextTransparency = 1,
	})

	buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0.5, 0)
	buttons.Position = UDim2.fromScale(0.5, 0.62)
	buttons.Size = UDim2.fromOffset(300, 130)
	buttons.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 14)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = buttons
	local center = Enum.TextXAlignment.Center
	Widgets.Button(buttons, "RESTART", UDim2.new(1, 0, 0, 48), function()
		if busy then
			return
		end
		busy = true
		if DeathScreen.OnRestart then
			DeathScreen.OnRestart()
		end
	end, { Align = center, TextSize = 36, UnderlineWidth = 0.5 })
	Widgets.Button(buttons, "MAIN MENU", UDim2.new(1, 0, 0, 44), function()
		if busy then
			return
		end
		busy = true
		if DeathScreen.OnMenu then
			DeathScreen.OnMenu()
		end
	end, { Align = center, TextSize = 28, UnderlineWidth = 0.5 })

	local modal = Instance.new("TextButton")
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Size = UDim2.fromScale(0, 0)
	modal.Modal = true
	modal.Parent = gui
end

function DeathScreen.Show(reason: string?)
	busy = false
	gui.Enabled = true
	bg.BackgroundTransparency = 0
	bleed.BackgroundTransparency = 1
	title.TextTransparency = 1
	tip.Text = reason or TIPS[math.random(1, #TIPS)]
	tip.TextTransparency = 1
	buttons.Visible = false
	title.TextSize = 200
	Util.tween(title, 2.4, { TextTransparency = 0, TextSize = 140 }, Enum.EasingStyle.Quart)
	Util.tween(bleed, 3, { BackgroundTransparency = 0.2 })
	Util.tween(tip, 1, { TextTransparency = 0.1 }, nil, nil, 0, false, 2)
	task.delay(2.6, function()
		buttons.Visible = true
		for i, child in buttons:GetChildren() do
			if child:IsA("GuiObject") then
				local label = child:FindFirstChild("Label") :: TextLabel?
				if label then
					label.TextTransparency = 1
					Util.tween(label, 0.6, { TextTransparency = 0 }, nil, nil, 0, false, i * 0.15)
				end
			end
		end
	end)
	if connection then
		connection:Disconnect()
	end
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local tremble = UDim2.new(0.5, math.noise(t * 18, 1) * 4, 0.38, math.noise(t * 18, 2) * 3)
		title.Position = tremble
		local glitching = math.noise(t * 3, 5) > 0.45
		local alpha = glitching and 0.45 or 0.85
		ghostR.TextTransparency = math.max(title.TextTransparency, alpha)
		ghostC.TextTransparency = math.max(title.TextTransparency, alpha + 0.05)
		ghostR.TextSize = title.TextSize
		ghostC.TextSize = title.TextSize
		local split = glitching and math.random(4, 12) or 3
		ghostR.Position = tremble + UDim2.fromOffset(-split, 0)
		ghostC.Position = tremble + UDim2.fromOffset(split, 0)
	end)
end

function DeathScreen.Hide()
	gui.Enabled = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return DeathScreen
