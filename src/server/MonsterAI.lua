--[[
	THE GRINNER - server-side AI.

	States
	  DORMANT      hidden; only scripted appearances (before the hunt begins)
	  IDLE         standing, twitching, looking around
	  PATROL       walking between patrol nodes (biased toward the players' area)
	  INVESTIGATE  walking to a noise / something it half-saw
	  STALK        appears in the distance, staring; vanishes when you look away
	  DETECTED     HEAD TURN -> SILENCE -> SCREAM (the signature moment)
	  CHASE        sprinting straight at the target, accelerating
	  ATTACK       caught the target -> jumpscare
	  SEARCH       lost the target; scanning the area
	  SLAM         target reached the safe room; pounds the steel door, then leaves
	  HIDDEN       vanished; reappears later somewhere out of sight

	The server only decides behaviour. Animation intent is published through
	attributes (AnimState / LookTarget) and every client animates the rig locally.
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MonsterRig = require(Shared.MonsterRig)
local Remotes = require(Shared.Remotes)
local SoundLibrary = require(Shared.SoundLibrary)

local Doors = require(script.Parent.Doors)
local Noise = require(script.Parent.Noise)

local MonsterAI = {}
MonsterAI.__index = MonsterAI

local CFG = Config.Monster
local HIDDEN_CFRAME = CFrame.new(-600, -400, -600)
local FLAT = Vector3.new(1, 0, 1)

export type Deps = {
	Kill: (player: Player, monster: any) -> (),
	IsInSafeZone: (player: Player) -> boolean,
	SealSafeRoom: (player: Player) -> any?, -- returns the safe door
	ReleaseSafeRoom: () -> (),
	GetLook: (player: Player) -> Vector3?,
	IsPlaying: (player: Player) -> boolean,
	OnChaseStart: (player: Player, final: boolean) -> (),
	OnChaseEnd: (reason: string) -> (),
}

local function flat(v: Vector3): Vector3
	return v * FLAT
end

function MonsterAI.new(map, deps: Deps)
	local self = setmetatable({}, MonsterAI)
	self.Map = map
	self.Deps = deps
	self.Enabled = false -- free roaming AI (stage 4+)
	self.State = "Dormant"
	self.StateTime = 0
	self.Target = nil :: Player?
	self.Final = false
	self.Suspicion = {} :: { [Player]: number }
	self.LastSeen = 0
	self.LastKnown = nil :: Vector3?
	self.NextStalk = os.clock() + 25
	self.NextGrowl = os.clock() + 12
	self.Busy = false -- a scripted sequence owns the monster
	self.Sequence = 0 -- incremented to cancel running sequences

	local model = MonsterRig.Build()
	model.Name = "Grinner"
	model:SetAttribute("State", "Dormant")
	model.Parent = Workspace
	self.Model = model
	self.Root = model:WaitForChild("HumanoidRootPart") :: BasePart
	self.Head = model:WaitForChild("Head") :: BasePart
	self.Humanoid = model:WaitForChild("Humanoid") :: Humanoid
	pcall(self.Root.SetNetworkOwner, self.Root, nil)

	self.Breath = SoundLibrary.Create("Monster", "Breath", self.Head)
	if self.Breath then
		self.Breath:Play()
	end

	self.Path = PathfindingService:CreatePath({
		AgentRadius = 2.4,
		AgentHeight = 10,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 5,
		Costs = { Door = 2 },
	})
	self.Waypoints = nil :: { PathWaypoint }?
	self.WaypointIndex = 1
	self.PathGoal = nil :: Vector3?
	self.PathTime = 0
	self.Pathing = false
	self.StuckCheck = { Position = Vector3.zero, Time = os.clock() }

	self.RayParams = RaycastParams.new()
	self.RayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.RayParams.FilterDescendantsInstances = { model }
	self.RayParams.IgnoreWater = true

	self:_hide()

	Noise.Emitted:Connect(function(position, radius, source, kind)
		self:_onNoise(position, radius, source, kind)
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			local step = accumulator
			accumulator = 0
			self:_tick(step)
		end
	end)
	return self
end

---------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------

function MonsterAI:_setState(state: string)
	if self.State ~= state then
		self.State = state
		self.StateTime = 0
		self.Model:SetAttribute("State", state)
	end
end

function MonsterAI:_anim(name: string)
	if self.Model:GetAttribute("AnimState") ~= name then
		self.Model:SetAttribute("AnimState", name)
	end
end

function MonsterAI:_look(position: Vector3?)
	self.Model:SetAttribute("LookTarget", position or Vector3.zero)
end

function MonsterAI:_hide()
	self.Root.Anchored = true
	self.Model:PivotTo(HIDDEN_CFRAME)
	self.Model:SetAttribute("Hidden", true)
	self:_look(nil)
	self.Waypoints = nil
	if self.Breath then
		self.Breath.Volume = 0
	end
end

-- Places the monster standing on `floorPosition`, facing `lookAt`.
function MonsterAI:_appear(floorPosition: Vector3, lookAt: Vector3?)
	local position = floorPosition + Vector3.new(0, MonsterRig.RootHeight + 0.1, 0)
	local facing = lookAt and flat(lookAt - floorPosition).Magnitude > 0.1 and Vector3.new(lookAt.X, position.Y, lookAt.Z) or (position + Vector3.new(0, 0, -1))
	self.Model:PivotTo(CFrame.lookAt(position, facing))
	self.Root.AssemblyLinearVelocity = Vector3.zero
	self.Root.Anchored = false
	pcall(self.Root.SetNetworkOwner, self.Root, nil)
	self.Model:SetAttribute("Hidden", false)
	self.Humanoid:MoveTo(self.Root.Position)
	self.Waypoints = nil
	if self.Breath then
		self.Breath.Volume = self.Breath:GetAttribute("BaseVolume") or 0.9
	end
end

function MonsterAI:IsHidden(): boolean
	return self.Model:GetAttribute("Hidden") == true
end

function MonsterAI:_characterOf(player: Player): (Model?, BasePart?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = (character:FindFirstChild("Head") or root) :: BasePart?
	return character, root, head
end

function MonsterAI:_validTarget(player: Player?): boolean
	if not player or not player.Parent or player:GetAttribute("Dead") then
		return false
	end
	if not self.Deps.IsPlaying(player) then
		return false
	end
	local _, root = self:_characterOf(player)
	return root ~= nil
end

-- Line of sight from the monster's eyes to a world point / character.
function MonsterAI:_lineOfSight(from: Vector3, character: Model, to: Vector3): boolean
	local result = Workspace:Raycast(from, to - from, self.RayParams)
	return result == nil or result.Instance:IsDescendantOf(character)
end

-- Can the monster currently see this player? Returns (visible, distance).
function MonsterAI:_canSee(player: Player, ignoreFov: boolean?): (boolean, number)
	local character, root, head = self:_characterOf(player)
	if not character or not root or not head then
		return false, math.huge
	end
	local eye = self.Head.Position
	local offset = head.Position - eye
	local distance = offset.Magnitude
	local range = CFG.SightRange
	if character:GetAttribute("Crouching") then
		range *= 0.55
	end
	if character:GetAttribute("Flashlight") then
		range *= 1.3
	end
	if character:GetAttribute("Sprinting") then
		range *= 1.15
	end
	if not Workspace:GetAttribute("Power") then
		range *= 0.8
	end
	if distance > range then
		return false, distance
	end
	if not ignoreFov and distance > CFG.InstantDetectDistance then
		local facing = flat(self.Root.CFrame.LookVector).Unit
		local dir = flat(offset)
		if dir.Magnitude > 0.01 then
			local angle = math.deg(math.acos(math.clamp(facing:Dot(dir.Unit), -1, 1)))
			if angle > CFG.FieldOfView / 2 then
				return false, distance
			end
		end
	end
	return self:_lineOfSight(eye, character, head.Position), distance
end

-- Is the player looking at the monster right now (camera direction + line of sight)?
function MonsterAI:_isWatchedBy(player: Player): boolean
	local character, root, head = self:_characterOf(player)
	if not character or not root or not head then
		return false
	end
	local look = self.Deps.GetLook(player) or root.CFrame.LookVector
	local target = self.Head.Position - Vector3.new(0, 2.5, 0)
	local dir = target - head.Position
	if dir.Magnitude < 0.1 then
		return true
	end
	if look:Dot(dir.Unit) < 0.72 then
		return false
	end
	local result = Workspace:Raycast(head.Position, dir, self.RayParams)
	return result == nil or result.Instance:IsDescendantOf(character)
end

function MonsterAI:_floorOf(y: number): string
	return y < -8 and "Basement" or "Ground"
end

---------------------------------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------------------------------

function MonsterAI:_computePath(goal: Vector3)
	if self.Pathing then
		return
	end
	self.Pathing = true
	local sequence = self.Sequence
	local start = self.Root.Position
	task.spawn(function()
		local ok = pcall(function()
			self.Path:ComputeAsync(start, goal)
		end)
		if sequence == self.Sequence then
			if ok and self.Path.Status == Enum.PathStatus.Success then
				self.Waypoints = self.Path:GetWaypoints()
				self.WaypointIndex = math.min(2, #self.Waypoints)
				self.PathGoal = goal
				self.PathFailures = 0
			else
				self.Waypoints = nil
				self.PathGoal = nil
				self.PathFailures = (self.PathFailures or 0) + 1
			end
		end
		self.PathTime = os.clock()
		self.Pathing = false
	end)
end

-- Moves toward `goal`. Returns true once arrived.
function MonsterAI:_moveTo(goal: Vector3, speed: number, direct: boolean?, repath: number?): boolean
	local root = self.Root
	self.Humanoid.WalkSpeed = speed
	local offset = goal - root.Position
	if flat(offset).Magnitude < 3.5 and math.abs(offset.Y + MonsterRig.RootHeight) < 7 then
		self.Humanoid:MoveTo(root.Position)
		return true
	end
	if direct then
		self.Waypoints = nil
		self.Humanoid:MoveTo(goal)
		return false
	end
	local needPath = not self.Waypoints
		or not self.PathGoal
		or ((self.PathGoal :: Vector3) - goal).Magnitude > 6
		or os.clock() - self.PathTime > (repath or 3)
	if needPath then
		self:_computePath(goal)
	end
	local waypoints = self.Waypoints
	if waypoints then
		local waypoint = waypoints[self.WaypointIndex]
		while waypoint and flat(waypoint.Position - root.Position).Magnitude < 3 do
			self.WaypointIndex += 1
			waypoint = waypoints[self.WaypointIndex]
		end
		if waypoint then
			self.Humanoid:MoveTo(waypoint.Position)
		else
			self.Waypoints = nil
			self.Humanoid:MoveTo(goal)
		end
	elseif (self.PathFailures or 0) > 2 then
		self.Humanoid:MoveTo(goal) -- path keeps failing: try walking straight
	end
	return false
end

function MonsterAI:_stop()
	self.Humanoid:MoveTo(self.Root.Position)
	self.Humanoid.WalkSpeed = 0
	self.Waypoints = nil
end

-- Doors in the way: opens them politely while roaming, smashes them while chasing.
function MonsterAI:_handleDoors(aggressive: boolean)
	local root = self.Root
	local forward = flat(root.AssemblyLinearVelocity)
	if forward.Magnitude < 1 then
		forward = flat(root.CFrame.LookVector)
	end
	for _, door in Doors.FindClosedNear(root.Position, 7.5) do
		local toDoor = flat(door.Position - root.Position)
		-- only doors it is actually heading into, not ones it walks past
		if toDoor.Magnitude < 2 or forward.Unit:Dot(toDoor.Unit) > (aggressive and 0.5 or 0.65) then
			if aggressive then
				if door:Smash(root.Position) then
					self:_stagger(CFG.DoorSmashStagger)
				end
			elseif not door.Locked and door.Type ~= "SafeDoor" and door.Type ~= "ExitDoor" then
				self:_doorPause(door)
			end
			return
		end
	end
end

function MonsterAI:_stagger(duration: number)
	local sequence = self.Sequence
	self.Busy = true
	self:_anim("Stagger")
	self:_stop()
	task.delay(duration, function()
		if sequence == self.Sequence then
			self.Busy = false
		end
	end)
end

function MonsterAI:_doorPause(door)
	local sequence = self.Sequence
	self.Busy = true
	self:_stop()
	self:_anim("DoorOpen")
	task.delay(0.5, function()
		if sequence ~= self.Sequence then
			return
		end
		door:Open(self.Root.Position)
		task.wait(0.5)
		if sequence == self.Sequence then
			self.Busy = false
		end
	end)
end

function MonsterAI:_stuckCheck(): boolean
	local now = os.clock()
	if now - self.StuckCheck.Time > 3 then
		local moved = (self.Root.Position - self.StuckCheck.Position).Magnitude
		self.StuckCheck = { Position = self.Root.Position, Time = now }
		return moved < 1.5
	end
	return false
end

---------------------------------------------------------------------------------------------
-- Senses
---------------------------------------------------------------------------------------------

function MonsterAI:_onNoise(position: Vector3, radius: number, source: Player?, kind: string)
	if not self.Enabled or self.Busy or self:IsHidden() then
		return
	end
	if not (self.State == "Idle" or self.State == "Patrol" or self.State == "Search" or self.State == "Investigate") then
		return
	end
	if source and not self:_validTarget(source) then
		return
	end
	if source and self.Deps.IsInSafeZone(source) then
		return
	end
	local distance = (position - self.Root.Position).Magnitude
	local hearing = radius * CFG.HearingMultiplier
	if self:_floorOf(position.Y) ~= self:_floorOf(self.Root.Position.Y) then
		hearing *= 0.35
	end
	if distance > hearing then
		return
	end
	if self.State == "Investigate" and self.InvestigateTarget and (self.InvestigateTarget - position).Magnitude < 8 then
		return
	end
	self:_investigate(position, kind == "Sprint" or kind == "Objective")
end

function MonsterAI:_investigate(position: Vector3, urgent: boolean?)
	self.InvestigateTarget = position
	self.InvestigateUrgent = urgent == true
	self.Waypoints = nil
	self:_setState("Investigate")
	if urgent and math.random() < 0.5 then
		self:_growl()
	end
end

function MonsterAI:_growl()
	SoundLibrary.Play("Monster", "Growl", self.Head, { PitchVariance = 0.1 })
end

-- Accumulates suspicion for every visible player; returns a player once detected.
function MonsterAI:_scan(dt: number): Player?
	local best, bestValue = nil, 0
	for _, player in Players:GetPlayers() do
		local value = self.Suspicion[player] or 0
		if self:_validTarget(player) and not self.Deps.IsInSafeZone(player) then
			local visible, distance = self:_canSee(player)
			if visible then
				if distance < CFG.InstantDetectDistance then
					return player
				end
				local closeness = 1 - math.clamp(distance / CFG.SightRange, 0, 1)
				value += dt * CFG.SuspicionRate * (0.6 + closeness * 2.2)
				self.LastKnown = (player.Character :: Model):GetPivot().Position
				self:_look(self.LastKnown)
			else
				value = math.max(0, value - dt * CFG.SuspicionDecay)
			end
		else
			value = 0
		end
		self.Suspicion[player] = value
		if value > bestValue then
			best, bestValue = player, value
		end
	end
	if best and bestValue >= 1 then
		return best
	end
	-- Half-noticed something: walk over to have a look.
	if best and bestValue > 0.35 and self.State ~= "Investigate" and self.LastKnown then
		self:_investigate(self.LastKnown, false)
	end
	return nil
end

---------------------------------------------------------------------------------------------
-- Public control
---------------------------------------------------------------------------------------------

-- Cancels any running sequence and hides the monster.
function MonsterAI:Reset(enabled: boolean)
	self.Sequence += 1
	self.Busy = false
	self.Enabled = enabled
	self.Final = false
	self.Target = nil
	self.Suspicion = {}
	self.Model:SetAttribute("ChaseTarget", 0)
	self:_hide()
	self:_setState(enabled and "Hidden" or "Dormant")
	self.HiddenUntil = os.clock() + 12
	self.NextStalk = os.clock() + math.random(CFG.StalkMinInterval, CFG.StalkMaxInterval)
end

function MonsterAI:SetEnabled(enabled: boolean)
	self.Enabled = enabled
	if enabled and self.State == "Dormant" then
		self:_setState("Hidden")
		self.HiddenUntil = os.clock() + 10
	elseif not enabled and not self.Busy and self.State ~= "Stalk" then
		self:Reset(false)
	end
end

-- Appear at a stalk point and stare. `scripted` glimpses always vanish (never attack).
function MonsterAI:Stalk(pointName: string?, player: Player, scripted: boolean?): boolean
	if self.State == "Chase" or self.State == "Detected" or self.State == "Attack" or self.State == "Slam" then
		return false
	end
	if not self:_validTarget(player) then
		return false
	end
	local _, root, head = self:_characterOf(player)
	if not root or not head then
		return false
	end
	local choice
	local candidates = {}
	for _, point in self.Map.StalkPoints do
		if not pointName or point.Name == pointName then
			table.insert(candidates, point)
		end
	end
	-- Prefer points the player can see but isn't looking at right now.
	local look = self.Deps.GetLook(player) or root.CFrame.LookVector
	local scored = {}
	for _, point in candidates do
		local eye = point.Position + Vector3.new(0, 9, 0)
		local offset = eye - head.Position
		local distance = offset.Magnitude
		local okDistance = pointName ~= nil or (distance > 22 and distance < 120)
		if okDistance and math.abs(point.Position.Y - root.Position.Y) < 10 then
			local result = Workspace:Raycast(head.Position, offset, self.RayParams)
			local visible = result == nil or (result.Position - eye).Magnitude < 2.5
			if visible or pointName then
				local inView = look:Dot(offset.Unit) > 0.55
				table.insert(scored, { Point = point, Score = (visible and 2 or 0) + (inView and 0 or 1) + math.random() })
			end
		end
	end
	table.sort(scored, function(a, b)
		return a.Score > b.Score
	end)
	choice = scored[1] and scored[1].Point
	if not choice then
		return false
	end

	self.Sequence += 1
	local sequence = self.Sequence
	self.Busy = true
	self.Target = player
	self.StalkScripted = scripted == true
	self:_setState("Stalk")
	self:_appear(choice.Position, head.Position)
	self:_anim("Breathing")
	self:_look(head.Position)
	Remotes.Event("ChaseCue"):FireClient(player, "Glimpse", { Position = self.Head.Position })

	task.spawn(function()
		local seenFor, unseenFor, elapsed = 0, 0, 0
		local wasSeen = false
		while sequence == self.Sequence and elapsed < CFG.StalkMaxDuration do
			local dt = task.wait(0.1)
			elapsed += dt
			if not self:_validTarget(player) then
				break
			end
			local _, proot, phead = self:_characterOf(player)
			if not proot or not phead then
				break
			end
			self:_look(phead.Position)
			local watched = self:_isWatchedBy(player)
			if watched then
				seenFor += dt
				unseenFor = 0
				if seenFor > 0.4 then
					wasSeen = true
				end
				self:_stop()
				self:_anim("Breathing")
			else
				unseenFor += dt
				-- It creeps closer while you're not looking.
				if not wasSeen and elapsed > 2 and not scripted then
					self:_anim("SlowWalk")
					self:_moveTo(proot.Position, CFG.StalkSpeed, true)
				end
			end
			local distance = (proot.Position - self.Root.Position).Magnitude
			if wasSeen and unseenFor > 0.25 then
				break -- looked away: it's gone
			end
			if distance < (scripted and 7 or 16) then
				if not scripted and self.Enabled and math.random() < 0.6 then
					self.Busy = false
					self:_detect(player)
					return
				end
				break
			end
		end
		if sequence == self.Sequence then
			self.Busy = false
			self:_vanish()
		end
	end)
	return true
end

-- Signature detection sequence: HEAD TURN -> SILENCE -> SCREAM -> CHASE
function MonsterAI:_detect(player: Player, final: boolean?)
	self.Sequence += 1
	local sequence = self.Sequence
	self.Busy = true
	self.Target = player
	self.Final = final == true
	self:_setState("Detected")
	self:_stop()
	self.Model:SetAttribute("ChaseTarget", player.UserId)
	local function alive(): boolean
		return sequence == self.Sequence and self:_validTarget(player)
	end
	local function cue(name: string)
		Remotes.Event("ChaseCue"):FireAllClients(name, {
			Target = player.UserId,
			Position = self.Head.Position,
			Final = self.Final,
		})
	end
	task.spawn(function()
		-- 1. Freeze. The head slowly turns toward you (MonsterAnimator limits turn speed).
		self:_anim("HeadTurn")
		cue("HeadTurn")
		local t = 0
		while t < CFG.HeadTurnTime do
			t += task.wait(0.05)
			if not alive() then
				break
			end
			local _, _, head = self:_characterOf(player)
			if head then
				self:_look(head.Position)
			end
		end
		if not alive() then
			if sequence == self.Sequence then
				self.Busy = false
				self:_setState("Search")
			end
			return
		end
		-- 2. Total silence.
		cue("Silence")
		task.wait(CFG.SilenceTime)
		if not alive() then
			if sequence == self.Sequence then
				self.Busy = false
				self:_setState("Search")
			end
			return
		end
		-- 3. The body snaps around to match the head, and it screams.
		local _, proot = self:_characterOf(player)
		if proot then
			local pos = self.Root.Position
			self.Root.CFrame = CFrame.lookAt(pos, Vector3.new(proot.Position.X, pos.Y, proot.Position.Z))
		end
		self:_anim("Scream")
		cue("Scream")
		SoundLibrary.Play("Monster", "Scream", self.Head)
		task.wait(CFG.ScreamTime)
		if not alive() then
			if sequence == self.Sequence then
				self.Busy = false
				self:_setState("Search")
			end
			return
		end
		-- 4. Launch.
		self.Busy = false
		self:_startChase(player)
	end)
end

function MonsterAI:_startChase(player: Player)
	self.Target = player
	self.ChaseStart = os.clock()
	self.LastSeen = os.clock()
	self.Waypoints = nil
	self:_setState("Chase")
	self:_anim("AggressiveSprint")
	if self.Breath then
		self.Breath.Volume = 1.6
	end
	self.Deps.OnChaseStart(player, self.Final)
	Remotes.Event("ChaseCue"):FireAllClients("ChaseStart", { Target = player.UserId, Final = self.Final })
end

function MonsterAI:_endChase(reason: string)
	self.Model:SetAttribute("ChaseTarget", 0)
	if self.Breath then
		self.Breath.Volume = self.Breath:GetAttribute("BaseVolume") or 0.9
	end
	self.Deps.OnChaseEnd(reason)
	Remotes.Event("ChaseCue"):FireAllClients("ChaseEnd", { Reason = reason })
end

-- The final, scripted chase: it appears down the hall, turns its head... and runs.
function MonsterAI:StartFinalChase(player: Player, spawnPoint: Vector3)
	self.Sequence += 1
	local sequence = self.Sequence
	self.Enabled = true
	self.Final = true
	self.Busy = true
	self.Target = player
	self:_setState("Stalk")
	-- It stands with its back to you, so the head has to turn all the way around.
	local _, proot = self:_characterOf(player)
	local away = proot and (spawnPoint + flat(spawnPoint - proot.Position).Unit * 10) or nil
	self:_appear(spawnPoint, away)
	self:_anim("Idle")
	task.spawn(function()
		-- Wait until the player can see it (or a few seconds pass).
		local waited = 0
		while sequence == self.Sequence and waited < 5 do
			waited += task.wait(0.1)
			if not self:_validTarget(player) then
				return
			end
			local _, proot, phead = self:_characterOf(player)
			if proot and phead then
				local character = player.Character :: Model
				if self:_lineOfSight(self.Head.Position, character, phead.Position) and waited > 1 then
					break
				end
			end
		end
		if sequence == self.Sequence then
			self.Busy = false
			self:_detect(player, true)
		end
	end)
end

-- Win: it slams against the gate as it closes, then is gone.
function MonsterAI:SlamAtGate(position: Vector3)
	self.Sequence += 1
	local sequence = self.Sequence
	local wasChasing = self.State == "Chase"
	self.Busy = true
	self:_setState("Slam")
	if wasChasing then
		self:_endChase("Escaped")
	end
	task.spawn(function()
		if (self.Root.Position - position).Magnitude > 40 or self:IsHidden() then
			self:_appear(position + Vector3.new(0, 0, 18), position)
		end
		local t = 0
		while sequence == self.Sequence and t < 2.5 do
			t += task.wait(0.1)
			self:_anim("AggressiveSprint")
			if self:_moveTo(position, CFG.FinalMaxSpeed, true) then
				break
			end
		end
		self:_stop()
		self.Root.CFrame = CFrame.lookAt(self.Root.Position, Vector3.new(position.X, self.Root.Position.Y, position.Z - 10))
		self:_anim("DoorSlam")
		for _ = 1, 8 do
			if sequence ~= self.Sequence then
				return
			end
			SoundLibrary.Play("Monster", "Slam", position, { PitchVariance = 0.1 })
			Remotes.Event("ScareEvent"):FireAllClients("Bang", { Position = position })
			task.wait(0.32)
		end
		if sequence == self.Sequence then
			self:Reset(false)
		end
	end)
end

function MonsterAI:_vanish()
	self:_hide()
	self.Target = nil
	self.Final = false
	self:_setState(self.Enabled and "Hidden" or "Dormant")
	self.HiddenUntil = os.clock() + CFG.RespawnAfterVanish * (0.7 + math.random() * 0.6)
end

-- Reappear at a patrol node far from (and out of sight of) every player.
function MonsterAI:_reappear(): boolean
	local nodes = self.Map.PatrolNodes.Ground
	local candidates = {}
	for _, node in nodes do
		local ok = true
		local nearest = math.huge
		for _, player in Players:GetPlayers() do
			local character, root, head = self:_characterOf(player)
			if character and root and head and self:_validTarget(player) then
				local distance = (root.Position - node).Magnitude
				nearest = math.min(nearest, distance)
				if distance < 55 then
					ok = false
					break
				end
				local eye = node + Vector3.new(0, 9, 0)
				local result = Workspace:Raycast(head.Position, eye - head.Position, self.RayParams)
				if result == nil then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(candidates, { Node = node, Distance = nearest })
		end
	end
	if #candidates == 0 then
		return false
	end
	-- Prefer nodes at a "hunting" distance rather than the far corner of the map.
	table.sort(candidates, function(a, b)
		return math.abs(a.Distance - 80) < math.abs(b.Distance - 80)
	end)
	local pick = candidates[math.random(1, math.min(3, #candidates))].Node
	self:_appear(pick, nil)
	self:_setState("Patrol")
	self.PatrolTarget = nil
	return true
end

function MonsterAI:_pickPatrolTarget(): Vector3
	local floor = self:_floorOf(self.Root.Position.Y)
	local nodes = self.Map.PatrolNodes[floor] or self.Map.PatrolNodes.Ground
	-- 55%: head toward the area some player is in (pressure); otherwise wander.
	local players = {}
	for _, player in Players:GetPlayers() do
		local _, root = self:_characterOf(player)
		if root and self:_validTarget(player) and not self.Deps.IsInSafeZone(player) then
			table.insert(players, root.Position)
		end
	end
	if #players > 0 and math.random() < 0.55 then
		local focus = players[math.random(1, #players)]
		local best, bestScore = nil, math.huge
		for _, node in nodes do
			local d = (node - focus).Magnitude
			local score = math.abs(d - 30) + math.random() * 15
			if (node - self.Root.Position).Magnitude > 12 and score < bestScore then
				best, bestScore = node, score
			end
		end
		if best then
			return best
		end
	end
	local choice
	repeat
		choice = nodes[math.random(1, #nodes)]
	until #nodes < 2 or (choice - self.Root.Position).Magnitude > 15
	return choice
end

---------------------------------------------------------------------------------------------
-- Main tick (10 Hz)
---------------------------------------------------------------------------------------------

function MonsterAI:_tick(dt: number)
	self.StateTime += dt
	local state = self.State
	if self.Busy then
		return
	end

	if state == "Dormant" then
		return
	elseif state == "Hidden" then
		if self.Enabled and os.clock() >= (self.HiddenUntil or 0) then
			if not self:_reappear() then
				self.HiddenUntil = os.clock() + 3
			end
		end
		return
	elseif state == "Chase" then
		self:_tickChase(dt)
		return
	elseif state == "Stalk" or state == "Detected" or state == "Attack" or state == "Slam" then
		return
	end

	-- Roaming states share perception.
	local detected = self:_scan(dt)
	if detected then
		self:_detect(detected)
		return
	end

	if os.clock() > self.NextGrowl then
		self.NextGrowl = os.clock() + math.random(14, 26)
		if math.random() < 0.6 then
			self:_growl()
		end
	end

	-- Occasional stalking appearance instead of patrolling.
	if self.Enabled and (state == "Patrol" or state == "Idle") and os.clock() > self.NextStalk then
		self.NextStalk = os.clock() + math.random(CFG.StalkMinInterval, CFG.StalkMaxInterval)
		local watchedByAnyone = false
		for _, player in Players:GetPlayers() do
			if self:_validTarget(player) and self:_isWatchedBy(player) then
				watchedByAnyone = true
			end
		end
		if not watchedByAnyone then
			local players = {}
			for _, player in Players:GetPlayers() do
				if self:_validTarget(player) and not self.Deps.IsInSafeZone(player) then
					table.insert(players, player)
				end
			end
			if #players > 0 and self:Stalk(nil, players[math.random(1, #players)], false) then
				return
			end
		end
	end

	if state == "Idle" then
		self:_stop()
		self:_anim(self.StateTime % 6 < 3 and "Idle" or "LookAround")
		if self.StateTime > (self.IdleDuration or 3) then
			self.PatrolTarget = self:_pickPatrolTarget()
			self:_setState("Patrol")
		end
	elseif state == "Patrol" then
		if not self.PatrolTarget then
			self.PatrolTarget = self:_pickPatrolTarget()
		end
		self:_anim("Walk")
		self:_handleDoors(false)
		if self.Busy then
			return
		end
		if self:_moveTo(self.PatrolTarget, CFG.PatrolSpeed) or self:_stuckCheck() then
			self.PatrolTarget = nil
			self.IdleDuration = 2 + math.random() * 3
			self:_setState("Idle")
		end
	elseif state == "Investigate" then
		local target = self.InvestigateTarget
		if not target then
			self:_setState("Patrol")
			return
		end
		self:_anim(self.InvestigateUrgent and "Sprint" or "Walk")
		self:_look(target + Vector3.new(0, 4, 0))
		self:_handleDoors(false)
		if self.Busy then
			return
		end
		local speed = self.InvestigateUrgent and CFG.InvestigateSpeed * 1.35 or CFG.InvestigateSpeed
		if self:_moveTo(target, speed) or self.StateTime > 20 or self:_stuckCheck() then
			self.SearchCenter = target
			self.SearchPoint = nil
			self:_setState("Search")
		end
	elseif state == "Search" then
		self:_look(nil)
		if not self.SearchPoint or self:_moveTo(self.SearchPoint, CFG.SearchSpeed) then
			-- pause, scan, then pick another spot nearby
			self:_stop()
			self:_anim("Search")
			if self.StateTime % 3 < 0.15 then
				local center = self.SearchCenter or self.Root.Position
				local offset = Vector3.new(math.random(-14, 14), 0, math.random(-14, 14))
				self.SearchPoint = center + offset
			end
		else
			self:_anim("Search")
		end
		if self.StateTime > CFG.SearchTime then
			self.SearchPoint = nil
			self.PatrolTarget = self:_pickPatrolTarget()
			self:_setState("Patrol")
		end
	end
end

function MonsterAI:_tickChase(dt: number)
	local player = self.Target
	if not player or not self:_validTarget(player) then
		self:_endChase("TargetLost")
		self.SearchCenter = self.LastKnown or self.Root.Position
		self:_setState("Search")
		return
	end
	local character, proot = self:_characterOf(player)
	if not character or not proot then
		return
	end

	-- Safe room: the door slams shut behind them and it pounds on the steel.
	if not self.Final and self.Deps.IsInSafeZone(player) then
		self:_slamSafeRoom(player)
		return
	end

	local visible = self:_canSee(player, true)
	if visible then
		self.LastSeen = os.clock()
		self.LastKnown = proot.Position
	elseif not self.Final and os.clock() - self.LastSeen > CFG.LoseTrackTime then
		self:_endChase("Lost")
		self.SearchCenter = self.LastKnown or proot.Position
		self.SearchPoint = self.SearchCenter
		self:_setState("Search")
		self:_growl()
		return
	end

	local elapsed = os.clock() - (self.ChaseStart or os.clock())
	local distance = flat(proot.Position - self.Root.Position).Magnitude
	local dy = math.abs(proot.Position.Y - self.Root.Position.Y)
	local playerSpeed = flat(proot.AssemblyLinearVelocity).Magnitude

	-- Caught.
	if distance < CFG.CatchDistance and dy < 6 then
		self:_attack(player)
		return
	end

	-- Speed model: violent launch, steady acceleration, catch-up when far, and
	-- "on your heels" pressure when close.
	local base = self.Final and CFG.FinalBaseSpeed or CFG.ChaseBaseSpeed
	local maxSpeed = self.Final and CFG.FinalMaxSpeed or CFG.ChaseMaxSpeed
	local burst = self.Final and CFG.FinalBurstSpeed or CFG.BurstSpeed
	local speed = math.min(base + CFG.ChaseRamp * elapsed, maxSpeed)
	if elapsed < CFG.BurstTime or distance > 45 then
		speed = burst
	end
	if distance < CFG.HeelDistance then
		if playerSpeed > CFG.HeelSlowThreshold then
			speed = math.min(speed, playerSpeed * (self.Final and 0.97 or 1.03))
		else
			speed = burst -- you slowed down: it lunges
		end
	end
	self:_anim(speed >= 22 and "AggressiveSprint" or "Sprint")
	self:_look(proot.Position + Vector3.new(0, 1.5, 0))

	self:_handleDoors(true)
	if self.Busy then
		return
	end

	local direct = visible and dy < 4
	self:_moveTo(proot.Position, speed, direct, 0.35)
end

function MonsterAI:_attack(player: Player)
	self.Sequence += 1
	local sequence = self.Sequence
	self.Busy = true
	self:_setState("Attack")
	self:_stop()
	local _, proot = self:_characterOf(player)
	if proot then
		local pos = self.Root.Position
		self.Root.CFrame = CFrame.lookAt(pos, Vector3.new(proot.Position.X, pos.Y, proot.Position.Z))
		self:_look(proot.Position + Vector3.new(0, 1.5, 0))
	end
	self:_anim("Attack")
	self.Deps.Kill(player, self)
	task.spawn(function()
		task.wait(0.45)
		if sequence ~= self.Sequence then
			return
		end
		self:_anim("Grab")
		task.wait(1.6)
		if sequence ~= self.Sequence then
			return
		end
		self:_endChase("Caught")
		self.Busy = false
		self:_vanish()
	end)
end

function MonsterAI:_slamSafeRoom(player: Player)
	self.Sequence += 1
	local sequence = self.Sequence
	self.Busy = true
	self:_setState("Slam")
	local door = self.Deps.SealSafeRoom(player)
	self:_endChase("Safe")
	task.spawn(function()
		if door then
			-- run up to the outside of the door
			local inside = door.RegionA and door.RegionA.Kind == "Safe"
			local outside = door.Position + door.Normal * (inside and -4.5 or 4.5)
			outside = Vector3.new(outside.X, door.Position.Y - door.Height / 2, outside.Z)
			local t = 0
			while sequence == self.Sequence and t < 3 do
				t += task.wait(0.1)
				self:_anim("AggressiveSprint")
				if self:_moveTo(outside, CFG.ChaseBaseSpeed) then
					break
				end
			end
			if sequence ~= self.Sequence then
				return
			end
			self:_stop()
			local pos = self.Root.Position
			self.Root.CFrame = CFrame.lookAt(pos, Vector3.new(door.Position.X, pos.Y, door.Position.Z))
			self:_anim("DoorSlam")
			self:_look(door.Position)
			local hits = math.floor(CFG.SlamDuration / 0.3)
			for _ = 1, hits do
				if sequence ~= self.Sequence then
					return
				end
				SoundLibrary.Play("Monster", "Slam", door.Panels[1], { PitchVariance = 0.12 })
				Remotes.Event("ScareEvent"):FireAllClients("Bang", { Position = door.Position })
				task.wait(0.3)
			end
			-- one last long look... then gone.
			self:_anim("Breathing")
			task.wait(0.8)
		end
		if sequence ~= self.Sequence then
			return
		end
		self.Busy = false
		self:_vanish()
		task.delay(1.5, function()
			self.Deps.ReleaseSafeRoom()
		end)
	end)
end

return MonsterAI
