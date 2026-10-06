-- The ending: there was never a way out. "THE END" and an epilogue types out.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util = require(Shared.Util)

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local WinScreen = {}
WinScreen.OnPlayAgain = nil :: (() -> ())?
WinScreen.OnMenu = nil :: (() -> ())?

local C = Theme.Colors
local EPILOGUE = "The night shift log for Hollowmere ends at 02:13 AM.\n\n"
	.. "Nobody answered the morning call. The doors were found chained, the exit bricked up\n"
	.. "from the inside, years before you ever took the job.\n\n"
	.. "There is a new drawing on the corridor wall.\nTwo figures now. Holding hands."

local gui: ScreenGui
local bg: Frame
local title: TextLabel
local timeLabel: TextLabel
local story: TextLabel
local buttons: Frame
local busy = false

function WinScreen.Init()
	gui = Theme.Screen("WinScreen", 20, Players.LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false
	bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = gui
	title = Theme.Label(gui, "THE END", Theme.Fonts.Title, 120, C.BloodBright, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.new(1, 0, 0, 120),
		TextTransparency = 1,
	})
	timeLabel = Theme.Label(gui, "", Theme.Fonts.Mono, 18, C.TextDim, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.2, 76),
		Size = UDim2.new(1, 0, 0, 24),
		TextTransparency = 1,
	})
	story = Theme.Label(gui, "", Theme.Fonts.Note, 24, C.Text, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.34),
		Size = UDim2.new(0.6, 0, 0, 260),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0.5, 0)
	buttons.Position = UDim2.fromScale(0.5, 0.74)
	buttons.Size = UDim2.fromOffset(320, 120)
	buttons.Visible = false
	buttons.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = buttons
	local center = Enum.TextXAlignment.Center
	Widgets.Button(buttons, "PLAY AGAIN", UDim2.new(1, 0, 0, 46), function()
		if not busy and WinScreen.OnPlayAgain then
			busy = true
			WinScreen.OnPlayAgain()
		end
	end, { Align = center, TextSize = 32, UnderlineWidth = 0.5 })
	Widgets.Button(buttons, "MAIN MENU", UDim2.new(1, 0, 0, 42), function()
		if not busy and WinScreen.OnMenu then
			busy = true
			WinScreen.OnMenu()
		end
	end, { Align = center, TextSize = 28, UnderlineWidth = 0.5 })
	local modal = Instance.new("TextButton")
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Size = UDim2.fromScale(0, 0)
	modal.Modal = true
	modal.Parent = gui
end

function WinScreen.Show(elapsed: number)
	busy = false
	gui.Enabled = true
	bg.BackgroundTransparency = 1
	Util.tween(bg, 2.5, { BackgroundTransparency = 0 })
	title.TextTransparency = 1
	timeLabel.TextTransparency = 1
	timeLabel.Text = "She was always behind you.      " .. Util.formatTime(elapsed)
	story.Text = ""
	buttons.Visible = false
	task.delay(2.5, function()
		Util.tween(title, 2, { TextTransparency = 0 })
		Util.tween(timeLabel, 2, { TextTransparency = 0.2 }, nil, nil, 0, false, 1)
		task.wait(2.5)
		for i = 1, #EPILOGUE do
			if not gui.Enabled then
				return
			end
			story.Text = string.sub(EPILOGUE, 1, i)
			task.wait(0.025)
		end
		task.wait(0.8)
		buttons.Visible = true
	end)
end

function WinScreen.Hide()
	gui.Enabled = false
end

return WinScreen
