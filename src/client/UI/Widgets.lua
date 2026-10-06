--[[
	Animated horror UI widgets (TweenService everywhere):
	  Button  - scales up on hover, turns blood red, an underline slashes in, the text
	            flickers; presses down on click and plays sounds
	  Slider  - draggable volume slider
	  Toggle  - ON/OFF switch
	  Selector- cycles through options (Low/Medium/High)
]]

local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local SoundLibrary = require(Shared.SoundLibrary)
local Util = require(Shared.Util)

local Theme = require(script.Parent.Theme)

local Widgets = {}

local C = Theme.Colors

function Widgets.Button(parent: Instance, text: string, size: UDim2, onClick: () -> (), options: { [string]: any }?): TextButton
	local opts = options or {}
	local button = Instance.new("TextButton")
	button.Name = text
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Size = size
	button.Text = ""
	button.Parent = parent

	local scale = Instance.new("UIScale")
	scale.Parent = button

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = opts.Font or Theme.Fonts.Heading
	label.Text = text
	label.TextSize = opts.TextSize or 34
	label.TextColor3 = C.Text
	label.TextXAlignment = opts.Align or Enum.TextXAlignment.Left
	label.Parent = button

	local glitch = label:Clone()
	glitch.Name = "Glitch"
	glitch.TextColor3 = C.BloodBright
	glitch.TextTransparency = 1
	glitch.ZIndex = label.ZIndex - 1
	glitch.Parent = button

	local underline = Instance.new("Frame")
	underline.Name = "Underline"
	underline.BorderSizePixel = 0
	underline.BackgroundColor3 = C.Blood
	underline.Size = UDim2.new(0, 0, 0, 3)
	underline.Position = UDim2.new(0, 0, 1, -4)
	underline.AnchorPoint = opts.Align == Enum.TextXAlignment.Center and Vector2.new(0.5, 0) or Vector2.zero
	if opts.Align == Enum.TextXAlignment.Center then
		underline.Position = UDim2.new(0.5, 0, 1, -4)
	end
	underline.Parent = button

	local marker = Instance.new("TextLabel")
	marker.BackgroundTransparency = 1
	marker.Text = ">"
	marker.Font = Theme.Fonts.Heading
	marker.TextSize = label.TextSize
	marker.TextColor3 = C.BloodBright
	marker.TextTransparency = 1
	marker.Size = UDim2.new(0, 30, 1, 0)
	marker.Position = UDim2.new(0, -34, 0, 0)
	marker.Visible = opts.Align ~= Enum.TextXAlignment.Center
	marker.Parent = button

	local hovered = false
	button.MouseEnter:Connect(function()
		hovered = true
		SoundLibrary.Play("UI", "Hover", nil, { PitchVariance = 0.05 })
		Util.tween(scale, 0.18, { Scale = 1.08 }, Enum.EasingStyle.Back)
		Util.tween(label, 0.15, { TextColor3 = C.BloodBright })
		Util.tween(underline, 0.25, { Size = UDim2.new(opts.UnderlineWidth or 0.6, 0, 0, 3) }, Enum.EasingStyle.Quart)
		Util.tween(marker, 0.15, { TextTransparency = 0, Position = UDim2.new(0, -30, 0, 0) })
		-- brief glitch flicker
		task.spawn(function()
			for _ = 1, 3 do
				if not hovered then
					break
				end
				glitch.TextTransparency = 0.3
				glitch.Position = UDim2.fromOffset(math.random(-4, 4), math.random(-2, 2))
				task.wait(0.04)
				glitch.TextTransparency = 1
				task.wait(0.05)
			end
		end)
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		Util.tween(scale, 0.2, { Scale = 1 })
		Util.tween(label, 0.2, { TextColor3 = C.Text })
		Util.tween(underline, 0.2, { Size = UDim2.new(0, 0, 0, 3) })
		Util.tween(marker, 0.2, { TextTransparency = 1, Position = UDim2.new(0, -34, 0, 0) })
	end)
	button.MouseButton1Down:Connect(function()
		Util.tween(scale, 0.07, { Scale = 0.94 })
	end)
	button.Activated:Connect(function()
		SoundLibrary.Play("UI", "Click")
		Util.tween(scale, 0.12, { Scale = hovered and 1.08 or 1 }, Enum.EasingStyle.Back)
		label.TextColor3 = Color3.new(1, 1, 1)
		Util.tween(label, 0.3, { TextColor3 = hovered and C.BloodBright or C.Text })
		onClick()
	end)
	return button
end

function Widgets.Row(parent: Instance, labelText: string, height: number?): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, height or 48)
	row.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0.42, 0, 1, 0)
	label.Font = Theme.Fonts.Body
	label.TextSize = 22
	label.TextColor3 = C.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = labelText
	label.Parent = row
	return row
end

