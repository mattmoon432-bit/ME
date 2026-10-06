--[[
	Hollowmere Psychiatric Annex - floor plans.

	The map is generated from a cell grid (CELL studs per cell). Each region is a set of
	rectangles {x0, z0, x1, z1} (inclusive cell coordinates). Walls are created
	automatically wherever a region borders empty space or a different region, except
	where an Edge says otherwise.

	Edge = { ax, az, bx, bz, Type, Label? } between two orthogonally adjacent cells.
	Types: Open, Door, Window, Locked, SafeDoor, SecurityDoor, BasementDoor, ExitDoor, ExitGate

	GROUND FLOOR (y = 0)                         x ->
	   z  0         4                   13      17 18 19
	   1           [=========== Back service corridor ==========]
	   2           [|][Storage ][ ][Office ][ ][Generator ][|]
	   5           [|]  door        door  w       door     [|]
	   6  [ Lobby ][============ East Ward Corridor ============][Security]
	   7  [       ]   [Safe Room]  [ Ward  ]  [S][ Records ]    [        ]
	   9                                       [o]           [Stair]
	  12                                       [uth hall ]===[well ]
]]

local Layout = {}

Layout.CELL = 10

Layout.Floors = {
	Ground = {
		Y = 0,
		Height = 14,
		Regions = {
			{ Id = "Lobby", Kind = "Lobby", Name = "Reception", Rects = { { 0, 4, 3, 8 } } },
			{ Id = "Hall", Kind = "Hallway", Name = "East Ward Corridor", Rects = { { 4, 6, 17, 6 } } },
			{
				Id = "Back",
				Kind = "Service",
				Name = "Service Corridor",
				Rects = { { 4, 1, 17, 1 }, { 4, 2, 4, 5 }, { 17, 2, 17, 5 } },
			},
			{ Id = "Storage", Kind = "Storage", Name = "Storage", Rects = { { 5, 2, 7, 5 } } },
			{ Id = "Office", Kind = "Office", Name = "Dr. Hale's Office", Rects = { { 9, 2, 11, 5 } } },
			{ Id = "Generator", Kind = "Generator", Name = "Generator Room", Rects = { { 13, 2, 16, 5 } } },
			{ Id = "Security", Kind = "Security", Name = "Security Office", Rects = { { 18, 4, 19, 8 } } },
			{ Id = "SafeRoom", Kind = "Safe", Name = "Break Room", Rects = { { 5, 7, 7, 9 } } },
			{ Id = "Ward", Kind = "Ward", Name = "Patient Ward", Rects = { { 9, 7, 11, 10 } } },
			{ Id = "SouthHall", Kind = "Hallway", Name = "South Corridor", Rects = { { 13, 7, 13, 12 }, { 14, 12, 16, 12 } } },
			{ Id = "Records", Kind = "Records", Name = "Records", Rects = { { 14, 7, 16, 10 } } },
			{ Id = "Stairwell", Kind = "StairsTop", Name = "Stairwell", Rects = { { 17, 9, 18, 12 } }, NoFloor = { { 17, 9, 18, 11 } } },
		},
		Edges = {
			{ 3, 6, 4, 6, "Open" },
			{ 0, 6, -1, 6, "ExitDoor", "MAIN ENTRANCE" },
			{ 0, 4, -1, 4, "Window" },
			{ 0, 8, -1, 8, "Window" },
			{ 1, 8, 1, 9, "Window" },
			{ 2, 8, 2, 9, "Window" },
			{ 1, 4, 1, 3, "Window" },
			{ 2, 4, 2, 3, "Window" },
			{ 4, 5, 4, 6, "Open" },
			{ 17, 5, 17, 6, "Open" },
			{ 6, 5, 6, 6, "Door", "STORAGE" },
			{ 10, 5, 10, 6, "Door", "DR. HALE" },
			{ 10, 2, 10, 1, "Door" },
			{ 14, 5, 14, 6, "Door", "GENERATOR" },
			{ 15, 5, 15, 6, "Window" },
			{ 14, 2, 14, 1, "Door" },
			{ 17, 6, 18, 6, "SecurityDoor", "SECURITY" },
			{ 6, 6, 6, 7, "SafeDoor", "BREAK ROOM" },
			{ 10, 6, 10, 7, "Door", "WARD C" },
			{ 13, 6, 13, 7, "Open" },
			{ 13, 8, 14, 8, "Door", "RECORDS" },
			{ 16, 12, 17, 12, "BasementDoor", "BASEMENT" },
			-- Doors that never open (environmental dressing)
			{ 5, 3, 4, 3, "Locked", "STORAGE B" },
			{ 9, 3, 8, 3, "Locked", "ARCHIVE" },
			{ 11, 8, 12, 8, "Locked", "RESTROOM" },
			{ 17, 1, 18, 1, "Locked", "ROOF ACCESS" },
			{ 19, 7, 20, 7, "Window" },
			{ 19, 5, 20, 5, "Window" },
		},
	},

	Basement = {
		Y = -18,
		Height = 14,
		WallTop = 0, -- basement walls extend up through the floor slab
		Regions = {
			{ Id = "StairsBottom", Kind = "StairsBottom", Name = "Stairwell", Rects = { { 17, 8, 18, 11 } }, NoCeiling = { { 17, 9, 18, 11 } } },
			{ Id = "Corridor", Kind = "BasementHall", Name = "Sub-Level Corridor", Rects = { { 6, 8, 16, 8 } } },
			{ Id = "Tunnel", Kind = "Tunnel", Name = "Maintenance Tunnel", Rects = { { 6, -2, 6, 7 } } },
			{ Id = "Boiler", Kind = "Boiler", Name = "Boiler Room", Rects = { { 8, 9, 11, 12 } } },
			{ Id = "Flooded", Kind = "Flooded", Name = "Flooded Storage", Rects = { { 12, 4, 15, 7 } } },
			{ Id = "Pump", Kind = "Pump", Name = "Pump Room", Rects = { { 7, 3, 10, 6 } } },
			{ Id = "Outside", Kind = "Outside", Name = "Riverbank", Rects = { { 4, -7, 8, -3 } }, NoCeiling = { { 4, -7, 8, -3 } } },
		},
		Edges = {
			{ 16, 8, 17, 8, "Open" },
			{ 6, 8, 6, 7, "Open" },
			{ 6, -2, 6, -3, "ExitGate" },
			{ 9, 8, 9, 9, "Door", "BOILER" },
			{ 13, 8, 13, 7, "Door" },
			{ 6, 4, 7, 4, "Door", "PUMP" },
		},
	},
}

