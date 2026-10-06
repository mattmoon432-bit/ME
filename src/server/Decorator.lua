--[[
	Furnishes each room and adds environmental storytelling.

	Every wall-mounted decoration (graffiti, scratches, blood, signs, drawings) goes
	through `onWall`, which raycasts into the wall behind it: if there is no real wall
	(e.g. the spot is a doorway or an open corridor junction) the decoration is skipped
	instead of floating in mid-air.

	Records named anchor CFrames (map.Anchors) for Interactions to place objective items.
]]

local Workspace = game:GetService("Workspace")

local Props = require(script.Parent.Props)

local Decorator = {}

local A = Props.A

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Decorator.Decorate(map)
	local rng = Random.new(777)
	local root = map.Folders.Props
	map.Anchors = {}
	local anchors = map.Anchors

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map.Folders.Structure }

	-- True when there is solid wall behind every part of a decoration `width` wide.
	local function onWall(cf: CFrame, width: number, height: number?): boolean
		local h = (height or 0) / 2
		for _, offset in { Vector3.zero, Vector3.new(-width / 2 * 0.95, 0, 0), Vector3.new(width / 2 * 0.95, 0, 0), Vector3.new(0, h * 0.9, 0), Vector3.new(0, -h * 0.9, 0) } do
			local origin = (cf * CFrame.new(offset)).Position + cf.LookVector * 0.3
			local result = Workspace:Raycast(origin, -cf.LookVector * 1.2, params)
			if not result then
				return false
			end
		end
		return true
	end

	local function folder(name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		return f
	end

	-- Wall-surface CFrame facing into the room. side: N (min Z), S (max Z), W (min X), E (max X)
	local function wall(minV: Vector3, maxV: Vector3, side: string, t: number, height: number, inset: number?): CFrame
		local i = inset or 0.06
		local pos, look
		if side == "N" then
			pos, look = Vector3.new(lerp(minV.X, maxV.X, t), minV.Y + height, minV.Z + i), Vector3.zAxis
		elseif side == "S" then
			pos, look = Vector3.new(lerp(minV.X, maxV.X, t), minV.Y + height, maxV.Z - i), -Vector3.zAxis
		elseif side == "W" then
			pos, look = Vector3.new(minV.X + i, minV.Y + height, lerp(minV.Z, maxV.Z, t)), Vector3.xAxis
		else
			pos, look = Vector3.new(maxV.X - i, minV.Y + height, lerp(minV.Z, maxV.Z, t)), -Vector3.xAxis
		end
		return CFrame.lookAt(pos, pos + look)
	end
	local function against(minV: Vector3, maxV: Vector3, side: string, t: number, depth: number): CFrame
		return wall(minV, maxV, side, t, 0, depth)
	end
	local function at(minV: Vector3, maxV: Vector3, fx: number, fz: number, yaw: number?): CFrame
		return CFrame.new(lerp(minV.X, maxV.X, fx), minV.Y, lerp(minV.Z, maxV.Z, fz)) * A(0, yaw or 0, 0)
	end

	-- Validated wall decorations
	local function writing(parent: Instance, cf: CFrame, text: string, width: number)
		if onWall(cf, width, width * 0.3) then
			Props.BloodWriting(parent, cf, text, width, rng)
		end
	end
	local function scratches(parent: Instance, cf: CFrame, size: number)
		if onWall(cf, size, size) then
			Props.Scratches(parent, cf, size, rng)
		end
	end
	local function smear(parent: Instance, cf: CFrame, size: Vector2, hands: boolean?)
		if onWall(cf, size.X, size.Y) then
			Props.BloodSmear(parent, cf, size, rng, hands)
		end
	end
	local function sign(parent: Instance, cf: CFrame, text: string, width: number, color: Color3?, textColor: Color3?)
		if onWall(cf, width, width * 0.25) then
			Props.Sign(parent, cf * CFrame.new(0, 0, -0.06), text, width, color, textColor)
		end
	end
	-- A child's crayon drawing: a stick figure girl with long hair and a message.
	local function drawing(parent: Instance, cf: CFrame, caption: string)
		if not onWall(cf, 3, 3.6) then
			return
		end
		local _, gui = Props.WallCanvas(parent, cf, Vector2.new(3, 3.6))
		local paper = Instance.new("Frame")
		paper.Size = UDim2.fromScale(1, 1)
		paper.BackgroundColor3 = Color3.fromRGB(220, 214, 196)
		paper.BorderSizePixel = 0
		paper.Rotation = rng:NextNumber(-5, 5)
		paper.Parent = gui
		local function line(x: number, y: number, w: number, h: number, rot: number, color: Color3)
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(x, y)
			f.Size = UDim2.fromScale(w, h)
			f.Rotation = rot
			f.BackgroundColor3 = color
			f.BorderSizePixel = 0
			f.Parent = paper
			return f
		end
		local black, red = Color3.fromRGB(20, 20, 20), Color3.fromRGB(170, 20, 20)
		local head = line(0.5, 0.25, 0.22, 0.18, 0, black)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = head
		line(0.5, 0.5, 0.3, 0.3, 0, Color3.fromRGB(230, 230, 230)) -- white dress
		line(0.5, 0.5, 0.32, 0.02, 0, black)
		line(0.3, 0.45, 0.25, 0.02, -30, black) -- arms reaching
		line(0.7, 0.45, 0.25, 0.02, 30, black)
		line(0.44, 0.73, 0.02, 0.15, 0, black)
		line(0.56, 0.73, 0.02, 0.15, 0, black)
		line(0.5, 0.33, 0.12, 0.02, 0, red) -- smile
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(0.9, 0.14)
		text.Position = UDim2.fromScale(0.05, 0.84)
		text.Font = Enum.Font.IndieFlower
		text.TextScaled = true
		text.TextColor3 = red
		text.Text = caption
		text.Parent = paper
	end

	---------------------------------------------------------------------------------------
	-- NIGHT OFFICE (start)
	---------------------------------------------------------------------------------------
	do
		local f = folder("Office")
		local mn, mx = map:Bounds("Office")
		local desk = against(mn, mx, "S", 0.5, 3)
		Props.Desk(f, desk)
		Props.Chair(f, desk * CFrame.new(0.4, 0, 2.4) * A(0, 180, 0))
		Props.Monitor(f, desk * CFrame.new(-1.6, 3.25, 0.4), "HOLLOWMERE\nNIGHT LOG\n02:13 AM", true)
		anchors.Flashlight = desk * CFrame.new(1.2, 3.27, -0.3)
		anchors.OfficeNote = desk * CFrame.new(-0.2, 3.27, -0.6)
		Props.Part(f, Vector3.new(0.35, 0.45, 0.35), desk * CFrame.new(2.4, 3.48, 0.5), Color3.fromRGB(200, 196, 186), Enum.Material.SmoothPlastic, {
			Shape = Enum.PartType.Cylinder,
			Name = "Mug",
		})
		Props.FilingCabinet(f, against(mn, mx, "E", 0.3, 1.3))
		Props.FilingCabinet(f, against(mn, mx, "E", 0.45, 1.3), true)
		Props.Shelf(f, against(mn, mx, "W", 0.5, 1.2), rng)
		Props.Papers(f, (at(mn, mx, 0.4, 0.55)).Position, 3, 8, rng)
		Props.Clock(f, wall(mn, mx, "E", 0.75, 9, 0.15))
		sign(f, wall(mn, mx, "W", 0.85, 7), "NIGHT STAFF ONLY", 5)
		-- The player starts in the middle of the room, facing the desk.
		local spawnPos = Vector3.new(lerp(mn.X, mx.X, 0.5), mn.Y + 3, lerp(mn.Z, mx.Z, 0.45))
		anchors.Spawn = CFrame.lookAt(spawnPos, Vector3.new(spawnPos.X, spawnPos.Y, mx.Z))
		anchors.OfficeCenter = CFrame.new(lerp(mn.X, mx.X, 0.5), mn.Y, lerp(mn.Z, mx.Z, 0.5))
	end

	---------------------------------------------------------------------------------------
	-- LOBBY (the bricked-up exit)
	---------------------------------------------------------------------------------------
	do
		local f = folder("Lobby")
		local mn, mx = map:Bounds("Lobby")
		local counter = at(mn, mx, 0.62, 0.18, 0)
		Props.Part(f, Vector3.new(8, 3.6, 2.4), counter * CFrame.new(0, 1.8, 0), Color3.fromRGB(70, 48, 36), Enum.Material.WoodPlanks)
		Props.Part(f, Vector3.new(8.4, 0.3, 3), counter * CFrame.new(0, 3.75, 0), Color3.fromRGB(110, 104, 96), Enum.Material.Marble)
		Props.Bench(f, against(mn, mx, "S", 0.25, 1.4))
		Props.DeadPlant(f, against(mn, mx, "E", 0.08, 1.2))
		Props.DeadPlant(f, against(mn, mx, "E", 0.92, 1.2))
		Props.Clock(f, wall(mn, mx, "N", 0.8, 10, 0.15))
		writing(f, wall(mn, mx, "N", 0.78, 6.5), "NO WAY OUT", 6)
		Props.Papers(f, (at(mn, mx, 0.5, 0.6)).Position, 4, 10, rng)
		Props.FogEmitter(f, CFrame.new((mn.X + mx.X) / 2, mn.Y + 1.2, (mn.Z + mx.Z) / 2), Vector3.new(16, 2, 26), 3)
	end

	---------------------------------------------------------------------------------------
	-- MAIN CORRIDOR
	---------------------------------------------------------------------------------------
	do
		local f = folder("Hall")
		local mn, mx = map:Bounds("Hall")
		local function tx(x: number): number
			return (x - mn.X) / (mx.X - mn.X)
		end
		Props.Gurney(f, CFrame.new(72, mn.Y, mn.Z + 2) * A(0, 86, 0), true)
		Props.Wheelchair(f, CFrame.new(112, mn.Y, mx.Z - 2) * A(0, -60, 0))
		Props.Cart(f, CFrame.new(155, mn.Y, mn.Z + 1.8) * A(0, 92, 0), rng)
		Props.Debris(f, CFrame.new(122, mn.Y, mn.Z + 2.2), rng, 0.5)
		Props.Papers(f, Vector3.new(80, mn.Y, (mn.Z + mx.Z) / 2), 3, 12, rng)
		Props.Papers(f, Vector3.new(130, mn.Y, (mn.Z + mx.Z) / 2), 3, 8, rng)
		Props.Puddle(f, Vector3.new(36, mn.Y, (mn.Z + mx.Z) / 2), Vector2.new(5, 3))
		writing(f, wall(mn, mx, "N", tx(120), 7), "SHE IS ALWAYS BEHIND YOU", 12)
		drawing(f, wall(mn, mx, "S", tx(80), 5), "PLAY WITH ME")
		drawing(f, wall(mn, mx, "S", tx(118), 5.2), "DONT LOOK AWAY")
		scratches(f, wall(mn, mx, "N", tx(40), 4.5), 4)
		smear(f, wall(mn, mx, "S", tx(152), 3.5), Vector2.new(4, 4), true)
		Props.DragMarks(f, Vector3.new(118, mn.Y, mn.Z + 3), Vector3.new(135, mn.Y, mx.Z + 1))
		sign(f, wall(mn, mx, "N", tx(32), 9), "<- EXIT", 3)
		Props.FogEmitter(f, CFrame.new((mn.X + mx.X) / 2, mn.Y + 1, (mn.Z + mx.Z) / 2), Vector3.new(mx.X - mn.X, 2, 8), 5)
		Props.Dust(f, CFrame.new((mn.X + mx.X) / 2, mn.Y + 7, (mn.Z + mx.Z) / 2), Vector3.new(mx.X - mn.X, 10, 8))
		anchors.Checkpoint = CFrame.lookAt(Vector3.new(95, mn.Y + 3, (mn.Z + mx.Z) / 2), Vector3.new(60, mn.Y + 3, (mn.Z + mx.Z) / 2))
	end

	---------------------------------------------------------------------------------------
	-- SERVICE CORRIDOR (loop behind the rooms)
	---------------------------------------------------------------------------------------
	do
		local f = folder("Back")
		local mn, mx = map:Bounds("Back", 2)
		local pipeY = mn.Y + 12.4
		Props.Pipe(f, Vector3.new(mn.X - 9, pipeY, mx.Z - 1), Vector3.new(mx.X + 9, pipeY, mx.Z - 1), 0.6)
		Props.Pipe(f, Vector3.new(mn.X - 9, pipeY - 1.4, mx.Z - 2.3), Vector3.new(mx.X + 9, pipeY - 1.4, mx.Z - 2.3), 0.35, Color3.fromRGB(60, 70, 80))
		for _, x in { 56, 78, 90, 122, 132 } do
			Props.Locker(f, CFrame.new(x, mn.Y, mx.Z - 1.2), x == 90)
		end
		Props.Crate(f, CFrame.new(115, mn.Y, mx.Z - 2) * A(0, 20, 0), 3)
		Props.Chain(f, Vector3.new(98, mn.Y + 14, (mn.Z + mx.Z) / 2), 7)
		writing(f, wall(mn, mx, "S", (84 - mn.X) / (mx.X - mn.X), 7.5), "DON'T LOOK AWAY", 9)
		smear(f, wall(mn, mx, "N", (110 - mn.X) / (mx.X - mn.X), 3), Vector2.new(4, 3), true)
		Props.FogEmitter(f, CFrame.new((mn.X + mx.X) / 2, mn.Y + 1, (mn.Z + mx.Z) / 2), Vector3.new(mx.X - mn.X, 2, 8), 5)
		local wmn, wmx = map:Bounds("Back", 1)
		Props.Barrel(f, CFrame.new(wmn.X + 2, wmn.Y, lerp(wmn.Z, wmx.Z, 0.4)), nil, true)
		scratches(f, wall(wmn, wmx, "W", 0.5, 4), 4)
		local emn, emx = map:Bounds("Back", 3)
		Props.Crate(f, CFrame.new(emx.X - 2, emn.Y, lerp(emn.Z, emx.Z, 0.35)), 3)
		Props.BloodPool(f, Vector3.new((emn.X + emx.X) / 2, emn.Y, lerp(emn.Z, emx.Z, 0.7)), 1.2, rng)
	end

	---------------------------------------------------------------------------------------
	-- BREAK ROOM
	---------------------------------------------------------------------------------------
	do
		local f = folder("Break")
		local mn, mx = map:Bounds("Break")
		Props.Sofa(f, against(mn, mx, "W", 0.5, 1.8))
		local table_ = at(mn, mx, 0.55, 0.5)
		Props.Table(f, table_)
		Props.Chair(f, at(mn, mx, 0.55, 0.36, 180))
		Props.Chair(f, at(mn, mx, 0.7, 0.55, -90), true)
		Props.VendingMachine(f, against(mn, mx, "E", 0.3, 1.6))
		Props.Locker(f, against(mn, mx, "E", 0.75, 1.2))
		anchors.BreakNote = table_ * CFrame.new(0.8, 3.13, 0.3)
		drawing(f, wall(mn, mx, "N", 0.25, 5), "SHE MOVES IN THE DARK")
	end

	---------------------------------------------------------------------------------------
	-- WARD C (storage key)
	---------------------------------------------------------------------------------------
	do
		local f = folder("Ward")
		local mn, mx = map:Bounds("Ward")
		for i = 0, 2 do
			local x = lerp(mn.X, mx.X, ({ 0.15, 0.45, 0.85 })[i + 1])
			Props.Bed(f, CFrame.new(x, mn.Y, mx.Z - 4.5), i == 1, true)
			Props.IVStand(f, CFrame.new(x + 3, mn.Y, mx.Z - 2))
			Props.Curtain(f, CFrame.new(x + 4.6, mn.Y, mx.Z - 5) * A(0, 90, 0), 8, i == 2)
		end
		Props.Bed(f, CFrame.new(lerp(mn.X, mx.X, 0.8), mn.Y, mn.Z + 4.5), false, true)
		-- the key lies on the bloody bed in the far corner
		anchors.StorageKey = CFrame.new(lerp(mn.X, mx.X, 0.45), mn.Y + 2.82, mx.Z - 3.8)
		writing(f, wall(mn, mx, "E", 0.5, 7), "SHE WAS HERE FIRST", 9)
		for _ = 1, 4 do
			scratches(f, wall(mn, mx, "W", rng:NextNumber(0.2, 0.8), rng:NextNumber(2, 6)), 3.5)
		end
		Props.BloodPool(f, (at(mn, mx, 0.6, 0.4)).Position, 1.6, rng)
		Props.FogEmitter(f, CFrame.new((mn.X + mx.X) / 2, mn.Y + 1, (mn.Z + mx.Z) / 2), Vector3.new(36, 2, 26), 3)
	end

	---------------------------------------------------------------------------------------
	-- STORAGE (exit key) - padlocked
	---------------------------------------------------------------------------------------
	do
		local f = folder("Storage")
		local mn, mx = map:Bounds("Storage")
		Props.Shelf(f, against(mn, mx, "N", 0.3, 1.2), rng)
		Props.Shelf(f, against(mn, mx, "N", 0.75, 1.2), rng)
		local mid = at(mn, mx, 0.5, 0.5, 0)
		Props.Shelf(f, mid, rng)
		Props.Shelf(f, against(mn, mx, "W", 0.6, 1.2), rng, 9)
		Props.Crate(f, at(mn, mx, 0.85, 0.85, 15), 3)
		Props.Barrel(f, at(mn, mx, 0.15, 0.88), Color3.fromRGB(40, 60, 90))
		Props.Dust(f, CFrame.new((mn + mx) / 2 + Vector3.new(0, 5, 0)), Vector3.new(26, 10, 26))
		-- key B sits on a small table in the open, lit by its own glint
		local stand = at(mn, mx, 0.5, 0.82, 0)
		Props.Table(f, stand, 3, 2)
		anchors.ExitKey = stand * CFrame.new(0, 3.13, 0)
		scratches(f, wall(mn, mx, "E", 0.4, 4), 4)
	end

	---------------------------------------------------------------------------------------
	-- RECORDS
	---------------------------------------------------------------------------------------
	do
		local f = folder("Records")
		local mn, mx = map:Bounds("Records")
		for i = 0, 1 do
			Props.Shelf(f, at(mn, mx, 0.3 + i * 0.4, 0.3, 0), rng, 8)
		end
		Props.FilingCabinet(f, against(mn, mx, "E", 0.5, 1.3))
		Props.FilingCabinet(f, against(mn, mx, "E", 0.62, 1.3), true)
		local desk = against(mn, mx, "W", 0.65, 2.2)
		Props.Desk(f, desk)
		anchors.RecordsNote = desk * CFrame.new(-1.2, 3.27, 0)
		Props.Papers(f, (at(mn, mx, 0.5, 0.7)).Position, 5, 25, rng)
		writing(f, wall(mn, mx, "N", 0.5, 9), "PATIENT 12 NEVER LEFT", 10)
	end

	---------------------------------------------------------------------------------------
	-- THERAPY ROOM (the girl's room: dolls, drawings, music box)
	---------------------------------------------------------------------------------------
	do
		local f = folder("Therapy")
		local mn, mx = map:Bounds("Therapy")
		local center = at(mn, mx, 0.5, 0.5)
		for i = 0, 5 do
			local angle = i / 6 * 360
			local cf = center * A(0, angle, 0) * CFrame.new(0, 0, -7) * A(0, 180, 0)
			Props.Chair(f, cf, i == 4)
			if i ~= 4 then
				Props.Doll(f, cf * CFrame.new(0, 2.05, 0.2))
			end
		end
		Props.Table(f, center, 3, 3)
		anchors.MusicBox = center * CFrame.new(0, 3.13, 0)
		Props.RockingHorse(f, at(mn, mx, 0.15, 0.25, 30))
		Props.Doll(f, at(mn, mx, 0.85, 0.2, 200))
		for i, caption in { "MY ROOM", "DONT LOOK AWAY", "PLAY WITH ME", "BEHIND YOU" } do
			drawing(f, wall(mn, mx, i <= 2 and "W" or "E", i % 2 == 0 and 0.3 or 0.7, 5), caption)
		end
		writing(f, wall(mn, mx, "E", 0.5, 9.5), "SHE WANTS TO PLAY", 9)
	end

	return anchors
end

return Decorator
