--[[
	Everything the player can interact with: objective items (fuse, fuse box, key),
	readable notes, the office drawer, the ringing phone, the ward radio, and scripted
	environmental scares (the rolling wheelchair, the self-opening security door).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local SoundLibrary = require(Shared.SoundLibrary)

local Doors = require(script.Parent.Doors)
local Noise = require(script.Parent.Noise)
local Objectives = require(script.Parent.Objectives)
local Props = require(script.Parent.Props)

local Interactions = {}

local A = Props.A

local NOTES = {
	Reception = {
		Title = "NIGHT SHIFT LOG - OCT 3",
		Body = "Power failed again at 01:40. Generator room says the main fuse blew.\n\n"
			.. "Spare fuses are in STORAGE, off the east corridor. The fuse box is in the GENERATOR ROOM.\n\n"
			.. "All patients were transferred this morning. All except the one in the sub-level.\n\n"
			.. "Dr. Hale says Subject 09 is 'just a man with a condition'.\nThe cameras keep losing it. Men don't do that.",
	},
	Office = {
		Title = "DR. HALE - OBSERVATION 41",
		Body = "Subject 09 does not blink. It does not sleep. It smiles constantly - the muscles never relax.\n\n"
			.. "It will not move while it is being watched. Look away and it is somewhere else.\n\n"
			.. "When it decides to hunt, it goes completely still. Then the head turns. Then it SCREAMS.\n\n"
			.. "After the scream it is faster than anything I have ever seen.\nIf you hear it, do not hide. Run.",
	},
	Drawer = {
		Title = "HALE - PRIVATE",
		Body = "They want it moved to Blackwater. They don't understand.\n\n"
			.. "It isn't contained down there. It's WAITING down there.\n\n"
			.. "If the power goes out, it will come up the stairs. It always comes up the stairs.\n\n"
			.. "God forgive me. I let it see my face.",
	},
	Exit = {
		Title = "TAPED TO THE DOORS",
		Body = "THEY CHAINED US IN.\n\nNobody leaves until 'it' is recovered - corporate's orders.\n\n"
			.. "There is another way out: the MAINTENANCE TUNNEL in the sub-level runs to the river outflow.\n\n"
			.. "The BASEMENT KEY is in the SECURITY OFFICE.\nSecurity was sealed when the power went. Maybe it's open now.\n\n- R.",
	},
	SafeRoom = {
		Title = "SCRAWLED ON A NAPKIN",
		Body = "Day 4.\n\nIt can't get through steel. I watched it try for an hour.\n\n"
			.. "It beats on the door until it gets bored, then it just... goes. Never saw where.\n\n"
			.. "If it's chasing you, get in here and SHUT THE DOOR.",
	},
	Records = {
		Title = "ADMISSION FILE - SUBJECT 09",
		Body = "Name: UNKNOWN\nAdmitted: UNKNOWN (predates facility records)\nHeight: 3.6 m\n\n"
			.. "Staff injuries attributed: 14\nStaff missing: 6\n\n"
			.. "NOTE: Subject's movement speed during 'agitated episodes' exceeds 40 km/h.\n"
			.. "NOTE: Subject is drawn to SOUND. Staff are advised to walk, never run, on the ward.",
	},
	Security = {
		Title = "GUARD LOG",
		Body = "It took Martinez right in front of me. Its face. That SMILE.\n\n"
			.. "I'm locking myself in. The basement key is on the hook by the door.\n\n"
			.. "Whoever finds this: the moment you take it, it will know. I don't know how. It just knows.\n\n"
			.. "Don't stop running until you see the river.",
	},
}

local RADIO_LINES = {
	"...anyone on this frequency... this is Blackwater recovery team...",
	"...repeat, do NOT engage Subject 09... it's attracted to noise...",
	"...if it screams, you have seconds. Find a steel door...",
	"...the tunnel... the river outflow is the only...",
	"...[static]...it's smiling... why is it smiling...",
}

local function newPrompt(parent: Instance, action: string, object: string, hold: number?, kind: string?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold or 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Kind", kind or "Interact")
	prompt.Parent = parent
	return prompt
end

local function setAction(player: Player, action: string)
	local character = player.Character
	if character then
		character:SetAttribute("Action", action)
		character:SetAttribute("ActionTime", Workspace:GetServerTimeNow())
	end
end

local function message(player: Player?, text: string, duration: number?, style: string?)
	if player then
		Remotes.Event("ShowMessage"):FireClient(player, text, duration or 3, style)
	else
		Remotes.Event("ShowMessage"):FireAllClients(text, duration or 3, style)
	end
end

local function showNote(player: Player, note)
	SoundLibrary.Play("Player", "Paper")
	Remotes.Event("ShowNote"):FireClient(player, note.Title, note.Body)
end

-- hooks: { Stalk = function(pointName, player), MonsterScream = function(position) }
function Interactions.Init(map, hooks)
	local folder = map.Folders.Interactables
	local anchors = map.Anchors
	local doorsByType = map.DoorsByType
	local securityDoor = doorsByType.SecurityDoor and doorsByType.SecurityDoor[1]
	local basementDoor = doorsByType.BasementDoor and doorsByType.BasementDoor[1]
	local exitDoor = doorsByType.ExitDoor and doorsByType.ExitDoor[1]

	-------------------------------------------------------------------------------------
	-- NOTES
	-------------------------------------------------------------------------------------
	local function placeNote(cf: CFrame, note, onWall: boolean?)
		local paper
		if onWall then
			paper = Props.Part(folder, Vector3.new(1.1, 1.4, 0.05), cf, Props.Colors.PAPER, Enum.Material.SmoothPlastic, {
				CanCollide = false,
				Name = "Note",
			})
			Props.Part(folder, Vector3.new(0.15, 0.15, 0.1), cf * CFrame.new(0, 0.6, 0.02), Color3.fromRGB(160, 20, 20), Enum.Material.SmoothPlastic, {
				CanCollide = false,
			})
		else
			paper = Props.Part(folder, Vector3.new(1.1, 0.04, 1.4), cf * CFrame.new(0, 0.02, 0) * A(0, 12, 0), Props.Colors.PAPER, Enum.Material.SmoothPlastic, {
				CanCollide = false,
				Name = "Note",
			})
		end
		-- faint glint so notes can be spotted in the dark
		local glint = Instance.new("PointLight")
		glint.Range = 3
		glint.Brightness = 0.35
		glint.Color = Color3.fromRGB(255, 240, 210)
		glint.Shadows = false
		glint.Parent = paper
		local prompt = newPrompt(paper, "Read", "Note", 0, "Note")
		prompt.Triggered:Connect(function(player)
			setAction(player, "Interact")
			showNote(player, note)
			if note == NOTES.Exit then
				Objectives.Advance(3, player)
			end
		end)
		return paper
	end

	placeNote(anchors.ReceptionDesk, NOTES.Reception)
	placeNote(anchors.OfficeDesk, NOTES.Office)
	placeNote(anchors.ExitNote, NOTES.Exit, true)
	placeNote(anchors.SafeNote, NOTES.SafeRoom, true)
	placeNote(anchors.RecordsDesk, NOTES.Records)
	placeNote(anchors.SecurityDesk, NOTES.Security)

	-------------------------------------------------------------------------------------
	-- OFFICE DRAWER
	-------------------------------------------------------------------------------------
	do
		local drawerCF = anchors.OfficeDrawer
		local drawer = Props.Part(folder, Vector3.new(1.6, 0.6, 0.15), drawerCF, Color3.fromRGB(70, 50, 34), Enum.Material.Wood, {
			Name = "Drawer",
			CanCollide = false,
		})
		local prompt = newPrompt(drawer, "Search", "Drawer", 0.5, "Interact")
		local searched = false
		prompt.Triggered:Connect(function(player)
			setAction(player, "Interact")
			SoundLibrary.Play("Player", "Drawer", drawer)
			Noise.Emit(drawer.Position, Config.Noise.Interact, player, "Interact")
			if not searched then
				searched = true
				TweenService:Create(drawer, TweenInfo.new(0.4), { CFrame = drawerCF * CFrame.new(0, 0, -1.1) }):Play()
				task.wait(0.4)
				showNote(player, NOTES.Drawer)
				prompt.ActionText = "Search"
				prompt.ObjectText = "Empty drawer"
			else
				message(player, "Nothing else in here.", 2)
			end
		end)
		Interactions._drawerReset = function()
			searched = false
			drawer.CFrame = drawerCF
			prompt.ObjectText = "Drawer"
		end
	end

	-------------------------------------------------------------------------------------
	-- FUSE
	-------------------------------------------------------------------------------------
	local fuseModel = Instance.new("Model")
	fuseModel.Name = "Fuse"
	fuseModel.Parent = folder
	local fuseCF = anchors.FuseShelf
	local fuseBody = Props.Part(fuseModel, Vector3.new(1.2, 0.45, 0.45), fuseCF * CFrame.new(0, 0.25, 0), Color3.fromRGB(220, 214, 196), Enum.Material.SmoothPlastic, {
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Name = "Body",
	})
	for _, x in { -0.65, 0.65 } do
		Props.Part(fuseModel, Vector3.new(0.25, 0.5, 0.5), fuseCF * CFrame.new(x, 0.25, 0), Color3.fromRGB(180, 160, 90), Enum.Material.Metal, {
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		})
	end
	local fuseGlow = Instance.new("PointLight")
	fuseGlow.Range = 4
	fuseGlow.Brightness = 0.5
	fuseGlow.Color = Color3.fromRGB(255, 220, 160)
	fuseGlow.Parent = fuseBody
	local fusePrompt = newPrompt(fuseBody, "Take", "Fuse", 0, "Pickup")
	fusePrompt.Triggered:Connect(function(player)
		if Objectives.State.HasFuse then
			return
		end
		Objectives.State.HasFuse = true
		setAction(player, "Pickup")
		SoundLibrary.Play("Player", "Pickup")
		Noise.Emit(fuseBody.Position, Config.Noise.Interact, player, "Pickup")
		for _, p in fuseModel:GetChildren() do
			(p :: BasePart).Transparency = 1
		end
		fusePrompt.Enabled = false
		fuseGlow.Enabled = false
		message(player, "Got a fuse. Now find the fuse box.", 3)
		Objectives.Advance(1, player)
		-- First glimpse: it watches you leave the storage room.
		task.delay(4, function()
			if hooks.Stalk then
				hooks.Stalk("HallWestEnd", player, true)
			end
		end)
	end)

	-------------------------------------------------------------------------------------
	-- FUSE BOX
	-------------------------------------------------------------------------------------
	local boxCF = anchors.FuseBox
	local box = Instance.new("Model")
	box.Name = "FuseBox"
	box.Parent = folder
	Props.Part(box, Vector3.new(3, 4, 1.1), boxCF, Color3.fromRGB(80, 90, 84), Enum.Material.Metal)
	-- sockets
	local installed = Props.Part(box, Vector3.new(1.2, 0.45, 0.45), boxCF * CFrame.new(0, 0, -0.6), Color3.fromRGB(220, 214, 196), Enum.Material.SmoothPlastic, {
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Transparency = 1,
	})
	for _, y in { 1.1, -1.1 } do
		Props.Part(box, Vector3.new(1.2, 0.45, 0.45), boxCF * CFrame.new(0, y, -0.6), Color3.fromRGB(200, 196, 180), Enum.Material.SmoothPlastic, {
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		})
	end
	Props.Part(box, Vector3.new(3.1, 4.1, 0.12), boxCF * CFrame.new(-1.55, 0, -0.62) * A(0, -110, 0) * CFrame.new(1.55, 0, 0), Color3.fromRGB(90, 100, 94), Enum.Material.Metal, {
		CanCollide = false,
	})
	local indicator = Props.Part(box, Vector3.new(0.35, 0.35, 0.2), boxCF * CFrame.new(1.1, 1.7, -0.6), Color3.fromRGB(200, 20, 20), Enum.Material.Neon, {
		CanCollide = false,
	})
	local leverPivot = boxCF * CFrame.new(1.9, 0, -0.2)
	local lever = Props.Part(box, Vector3.new(0.3, 1.8, 0.3), leverPivot * A(-35, 0, 0) * CFrame.new(0, 0.9, 0), Color3.fromRGB(150, 20, 20), Enum.Material.Metal, {
		CanCollide = false,
	})
	Props.Sign(box, boxCF * CFrame.new(0, 2.6, -0.4), "MAIN BREAKER", 3, Color3.fromRGB(170, 140, 20), Color3.fromRGB(20, 20, 20))
	local boxPrompt = newPrompt(box.PrimaryPart or box:FindFirstChildWhichIsA("BasePart") :: BasePart, "Insert Fuse", "Fuse Box", 1.2, "Interact")
	local generatorHum: Sound? = nil
	boxPrompt.Triggered:Connect(function(player)
		if Objectives.State.Power then
			return
		end
		if not Objectives.State.HasFuse then
			setAction(player, "Interact")
			message(player, "The middle slot is empty. It needs a fuse.", 3)
			SoundLibrary.Play("Player", "DoorLocked", installed)
			return
		end
		setAction(player, "Interact")
		installed.Transparency = 0
		SoundLibrary.Play("Player", "FuseInsert", installed)
		task.wait(0.6)
		TweenService:Create(lever, TweenInfo.new(0.25, Enum.EasingStyle.Back), { CFrame = leverPivot * A(35, 0, 0) * CFrame.new(0, 0.9, 0) }):Play()
		SoundLibrary.Play("Player", "Lever", lever)
		indicator.Color = Color3.fromRGB(40, 255, 80)
		boxPrompt.Enabled = false
		Objectives.State.Power = true
		Workspace:SetAttribute("Power", true)
		Remotes.Event("ScareEvent"):FireAllClients("PowerOn")
		SoundLibrary.Play("Ambient", "PowerOn", boxCF.Position)
		generatorHum = SoundLibrary.Create("Ambient", "GeneratorHum", Props.Part(folder, Vector3.new(1, 1, 1), anchors.GeneratorHum, Color3.new(), nil, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Name = "HumSource",
		}))
		if generatorHum then
			generatorHum:Play()
		end
		Noise.Emit(boxCF.Position, Config.Noise.Objective, player, "Objective")
		Objectives.Advance(2, player)
		-- Something below heard the generator.
		task.delay(7, function()
			if hooks.MonsterScream then
				hooks.MonsterScream(map.StairsBottom or boxCF.Position)
			end
			Remotes.Event("ScareEvent"):FireAllClients("PowerSurge")
			message(nil, "...what was that?", 3, "Thought")
		end)
	end)

	-------------------------------------------------------------------------------------
	-- PHONE (rings after the power comes back)
	-------------------------------------------------------------------------------------
	local phone = Instance.new("Model")
	phone.Name = "Phone"
	phone.Parent = folder
	local phoneBase = Props.Part(phone, Vector3.new(1.4, 0.5, 1), anchors.Phone * CFrame.new(0, 0.25, 0), Color3.fromRGB(26, 24, 22), Enum.Material.SmoothPlastic, {
		CanCollide = false,
	})
	local handset = Props.Part(phone, Vector3.new(1.5, 0.3, 0.35), anchors.Phone * CFrame.new(0, 0.62, 0), Color3.fromRGB(30, 28, 26), Enum.Material.SmoothPlastic, {
		CanCollide = false,
	})
	local ringSound: Sound? = nil
	local phonePrompt = newPrompt(phoneBase, "Answer", "Phone", 0, "Interact")
	phonePrompt.Enabled = false
	local phoneUsed = false
	local function stopRing()
		if ringSound then
			ringSound:Destroy()
			ringSound = nil
		end
		phonePrompt.Enabled = false
	end
	phonePrompt.Triggered:Connect(function(player)
		if phoneUsed then
			return
		end
		phoneUsed = true
		stopRing()
		setAction(player, "Interact")
		handset.CFrame = anchors.Phone * CFrame.new(0.4, 1.2, 0.6) * A(30, 40, 0)
		local breath = SoundLibrary.Create("Monster", "Breath", handset)
		if breath then
			breath.Volume = 0.6
			breath:Play()
		end
		message(player, "...", 2, "Phone")
		task.wait(2.2)
		message(player, "(slow, wet breathing)", 2.5, "Phone")
		task.wait(2.7)
		message(player, "I  S E E  Y O U .", 2.5, "Phone")
		if breath then
			breath:Destroy()
		end
		Remotes.Event("ScareEvent"):FireClient(player, "Stinger")
		task.wait(0.3)
		if hooks.Stalk then
			hooks.Stalk("OfficeDoorway", player, true)
		end
	end)
	Interactions._startPhone = function()
		if phoneUsed then
			return
		end
		ringSound = SoundLibrary.Create("Ambient", "PhoneRing", phoneBase)
		if ringSound then
			ringSound:Play()
		end
		phonePrompt.Enabled = true
		task.delay(45, function()
			if not phoneUsed then
				stopRing()
			end
		end)
	end
	Interactions._resetPhone = function()
		phoneUsed = false
		stopRing()
		handset.CFrame = anchors.Phone * CFrame.new(0, 0.62, 0)
	end

	-------------------------------------------------------------------------------------
	-- WARD RADIO
	-------------------------------------------------------------------------------------
	do
		local radio = Props.Part(folder, Vector3.new(1.6, 1, 0.8), anchors.Radio * CFrame.new(0, 0.5, 0), Color3.fromRGB(60, 50, 40), Enum.Material.Wood, {
			Name = "Radio",
		})
		Props.Part(folder, Vector3.new(0.08, 1.6, 0.08), anchors.Radio * CFrame.new(0.6, 1.6, 0) * A(0, 0, -20), Color3.fromRGB(150, 150, 150), Enum.Material.Metal, {
			CanCollide = false,
		})
		local dial = Props.Part(folder, Vector3.new(0.6, 0.3, 0.05), anchors.Radio * CFrame.new(-0.3, 0.6, -0.42), Color3.fromRGB(255, 170, 60), Enum.Material.Neon, {
			CanCollide = false,
		})
		dial.Transparency = 0.6
		local busy = false
		local index = 0
		local prompt = newPrompt(radio, "Listen", "Radio", 0, "Interact")
		prompt.Triggered:Connect(function(player)
			if busy then
				return
			end
			busy = true
			setAction(player, "Interact")
			dial.Transparency = 0
			local static = SoundLibrary.Create("Ambient", "Static", radio)
			if static then
				static:Play()
			end
			Noise.Emit(radio.Position, Config.Noise.Interact, player, "Interact")
			index = index % #RADIO_LINES + 1
			message(player, RADIO_LINES[index], 4.5, "Radio")
			task.wait(5)
			if static then
				static:Destroy()
			end
			dial.Transparency = 0.6
			busy = false
		end)
	end

	-------------------------------------------------------------------------------------
	-- BASEMENT KEY
	-------------------------------------------------------------------------------------
	local keyModel = Instance.new("Model")
	keyModel.Name = "BasementKey"
	keyModel.Parent = folder
	local keyCF = anchors.KeyHook
	local brass = Color3.fromRGB(196, 160, 70)
	local ring = Props.Part(keyModel, Vector3.new(0.12, 0.55, 0.55), keyCF * A(0, 90, 0), brass, Enum.Material.Metal, {
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Name = "Ring",
	})
	Props.Part(keyModel, Vector3.new(0.12, 0.9, 0.12), keyCF * CFrame.new(0, -0.65, 0), brass, Enum.Material.Metal, { CanCollide = false })
	Props.Part(keyModel, Vector3.new(0.3, 0.12, 0.1), keyCF * CFrame.new(0.15, -0.95, 0), brass, Enum.Material.Metal, { CanCollide = false })
	Props.Part(keyModel, Vector3.new(0.6, 0.35, 0.05), keyCF * CFrame.new(0, -1.5, 0), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic, {
		CanCollide = false,
	})
	local keyGlow = Instance.new("PointLight")
	keyGlow.Range = 4
	keyGlow.Brightness = 0.6
	keyGlow.Color = Color3.fromRGB(255, 220, 140)
	keyGlow.Parent = ring
	local keyPrompt = newPrompt(ring, "Take", "Basement Key", 0.6, "Pickup")
	keyPrompt.Enabled = false
	local function setKeyVisible(visible: boolean)
		for _, p in keyModel:GetChildren() do
			(p :: BasePart).Transparency = visible and 0 or 1
		end
		keyGlow.Enabled = visible
	end
	keyPrompt.Triggered:Connect(function(player)
		if Objectives.Stage ~= 4 or Objectives.State.KeyTaken then
			return
		end
		Objectives.State.KeyTaken = true
		setAction(player, "Pickup")
		SoundLibrary.Play("Player", "KeyJingle")
		setKeyVisible(false)
		keyPrompt.Enabled = false
		Objectives.Advance(4, player)
	end)

	-------------------------------------------------------------------------------------
	-- EXIT DOORS (chained) -> reveals the tunnel route
	-------------------------------------------------------------------------------------
	if exitDoor then
		exitDoor.SuppressLockedMessage = true
	end
	Doors.LockedInteract:Connect(function(door, player)
		if door.Type == "ExitDoor" then
			setAction(player, "Interact")
			if Objectives.Stage >= 3 then
				message(player, "Chained shut from the outside. There's a note taped to the glass.", 3.5)
				task.wait(1.2)
				showNote(player, NOTES.Exit)
				Objectives.Advance(3, player)
			else
				message(player, "Chained shut from the outside... and it's pitch black out there anyway.", 3.5)
			end
		end
	end)

	-------------------------------------------------------------------------------------
	-- WHEELCHAIR SCARE
	-------------------------------------------------------------------------------------
	local chairStart = anchors.Wheelchair
	local wheelchair = Props.Wheelchair(folder, chairStart)
	local chairRolled = false
	local function rollWheelchair(player: Player)
		chairRolled = true
		local target = chairStart * CFrame.new(1.5, 0, -6.4) * A(0, 35, 0)
		local value = Instance.new("CFrameValue")
		value.Value = chairStart
		value.Changed:Connect(function(cf)
			wheelchair:PivotTo(cf)
		end)
		local tween = TweenService:Create(value, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Value = target })
		tween:Play()
		SoundLibrary.Play("Ambient", "MetalCreak", wheelchair:GetPivot().Position, { Pitch = 1.6 })
		Remotes.Event("ScareEvent"):FireClient(player, "Stinger")
		tween.Completed:Wait()
		value:Destroy()
	end
	local scareAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		scareAccumulator += dt
		if scareAccumulator < 0.25 then
			return
		end
		scareAccumulator = 0
		if chairRolled or Objectives.Stage < 2 then
			return
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - chairStart.Position).Magnitude < 22 and (root.Position - chairStart.Position).Magnitude > 9 then
				task.spawn(rollWheelchair, player)
				break
			end
		end
	end)

	-------------------------------------------------------------------------------------
	-- EXIT GATE + WIN ZONE (riverbank)
	-------------------------------------------------------------------------------------
	local gateCF: CFrame = map.ExitGateCFrame
	local gate = Instance.new("Model")
	gate.Name = "ExitGate"
	gate.Parent = folder
	local gateWidth = map.ExitGateWidth or 8
	local gateParts = {}
	for i = 0, 8 do
		table.insert(gateParts, Props.Part(gate, Vector3.new(0.3, 10.5, 0.3), gateCF * CFrame.new(-gateWidth / 2 + 0.4 + i * (gateWidth - 0.8) / 8, 5.25, 0), Color3.fromRGB(70, 50, 40), Enum.Material.CorrodedMetal))
	end
	for _, y in { 1, 5.25, 9.5 } do
		table.insert(gateParts, Props.Part(gate, Vector3.new(gateWidth, 0.35, 0.35), gateCF * CFrame.new(0, y, 0), Color3.fromRGB(70, 50, 40), Enum.Material.CorrodedMetal))
	end
	local gateClosed = gate:GetPivot()
	local gateOpen = gateClosed * CFrame.new(0, 9.8, 0)
	gate:PivotTo(gateOpen)
	local function setGate(closed: boolean, fast: boolean?)
		local value = Instance.new("CFrameValue")
		value.Value = gate:GetPivot()
		value.Changed:Connect(function(cf)
			gate:PivotTo(cf)
		end)
		local tween = TweenService:Create(value, TweenInfo.new(fast and 0.35 or 1.2, fast and Enum.EasingStyle.Bounce or Enum.EasingStyle.Quad), {
			Value = closed and gateClosed or gateOpen,
		})
		tween:Play()
		tween.Completed:Once(function()
			value:Destroy()
		end)
	end
	Interactions.CloseGate = function()
		setGate(true, true)
		SoundLibrary.Play("Monster", "Slam", gateCF.Position)
	end

	local outsideMin, outsideMax = map:Bounds("Outside")
	local winMax = Vector3.new(outsideMax.X, outsideMax.Y, gateCF.Position.Z - 6)
	RunService.Heartbeat:Connect(function()
		if Objectives.Stage < 5 or Objectives.Stage >= 7 then
			return
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and not player:GetAttribute("Dead") then
				local p = root.Position
				if p.X > outsideMin.X and p.X < winMax.X and p.Z > outsideMin.Z and p.Z < winMax.Z and p.Y < outsideMin.Y + 12 then
					Objectives.Set(7, player)
					return
				end
			end
		end
	end)
	map.ExitGateSlamPosition = gateCF.Position + Vector3.new(0, 0, 4) -- tunnel side (tunnel lies at +Z)

	-------------------------------------------------------------------------------------
	-- STAGE HOOKS / RESETS
	-------------------------------------------------------------------------------------
	Objectives.StageChanged:Connect(function(stage)
		if stage == 3 then
			task.delay(22, function()
				if Objectives.Stage >= 3 then
					Interactions._startPhone()
				end
			end)
		elseif stage == 4 then
			keyPrompt.Enabled = true
			if securityDoor then
				-- The security door unlocks... and creaks open on its own.
				securityDoor:SetLocked(false)
				task.delay(1.5, function()
					-- swing into the office: open "from" the corridor side
					local intoA = securityDoor.RegionA and securityDoor.RegionA.Kind == "Security"
					securityDoor:Open(securityDoor.Position + securityDoor.Normal * (intoA and -5 or 5))
					SoundLibrary.Play("Ambient", "MetalCreak", securityDoor.Position)
				end)
			end
		elseif stage == 5 then
			if basementDoor then
				basementDoor:SetLocked(false)
			end
		end
	end)

	Objectives.Reset:Connect(function(stage)
		Workspace:SetAttribute("ChaseActive", false)
		Workspace:SetAttribute("FinalChase", false)
		setGate(false)
		-- key always returns on reset
		setKeyVisible(true)
		keyPrompt.Enabled = stage == 4
		if basementDoor then
			basementDoor:Close(true)
			basementDoor:SetLocked(true)
		end
		if stage <= 1 then
			Objectives.State.HasFuse = false
			for _, p in fuseModel:GetChildren() do
				(p :: BasePart).Transparency = 0
			end
			fusePrompt.Enabled = true
			fuseGlow.Enabled = true
			installed.Transparency = 1
			lever.CFrame = leverPivot * A(-35, 0, 0) * CFrame.new(0, 0.9, 0)
			indicator.Color = Color3.fromRGB(200, 20, 20)
			boxPrompt.Enabled = true
			if generatorHum then
				generatorHum:Destroy()
				generatorHum = nil
			end
			Interactions._resetPhone()
			Interactions._drawerReset()
			chairRolled = false
			wheelchair:PivotTo(chairStart)
			for _, door in Doors.All do
				door:Close(true)
			end
			if securityDoor then
				securityDoor:SetLocked(true)
			end
		end
	end)
end

return Interactions
