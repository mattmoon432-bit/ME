-- Full-screen black fader used for every cinematic transition.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Util = require(Shared.Util)

local Theme = require(script.Parent.Theme)

local Fader = {}

local frame: Frame

function Fader.Init()
	local gui = Theme.Screen("Fader", 100, Players.LocalPlayer:WaitForChild("PlayerGui"))
	frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 0 -- start black; the menu fades in
	frame.Parent = gui
end

-- Fades to black and yields until done.
function Fader.Out(time: number?)
	local tween = Util.tween(frame, time or 1, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	tween.Completed:Wait()
end

-- Fades from black and yields until done.
function Fader.In(time: number?)
	local tween = Util.tween(frame, time or 1, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	tween.Completed:Wait()
end

function Fader.Black()
	frame.BackgroundTransparency = 0
end

return Fader
