--[[
	Everything the player can interact with:
	  * the glowing flashlight on the office desk (-> turn-around scare)
	  * the storage key (Ward C) and the padlocked storage door
	  * the exit key (Storage) and the main exit... which is bricked up
	  * readable notes and the therapy-room music box
]]

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local SoundLibrary = require(Shared.SoundLibrary)

local Doors = require(script.Parent.Doors)
local Objectives = require(script.Parent.Objectives)
local Props = require(script.Parent.Props)

local Interactions = {}

local A = Props.A
local YELLOW = Color3.fromRGB(255, 205, 70)

local NOTES = {
	Office = {
		Title = "NIGHT SHIFT - HANDOVER",
		Body = "Quiet night, mostly. The power keeps flickering - keep your flashlight on the desk where you can find it.\n\n"
			.. "If you hear footsteps on the ward when nobody's on the ward... ignore them.\n\n"
			.. "And whatever the patients say about the girl in white: she isn't real. She isn't.",
	},
	Records = {
		Title = "PATIENT 12 - INCIDENT LOG",
		Body = "Patient 12 does not move while she is observed. Staff report she has never once been SEEN moving.\n\n"
			.. "Every time the lights go out, she is somewhere else. Closer.\n\n"
			.. "Keep your eyes on her and back away slowly. Do not turn your back. Do not blink.\n\n"
			.. "(Someone has scrawled underneath:) spare storage key is in WARD C",
	},
	Break = {
		Title = "STICKY NOTE ON THE TABLE",
		Body = "Main entrance key is locked in STORAGE.\nStorage key went missing again.\n\n"
			.. "Also - who keeps drawing those pictures on the walls?",
	},
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
		Remotes.Event("ShowMessage"):FireClient(player, text, duration or 2.5, style)
	else
		Remotes.Event("ShowMessage"):FireAllClients(text, duration or 2.5, style)
	end
end

-- A key model (brass, with a coloured tag) and its glint.
local function makeKey(parent: Instance, cf: CFrame, tagColor: Color3): (Model, BasePart, PointLight)
	local model = Instance.new("Model")
	model.Name = "Key"
	model.Parent = parent
	local brass = Color3.fromRGB(196, 160, 70)
	local base = cf * A(90, 0, 0) -- lying flat
	local ring = Props.Part(model, Vector3.new(0.12, 0.55, 0.55), base * A(0, 90, 0), brass, Enum.Material.Metal, {
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Name = "Ring",
	})
	Props.Part(model, Vector3.new(0.12, 0.9, 0.12), base * CFrame.new(0, -0.65, 0), brass, Enum.Material.Metal, { CanCollide = false })
	Props.Part(model, Vector3.new(0.3, 0.12, 0.1), base * CFrame.new(0.15, -0.95, 0), brass, Enum.Material.Metal, { CanCollide = false })
	Props.Part(model, Vector3.new(0.6, 0.35, 0.05), base * CFrame.new(0.4, 0.2, 0) * A(0, 0, 30), tagColor, Enum.Material.SmoothPlastic, {
		CanCollide = false,
	})
	local glint = Instance.new("PointLight")
	glint.Range = 6
	glint.Brightness = 1
	glint.Color = Color3.fromRGB(255, 225, 150)
	glint.Shadows = false
	glint.Parent = ring
	return model, ring, glint
end

local function setVisible(model: Model, visible: boolean)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = visible and 0 or 1
		elseif p:IsA("Light") then
			p.Enabled = visible
		end
	end
end

function Interactions.Init(map)
	local folder = map.Folders.Interactables
	local anchors = map.Anchors
	local storageDoor = map.DoorsByType.KeyDoor and map.DoorsByType.KeyDoor[1]
	local exitDoor = map.DoorsByType.FinalDoor and map.DoorsByType.FinalDoor[1]

	-------------------------------------------------------------------------------------
	-- NOTES
	-------------------------------------------------------------------------------------
	local function placeNote(cf: CFrame, note)
		local paper = Props.Part(folder, Vector3.new(1.1, 0.04, 1.4), cf * CFrame.new(0, 0.02, 0) * A(0, 12, 0), Props.Colors.PAPER, Enum.Material.SmoothPlastic, {
			CanCollide = false,
			Name = "Note",
		})
		local glint = Instance.new("PointLight")
		glint.Range = 3
		glint.Brightness = 0.4
		glint.Color = Color3.fromRGB(255, 240, 210)
		glint.Shadows = false
		glint.Parent = paper
		local prompt = newPrompt(paper, "Read", "Note", 0, "Note")
		prompt.Triggered:Connect(function(player)
			setAction(player, "Interact")
			SoundLibrary.Play("Player", "Paper")
			Remotes.Event("ShowNote"):FireClient(player, note.Title, note.Body)
		end)
	end
	placeNote(anchors.OfficeNote, NOTES.Office)
	placeNote(anchors.RecordsNote, NOTES.Records)
	placeNote(anchors.BreakNote, NOTES.Break)

	-------------------------------------------------------------------------------------
	-- FLASHLIGHT (glows yellow once the lights die)
	-------------------------------------------------------------------------------------
	local torch = Instance.new("Model")
	torch.Name = "Flashlight"
	torch.Parent = folder
	local torchCF = anchors.Flashlight * CFrame.new(0, 0.25, 0) * A(0, 70, 0)
	local body = Props.Part(torch, Vector3.new(1.4, 0.38, 0.38), torchCF, Color3.fromRGB(30, 30, 32), Enum.Material.Metal, {
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Name = "Body",
	})
	local lens = Props.Part(torch, Vector3.new(0.3, 0.55, 0.55), torchCF * CFrame.new(0.8, 0, 0), Color3.fromRGB(80, 70, 40), Enum.Material.Metal, {
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Name = "Lens",
	})
	local halo = Props.Part(torch, Vector3.new(2.2, 1.2, 1.2), torchCF, YELLOW, Enum.Material.Neon, {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Name = "Halo",
	})
	local glow = Instance.new("PointLight")
	glow.Color = YELLOW
	glow.Range = 10
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = body
	local torchPrompt = newPrompt(body, "Take", "Flashlight", 0, "Pickup")
	torchPrompt.Enabled = false
	local glowing = false
	local function setGlow(on: boolean)
		glowing = on
		torchPrompt.Enabled = on
		if not on then
			glow.Brightness = 0
			halo.Transparency = 1
			lens.Color = Color3.fromRGB(80, 70, 40)
		end
	end
	-- pulse while waiting to be picked up
	task.spawn(function()
		while true do
			if glowing then
				local p = (math.sin(os.clock() * 4) + 1) / 2
				glow.Brightness = 1.2 + p * 1.6
				halo.Transparency = 0.82 - p * 0.12
				lens.Color = YELLOW
			end
			task.wait(0.05)
		end
	end)
	torchPrompt.Triggered:Connect(function(player)
		if Objectives.Stage ~= 1 or Objectives.State.FlashlightTaken then
			return
		end
		Objectives.State.FlashlightTaken = true
		Workspace:SetAttribute("FlashlightTaken", true)
		setAction(player, "Pickup")
		setGlow(false)
		setVisible(torch, false)
		SoundLibrary.Play("Player", "Pickup")
		Objectives.Advance(1, player)
		-- She is waiting behind you. The client triggers the leap when you turn around.
		Remotes.Event("TurnScare"):FireClient(player)
	end)
	Interactions.StartFlashlightGlow = function()
		setGlow(true)
	end

	-------------------------------------------------------------------------------------
	-- STORAGE KEY (Ward C) & STORAGE DOOR
	-------------------------------------------------------------------------------------
	local storageKey, storageKeyRing = makeKey(folder, anchors.StorageKey, Color3.fromRGB(200, 40, 40))
	local storagePrompt = newPrompt(storageKeyRing, "Take", "Storage Key", 0, "Pickup")
	storagePrompt.Triggered:Connect(function(player)
		if Objectives.State.StorageKey or Objectives.Stage < 2 then
			return
		end
		Objectives.State.StorageKey = true
		setAction(player, "Pickup")
		setVisible(storageKey, false)
		storagePrompt.Enabled = false
		SoundLibrary.Play("Player", "KeyJingle")
		message(player, "A rusty key. The tag says STORAGE.", 2.5)
		Objectives.Advance(2, player)
	end)

	-------------------------------------------------------------------------------------
	-- EXIT KEY (Storage)
	-------------------------------------------------------------------------------------
	local exitKey, exitKeyRing = makeKey(folder, anchors.ExitKey, Color3.fromRGB(40, 140, 60))
	local exitPrompt = newPrompt(exitKeyRing, "Take", "Exit Key", 0, "Pickup")
	exitPrompt.Triggered:Connect(function(player)
		if Objectives.State.ExitKey or Objectives.Stage < 3 then
			return
		end
		Objectives.State.ExitKey = true
		setAction(player, "Pickup")
		setVisible(exitKey, false)
		exitPrompt.Enabled = false
		SoundLibrary.Play("Player", "KeyJingle")
		message(player, "MAIN ENTRANCE. This is it. I'm getting out of here.", 3)
		Objectives.Advance(3, player)
	end)

	-------------------------------------------------------------------------------------
	-- LOCKED DOORS
	-------------------------------------------------------------------------------------
	if storageDoor then
		storageDoor.SuppressLockedMessage = true
	end
	if exitDoor then
		exitDoor.SuppressLockedMessage = true
	end
	Doors.LockedInteract:Connect(function(door, player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if door == storageDoor then
			setAction(player, "Door")
			if Objectives.State.StorageKey then
				door:SetLocked(false)
				SoundLibrary.Play("Player", "Unlock", door.Panels[1])
				task.wait(0.4)
				door:Open(root and root.Position or nil, false, player)
			else
				message(player, door.LockedMessage, 2)
			end
		elseif door == exitDoor then
			setAction(player, "Door")
			if Objectives.State.ExitKey and Objectives.Stage == 4 then
				door:SetLocked(false)
				SoundLibrary.Play("Player", "Unlock", door.Panels[1])
				task.wait(0.5)
				-- swing INTO the lobby, revealing what's behind
				door:Open(door.Position - door.Normal * 6, false, player)
				task.wait(0.4)
				Objectives.Set(5, player)
			else
				message(player, door.LockedMessage, 2.5)
			end
		end
	end)

	-------------------------------------------------------------------------------------
	-- MUSIC BOX (therapy room) - plays her lullaby
	-------------------------------------------------------------------------------------
	do
		local boxCF = anchors.MusicBox * CFrame.new(0, 0.35, 0)
		local box = Props.Part(folder, Vector3.new(1, 0.7, 0.8), boxCF, Color3.fromRGB(150, 60, 70), Enum.Material.Wood, { Name = "MusicBox" })
		Props.Part(folder, Vector3.new(0.12, 0.6, 0.12), boxCF * CFrame.new(0, 0.6, 0), Color3.fromRGB(220, 200, 200), Enum.Material.SmoothPlastic, {
			CanCollide = false,
		})
		local prompt = newPrompt(box, "Wind", "Music Box", 0.6, "Interact")
		local playing = false
		prompt.Triggered:Connect(function(player)
			if playing then
				return
			end
			playing = true
			setAction(player, "Interact")
			local tune = SoundLibrary.Create("Ambient", "MusicBox", box)
			if tune then
				tune:Play()
			end
			task.wait(6)
			if tune then
				tune:Destroy()
			end
			SoundLibrary.Play("Ambient", "Giggle", box.Position + Vector3.new(0, 0, 12))
			playing = false
		end)
	end

	-------------------------------------------------------------------------------------
	-- RESET
	-------------------------------------------------------------------------------------
	Objectives.Reset:Connect(function()
		setGlow(false)
		setVisible(torch, true)
		setVisible(storageKey, true)
		storagePrompt.Enabled = true
		setVisible(exitKey, true)
		exitPrompt.Enabled = true
		for _, door in Doors.All do
			door:Close(true)
		end
		if storageDoor then
			storageDoor:SetLocked(true)
		end
		if exitDoor then
			exitDoor:SetLocked(true)
		end
	end)
end

return Interactions
