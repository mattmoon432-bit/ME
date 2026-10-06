-- Shared look & feel for every horror UI screen.

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(6, 5, 5),
	Panel = Color3.fromRGB(14, 12, 12),
	PanelLight = Color3.fromRGB(26, 22, 22),
	Text = Color3.fromRGB(214, 204, 192),
	TextDim = Color3.fromRGB(130, 122, 114),
	Blood = Color3.fromRGB(150, 12, 12),
	BloodBright = Color3.fromRGB(220, 24, 24),
	Accent = Color3.fromRGB(190, 160, 120),
	Black = Color3.new(0, 0, 0),
}

Theme.Fonts = {
	Title = Enum.Font.Creepster,
	Heading = Enum.Font.SpecialElite,
	Body = Enum.Font.SpecialElite,
	Note = Enum.Font.Garamond,
	Mono = Enum.Font.Code,
}

function Theme.Screen(name: string, displayOrder: number, parent: Instance): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = displayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent
	return gui
end

function Theme.Label(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3?, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color or Theme.Colors.Text
	label.Size = UDim2.new(1, 0, 0, size + 8)
	if props then
		for k, v in props do
			(label :: any)[k] = v
		end
	end
	label.Parent = parent
	return label
end

return Theme
