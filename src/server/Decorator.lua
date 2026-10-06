--[[
	Furnishes each room and adds environmental storytelling: blood trails that lead
	somewhere, scratch marks around the safe-room door, messages left by staff, a
	sheet-covered gurney, obstacles on the escape route, etc.

	Also records named anchor CFrames (map.Anchors) used by Interactions to place
	objective items, notes and scare props.
]]

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
	-- Floor CFrame `depth` studs from a wall, LookVector pointing into the room.
	local function against(minV: Vector3, maxV: Vector3, side: string, t: number, depth: number): CFrame
		local cf = wall(minV, maxV, side, t, 0, depth)
		return cf
	end
	local function at(minV: Vector3, maxV: Vector3, fx: number, fz: number, yaw: number?): CFrame
		return CFrame.new(lerp(minV.X, maxV.X, fx), minV.Y, lerp(minV.Z, maxV.Z, fz)) * A(0, yaw or 0, 0)
	end

	---------------------------------------------------------------------------------------
	-- LOBBY / RECEPTION
	---------------------------------------------------------------------------------------
	do
		local f = folder("Lobby")
		local mn, mx = map:Bounds("Lobby")
		-- Reception counter facing the entrance.
		local counter = at(mn, mx, 0.62, 0.3, -90)
		Props.Part(f, Vector3.new(12, 3.6, 2.4), counter * CFrame.new(0, 1.8, 0), Color3.fromRGB(70, 48, 36), Enum.Material.WoodPlanks)
		Props.Part(f, Vector3.new(12.4, 0.3, 3), counter * CFrame.new(0, 3.75, 0), Color3.fromRGB(110, 104, 96), Enum.Material.Marble)
		Props.Monitor(f, counter * CFrame.new(-3, 3.9, 0.4), "HOLLOWMERE\nPATIENT INTAKE\n\nSESSION TIMED OUT", false)
		Props.Chair(f, counter * CFrame.new(1, 0, 3) * A(0, 200, 0), true)
		anchors.ReceptionDesk = counter * CFrame.new(3, 3.92, 0)
		Props.Papers(f, (counter * CFrame.new(0, 0, -3)).Position, 4, 10, rng)
		Props.Sign(f, wall(mn, mx, "E", 0.18, 9.5), "HOLLOWMERE PSYCHIATRIC ANNEX", 13, Color3.fromRGB(30, 34, 32))
		-- Waiting area.
		Props.Bench(f, against(mn, mx, "N", 0.3, 1.4))
		Props.Bench(f, against(mn, mx, "S", 0.35, 1.4))
		Props.Bench(f, at(mn, mx, 0.32, 0.55, 90) * CFrame.new(0, 0, 0))
		Props.DeadPlant(f, against(mn, mx, "N", 0.08, 1.2))
		Props.DeadPlant(f, against(mn, mx, "S", 0.08, 1.2))
		Props.VendingMachine(f, against(mn, mx, "S", 0.78, 1.6))
		Props.Clock(f, wall(mn, mx, "N", 0.62, 10, 0.15))
		Props.Chair(f, at(mn, mx, 0.4, 0.75, 40), true)
		-- Story: blood leads from the entrance into the corridor.
		Props.BloodWriting(f, wall(mn, mx, "W", 0.2, 6), "THERE IS NO WAY OUT", 9, rng)
		Props.DragMarks(f, Vector3.new(mn.X + 4, mn.Y, lerp(mn.Z, mx.Z, 0.52)), Vector3.new(mx.X + 2, mn.Y, lerp(mn.Z, mx.Z, 0.52)))
		Props.BloodPool(f, Vector3.new(mn.X + 4, mn.Y, lerp(mn.Z, mx.Z, 0.52)), 1.6, rng)
		Props.FogEmitter(f, CFrame.new((mn + mx) / 2 + Vector3.new(0, 1.2 - (mx.Y - mn.Y) / 2, 0)), Vector3.new(30, 2, 40), 3)
		Props.Dust(f, CFrame.new((mn + mx) / 2), Vector3.new(30, 10, 40))
		anchors.LobbySpawn = CFrame.lookAt(Vector3.new(lerp(mn.X, mx.X, 0.25), mn.Y + 3, lerp(mn.Z, mx.Z, 0.5)), Vector3.new(mx.X + 20, mn.Y + 3, lerp(mn.Z, mx.Z, 0.5)))
		anchors.ExitNote = wall(mn, mx, "W", 0.28, 4.5, 0.1)
	end

	---------------------------------------------------------------------------------------
	-- EAST WARD CORRIDOR (long main hallway)
	---------------------------------------------------------------------------------------
	do
		local f = folder("Hall")
		local mn, mx = map:Bounds("Hall")
		Props.Gurney(f, CFrame.new(lerp(mn.X, mx.X, 0.1), mn.Y, mn.Z + 2) * A(0, 84, 0), true)
		Props.Cart(f, CFrame.new(lerp(mn.X, mx.X, 0.4), mn.Y, mx.Z - 1.8) * A(0, 95, 0), rng)
		Props.Debris(f, CFrame.new(lerp(mn.X, mx.X, 0.55), mn.Y, mn.Z + 2), rng, 0.7)
		Props.Chair(f, CFrame.new(lerp(mn.X, mx.X, 0.66), mn.Y, mx.Z - 2) * A(0, 30, 0), true)
		Props.Papers(f, Vector3.new(lerp(mn.X, mx.X, 0.3), mn.Y, (mn.Z + mx.Z) / 2), 3, 12, rng)
		Props.Papers(f, Vector3.new(lerp(mn.X, mx.X, 0.75), mn.Y, (mn.Z + mx.Z) / 2), 3, 8, rng)
		Props.Puddle(f, Vector3.new(lerp(mn.X, mx.X, 0.85), mn.Y, (mn.Z + mx.Z) / 2 + 1), Vector2.new(5, 3))
		Props.BloodWriting(f, wall(mn, mx, "N", 0.27, 6.5), "DON'T LET IT SEE YOU RUN", 10, rng)
		Props.Scratches(f, wall(mn, mx, "S", 0.6, 5), 5, rng)
		Props.Scratches(f, wall(mn, mx, "N", 0.88, 3.5), 4, rng)
		Props.BloodSmear(f, wall(mn, mx, "S", 0.43, 3.5), Vector2.new(5, 4), rng, true)
		-- drag marks into the ward
		local wardDoorX = 10 * map.CELL + map.CELL / 2
		Props.DragMarks(f, Vector3.new(wardDoorX - 14, mn.Y, mn.Z + 3), Vector3.new(wardDoorX, mn.Y, mx.Z + 1))
		Props.Sign(f, wall(mn, mx, "N", 0.04, 9), "<- RECEPTION", 4)
		Props.Sign(f, wall(mn, mx, "S", 0.96, 9), "SECURITY ->", 4)
		Props.FogEmitter(f, CFrame.new((mn.X + mx.X) / 2, mn.Y + 1, (mn.Z + mx.Z) / 2), Vector3.new(mx.X - mn.X, 2, 8), 5)
		Props.Dust(f, CFrame.new((mn.X + mx.X) / 2, mn.Y + 7, (mn.Z + mx.Z) / 2), Vector3.new(mx.X - mn.X, 10, 8))
		-- The wheelchair that rolls across the corridor (Interactions animates it).
		anchors.Wheelchair = CFrame.new(lerp(mn.X, mx.X, 0.62), mn.Y, mn.Z + 1.6) * A(0, 180, 0)
		anchors.HallMid = CFrame.new(lerp(mn.X, mx.X, 0.5), mn.Y + 3, (mn.Z + mx.Z) / 2)
		anchors.HallEast = CFrame.new(mx.X - 6, mn.Y + 3, (mn.Z + mx.Z) / 2)
		anchors.HallWest = CFrame.new(mn.X + 2, mn.Y, (mn.Z + mx.Z) / 2)
	end

	---------------------------------------------------------------------------------------
	-- SERVICE CORRIDOR (loop behind the rooms)
	---------------------------------------------------------------------------------------
	do
		local f = folder("Back")
		local mn, mx = map:Bounds("Back", 1)
		local pipeY = mn.Y + 12.4
		Props.Pipe(f, Vector3.new(mn.X - 8, pipeY, mn.Z + 1), Vector3.new(mx.X + 8, pipeY, mn.Z + 1), 0.6)
		Props.Pipe(f, Vector3.new(mn.X - 8, pipeY - 1.4, mn.Z + 2.3), Vector3.new(mx.X + 8, pipeY - 1.4, mn.Z + 2.3), 0.35, Color3.fromRGB(60, 70, 80))
		for i = 0, 6 do
			local x = lerp(mn.X, mx.X, i / 6)
			if i % 2 == 0 then
				Props.Locker(f, CFrame.new(x + 3, mn.Y, mn.Z + 1.2) * A(0, 180, 0), i == 4)
			else
				Props.Crate(f, CFrame.new(x, mn.Y, mn.Z + 2) * A(0, rng:NextNumber(0, 40), 0), rng:NextNumber(2.4, 3.4))
			end
		end
		Props.Chain(f, Vector3.new(lerp(mn.X, mx.X, 0.35), mn.Y + 14, (mn.Z + mx.Z) / 2), 7)
		Props.Chain(f, Vector3.new(lerp(mn.X, mx.X, 0.37), mn.Y + 14, (mn.Z + mx.Z) / 2 + 1), 5)
		Props.BloodWriting(f, wall(mn, mx, "S", 0.15, 6), "IT WALKS THESE HALLS", 9, rng)
		Props.BloodSmear(f, wall(mn, mx, "S", 0.7, 3), Vector2.new(4, 3), rng, true)
		Props.Scratches(f, wall(mn, mx, "N", 0.5, 4), 5, rng)
		Props.FogEmitter(f, CFrame.new((mn.X + mx.X) / 2, mn.Y + 1, (mn.Z + mx.Z) / 2), Vector3.new(mx.X - mn.X, 2, 8), 5)
		-- west & east legs
		local wmn, wmx = map:Bounds("Back", 2)
		Props.Barrel(f, CFrame.new(wmn.X + 2, wmn.Y, lerp(wmn.Z, wmx.Z, 0.4)), nil, true)
		Props.Scratches(f, wall(wmn, wmx, "E", 0.6, 4), 4, rng)
		local emn, emx = map:Bounds("Back", 3)
		Props.Crate(f, CFrame.new(emx.X - 2, emn.Y, lerp(emn.Z, emx.Z, 0.3)), 3)
		Props.BloodPool(f, Vector3.new((emn.X + emx.X) / 2, emn.Y, lerp(emn.Z, emx.Z, 0.7)), 1.2, rng)
	end

	---------------------------------------------------------------------------------------
	-- STORAGE (fuse is here)
	---------------------------------------------------------------------------------------
	do
		local f = folder("Storage")
		local mn, mx = map:Bounds("Storage")
		Props.Shelf(f, against(mn, mx, "N", 0.3, 1.2), rng)
		Props.Shelf(f, against(mn, mx, "N", 0.75, 1.2), rng)
		local midShelf = at(mn, mx, 0.35, 0.55, 0)
		Props.Shelf(f, midShelf, rng)
		Props.Shelf(f, against(mn, mx, "W", 0.6, 1.2), rng, 9)
		-- a toppled shelf
		Props.Part(f, Vector3.new(7, 1.2, 9), at(mn, mx, 0.78, 0.6, 20) * CFrame.new(0, 0.6, 0), Props.Colors.RUST, Enum.Material.CorrodedMetal)
		Props.Crate(f, at(mn, mx, 0.85, 0.85, 15), 3)
		Props.Crate(f, at(mn, mx, 0.85, 0.85, 40) * CFrame.new(0, 3, 0), 2.4)
		Props.Barrel(f, at(mn, mx, 0.15, 0.88), Color3.fromRGB(40, 60, 90))
		Props.Barrel(f, at(mn, mx, 0.25, 0.9), Color3.fromRGB(40, 60, 90), true)
		Props.Papers(f, (at(mn, mx, 0.55, 0.75)).Position, 2, 5, rng)
		Props.Scratches(f, wall(mn, mx, "E", 0.3, 5), 4, rng)
		Props.Dust(f, CFrame.new((mn + mx) / 2 + Vector3.new(0, 5, 0)), Vector3.new(26, 10, 36))
		anchors.FuseShelf = midShelf * CFrame.new(1.2, 3.35, 0)
	end

	---------------------------------------------------------------------------------------
	-- DR. HALE'S OFFICE
	---------------------------------------------------------------------------------------
	do
		local f = folder("Office")
		local mn, mx = map:Bounds("Office")
		local desk = at(mn, mx, 0.5, 0.35, 180)
		Props.Desk(f, desk)
		Props.Chair(f, desk * CFrame.new(-0.5, 0, 2.6) * A(0, 170, 0))
		Props.Monitor(f, desk * CFrame.new(-1.5, 3.25, 0.3), "SUBJECT 09\nOBSERVATION LOG\n\n[FILE CORRUPTED]", false)
		anchors.OfficeDesk = desk * CFrame.new(1.2, 3.27, 0.2)
		anchors.OfficeDrawer = desk * CFrame.new(1.6, 2.4, -1.4)
		anchors.Phone = desk * CFrame.new(2.4, 3.25, -0.5)
		Props.FilingCabinet(f, against(mn, mx, "E", 0.2, 1.3), true)
		Props.FilingCabinet(f, against(mn, mx, "E", 0.38, 1.3))
		Props.Shelf(f, against(mn, mx, "W", 0.3, 1.2), rng)
		Props.Sofa(f, against(mn, mx, "W", 0.75, 1.6))
		Props.Papers(f, (at(mn, mx, 0.5, 0.65)).Position, 4, 18, rng)
		Props.Sign(f, wall(mn, mx, "N", 0.5, 8.5), "DR. E. HALE - CLINICAL DIRECTOR", 8)
		Props.BloodWriting(f, wall(mn, mx, "E", 0.75, 6), "HE ONLY SMILES", 8, rng)
		Props.BloodSmear(f, wall(mn, mx, "S", 0.2, 3.5), Vector2.new(3, 3), rng, true)
		Props.Clock(f, wall(mn, mx, "N", 0.15, 10, 0.15))
		Props.Dust(f, CFrame.new((mn + mx) / 2 + Vector3.new(0, 5, 0)), Vector3.new(26, 10, 36))
		anchors.OfficeDoorway = CFrame.new(lerp(mn.X, mx.X, 0.5), mn.Y, mx.Z - 3)
	end

	---------------------------------------------------------------------------------------
	-- GENERATOR ROOM (fuse box)
	---------------------------------------------------------------------------------------
	do
		local f = folder("Generator")
		local mn, mx = map:Bounds("Generator")
		Props.Generator(f, at(mn, mx, 0.32, 0.4, 0))
		Props.Pipe(f, Vector3.new(lerp(mn.X, mx.X, 0.36), mn.Y + 10, lerp(mn.Z, mx.Z, 0.45)), Vector3.new(lerp(mn.X, mx.X, 0.36), mn.Y + 14, lerp(mn.Z, mx.Z, 0.45)), 0.5)
		Props.Pipe(f, Vector3.new(mn.X, mn.Y + 12, mn.Z + 2), Vector3.new(mx.X, mn.Y + 12, mn.Z + 2), 0.55)
		Props.Pipe(f, Vector3.new(mn.X + 1.5, mn.Y, mn.Z + 1.5), Vector3.new(mn.X + 1.5, mn.Y + 14, mn.Z + 1.5), 0.4)
		Props.Barrel(f, at(mn, mx, 0.08, 0.85), Color3.fromRGB(150, 110, 20))
		Props.Barrel(f, at(mn, mx, 0.16, 0.9), Color3.fromRGB(150, 110, 20))
		Props.Cart(f, at(mn, mx, 0.6, 0.15, 90), rng)
		Props.Sign(f, wall(mn, mx, "W", 0.5, 8), "DANGER - HIGH VOLTAGE", 6, Color3.fromRGB(170, 140, 20), Color3.fromRGB(20, 20, 20))
		Props.Scratches(f, wall(mn, mx, "S", 0.25, 4), 4, rng)
		Props.Puddle(f, (at(mn, mx, 0.55, 0.6)).Position, Vector2.new(4, 6), Color3.fromRGB(20, 18, 16))
		-- fuse box on the north wall
		anchors.FuseBox = wall(mn, mx, "N", 0.72, 5, 0.6)
		anchors.GeneratorHum = CFrame.new((at(mn, mx, 0.32, 0.4)).Position + Vector3.new(0, 3, 0))
	end

	---------------------------------------------------------------------------------------
	-- SECURITY OFFICE (basement key)
	---------------------------------------------------------------------------------------
	do
		local f = folder("Security")
		local mn, mx = map:Bounds("Security")
		-- CCTV wall
		for _, y in { 2.05, 4.15 } do
			Props.Part(f, Vector3.new(9, 0.25, 2.2), wall(mn, mx, "E", 0.33, y, 1.3), Color3.fromRGB(50, 52, 56), Enum.Material.Metal)
		end
		local feeds = { "CAM 01  RECEPTION", "CAM 02  E. CORRIDOR", "CAM 03  WARD C", "CAM 04  B1 CORRIDOR", "NO SIGNAL", "CAM 06  TUNNEL" }
		for i, label in feeds do
			local row = (i - 1) // 3
			local col = (i - 1) % 3
			local cf = wall(mn, mx, "E", 0.2 + col * 0.13, 0, 1.2) * CFrame.new(0, 2.18 + row * 2.1, 0)
			Props.Monitor(f, cf, label .. "\n02:13:" .. string.format("%02d", 10 + i * 7), true)
		end
		local desk = against(mn, mx, "E", 0.33, 3.6)
		Props.Desk(f, desk, Color3.fromRGB(60, 62, 66))
		anchors.SecurityDesk = desk * CFrame.new(-1.6, 3.27, 0.3)
		Props.Chair(f, desk * CFrame.new(0.5, 0, -2.4) * A(0, 20, 0), true)
		Props.Locker(f, against(mn, mx, "W", 0.75, 1.2))
		Props.Locker(f, against(mn, mx, "W", 0.85, 1.2), true)
		Props.FilingCabinet(f, against(mn, mx, "S", 0.8, 1.3))
		Props.BloodPool(f, (at(mn, mx, 0.5, 0.6)).Position, 2.2, rng)
		Props.BloodSmear(f, wall(mn, mx, "W", 0.45, 4), Vector2.new(4, 4), rng, true)
		Props.Papers(f, (at(mn, mx, 0.4, 0.4)).Position, 3, 10, rng)
		Props.Sign(f, wall(mn, mx, "S", 0.4, 8.5), "SECURITY - STAFF ONLY", 6)
		-- Key hook board
		local board = wall(mn, mx, "N", 0.7, 5.2, 0.15)
		Props.Part(f, Vector3.new(3, 2, 0.2), board, Color3.fromRGB(80, 60, 40), Enum.Material.Wood)
		for i = 0, 4 do
			Props.Part(f, Vector3.new(0.1, 0.1, 0.4), board * CFrame.new(-1.2 + i * 0.6, 0.3, -0.25), Color3.fromRGB(160, 160, 150), Enum.Material.Metal, {
				CanCollide = false,
			})
		end
		anchors.KeyHook = board * CFrame.new(0, 0.05, -0.38)
		anchors.SecurityInside = CFrame.new(lerp(mn.X, mx.X, 0.5), mn.Y + 3, lerp(mn.Z, mx.Z, 0.5))
	end

	---------------------------------------------------------------------------------------
	-- BREAK ROOM (SAFE ROOM)
	---------------------------------------------------------------------------------------
	do
		local f = folder("SafeRoom")
		local mn, mx = map:Bounds("SafeRoom")
		Props.Sofa(f, against(mn, mx, "S", 0.4, 1.8))
		Props.Table(f, at(mn, mx, 0.4, 0.55))
		Props.Chair(f, at(mn, mx, 0.25, 0.5, 90))
		Props.Chair(f, at(mn, mx, 0.55, 0.45, -100))
		Props.VendingMachine(f, against(mn, mx, "E", 0.3, 1.6))
		Props.Locker(f, against(mn, mx, "W", 0.3, 1.2))
		Props.Locker(f, against(mn, mx, "W", 0.42, 1.2))
		-- rug
		Props.Part(f, Vector3.new(10, 0.06, 7), at(mn, mx, 0.42, 0.55) * CFrame.new(0, 0.03, 0), Color3.fromRGB(110, 40, 36), Enum.Material.Fabric, {
			CanCollide = false,
		})
		-- staff's message: the door is the one thing it can't get through
		local _, gui = Props.WallCanvas(f, wall(mn, mx, "W", 0.75, 5.5), Vector2.new(8, 3))
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.PermanentMarker
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(30, 30, 30)
		label.Text = "STEEL DOOR. IT CAN'T GET IN.\nSTAY QUIET. WAIT FOR IT TO LEAVE."
		label.Parent = gui
		anchors.SafeRoomInside = CFrame.new(lerp(mn.X, mx.X, 0.5), mn.Y + 3, lerp(mn.Z, mx.Z, 0.6))
		anchors.SafeNote = wall(mn, mx, "E", 0.8, 4.5, 0.1)
	end

	---------------------------------------------------------------------------------------
	-- PATIENT WARD
	---------------------------------------------------------------------------------------
	do
		local f = folder("Ward")
		local mn, mx = map:Bounds("Ward")
		for i = 0, 2 do
			local z = lerp(mn.Z, mx.Z, 0.22 + i * 0.28)
			Props.Bed(f, CFrame.new(mn.X + 4.5, mn.Y, z) * A(0, 90, 0), i == 1, true)
			Props.Bed(f, CFrame.new(mx.X - 4.5, mn.Y, z) * A(0, -90, 0), i == 2, i ~= 0)
			Props.IVStand(f, CFrame.new(mn.X + 2, mn.Y, z + 3))
			Props.Curtain(f, CFrame.new(mn.X + 5, mn.Y, z + 4.6), 8, i == 1)
			Props.Curtain(f, CFrame.new(mx.X - 5, mn.Y, z + 4.6), 8, i ~= 1)
		end
		Props.Table(f, at(mn, mx, 0.5, 0.9), 4, 2.5)
		anchors.Radio = at(mn, mx, 0.5, 0.9) * CFrame.new(0, 3.13, 0)
		Props.BloodWriting(f, wall(mn, mx, "S", 0.5, 8), "HE SMILES WHEN HE SEES YOU", 11, rng)
		for i = 1, 5 do
			Props.Scratches(f, wall(mn, mx, i % 2 == 0 and "W" or "E", rng:NextNumber(0.15, 0.85), rng:NextNumber(2, 6)), 3.5, rng)
		end
		Props.BloodPool(f, (at(mn, mx, 0.5, 0.2)).Position, 1.8, rng)
		Props.FogEmitter(f, CFrame.new((mn + mx) / 2 + Vector3.new(0, 1 - (mx.Y - mn.Y) / 2, 0)), Vector3.new(26, 2, 36), 3)
	end

	---------------------------------------------------------------------------------------
	-- SOUTH CORRIDOR (first part of the final chase)
	---------------------------------------------------------------------------------------
	do
		local f = folder("SouthHall")
		local mn, mx = map:Bounds("SouthHall", 1)
		Props.FallenPanel(f, CFrame.new(mn.X + 2.2, mn.Y, lerp(mn.Z, mx.Z, 0.35)))
		Props.Debris(f, CFrame.new(mx.X - 2.5, mn.Y, lerp(mn.Z, mx.Z, 0.62)), rng, 0.6)
		Props.Wheelchair(f, CFrame.new(mn.X + 2.5, mn.Y, lerp(mn.Z, mx.Z, 0.85)) * A(0, 60, 0))
		Props.BloodWriting(f, wall(mn, mx, "E", 0.9, 7), "RUN", 6, rng)
		Props.Scratches(f, wall(mn, mx, "W", 0.5, 4), 4, rng)
		local emn, emx = map:Bounds("SouthHall", 2)
		Props.Cart(f, CFrame.new(lerp(emn.X, emx.X, 0.4), emn.Y, emn.Z + 2) * A(0, 10, 0), rng)
		Props.Chain(f, Vector3.new(lerp(emn.X, emx.X, 0.7), emn.Y + 14, (emn.Z + emx.Z) / 2), 6)
		Props.Sign(f, wall(emn, emx, "S", 0.9, 9), "STAIRS B1 ->", 4)
		Props.FogEmitter(f, CFrame.new((mn.X + mx.X) / 2, mn.Y + 1, (mn.Z + mx.Z) / 2), Vector3.new(8, 2, mx.Z - mn.Z), 4)
	end

	---------------------------------------------------------------------------------------
	-- RECORDS
	---------------------------------------------------------------------------------------
	do
		local f = folder("Records")
		local mn, mx = map:Bounds("Records")
		for i = 0, 2 do
			Props.Shelf(f, at(mn, mx, 0.3 + i * 0.25, 0.35, 90), rng, 9)
		end
		Props.FilingCabinet(f, against(mn, mx, "S", 0.2, 1.3))
		Props.FilingCabinet(f, against(mn, mx, "S", 0.32, 1.3), true)
		Props.FilingCabinet(f, against(mn, mx, "S", 0.44, 1.3))
		Props.Desk(f, against(mn, mx, "N", 0.2, 2.2))
		Props.Papers(f, (at(mn, mx, 0.5, 0.75)).Position, 6, 30, rng)
		anchors.RecordsDesk = against(mn, mx, "N", 0.2, 2.2) * CFrame.new(-1.5, 3.27, 0)
		Props.BloodWriting(f, wall(mn, mx, "E", 0.7, 6), "SUBJECT 09 IS NOT A PATIENT", 10, rng)
		Props.Dust(f, CFrame.new((mn + mx) / 2 + Vector3.new(0, 5, 0)), Vector3.new(26, 10, 36))
	end

	---------------------------------------------------------------------------------------
	-- BASEMENT
	---------------------------------------------------------------------------------------
	do
		local f = folder("Basement")
		local mn, mx = map:Bounds("Corridor")
		local top = mn.Y + 13
		-- pipe runs along both walls with steam leaks
		for _, z in { mn.Z + 0.8, mx.Z - 0.8 } do
			Props.Pipe(f, Vector3.new(mn.X - 4, top - 0.5, z), Vector3.new(mx.X + 14, top - 0.5, z), 0.6)
			Props.Pipe(f, Vector3.new(mn.X - 4, top - 2, z), Vector3.new(mx.X + 14, top - 2, z), 0.35, Color3.fromRGB(70, 80, 90))
		end
		for i = 1, 4 do
			Props.Steam(f, Vector3.new(lerp(mn.X, mx.X, i / 5), top - 0.5, mn.Z + 1.4), Vector3.new(0, -0.6, 1).Unit)
		end
		-- obstacles you have to weave around during the final chase
		Props.Debris(f, CFrame.new(lerp(mn.X, mx.X, 0.78), mn.Y, mn.Z + 2.5), rng, 0.7)
		Props.Crate(f, CFrame.new(lerp(mn.X, mx.X, 0.6), mn.Y, mx.Z - 2) * A(0, 20, 0), 3)
		Props.Barrel(f, CFrame.new(lerp(mn.X, mx.X, 0.42), mn.Y, mn.Z + 2), nil, true)
		Props.Debris(f, CFrame.new(lerp(mn.X, mx.X, 0.25), mn.Y, mx.Z - 2.6), rng, 0.6)
		Props.Chain(f, Vector3.new(lerp(mn.X, mx.X, 0.5), top + 1, (mn.Z + mx.Z) / 2), 6)
		Props.Chain(f, Vector3.new(lerp(mn.X, mx.X, 0.15), top + 1, (mn.Z + mx.Z) / 2 + 1), 8)
		for i = 0, 4 do
			Props.Puddle(f, Vector3.new(lerp(mn.X, mx.X, 0.1 + i * 0.2), mn.Y, (mn.Z + mx.Z) / 2 + rng:NextNumber(-2, 2)), Vector2.new(rng:NextNumber(3, 6), rng:NextNumber(2, 4)))
		end
		Props.BloodWriting(f, wall(mn, mx, "N", 0.6, 6), "IT CAME FROM DOWN HERE", 10, rng)
		Props.DragMarks(f, Vector3.new(mx.X - 4, mn.Y, (mn.Z + mx.Z) / 2), Vector3.new(lerp(mn.X, mx.X, 0.35), mn.Y, (mn.Z + mx.Z) / 2))
		Props.Sign(f, wall(mn, mx, "S", 0.06, 8.5), "<- MAINTENANCE TUNNEL / RIVER OUTFLOW", 8, Color3.fromRGB(150, 120, 20), Color3.fromRGB(20, 20, 20))
		Props.FogEmitter(f, CFrame.new((mn.X + mx.X) / 2, mn.Y + 1, (mn.Z + mx.Z) / 2), Vector3.new(mx.X - mn.X, 2, 8), 6)
		anchors.BasementCorridor = CFrame.new((mn.X + mx.X) / 2, mn.Y + 3, (mn.Z + mx.Z) / 2)

		-- Tunnel
		local tmn, tmx = map:Bounds("Tunnel")
		for i = 0, 6 do
			Props.Puddle(f, Vector3.new((tmn.X + tmx.X) / 2 + rng:NextNumber(-2, 2), tmn.Y, lerp(tmn.Z, tmx.Z, i / 6)), Vector2.new(rng:NextNumber(3, 5), rng:NextNumber(4, 7)))
		end
		Props.Pipe(f, Vector3.new(tmn.X + 0.8, tmn.Y + 11, tmn.Z - 10), Vector3.new(tmn.X + 0.8, tmn.Y + 11, tmx.Z + 6), 0.7)
		for i = 1, 3 do
			Props.Debris(f, CFrame.new(i % 2 == 0 and tmn.X + 2.4 or tmx.X - 2.4, tmn.Y, lerp(tmn.Z, tmx.Z, i / 4)), rng, 0.55)
		end
		Props.Sign(f, wall(tmn, tmx, "E", 0.1, 7), "OUTFLOW ->", 4, Color3.fromRGB(150, 120, 20), Color3.fromRGB(20, 20, 20))
		Props.BloodSmear(f, wall(tmn, tmx, "W", 0.35, 3), Vector2.new(4, 4), rng, true)
		Props.FogEmitter(f, CFrame.new((tmn.X + tmx.X) / 2, tmn.Y + 1, (tmn.Z + tmx.Z) / 2), Vector3.new(8, 2, tmx.Z - tmn.Z), 6)
		anchors.TunnelEnd = CFrame.new((tmn.X + tmx.X) / 2, tmn.Y, tmn.Z + 4)

		-- Boiler room
		local bmn, bmx = map:Bounds("Boiler")
		Props.Boiler(f, at(bmn, bmx, 0.35, 0.5))
		Props.Boiler(f, at(bmn, bmx, 0.7, 0.55))
		Props.Steam(f, (at(bmn, bmx, 0.5, 0.3)).Position + Vector3.new(0, 9, 0), Vector3.new(0.3, -1, 0).Unit)
		Props.Scratches(f, wall(bmn, bmx, "S", 0.5, 4), 5, rng)
		anchors.BoilerRoom = CFrame.new((bmn + bmx) / 2)

		-- Flooded storage
		local fmn, fmx = map:Bounds("Flooded")
		Props.Part(f, Vector3.new(fmx.X - fmn.X, 0.8, fmx.Z - fmn.Z), CFrame.new((fmn.X + fmx.X) / 2, fmn.Y + 0.4, (fmn.Z + fmx.Z) / 2), Color3.fromRGB(22, 30, 30), Enum.Material.Glass, {
			Transparency = 0.2,
			Reflectance = 0.2,
			CanCollide = false,
			CanQuery = false,
		})
		for _ = 1, 5 do
			Props.Crate(f, at(fmn, fmx, rng:NextNumber(0.15, 0.85), rng:NextNumber(0.15, 0.7), rng:NextNumber(0, 90)), rng:NextNumber(2.5, 3.5))
		end
		Props.Barrel(f, at(fmn, fmx, 0.8, 0.8), nil, true)
		Props.BloodWriting(f, wall(fmn, fmx, "N", 0.5, 7), "WE SHOULD NEVER HAVE WOKEN IT", 11, rng)

		-- Pump room
		local pmn, pmx = map:Bounds("Pump")
		for i = 0, 1 do
			Props.Part(f, Vector3.new(6, 4, 4), at(pmn, pmx, 0.35 + i * 0.35, 0.4) * CFrame.new(0, 3, 0) * A(0, 0, 90), Color3.fromRGB(60, 80, 100), Enum.Material.Metal, {
				Shape = Enum.PartType.Cylinder,
			})
			Props.Pipe(f, (at(pmn, pmx, 0.35 + i * 0.35, 0.4)).Position + Vector3.new(0, 6, 0), (at(pmn, pmx, 0.35 + i * 0.35, 0.4)).Position + Vector3.new(0, 14, 0), 0.6)
		end
		Props.Sign(f, wall(pmn, pmx, "N", 0.5, 8), "PUMP STATION 2", 5, Color3.fromRGB(150, 120, 20), Color3.fromRGB(20, 20, 20))
	end

	return anchors
end

return Decorator
