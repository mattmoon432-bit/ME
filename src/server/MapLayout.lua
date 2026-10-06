--[[
	Hollowmere Psychiatric Annex - night shift floor plan.

	The map is generated from a cell grid (CELL studs per cell). Each region is a set of
	rectangles {x0, z0, x1, z1} (inclusive cell coordinates). Walls are created
	automatically wherever a region borders empty space or a different region, except
	where an Edge says otherwise.

	Edge = { ax, az, bx, bz, Type, Label? } between two orthogonally adjacent cells.
	Types: Open, Door, Window, Locked, KeyDoor (needs the storage key),
	       FinalDoor (the "exit" - bricked up behind)

	          x ->  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
	   z  4                    [ STORAGE ]  [RECORDS ]   [ THERAPY  ]
	      6                    [  (key)  ]  [        ]   [          ]
	      7     [LOBBY]========= MAIN CORRIDOR =========================
	      8  EXIT[     ]        |[BREAK  ][ OFFICE ]   [  WARD C   ]|
	     10                    |[ ROOM  ][ (start)]   [  (key)    ]|
	     11                    [========= SERVICE CORRIDOR ==========]
]]

local Layout = {}

Layout.CELL = 10

Layout.Floors = {
	Ground = {
		Y = 0,
		Height = 14,
		Regions = {
			{ Id = "Lobby", Kind = "Lobby", Name = "Reception", Rects = { { 0, 6, 1, 8 } } },
			{ Id = "Hall", Kind = "Hallway", Name = "Main Corridor", Rects = { { 2, 7, 16, 7 } } },
			{ Id = "Back", Kind = "Service", Name = "Service Corridor", Rects = { { 4, 8, 4, 11 }, { 5, 11, 15, 11 }, { 16, 8, 16, 11 } } },
			{ Id = "Office", Kind = "Office", Name = "Night Office", Rects = { { 8, 8, 10, 10 } } },
			{ Id = "Break", Kind = "Safe", Name = "Break Room", Rects = { { 5, 8, 7, 10 } } },
			{ Id = "Ward", Kind = "Ward", Name = "Ward C", Rects = { { 12, 8, 15, 10 } } },
			{ Id = "Storage", Kind = "Storage", Name = "Storage", Rects = { { 4, 4, 6, 6 } } },
			{ Id = "Records", Kind = "Records", Name = "Records", Rects = { { 8, 4, 10, 6 } } },
			{ Id = "Therapy", Kind = "Therapy", Name = "Therapy Room", Rects = { { 12, 4, 15, 6 } } },
		},
		Edges = {
			{ 1, 7, 2, 7, "Open" },
			{ 4, 7, 4, 8, "Open" },
			{ 16, 7, 16, 8, "Open" },
			{ 0, 7, -1, 7, "FinalDoor", "EXIT" },
			{ 9, 7, 9, 8, "Door", "NIGHT OFFICE" },
			{ 6, 7, 6, 8, "Door", "BREAK ROOM" },
			{ 13, 7, 13, 8, "Door", "WARD C" },
			{ 5, 6, 5, 7, "KeyDoor", "STORAGE" },
			{ 9, 6, 9, 7, "Door", "RECORDS" },
			{ 14, 6, 14, 7, "Door", "THERAPY" },
			{ 14, 10, 14, 11, "Door" },
			{ 6, 10, 6, 11, "Door" },
			-- windows
			{ 0, 6, -1, 6, "Window" },
			{ 0, 8, -1, 8, "Window" },
			{ 1, 8, 1, 9, "Window" },
			{ 0, 6, 0, 5, "Window" },
			{ 15, 4, 15, 3, "Window" },
			{ 13, 4, 13, 3, "Window" },
			-- doors that never open
			{ 2, 7, 2, 6, "Locked", "STAIRS - B1" },
			{ 2, 7, 2, 8, "Locked", "ELEVATOR" },
			{ 10, 11, 10, 12, "Locked", "BOILER" },
			{ 16, 7, 17, 7, "Locked", "EAST WING" },
		},
	},
}

-- Where the Girl may appear / wander (cell coordinates).
Layout.PatrolCells = {
	Ground = {
		{ 3, 7 },
		{ 7, 7 },
		{ 11, 7 },
		{ 15, 7 },
		{ 4, 9 },
		{ 16, 9 },
		{ 6, 11 },
		{ 10, 11 },
		{ 14, 11 },
		{ 13, 9 },
		{ 6, 9 },
		{ 9, 5 },
		{ 13, 5 },
		{ 0, 7 },
	},
}

return Layout
