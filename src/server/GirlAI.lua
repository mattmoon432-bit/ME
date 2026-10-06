--[[
	THE GIRL IN WHITE - server-side AI (Weeping Angel rules).

	  * While she is anywhere in the front half of ANY player's view she is frozen
	    solid: her body is anchored and her animation stops mid-pose. She only moves
	    once she is behind you.
	  * The instant nobody is looking, she lurches toward the nearest player at
	    Config.Girl.Speed, stomping loudly (footsteps are produced client-side from her
	    gait), bursting through closed doors.
	  * If she reaches you: jumpscare, you die, she vanishes and returns later.

	Animation intent is published as model attributes (AnimState, LookTarget, Moving,
	Hidden); every client animates the rig locally.
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local GirlRig = require(Shared.GirlRig)
local SoundLibrary = require(Shared.SoundLibrary)

local Doors = require(script.Parent.Doors)

local GirlAI = {}
GirlAI.__index = GirlAI

local CFG = Config.Girl
local HIDDEN_CFRAME = CFrame.new(-600, -400, -600)
local FLAT = Vector3.new(1, 0, 1)

export type Deps = {
	Kill: (player: Player, girl: any) -> (),
	GetLook: (player: Player) -> Vector3?,
	IsPlaying: (player: Player) -> boolean,
}

function GirlAI.new(map, deps: Deps)
	local self = setmetatable({}, GirlAI)
	self.Map = map
	self.Deps = deps
	self.Active = false
	self.Hidden = true
	self.Busy = false
	self.AppearAt = math.huge
	self.NextGiggle = os.clock() + 20
	self.Frozen = true

	local model = GirlRig.Build()
	model.Name = "Girl"
	model.Parent = Workspace
	self.Model = model
	self.Root = model:WaitForChild("HumanoidRootPart") :: BasePart
	self.Head = model:WaitForChild("Head") :: BasePart
	self.Humanoid = model:WaitForChild("Humanoid") :: Humanoid

	self.Breath = SoundLibrary.Create("Monster", "Breath", self.Head)
	if self.Breath then
		self.Breath:Play()
	end

	self.Path = PathfindingService:CreatePath({
		AgentRadius = 1.6,
		AgentHeight = 7,
		AgentCanJump = false,
		WaypointSpacing = 4,
		Costs = { Door = 1.5 },
	})
	self.Waypoints = nil :: { PathWaypoint }?
	self.WaypointIndex = 1
	self.PathGoal = nil :: Vector3?
	self.PathTime = 0
	self.Pathing = false

	self.RayParams = RaycastParams.new()
	self.RayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.RayParams.FilterDescendantsInstances = { model }
	self.RayParams.IgnoreWater = true

	self:_hide()

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.05 then
			accumulator = 0
			self:_tick()
		end
	end)
	return self
end

---------------------------------------------------------------------------------------------
-- Visibility
---------------------------------------------------------------------------------------------

function GirlAI:_hide()
	self.Hidden = true
	self.Root.Anchored = true
	self.Model:PivotTo(HIDDEN_CFRAME)
	self.Model:SetAttribute("Hidden", true)
	self.Model:SetAttribute("Moving", false)
	self.Model:SetAttribute("AnimState", "Stand")
	self.Model:SetAttribute("LookTarget", Vector3.zero)
	self.Waypoints = nil
	if self.Breath then
		self.Breath.Volume = 0
	end
end

function GirlAI:_appear(floorPosition: Vector3, lookAt: Vector3?)
	local position = floorPosition + Vector3.new(0, GirlRig.RootHeight + 0.05, 0)
	local facing = position + Vector3.new(0, 0, -1)
	if lookAt and ((lookAt - position) * FLAT).Magnitude > 0.1 then
		facing = Vector3.new(lookAt.X, position.Y, lookAt.Z)
	end
	self.Model:PivotTo(CFrame.lookAt(position, facing))
	self.Root.AssemblyLinearVelocity = Vector3.zero
	self.Hidden = false
	self.Frozen = true
	self.Model:SetAttribute("Hidden", false)
	self.Model:SetAttribute("AnimState", "Frozen")
	if self.Breath then
		self.Breath.Volume = self.Breath:GetAttribute("BaseVolume") or 0.6
	end
end

function GirlAI:_characterOf(player: Player): (Model?, BasePart?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = (character:FindFirstChild("Head") or root) :: BasePart?
	return character, root, head
end

function GirlAI:_validTarget(player: Player): boolean
	if not player.Parent or player:GetAttribute("Dead") or not self.Deps.IsPlaying(player) then
		return false
	end
	local _, root = self:_characterOf(player)
	return root ~= nil
end

-- Is this player facing her? Anywhere in the front half of their view counts (walls
-- and props don't matter) - she only moves once she is behind them.
function GirlAI:_watchedBy(player: Player): boolean
	local character, root, head = self:_characterOf(player)
	if not character or not root or not head then
		return false
	end
	local look = self.Deps.GetLook(player) or root.CFrame.LookVector
	local flatLook = look * FLAT
	local dir = (self.Root.Position - head.Position) * FLAT
	if dir.Magnitude < 3 then
		return true
	end
	if dir.Magnitude > CFG.SightRange or flatLook.Magnitude < 0.05 then
		return false
	end
	return flatLook.Unit:Dot(dir.Unit) >= CFG.ViewDot
end

function GirlAI:_isWatched(): boolean
	for _, player in Players:GetPlayers() do
		if self:_validTarget(player) and self:_watchedBy(player) then
			return true
		end
	end
	return false
end

-- Called the moment a player's camera direction arrives: freeze on the spot instead of
-- waiting for the next tick, so turning to face her stops her immediately.
function GirlAI:OnLook()
	if self.Active and not self.Hidden and not self.Busy and not self.Frozen and self:_isWatched() then
		self:_freeze()
	end
end

-- Could any player see this floor position?
function GirlAI:_pointVisible(point: Vector3): boolean
	for _, player in Players:GetPlayers() do
		if self:_validTarget(player) then
			local _, _, head = self:_characterOf(player)
			if head then
				for _, h in { 1, 5.5 } do
					local target = point + Vector3.new(0, h, 0)
					local result = Workspace:Raycast(head.Position, target - head.Position, self.RayParams)
					if result == nil then
						return true
					end
				end
			end
		end
	end
	return false
end

---------------------------------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------------------------------

function GirlAI:_freeze()
	if self.Frozen then
		return
	end
	self.Frozen = true
	self.Humanoid:MoveTo(self.Root.Position)
	self.Root.AssemblyLinearVelocity = Vector3.zero
	self.Root.Anchored = true
	self.Model:SetAttribute("AnimState", "Frozen")
	self.Model:SetAttribute("Moving", false)
end

function GirlAI:_unfreeze()
	if not self.Frozen then
		return
	end
	self.Frozen = false
	self.Root.Anchored = false
	pcall(self.Root.SetNetworkOwner, self.Root, nil)
	self.Model:SetAttribute("AnimState", "Run")
	self.Model:SetAttribute("Moving", true)
end

function GirlAI:_computePath(goal: Vector3)
	if self.Pathing then
		return
	end
	self.Pathing = true
	local start = self.Root.Position
	task.spawn(function()
		local ok = pcall(function()
			self.Path:ComputeAsync(start, goal)
		end)
		if ok and self.Path.Status == Enum.PathStatus.Success then
			self.Waypoints = self.Path:GetWaypoints()
			self.WaypointIndex = math.min(2, #self.Waypoints)
			self.PathGoal = goal
		else
			self.Waypoints = nil
			self.PathGoal = nil
		end
		self.PathTime = os.clock()
		self.Pathing = false
	end)
end

function GirlAI:_moveTowards(goal: Vector3, direct: boolean)
	self.Humanoid.WalkSpeed = CFG.Speed
	if direct then
		self.Waypoints = nil
		self.Humanoid:MoveTo(goal)
		return
	end
	if not self.Waypoints or not self.PathGoal or ((self.PathGoal :: Vector3) - goal).Magnitude > 5 or os.clock() - self.PathTime > 0.6 then
		self:_computePath(goal)
	end
	local waypoints = self.Waypoints
	if waypoints then
		local waypoint = waypoints[self.WaypointIndex]
		while waypoint and ((waypoint.Position - self.Root.Position) * FLAT).Magnitude < 2.5 do
			self.WaypointIndex += 1
			waypoint = waypoints[self.WaypointIndex]
		end
		self.Humanoid:MoveTo(waypoint and waypoint.Position or goal)
	else
		self.Humanoid:MoveTo(goal)
	end
end

-- Closed doors in her way burst open (only ever while nobody is watching).
function GirlAI:_handleDoors()
	local forward = (self.Root.AssemblyLinearVelocity * FLAT)
	if forward.Magnitude < 1 then
		return
	end
	for _, door in Doors.FindClosedNear(self.Root.Position, 5.5) do
		local toDoor = (door.Position - self.Root.Position) * FLAT
		if toDoor.Magnitude < 1.5 or forward.Unit:Dot(toDoor.Unit) > 0.4 then
			door:Smash(self.Root.Position)
		end
	end
end

-- Appear at a node out of everyone's sight, preferring ones near the closest player.
function GirlAI:_reappear(): boolean
	local best, bestScore = nil, math.huge
	for _, node in self.Map.PatrolNodes.Ground do
		local nearest = math.huge
		for _, player in Players:GetPlayers() do
			if self:_validTarget(player) then
				local _, root = self:_characterOf(player)
				if root then
					nearest = math.min(nearest, (root.Position - node).Magnitude)
				end
			end
		end
		if nearest ~= math.huge and nearest >= CFG.MinSpawnDistance and not self:_pointVisible(node) then
			local score = nearest + math.random() * 20
			if score < bestScore then
				best, bestScore = node, score
			end
		end
	end
	if not best then
		return false
	end
	self:_appear(best, nil)
	return true
end

---------------------------------------------------------------------------------------------
-- Control
---------------------------------------------------------------------------------------------

function GirlAI:Reset(active: boolean, delay: number?)
	self.Busy = false
	self.Active = active
	self:_hide()
	self.Frozen = true
	self.AppearAt = os.clock() + (delay or CFG.ActivateDelay)
end

function GirlAI:_tick()
	if not self.Active or self.Busy then
		return
	end
	if self.Hidden then
		if os.clock() >= self.AppearAt and not self:_reappear() then
			self.AppearAt = os.clock() + 1
		end
		return
	end

	-- Nearest living target.
	local target, targetRoot, best = nil, nil, math.huge
	for _, player in Players:GetPlayers() do
		if self:_validTarget(player) then
			local _, root = self:_characterOf(player)
			if root then
				local d = (root.Position - self.Root.Position).Magnitude
				if d < best then
					target, targetRoot, best = player, root, d
				end
			end
		end
	end
	if not target or not targetRoot then
		self:_freeze()
		return
	end

	if self:_isWatched() then
		self:_freeze()
		return
	end

	self:_unfreeze()
	local _, _, head = self:_characterOf(target)
	self.Model:SetAttribute("LookTarget", head and head.Position or targetRoot.Position)

	local dy = math.abs(targetRoot.Position.Y - self.Root.Position.Y)
	if ((targetRoot.Position - self.Root.Position) * FLAT).Magnitude < CFG.CatchDistance and dy < 5 then
		self:_catch(target)
		return
	end

	local result = Workspace:Raycast(self.Head.Position, targetRoot.Position - self.Head.Position, self.RayParams)
	local direct = result == nil or result.Instance:IsDescendantOf(target.Character :: Model)
	self:_moveTowards(targetRoot.Position, direct)
	self:_handleDoors()

	if os.clock() > self.NextGiggle then
		self.NextGiggle = os.clock() + 18 + math.random() * 20
		SoundLibrary.Play("Ambient", "Giggle", self.Head)
	end
end

function GirlAI:_catch(player: Player)
	self.Busy = true
	self:_freeze()
	local pos = self.Root.Position
	local character, root = self:_characterOf(player)
	if character and root then
		self.Root.CFrame = CFrame.lookAt(pos, Vector3.new(root.Position.X, pos.Y, root.Position.Z))
	end
	self.Deps.Kill(player, self)
	task.delay(1.2, function()
		self:_hide()
		self.AppearAt = os.clock() + CFG.RespawnDelay
		self.Busy = false
	end)
end

return GirlAI
