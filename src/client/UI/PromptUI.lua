--[[
	Custom-styled ProximityPrompts (all prompts use Style = Custom):
	a small key box + action text that fades in, a hold-progress bar, and touch support.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util = require(Shared.Util)

local Theme = require(script.Parent.Theme)

local PromptUI = {}

local C = Theme.Colors

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return string.gsub(prompt.GamepadKeyCode.Name, "Button", "")
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	end
	return prompt.KeyboardKeyCode.Name
end

local function build(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType, gui: ScreenGui)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Prompt"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(260, 60)
	billboard.StudsOffset = Vector3.new(0, 0.6, 0)
	billboard.LightInfluence = 0
	billboard.Adornee = prompt.Parent :: any
	billboard.Parent = gui

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = billboard

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0, 0.5)
	key.Position = UDim2.new(0, 10, 0.5, 0)
	key.Size = UDim2.fromOffset(34, 34)
	key.BackgroundColor3 = Color3.fromRGB(12, 10, 10)
	key.BackgroundTransparency = 0.2
	key.Font = Theme.Fonts.Mono
	key.TextSize = 18
	key.TextColor3 = C.Text
	key.Text = keyText(prompt, inputType)
	key.Parent = holder
	local keyStroke = Instance.new("UIStroke")
	keyStroke.Color = C.Text
	keyStroke.Transparency = 0.5
	keyStroke.Parent = key
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 4)
	keyCorner.Parent = key

	local action = Instance.new("TextLabel")
	action.BackgroundTransparency = 1
	action.Position = UDim2.new(0, 54, 0, 8)
	action.Size = UDim2.new(1, -60, 0, 24)
	action.Font = Theme.Fonts.Body
	action.TextSize = 22
	action.TextColor3 = C.Text
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.Text = prompt.ActionText
	action.Parent = holder
	local actionStroke = Instance.new("UIStroke")
	actionStroke.Transparency = 0.3
	actionStroke.Parent = action

	local object = Instance.new("TextLabel")
	object.BackgroundTransparency = 1
	object.Position = UDim2.new(0, 54, 0, 32)
	object.Size = UDim2.new(1, -60, 0, 18)
	object.Font = Theme.Fonts.Mono
	object.TextSize = 14
	object.TextColor3 = C.TextDim
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.Text = prompt.ObjectText
	object.Parent = holder

	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = C.BloodBright
	bar.Position = UDim2.new(0, 10, 1, -6)
	bar.Size = UDim2.new(0, 0, 0, 2)
	bar.Parent = holder

	local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size = UDim2.fromScale(1, 1)
	button.Parent = holder
	button.Active = inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt

	-- appear animation
	for _, label in { key, action, object } do
		label.TextTransparency = 1
		Util.tween(label, 0.2, { TextTransparency = 0 })
	end
	holder.Position = UDim2.fromOffset(-12, 0)
	Util.tween(holder, 0.25, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quart)

	local connections = {}
	table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			bar.Size = UDim2.new(0, 0, 0, 2)
			Util.tween(bar, prompt.HoldDuration, { Size = UDim2.new(1, -20, 0, 2) }, Enum.EasingStyle.Linear)
		end
	end))
	table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
		Util.tween(bar, 0.15, { Size = UDim2.new(0, 0, 0, 2) })
	end))
	table.insert(connections, prompt.Triggered:Connect(function()
		key.BackgroundColor3 = C.Blood
		Util.tween(key, 0.3, { BackgroundColor3 = Color3.fromRGB(12, 10, 10) })
	end))
	table.insert(connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		action.Text = prompt.ActionText
	end))
	table.insert(connections, prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		object.Text = prompt.ObjectText
	end))
	if button.Active then
		table.insert(connections, button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
			end
		end))
		table.insert(connections, button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldEnd()
			end
		end))
	end

	return function()
		for _, c in connections do
			c:Disconnect()
		end
		for _, label in { key, action, object } do
			Util.tween(label, 0.15, { TextTransparency = 1 })
		end
		task.delay(0.16, function()
			billboard:Destroy()
		end)
	end
end

function PromptUI.Init()
	local gui = Theme.Screen("Prompts", 6, Players.LocalPlayer:WaitForChild("PlayerGui"))
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local cleanup = build(prompt, inputType, gui)
		prompt.PromptHidden:Once(cleanup)
	end)
end

return PromptUI