function Widgets.Slider(parent: Instance, labelText: string, initial: number, onChanged: (number) -> ()): (Frame, (number) -> ())
	local row = Widgets.Row(parent, labelText)
	local track = Instance.new("Frame")
	track.BackgroundColor3 = C.PanelLight
	track.BorderSizePixel = 0
	track.Size = UDim2.new(0.45, 0, 0, 6)
	track.Position = UDim2.new(0.44, 0, 0.5, -3)
	track.Parent = row
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = C.Blood
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(initial, 1)
	fill.Parent = track
	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = C.Text
	knob.BorderSizePixel = 0
	knob.Size = UDim2.fromOffset(14, 22)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(initial, 0.5)
	knob.Parent = track
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Size = UDim2.new(0.1, 0, 1, 0)
	value.Position = UDim2.new(0.91, 0, 0, 0)
	value.Font = Theme.Fonts.Mono
	value.TextSize = 18
	value.TextColor3 = C.TextDim
	value.Text = string.format("%d%%", initial * 100)
	value.Parent = row

	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.new(1, 20, 0, 34)
	hit.Position = UDim2.new(0, -10, 0.5, -17)
	hit.Parent = track

	local function set(alpha: number, fire: boolean?)
		alpha = math.clamp(alpha, 0, 1)
		Util.tween(fill, 0.08, { Size = UDim2.fromScale(alpha, 1) })
		Util.tween(knob, 0.08, { Position = UDim2.fromScale(alpha, 0.5) })
		value.Text = string.format("%d%%", math.floor(alpha * 100 + 0.5))
		if fire then
			onChanged(alpha)
		end
	end

	local dragging = false
	local lastTick = 0
	local function update(x: number)
		local alpha = (x - track.AbsolutePosition.X) / track.AbsoluteSize.X
		set(alpha, true)
		if os.clock() - lastTick > 0.06 then
			lastTick = os.clock()
			SoundLibrary.Play("UI", "Slider")
		end
	end
	hit.MouseButton1Down:Connect(function(x)
		dragging = true
		update(x)
		Util.tween(knob, 0.1, { BackgroundColor3 = C.BloodBright })
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			Util.tween(knob, 0.15, { BackgroundColor3 = C.Text })
		end
	end)
	return row, function(alpha: number)
		set(alpha, false)
	end
end

function Widgets.Toggle(parent: Instance, labelText: string, initial: boolean, onChanged: (boolean) -> ()): (Frame, (boolean) -> ())
	local row = Widgets.Row(parent, labelText)
	local box = Instance.new("TextButton")
	box.AutoButtonColor = false
	box.BackgroundColor3 = C.PanelLight
	box.BorderSizePixel = 0
	box.Size = UDim2.fromOffset(74, 30)
	box.Position = UDim2.new(0.44, 0, 0.5, -15)
	box.Text = ""
	box.Parent = row
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = box
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(24, 24)
	knob.BorderSizePixel = 0
	knob.Parent = box
	local knobCorner = corner:Clone()
	knobCorner.Parent = knob
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromOffset(60, 30)
	text.Position = UDim2.new(0.44, 86, 0.5, -15)
	text.Font = Theme.Fonts.Mono
	text.TextSize = 18
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = row

	local value = initial
	local function render(animate: boolean)
		local time = animate and 0.18 or 0
		Util.tween(knob, time, {
			Position = value and UDim2.fromOffset(47, 3) or UDim2.fromOffset(3, 3),
			BackgroundColor3 = value and C.BloodBright or C.TextDim,
		}, Enum.EasingStyle.Back)
		Util.tween(box, time, { BackgroundColor3 = value and Color3.fromRGB(60, 10, 10) or C.PanelLight })
		text.Text = value and "ON" or "OFF"
		text.TextColor3 = value and C.Text or C.TextDim
	end
	render(false)
	box.Activated:Connect(function()
		value = not value
		SoundLibrary.Play("UI", "Click")
		render(true)
		onChanged(value)
	end)
	return row, function(v: boolean)
		value = v
		render(false)
	end
end

function Widgets.Selector(parent: Instance, labelText: string, options: { string }, initial: string, onChanged: (string) -> ()): (Frame, (string) -> ())
	local row = Widgets.Row(parent, labelText)
	local index = table.find(options, initial) or 1
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(0.5, 0, 1, 0)
	holder.Position = UDim2.new(0.44, 0, 0, 0)
	holder.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = holder
	local buttons = {}
	local function render()
		for i, button in buttons do
			local selected = i == index
			Util.tween(button, 0.15, {
				BackgroundColor3 = selected and Color3.fromRGB(70, 10, 10) or C.PanelLight,
				TextColor3 = selected and C.Text or C.TextDim,
			})
		end
	end
	for i, option in options do
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.BorderSizePixel = 0
		button.Size = UDim2.fromOffset(92, 30)
		button.Font = Theme.Fonts.Body
		button.TextSize = 18
		button.Text = option
		button.Parent = holder
		local scale = Instance.new("UIScale")
		scale.Parent = button
		button.MouseEnter:Connect(function()
			SoundLibrary.Play("UI", "Hover")
			Util.tween(scale, 0.12, { Scale = 1.06 })
		end)
		button.MouseLeave:Connect(function()
			Util.tween(scale, 0.12, { Scale = 1 })
		end)
		button.Activated:Connect(function()
			index = i
			SoundLibrary.Play("UI", "Click")
			render()
			onChanged(option)
		end)
		buttons[i] = button
	end
	render()
	return row, function(value: string)
		index = table.find(options, value) or index
		render()
	end
end

return Widgets
