--[[
	Hinged doors. A door is an anchored, invisible hinge part with the panel welded to
	it; opening tweens the hinge. Handles:
	  * player interaction (ProximityPrompt, custom-styled on the client)
	  * locked doors with per-door messages
	  * the Girl bursting doors open while nobody is watching
	  * PathfindingModifiers so the Girl plans routes through closed doors
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local SoundLibrary = require(Shared.SoundLibrary)
local Util = require(Shared.Util)
local Props = require(script.Parent.Props)

local Doors = {}
Doors.All = {} :: { any }
Doors.Opened = Util.Signal.new() -- (door, player?)
Doors.LockedInteract = Util.Signal.new() -- (door, player)

local Door = {}
Door.__index = Door

local A = Props.A

local STYLE = {
	Door = { Color = Color3.fromRGB(96, 74, 54), Material = Enum.Material.WoodPlanks, Window = true },
	Locked = { Color = Color3.fromRGB(82, 64, 48), Material = Enum.Material.WoodPlanks, Window = true },
	SafeDoor = { Color = Color3.fromRGB(78, 92, 100), Material = Enum.Material.DiamondPlate, Window = false, Thick = 0.6 },
	KeyDoor = { Color = Color3.fromRGB(92, 60, 40), Material = Enum.Material.CorrodedMetal, Window = false, Thick = 0.5 },
	FinalDoor = { Color = Color3.fromRGB(46, 50, 54), Material = Enum.Material.Metal, Window = false, Thick = 0.45 },
}

local LOCKED_MESSAGES = {
	Locked = "Locked. It won't budge.",
	KeyDoor = "Padlocked. I need a key.",
	FinalDoor = "The exit. Chained and padlocked... there has to be a key somewhere.",
	SafeDoor = "Something is holding it shut from the other side...",
	Door = "Locked.",
}

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- spec: { CFrame, Width, Height, Type, Label, Parent }
function Doors.Create(spec: { [string]: any })
	local self = setmetatable({}, Door)
	self.Type = spec.Type
	self.Label = spec.Label
	self.CFrame = spec.CFrame -- bottom-centre of the opening; LookVector = wall normal (side A)
	self.Width = spec.Width
	self.Height = spec.Height
	self.IsOpen = false
	self.Locked = spec.Type == "Locked" or spec.Type == "KeyDoor" or spec.Type == "FinalDoor"
	self.LockedMessage = LOCKED_MESSAGES[spec.Type] or "Locked."
	self.Busy = false
	self.Position = (spec.CFrame :: CFrame).Position + Vector3.new(0, spec.Height / 2, 0)
	self.Normal = (spec.CFrame :: CFrame).LookVector
	self.Panels = {} :: { BasePart }

	local style = STYLE[spec.Type] or STYLE.Door
	local m = Instance.new("Model")
	m.Name = (spec.Label or spec.Type) .. "_Door"
	m.Parent = spec.Parent
	self.Model = m

	local cf: CFrame = spec.CFrame
	local w, h = spec.Width, spec.Height
	-- Frame
	local frameColor = Color3.fromRGB(56, 58, 60)
	Props.Part(m, Vector3.new(0.5, h + 0.5, 1.3), cf * CFrame.new(-w / 2 - 0.2, (h + 0.5) / 2, 0), frameColor, Enum.Material.Metal)
	Props.Part(m, Vector3.new(0.5, h + 0.5, 1.3), cf * CFrame.new(w / 2 + 0.2, (h + 0.5) / 2, 0), frameColor, Enum.Material.Metal)
	Props.Part(m, Vector3.new(w + 0.9, 0.5, 1.3), cf * CFrame.new(0, h + 0.25, 0), frameColor, Enum.Material.Metal)

	local double = spec.Type == "FinalDoor"
	local leaves = double and { { -w / 2, w / 2, 1 }, { w / 2, w / 2, -1 } } or { { -w / 2, w, 1 } }
	self.Hinges = {}
	for _, leaf in leaves do
		local hingeX, leafWidth, dir = leaf[1], leaf[2], leaf[3]
		local hinge = Props.Part(m, Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(hingeX, 0, 0), frameColor, Enum.Material.Metal, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Name = "Hinge",
		})
		local thick = style.Thick or 0.35
		local panelCF = hinge.CFrame * CFrame.new(dir * leafWidth / 2, h / 2, 0)
		local panel = Props.Part(m, Vector3.new(leafWidth - 0.15, h - 0.1, thick), panelCF, style.Color, style.Material, {
			Anchored = false,
			Name = "Panel",
			Massless = true,
		})
		weld(hinge, panel)
		table.insert(self.Panels, panel)

		local function attach(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, extra: { [string]: any }?)
			local p = Props.Part(m, size, panelCF * offset, color, material, extra)
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			weld(panel, p)
			return p
		end

		-- handle on both faces
		for _, side in { -1, 1 } do
			attach(Vector3.new(0.3, 0.2, 0.5), CFrame.new(dir * (leafWidth / 2 - 0.7), -h / 2 + 4.4, side * (thick / 2 + 0.2)), Color3.fromRGB(150, 150, 140), Enum.Material.Metal)
		end
		if style.Window then
			local glassColor = Color3.fromRGB(70, 80, 80)
			attach(Vector3.new(leafWidth * 0.45, h * 0.3, thick + 0.05), CFrame.new(0, h * 0.18, 0), glassColor, Enum.Material.Glass, {
				Transparency = 0.55,
				CanQuery = false,
			})
		end
		if spec.Type == "SafeDoor" then
			for _, y in { -2.5, 0, 2.5 } do
				attach(Vector3.new(leafWidth - 0.6, 0.35, thick + 0.15), CFrame.new(0, y, 0), Color3.fromRGB(60, 66, 70), Enum.Material.Metal)
			end
			attach(Vector3.new(0.3, 3, 0.4), CFrame.new(dir * (leafWidth / 2 - 0.9), 0, -(thick / 2 + 0.25)), Color3.fromRGB(170, 170, 160), Enum.Material.Metal)
		end
		-- kick plate + grime
		attach(Vector3.new(leafWidth - 0.4, 1.2, thick + 0.04), CFrame.new(0, -h / 2 + 0.8, 0), Color3.fromRGB(70, 70, 66), Enum.Material.Metal)

		local modifier = Instance.new("PathfindingModifier")
		modifier.Label = "Door"
		modifier.PassThrough = not self.Locked and spec.Type ~= "SafeDoor"
		modifier.Parent = panel

		table.insert(self.Hinges, { Part = hinge, Closed = hinge.CFrame, Dir = dir, Modifier = modifier })
	end

	-- Chains across the exit doors / basement door.
	if spec.Type == "FinalDoor" or spec.Type == "KeyDoor" then
		local chain = Instance.new("Model")
		chain.Name = "Chains"
		chain.Parent = m
		for _, side in { -1, 1 } do
			for i = 0, 1 do
				Props.Part(chain, Vector3.new(w + 0.6, 0.18, 0.18), cf * CFrame.new(0, 4.2 + i * 0.5, side * 0.6) * A(0, 0, (i == 0) and 8 or -8), Color3.fromRGB(50, 50, 54), Enum.Material.Metal, {
					CanCollide = false,
					CanQuery = false,
				})
			end
		end
		Props.Part(chain, Vector3.new(0.7, 0.9, 0.35), cf * CFrame.new(0.2, 4, -0.85), Color3.fromRGB(140, 120, 60), Enum.Material.Metal, {
			CanCollide = false,
			Name = "Padlock",
		})
		self.Chains = chain
	end

	-- Status lamp above security/safe doors (red = locked, green = open/safe).
	if spec.Type == "KeyDoor" or spec.Type == "FinalDoor" then
		local lamp = Props.Part(m, Vector3.new(0.6, 0.6, 0.3), cf * CFrame.new(0, h + 1.1, -0.75), Color3.new(), Enum.Material.Neon, {
			CanCollide = false,
			Name = "StatusLamp",
		})
		local light = Instance.new("PointLight")
		light.Range = 9
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = lamp
		self.Lamp = lamp
		local lampBack = lamp:Clone()
		lampBack.CFrame = cf * CFrame.new(0, h + 1.1, 0.75)
		lampBack.Parent = m
		self.LampBack = lampBack
	end

	-- Interaction prompt
	do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = spec.Label or ""
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt:SetAttribute("Kind", "Door")
		prompt.Parent = self.Panels[1]
		self.Prompt = prompt
		prompt.Triggered:Connect(function(player)
			self:_onPrompt(player)
		end)
	end

	self:_refreshLamp()
	table.insert(Doors.All, self)
	CollectionService:AddTag(m, "Door")
	return self
end

function Door:_refreshLamp()
	if not self.Lamp then
		return
	end
	local color
	if self.Type == "SafeDoor" then
		color = self.Locked and Color3.fromRGB(255, 160, 20) or Color3.fromRGB(40, 255, 90)
	else
		color = self.Locked and Color3.fromRGB(255, 30, 20) or Color3.fromRGB(40, 255, 90)
	end
	for _, lamp in { self.Lamp, self.LampBack } do
		lamp.Color = color
		local light = lamp:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = color
		end
	end
	if self.Keypad then
		self.Keypad.Color = self.Locked and Color3.fromRGB(60, 10, 10) or Color3.fromRGB(10, 60, 20)
	end
end

function Door:_onPrompt(player: Player)
	local character = player.Character
	if not character or player:GetAttribute("Dead") then
		return
	end
	if self.Locked then
		SoundLibrary.Play("Player", "DoorLocked", self.Panels[1])
		Doors.LockedInteract:Fire(self, player)
		if not self.SuppressLockedMessage then
			Remotes.Event("ShowMessage"):FireClient(player, self.LockedMessage, 3)
		end
		return
	end
	character:SetAttribute("Action", "Door")
	character:SetAttribute("ActionTime", Workspace:GetServerTimeNow())
	if self.IsOpen then
		self:Close()
	else
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		self:Open(root and root.Position or nil, false, player)
	end
end

-- Swings away from `fromPosition`.
function Door:Open(fromPosition: Vector3?, fast: boolean?, player: Player?)
	if self.IsOpen then
		return
	end
	self.IsOpen = true
	local side = 1
	if fromPosition then
		side = ((fromPosition - self.Position):Dot(self.Normal) > 0) and -1 or 1
	end
	local angle = fast and 118 or 100
	local info = fast and TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		or TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, hinge in self.Hinges do
		TweenService:Create(hinge.Part, info, { CFrame = hinge.Closed * CFrame.Angles(0, math.rad(angle * side * hinge.Dir), 0) }):Play()
	end
	for _, panel in self.Panels do
		panel.CanCollide = false
	end
	if self.Prompt then
		self.Prompt.ActionText = "Close"
	end
	if not fast then
		SoundLibrary.Play("Player", "DoorOpen", self.Panels[1], { PitchVariance = 0.08 })
	end
	Doors.Opened:Fire(self, player)
end

function Door:Close(fast: boolean?)
	if not self.IsOpen then
		return
	end
	self.IsOpen = false
	local info = TweenInfo.new(fast and 0.18 or 0.7, fast and Enum.EasingStyle.Quad or Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	for _, hinge in self.Hinges do
		TweenService:Create(hinge.Part, info, { CFrame = hinge.Closed }):Play()
	end
	task.delay(fast and 0.18 or 0.7, function()
		if not self.IsOpen then
			for _, panel in self.Panels do
				panel.CanCollide = true
			end
			SoundLibrary.Play("Player", "DoorClose", self.Panels[1], { PitchVariance = 0.08, Volume = fast and 1.8 or 1 })
		end
	end)
	if self.Prompt then
		self.Prompt.ActionText = "Open"
	end
end

function Door:SetLocked(locked: boolean)
	self.Locked = locked
	for _, hinge in self.Hinges do
		hinge.Modifier.PassThrough = not locked and self.Type ~= "SafeDoor"
	end
	if not locked and self.Chains then
		self.Chains:Destroy()
		self.Chains = nil
	end
	self:_refreshLamp()
end

-- Monster bursts through. Returns false if the door can't be smashed.
function Door:Smash(fromPosition: Vector3): boolean
	if self.IsOpen then
		return true
	end
	if self.Locked or self.Type == "SafeDoor" or self.Type == "FinalDoor" then
		return false
	end
	self:Open(fromPosition, true)
	SoundLibrary.Play("Monster", "DoorSmash", self.Panels[1], { PitchVariance = 0.1 })
	local burst = Instance.new("Attachment")
	burst.WorldPosition = self.Position
	burst.Parent = Workspace.Terrain
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(140, 130, 120))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 5) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.8, 1.4)
	dust.Speed = NumberRange.new(6, 14)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.LightInfluence = 1
	dust.Rate = 0
	dust.Parent = burst
	dust:Emit(25)
	task.delay(2, function()
		burst:Destroy()
	end)
	Remotes.Event("ScareEvent"):FireAllClients("DoorSmash", { Position = self.Position })
	return true
end

-- Closed, smashable/openable doors within `range` of `position` (used by the monster).
function Doors.FindClosedNear(position: Vector3, range: number)
	local found = {}
	for _, door in Doors.All do
		if not door.IsOpen and (door.Position - position).Magnitude < range then
			table.insert(found, door)
		end
	end
	return found
end

function Doors.Nearest(position: Vector3, filter: ((any) -> boolean)?)
	local best, bestDist = nil, math.huge
	for _, door in Doors.All do
		if not filter or filter(door) then
			local d = (door.Position - position).Magnitude
			if d < bestDist then
				best, bestDist = door, d
			end
		end
	end
	return best, bestDist
end

return Doors
