--[[
	Noise events the monster can hear: footsteps, sprinting, doors, objective
	interactions. MonsterAI subscribes to Noise.Emitted.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Noise = {}

-- (position: Vector3, radius: number, source: Player?, kind: string)
Noise.Emitted = Util.Signal.new()

function Noise.Emit(position: Vector3, radius: number, source: Player?, kind: string?)
	if radius <= 0 then
		return
	end
	Noise.Emitted:Fire(position, radius, source, kind or "Generic")
end

-- Movement noise sampled from every living player.
function Noise.StartMovementNoise()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.45 then
			return
		end
		accumulator = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and character and not player:GetAttribute("Dead") then
				local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
				if character:GetAttribute("Crouching") then
					continue
				end
				if character:GetAttribute("Sprinting") and speed > Config.Player.WalkSpeed + 2 then
					Noise.Emit(root.Position, Config.Noise.Sprint, player, "Sprint")
				elseif speed > 4 then
					Noise.Emit(root.Position, Config.Noise.Walk, player, "Walk")
				end
			end
		end
	end)
end

return Noise
