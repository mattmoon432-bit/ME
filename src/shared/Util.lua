-- Small shared helpers: instance construction, tweening, math, signals.

local TweenService = game:GetService("TweenService")

local Util = {}

-- Util.new("Part", { Size = ..., Parent = ... }, { children })
-- Parent is always assigned last so property changes don't replicate one by one.
function Util.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Util.tween(
	inst: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?,
	repeatCount: number?,
	reverses: boolean?,
	delayTime: number?
): Tween
	local info = TweenInfo.new(
		time,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out,
		repeatCount or 0,
		reverses or false,
		delayTime or 0
	)
	local tween = TweenService:Create(inst, info, props)
	tween:Play()
	return tween
end

function Util.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Frame-rate independent exponential smoothing.
function Util.damp(current: number, target: number, speed: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-speed * dt))
end

function Util.moveTowards(current: number, target: number, maxDelta: number): number
	if math.abs(target - current) <= maxDelta then
		return target
	end
	return current + math.sign(target - current) * maxDelta
end

-- Deterministic 0..1 hash, used for repeatable "random" twitches.
function Util.hash(n: number): number
	local x = math.sin(n * 127.1 + 311.7) * 43758.5453
	return x - math.floor(x)
end

-- Returns a 0..1..0 pulse while frac < width, otherwise 0.
function Util.spike(frac: number, width: number): number
	if frac < width then
		return math.sin(frac / width * math.pi)
	end
	return 0
end

function Util.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Util.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

-- Minimal signal implementation (no BindableEvent overhead, keeps argument identity).
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self._handlers
	table.insert(handlers, fn)
	return {
		Disconnect = function()
			local index = table.find(handlers, fn)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, fn in table.clone(self._handlers) do
		task.spawn(fn, ...)
	end
end

Util.Signal = Signal

return Util