-- Stair run connecting the ground stairwell to the basement (world-space description).
Layout.Stairs = {
	X0 = 17, -- cells
	X1 = 18,
	TopZ = 12, -- the top step starts at the south edge of row 9..11 (z = 12 * CELL)
	BottomZ = 9, -- ...and ends at z = 9 * CELL on the basement landing
	TopY = 0,
	BottomY = -18,
}

-- Monster patrol targets per floor (cell coordinates).
Layout.PatrolCells = {
	Ground = {
		{ 2, 6 },
		{ 6, 6 },
		{ 10, 6 },
		{ 15, 6 },
		{ 17, 6 },
		{ 4, 1 },
		{ 10, 1 },
		{ 17, 1 },
		{ 4, 3 },
		{ 17, 3 },
		{ 6, 3 },
		{ 10, 3 },
		{ 14, 3 },
		{ 10, 9 },
		{ 13, 9 },
		{ 13, 12 },
		{ 15, 12 },
		{ 15, 8 },
		{ 19, 6 },
		{ 1, 5 },
	},
	Basement = {
		{ 8, 8 },
		{ 12, 8 },
		{ 16, 8 },
		{ 10, 10 },
		{ 6, 5 },
		{ 13, 6 },
		{ 8, 4 },
	},
}

-- Places where the Grinner can be glimpsed. LookCell = which way it faces by default.
Layout.StalkPoints = {
	{ Name = "HallWestEnd", Cell = { 4, 6 }, Offset = Vector3.new(-2, 0, 0), LookCell = { 12, 6 } },
	{ Name = "HallEastEnd", Cell = { 17, 6 }, Offset = Vector3.new(2, 0, 0), LookCell = { 8, 6 } },
	{ Name = "OfficeDoorway", Cell = { 10, 4 }, Offset = Vector3.new(0, 0, 3), LookCell = { 10, 6 } },
	{ Name = "GeneratorWindow", Cell = { 15, 5 }, Offset = Vector3.new(0, 0, -1.5), LookCell = { 15, 6 } },
	{ Name = "WardDoorway", Cell = { 10, 8 }, Offset = Vector3.new(0, 0, -2), LookCell = { 10, 6 } },
	{ Name = "BackWest", Cell = { 4, 1 }, Offset = Vector3.new(0, 0, 0), LookCell = { 12, 1 } },
	{ Name = "BackEast", Cell = { 17, 1 }, Offset = Vector3.new(0, 0, 0), LookCell = { 8, 1 } },
	{ Name = "SouthHallEnd", Cell = { 13, 12 }, Offset = Vector3.new(0, 0, 2), LookCell = { 13, 7 } },
	{ Name = "LobbyCorner", Cell = { 0, 8 }, Offset = Vector3.new(-2, 0, 2), LookCell = { 3, 5 } },
	{ Name = "RecordsShelves", Cell = { 16, 10 }, Offset = Vector3.new(1, 0, 1), LookCell = { 14, 8 } },
}

return Layout
