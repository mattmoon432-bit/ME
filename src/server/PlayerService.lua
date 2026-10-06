--[[
	Player lifecycle: main menu -> PLAY -> spawn at checkpoint, death (jumpscare),
	RESTART / MAIN MENU, movement-state replication (crouch, sprint, flashlight, fear),
	camera look direction (for the "vanishes when you look away" stalking), and
	settings persistence through DataStore.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AnimationIds = require(Shared.AnimationIds)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Objectives = require(script.Parent.Objectives)

local PlayerService = {}
PlayerService.Look = {} :: { [Player]: Vector3 }
PlayerService.Playing = {} :: { [Player]: boolean }
PlayerService.RetryChase = false

local settingsStore = nil
pcall(function()
	settingsStore = DataStoreService:GetDataStore("HollowmereSettings_v1")
end)

local DEFAULT_SETTINGS = {
	Master = 1,
	Music = 0.8,
	SFX = 1,
	Graphics = "High",
	CameraShake = true,
	View = "First",
	Sensitivity = 1,
}

local function sanitizeSettings(input: any): { [string]: any }
	local out = table.clone(DEFAULT_SETTINGS)
	if type(input) ~= "table" then
		return out
	end
	for _, key in { "Master", "Music", "SFX", "Sensitivity" } do
		if type(input[key]) == "number" and input[key] == input[key] then
			out[key] = math.clamp(input[key], 0, key == "Sensitivity" and 2 or 1)
		end
	end
	if input.Graphics == "Low" or input.Graphics == "Medium" or input.Graphics == "High" then
		out.Graphics = input.Graphics
	end
	if type(input.CameraShake) == "boolean" then
		out.CameraShake = input.CameraShake
	end
	if input.View == "First" or input.View == "Third" then
		out.View = input.View
	end
	return out
end

function PlayerService.IsPlaying(player: Player): boolean
	return PlayerService.Playing[player] == true
end

function PlayerService.GetLook(player: Player): Vector3?
	return PlayerService.Look[player]
end

function PlayerService.ActivePlayers(): { Player }
	local list = {}
	for player, playing in PlayerService.Playing do
		if playing and player.Parent and not player:GetAttribute("Dead") and not player:GetAttribute("Won") then
			table.insert(list, player)
		end
	end
	return list
end

function PlayerService.Init(map)
	PlayerService.Map = map

	local function checkpoint(): CFrame
		local anchors = map.Anchors
		local stage = Objectives.Stage
		if stage == 4 and PlayerService.RetryChase then
			return anchors.HallEast
		end
		return anchors.LobbySpawn
	end

	local function setupCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.WalkSpeed = Config.Player.WalkSpeed
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = 4.5
		humanoid.BreakJointsOnDeath = false
		for _, name in { "Crouching", "Sprinting", "Flashlight", "Afraid", "Chased" } do
			character:SetAttribute(name, false)
		end
		character:SetAttribute("Action", "")
		character:SetAttribute("ActionTime", 0)

		-- Locomotion animation ids (stock R15 by default, see AnimationIds.lua).
		local animate = character:FindFirstChild("Animate")
		if animate then
			local walk = animate:FindFirstChild("walk")
			local run = animate:FindFirstChild("run")
			local walkAnim = walk and walk:FindFirstChildOfClass("Animation")
			local runAnim = run and run:FindFirstChildOfClass("Animation")
			if walkAnim and AnimationIds.Player.Walk ~= "" then
				walkAnim.AnimationId = AnimationIds.Player.Walk
			end
			if runAnim and AnimationIds.Player.Run ~= "" then
				runAnim.AnimationId = AnimationIds.Player.Run
			end
		end

		humanoid.Died:Connect(function()
			if not player:GetAttribute("Dead") then
				player:SetAttribute("Dead", true)
				Remotes.Event("PlayerDied"):FireClient(player, "Unknown")
				PlayerService._afterDeath()
			end
		end)
	end

	function PlayerService.Spawn(player: Player)
		player:SetAttribute("Dead", false)
		player:SetAttribute("Won", false)
		PlayerService.Playing[player] = true
		local ok, err = pcall(function()
			-- LoadCharacterAsync is the modern API; fall back for older engines.
			local loader = (player :: any).LoadCharacterAsync
			if loader then
				loader(player)
			else
				player:LoadCharacter()
			end
		end)
		if not ok then
			warn("[PlayerService] LoadCharacter failed: " .. tostring(err))
			return
		end
		local character = player.Character
		if not character then
			return
		end
		setupCharacter(player, character)
		character:PivotTo(checkpoint())
		Remotes.Event("Spawned"):FireClient(player, Objectives.Stage)
		Objectives.SendTo(player)
	end

	function PlayerService.ToMenu(player: Player)
		PlayerService.Playing[player] = false
		player:SetAttribute("Dead", false)
		local character = player.Character
		if character then
			character:Destroy()
			player.Character = nil
		end
		PlayerService._afterDeath()
	end

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("Dead", false)
		local loaded = DEFAULT_SETTINGS
		if settingsStore then
			local ok, data = pcall(function()
				return settingsStore:GetAsync("u_" .. player.UserId)
			end)
			if ok then
				loaded = sanitizeSettings(data)
			end
		end
		Remotes.Event("LoadSettings"):FireClient(player, loaded)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerService.Playing[player] = nil
		PlayerService.Look[player] = nil
		PlayerService._afterDeath()
	end)

	Remotes.Event("RequestPlay").OnServerEvent:Connect(function(player)
		if PlayerService.Playing[player] and player.Character and not player:GetAttribute("Dead") then
			return
		end
		-- Starting fresh after an escape (or alone after a wipe) restarts the run.
		if #PlayerService.ActivePlayers() == 0 and (Objectives.Stage >= 7 or player:GetAttribute("Won")) then
			Objectives.ResetRun()
		end
		PlayerService.Spawn(player)
	end)

	Remotes.Event("RequestRestart").OnServerEvent:Connect(function(player)
		if not player:GetAttribute("Dead") and not player:GetAttribute("Won") then
			return
		end
		if player:GetAttribute("Won") and #PlayerService.ActivePlayers() == 0 then
			Objectives.ResetRun()
		end
		PlayerService.Spawn(player)
	end)

	Remotes.Event("RequestMenu").OnServerEvent:Connect(function(player)
		PlayerService.ToMenu(player)
	end)

	Remotes.Event("SetMoveState").OnServerEvent:Connect(function(player, state)
		local character = player.Character
		if not character or type(state) ~= "table" then
			return
		end
		for _, key in { "Crouching", "Sprinting", "Flashlight", "Afraid" } do
			if type(state[key]) == "boolean" then
				character:SetAttribute(key, state[key])
			end
		end
	end)

	Remotes.Event("CameraLook").OnServerEvent:Connect(function(player, look)
		if typeof(look) == "Vector3" and look.Magnitude > 0.5 and look.Magnitude < 1.5 then
			PlayerService.Look[player] = look.Unit
		end
	end)

	local lastSave: { [Player]: number } = {}
	Remotes.Event("SaveSettings").OnServerEvent:Connect(function(player, data)
		if not settingsStore then
			return
		end
		local now = os.clock()
		if lastSave[player] and now - lastSave[player] < 6 then
			return
		end
		lastSave[player] = now
		local clean = sanitizeSettings(data)
		task.spawn(function()
			pcall(function()
				settingsStore:SetAsync("u_" .. player.UserId, clean)
			end)
		end)
	end)
end

-- The monster caught `player`.
function PlayerService.Kill(player: Player, monster)
	if player:GetAttribute("Dead") then
		return
	end
	player:SetAttribute("Dead", true)
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpHeight = 0
		end
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.Anchored = true
		end
		character:SetAttribute("Afraid", true)
	end
	Remotes.Event("Jumpscare"):FireClient(player, monster.Root.CFrame)
	PlayerService._afterDeath()
end

-- When nobody is left alive in the final chase, roll back to "Find the basement key".
function PlayerService._afterDeath()
	task.delay(2, function()
		if #PlayerService.ActivePlayers() == 0 and Objectives.Stage >= 5 and Objectives.Stage < 7 then
			PlayerService.RetryChase = true
			Objectives.RollbackTo(4)
		end
	end)
end

function PlayerService.MarkWon()
	for player, playing in PlayerService.Playing do
		if playing then
			player:SetAttribute("Won", true)
		end
	end
	Workspace:SetAttribute("ChaseActive", false)
end

return PlayerService
