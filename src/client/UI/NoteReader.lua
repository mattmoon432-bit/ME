-- Paper note overlay. Freezes movement while reading; close with E, ESC, Space or click.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SoundLibrary = require(Shared.SoundLibrary)
local Util = require(Shared.Util)

local Movement = require(script.Parent.Parent.Movement)
local Theme = require(script.Parent.Theme)

local NoteReader = {}
NoteReader.Open = false

local gui: ScreenGui
local backdrop: TextButton
local paper: Frame
local titleLabel: TextLabel
local bodyLabel: TextLabel
local scale: UIScale

function NoteReader.Init()
	gui = Theme.Screen("NoteReader", 8, Players.LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false

	backdrop = Instance.new("TextButton")
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.Modal = true -- frees the mouse in first person
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = gui
	backdrop.Activated:Connect(function()
		NoteReader.Close()
	end)

	paper = Instance.new("Frame")
	paper.AnchorPoint = Vector2.new(0.5, 0.5)
	paper.Position = UDim2.fromScale(0.5, 0.5)
	paper.Size = UDim2.fromOffset(520, 620)
	paper.BackgroundColor3 = Color3.fromRGB(214, 204, 178)
	paper.BorderSizePixel = 0
	paper.Rotation = -1.5
	paper.Parent = gui
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(520, 620)
	constraint.Parent = paper
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 520 / 620
	aspect.Parent = paper
	scale = Instance.new("UIScale")
	scale.Parent = paper
	local grime = Instance.new("UIGradient")
	grime.Rotation = 35
	grime.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 235)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(230, 220, 195)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 150, 120)),
	})
	grime.Parent = paper
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 40)
	padding.PaddingRight = UDim.new(0, 40)
	padding.PaddingTop = UDim.new(0, 36)
	padding.PaddingBottom = UDim.new(0, 36)
	padding.Parent = paper

	-- blood smudge in the corner
	local smudge = Instance.new("Frame")
	smudge.BackgroundColor3 = Color3.fromRGB(110, 14, 10)
	smudge.BackgroundTransparency = 0.35
	smudge.BorderSizePixel = 0
	smudge.Size = UDim2.fromOffset(70, 40)
	smudge.Position = UDim2.new(1, -40, 1, -30)
	smudge.Rotation = 25
	local smudgeCorner = Instance.new("UICorner")
	smudgeCorner.CornerRadius = UDim.new(0.5, 0)
	smudgeCorner.Parent = smudge
	smudge.Parent = paper

	titleLabel = Theme.Label(paper, "", Theme.Fonts.Heading, 26, Color3.fromRGB(40, 30, 26), {
		Size = UDim2.new(1, 0, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
	bodyLabel = Theme.Label(paper, "", Theme.Fonts.Note, 22, Color3.fromRGB(30, 26, 24), {
		Size = UDim2.new(1, 0, 1, -80),
		Position = UDim2.fromOffset(0, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	})
	Theme.Label(paper, "[E] close", Theme.Fonts.Mono, 14, Color3.fromRGB(90, 80, 70), {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
end

function NoteReader.Show(title: string, body: string)
	titleLabel.Text = title
	bodyLabel.Text = body
	NoteReader.Open = true
	gui.Enabled = true
	Movement.Frozen = true
	backdrop.BackgroundTransparency = 1
	Util.tween(backdrop, 0.3, { BackgroundTransparency = 0.45 })
	scale.Scale = 0.85
	paper.Rotation = -6
	Util.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	Util.tween(paper, 0.4, { Rotation = -1.5 }, Enum.EasingStyle.Quart)
	-- Close keys are bound a moment later so the E that opened it doesn't close it.
	task.delay(0.25, function()
		if NoteReader.Open then
			ContextActionService:BindActionAtPriority("CloseNote", function(_, state)
				if state == Enum.UserInputState.Begin then
					NoteReader.Close()
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.E, Enum.KeyCode.Escape, Enum.KeyCode.Space, Enum.KeyCode.ButtonB)
		end
	end)
end

function NoteReader.Close()
	if not NoteReader.Open then
		return
	end
	NoteReader.Open = false
	ContextActionService:UnbindAction("CloseNote")
	SoundLibrary.Play("Player", "Paper", nil, { Pitch = 0.8 })
	Util.tween(backdrop, 0.25, { BackgroundTransparency = 1 })
	local tween = Util.tween(scale, 0.2, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween.Completed:Once(function()
		if not NoteReader.Open then
			gui.Enabled = false
			Movement.Frozen = false
		end
	end)
end

return NoteReader
