--[[
	Minimal in-game HUD:
	  * objective (top-left) with an animated "NEW OBJECTIVE" reveal + typewriter
	  * subtitles / thoughts / phone & radio lines (bottom centre)
	  * stamina bar (only visible when not full; red when exhausted)
	  * centre dot, chapter cards, control hints
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SoundLibrary = require(Shared.SoundLibrary)
local Util = require(Shared.Util)

local Lock = require(script.Parent.Parent.Lock)
local Movement = require(script.Parent.Parent.Movement)
local Theme = require(script.Parent.Theme)

local HUD = {}

local C = Theme.Colors
local gui: ScreenGui
local objectiveFrame: Frame
local objectiveTitle: TextLabel
local objectiveText: TextLabel
local objectiveBar: Frame
local subtitle: TextLabel
local staminaHolder: Frame
local staminaFill: Frame
local dot: Frame
local chapter: TextLabel
local chapterSub: TextLabel
local hints: TextLabel
local messageToken = 0
local typeToken = 0

function HUD.Init()
	gui = Theme.Screen("HUD", 5, Players.LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false

	objectiveFrame = Instance.new("Frame")
	objectiveFrame.BackgroundTransparency = 1
	objectiveFrame.Size = UDim2.fromOffset(460, 80)
	objectiveFrame.Position = UDim2.fromOffset(36, 34)
	objectiveFrame.Parent = gui
	objectiveBar = Instance.new("Frame")
	objectiveBar.BorderSizePixel = 0
	objectiveBar.BackgroundColor3 = C.Blood
	objectiveBar.Size = UDim2.new(0, 3, 1, -10)
	objectiveBar.Position = UDim2.fromOffset(0, 5)
	objectiveBar.Parent = objectiveFrame
	objectiveTitle = Theme.Label(objectiveFrame, "OBJECTIVE", Theme.Fonts.Mono, 14, C.TextDim, {
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(16, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	objectiveText = Theme.Label(objectiveFrame, "", Theme.Fonts.Heading, 26, C.Text, {
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.fromOffset(16, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Transparency = 0.4
	stroke.Parent = objectiveText

	subtitle = Theme.Label(gui, "", Theme.Fonts.Body, 24, C.Text, {
		Size = UDim2.new(0.7, 0, 0, 60),
		Position = UDim2.new(0.15, 0, 1, -160),
		TextWrapped = true,
		TextTransparency = 1,
	})
	local subStroke = Instance.new("UIStroke")
	subStroke.Thickness = 1.5
	subStroke.Transparency = 0.1
	subStroke.Parent = subtitle

	staminaHolder = Instance.new("Frame")
	staminaHolder.BackgroundColor3 = Color3.fromRGB(20, 18, 18)
	staminaHolder.BackgroundTransparency = 1
	staminaHolder.BorderSizePixel = 0
	staminaHolder.AnchorPoint = Vector2.new(0.5, 1)
	staminaHolder.Size = UDim2.fromOffset(260, 4)
	staminaHolder.Position = UDim2.new(0.5, 0, 1, -48)
	staminaHolder.Parent = gui
	staminaFill = Instance.new("Frame")
	staminaFill.BorderSizePixel = 0
	staminaFill.BackgroundColor3 = C.Text
	staminaFill.BackgroundTransparency = 1
	staminaFill.AnchorPoint = Vector2.new(0.5, 0)
	staminaFill.Position = UDim2.fromScale(0.5, 0)
	staminaFill.Size = UDim2.fromScale(1, 1)
	staminaFill.Parent = staminaHolder

	dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = C.Text
	dot.BackgroundTransparency = 0.5
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	dot.Parent = gui

	chapter = Theme.Label(gui, "", Theme.Fonts.Heading, 40, Color3.new(1, 1, 1), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, 0, 0, 50),
		TextTransparency = 1,
	})
	chapterSub = Theme.Label(gui, "", Theme.Fonts.Mono, 18, Color3.new(1, 1, 1), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.45, 44),
		Size = UDim2.new(1, 0, 0, 24),
		TextTransparency = 1,
	})
	hints = Theme.Label(gui, "[SHIFT] run     [C] crouch     [F] flashlight     [E] interact", Theme.Fonts.Mono, 16, C.TextDim, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 22),
		TextTransparency = 1,
	})

	RunService.RenderStepped:Connect(function()
		if not gui.Enabled then
			return
		end
		local ratio = Movement.Stamina / Movement.MaxStamina
		local visible = ratio < 0.995
		staminaFill.Size = UDim2.fromScale(ratio, 1)
		staminaFill.BackgroundColor3 = Movement.Exhausted and C.BloodBright or C.Text
		local target = visible and 0.25 or 1
		staminaFill.BackgroundTransparency += (target - staminaFill.BackgroundTransparency) * 0.12
		staminaHolder.BackgroundTransparency = 0.4 + staminaFill.BackgroundTransparency * 0.6
	end)
end

function HUD.SetVisible(visible: boolean)
	gui.Enabled = visible
end

local function typewrite(label: TextLabel, text: string, speed: number)
	typeToken += 1
	local token = typeToken
	label.Text = ""
	task.spawn(function()
		for i = 1, #text do
			if token ~= typeToken then
				return
			end
			label.Text = string.sub(text, 1, i)
			task.wait(speed)
		end
	end)
end

function HUD.SetObjective(stage: number, text: string, isNew: boolean)
	if text == "" then
		objectiveFrame.Visible = false
		return
	end
	objectiveFrame.Visible = true
	if not isNew then
		objectiveText.Text = text
		return
	end
	SoundLibrary.Play("UI", "Objective")
	objectiveTitle.Text = "NEW OBJECTIVE"
	objectiveTitle.TextColor3 = C.BloodBright
	objectiveFrame.Position = UDim2.fromOffset(-20, 34)
	Util.tween(objectiveFrame, 0.6, { Position = UDim2.fromOffset(36, 34) }, Enum.EasingStyle.Quart)
	objectiveBar.Size = UDim2.new(0, 3, 0, 0)
	Util.tween(objectiveBar, 0.5, { Size = UDim2.new(0, 3, 1, -10) }, Enum.EasingStyle.Quart)
	typewrite(objectiveText, text, 0.035)
	task.delay(3, function()
		objectiveTitle.Text = "OBJECTIVE"
		Util.tween(objectiveTitle, 0.6, { TextColor3 = C.TextDim })
	end)
end

-- Subtitles are always pure white (readable in the dark) and freeze the player -
-- movement and camera - for as long as they're on screen.
-- style: nil | "Thought" (italic)
function HUD.Message(text: string, duration: number?, style: string?)
	messageToken += 1
	local token = messageToken
	local time = duration or 3
	subtitle.Font = Theme.Fonts.Body
	subtitle.TextColor3 = Color3.new(1, 1, 1)
	subtitle.Text = style == "Thought" and ("<i>" .. text .. "</i>") or text
	subtitle.RichText = style == "Thought"
	subtitle.TextTransparency = 1
	Lock.Push("Subtitle")
	Util.tween(subtitle, 0.3, { TextTransparency = 0 })
	task.delay(time, function()
		if token == messageToken then
			Util.tween(subtitle, 0.5, { TextTransparency = 1 })
			task.wait(0.5)
			if token == messageToken then
				Lock.Pop("Subtitle")
			end
		end
	end)
end

-- Shows a sequence of subtitles back to back and yields until they're gone.
function HUD.Sequence(lines: { { any } })
	for _, line in lines do
		HUD.Message(line[1], line[2], line[3])
		task.wait((line[2] or 3) + 0.6)
	end
end

function HUD.ClearMessages()
	messageToken += 1
	subtitle.TextTransparency = 1
	Lock.Pop("Subtitle")
end

function HUD.Chapter(title: string, sub: string)
	Lock.Push("Chapter")
	chapter.Text = title
	chapterSub.Text = sub
	chapter.TextTransparency = 1
	chapterSub.TextTransparency = 1
	Util.tween(chapter, 1.5, { TextTransparency = 0 })
	Util.tween(chapterSub, 1.5, { TextTransparency = 0 }, nil, nil, 0, false, 0.6)
	task.delay(4.5, function()
		Util.tween(chapter, 1.5, { TextTransparency = 1 })
		Util.tween(chapterSub, 1.5, { TextTransparency = 1 })
		task.wait(1.5)
		Lock.Pop("Chapter")
	end)
end

function HUD.ShowHints()
	hints.TextTransparency = 1
	Util.tween(hints, 1, { TextTransparency = 0.2 }, nil, nil, 0, false, 5)
	task.delay(14, function()
		Util.tween(hints, 2, { TextTransparency = 1 })
	end)
end

function HUD.SetDotVisible(visible: boolean)
	dot.Visible = visible
end

return HUD
