--[[
	Generates the facility from MapLayout:
	  * floors / ceilings per cell (with broken ceiling tiles in corridors)
	  * two-tone institutional walls (tiled lower half, plaster upper half, trims),
	    each face styled by the room it belongs to
	  * door / window openings, pillars at every wall junction
	  * light fixtures with randomised failure modes
	  * the stairwell, the exterior grounds, the riverbank exit and the menu set
	Returns a `map` table describing regions, doors, patrol nodes and stalk points.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Doors = require(script.Parent.Doors)
local Layout = require(script.Parent.MapLayout)
local Props = require(script.Parent.Props)

local MapBuilder = {}

local C = Layout.CELL
local T = 1 -- total wall thickness (two 0.5 layers, one per side)
local DOOR_W, DOOR_H = 6, 10.5
local WIN_W, WIN_SILL, WIN_TOP = 6.4, 3.4, 8.8
local BAND = 4.5 -- height where the lower wall finish meets the upper one

local A = Props.A

type Finish = { Material: Enum.Material, Color: Color3 }
type Style = { Floor: Finish, Lower: Finish, Upper: Finish, Ceiling: Finish, Trim: Color3 }

local function F(material: Enum.Material, r: number, g: number, b: number): Finish
	return { Material = material, Color = Color3.fromRGB(r, g, b) }
end

local M = Enum.Material
local STYLES: { [string]: Style } = {
	Lobby = { Floor = F(M.Marble, 58, 56, 54), Lower = F(M.WoodPlanks, 68, 46, 34), Upper = F(M.Plaster, 116, 106, 92), Ceiling = F(M.Plaster, 96, 92, 86), Trim = Color3.fromRGB(40, 28, 22) },
	Hallway = { Floor = F(M.CeramicTiles, 84, 90, 86), Lower = F(M.CeramicTiles, 64, 84, 74), Upper = F(M.Plaster, 138, 136, 120), Ceiling = F(M.Plaster, 104, 104, 98), Trim = Color3.fromRGB(38, 44, 40) },
	Service = { Floor = F(M.Concrete, 70, 70, 68), Lower = F(M.Concrete, 82, 84, 82), Upper = F(M.Concrete, 96, 96, 92), Ceiling = F(M.Concrete, 70, 70, 68), Trim = Color3.fromRGB(44, 44, 44) },
	Storage = { Floor = F(M.Concrete, 74, 72, 68), Lower = F(M.Brick, 92, 76, 66), Upper = F(M.Concrete, 98, 96, 90), Ceiling = F(M.Concrete, 76, 76, 72), Trim = Color3.fromRGB(50, 44, 40) },
	Office = { Floor = F(M.Carpet, 62, 40, 40), Lower = F(M.WoodPlanks, 80, 58, 42), Upper = F(M.Plaster, 128, 118, 100), Ceiling = F(M.Plaster, 110, 106, 98), Trim = Color3.fromRGB(46, 32, 24) },
	Generator = { Floor = F(M.DiamondPlate, 72, 74, 76), Lower = F(M.Metal, 62, 66, 68), Upper = F(M.Concrete, 90, 90, 88), Ceiling = F(M.Concrete, 70, 70, 70), Trim = Color3.fromRGB(150, 120, 20) },
	Security = { Floor = F(M.CeramicTiles, 70, 74, 80), Lower = F(M.Metal, 56, 60, 68), Upper = F(M.Plaster, 108, 114, 120), Ceiling = F(M.Plaster, 96, 100, 104), Trim = Color3.fromRGB(34, 38, 44) },
	Safe = { Floor = F(M.WoodPlanks, 92, 70, 50), Lower = F(M.WoodPlanks, 96, 72, 52), Upper = F(M.Plaster, 150, 132, 104), Ceiling = F(M.Plaster, 120, 112, 100), Trim = Color3.fromRGB(56, 40, 28) },
	Ward = { Floor = F(M.CeramicTiles, 118, 120, 116), Lower = F(M.CeramicTiles, 126, 134, 128), Upper = F(M.Plaster, 156, 154, 146), Ceiling = F(M.Plaster, 128, 128, 122), Trim = Color3.fromRGB(70, 80, 76) },
	Records = { Floor = F(M.Carpet, 50, 52, 60), Lower = F(M.WoodPlanks, 74, 54, 40), Upper = F(M.Plaster, 120, 116, 104), Ceiling = F(M.Plaster, 100, 98, 92), Trim = Color3.fromRGB(40, 30, 24) },
	StairsTop = { Floor = F(M.Concrete, 72, 72, 70), Lower = F(M.Concrete, 80, 80, 78), Upper = F(M.Concrete, 92, 92, 88), Ceiling = F(M.Concrete, 70, 70, 68), Trim = Color3.fromRGB(150, 120, 20) },
	StairsBottom = { Floor = F(M.Concrete, 60, 60, 58), Lower = F(M.Concrete, 70, 70, 68), Upper = F(M.Concrete, 82, 82, 78), Ceiling = F(M.Concrete, 60, 60, 58), Trim = Color3.fromRGB(150, 120, 20) },
	BasementHall = { Floor = F(M.Concrete, 54, 54, 52), Lower = F(M.Brick, 72, 50, 42), Upper = F(M.Concrete, 74, 74, 70), Ceiling = F(M.Concrete, 50, 50, 48), Trim = Color3.fromRGB(36, 34, 32) },
	Tunnel = { Floor = F(M.Concrete, 44, 48, 46), Lower = F(M.Rock, 58, 58, 56), Upper = F(M.Rock, 64, 64, 60), Ceiling = F(M.Rock, 50, 50, 48), Trim = Color3.fromRGB(30, 32, 30) },
	Boiler = { Floor = F(M.DiamondPlate, 60, 58, 56), Lower = F(M.Brick, 80, 52, 40), Upper = F(M.Concrete, 78, 76, 72), Ceiling = F(M.Concrete, 54, 52, 50), Trim = Color3.fromRGB(40, 30, 26) },
	Flooded = { Floor = F(M.Concrete, 40, 44, 44), Lower = F(M.CorrodedMetal, 70, 64, 56), Upper = F(M.Concrete, 70, 72, 70), Ceiling = F(M.Concrete, 50, 52, 52), Trim = Color3.fromRGB(30, 30, 30) },
	Pump = { Floor = F(M.DiamondPlate, 64, 66, 68), Lower = F(M.Metal, 60, 64, 66), Upper = F(M.Concrete, 76, 76, 74), Ceiling = F(M.Concrete, 56, 56, 56), Trim = Color3.fromRGB(150, 120, 20) },
	Outside = { Floor = F(M.Mud, 52, 46, 36), Lower = F(M.Rock, 66, 64, 60), Upper = F(M.Rock, 70, 68, 62), Ceiling = F(M.Rock, 60, 60, 60), Trim = Color3.fromRGB(50, 50, 50) },
}
local EXTERIOR: Style = { Floor = F(M.Ground, 40, 40, 36), Lower = F(M.Brick, 74, 50, 42), Upper = F(M.Brick, 80, 56, 46), Ceiling = F(M.Concrete, 60, 60, 60), Trim = Color3.fromRGB(40, 36, 34) }

local function key(x: number, z: number): string
	return x .. "," .. z
end

local function edgeKey(ax: number, az: number, bx: number, bz: number): string
	if ax < bx or (ax == bx and az < bz) then
		return key(ax, az) .. "|" .. key(bx, bz)
	end
	return key(bx, bz) .. "|" .. key(ax, az)
end

local function inRects(rects: { { number } }?, x: number, z: number): boolean
	if not rects then
		return false
	end
	for _, r in rects do
		if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then
			return true
		end
	end
	return false
end

local function vary(color: Color3, rng: Random, amount: number): Color3
	local k = 1 + rng:NextNumber(-amount, amount)
	return Color3.new(math.clamp(color.R * k, 0, 1), math.clamp(color.G * k, 0, 1), math.clamp(color.B * k, 0, 1))
end

---------------------------------------------------------------------------------------------

function MapBuilder.Build()
	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Map"
	local folders = {}
	for _, name in { "Structure", "Lights", "Props", "Doors", "Interactables", "Zones", "Exterior", "MenuSet" } do
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		folders[name] = f
	end

	local rng = Random.new(1313)
	local map = {
		Folder = root,
		Folders = folders,
		CELL = C,
		Regions = {} :: { [string]: any },
		RegionList = {} :: { any },
		Floors = {} :: { [string]: any },
		Doors = {} :: { any },
		DoorsByType = {} :: { [string]: { any } },
		PatrolNodes = {} :: { [string]: { Vector3 } },
		StalkPoints = {} :: { any },
		Rng = rng,
	}

	function map:Cell(floorName: string, x: number, z: number): Vector3
		local floor = Layout.Floors[floorName]
		return Vector3.new(x * C + C / 2, floor.Y, z * C + C / 2)
	end

	-- Interior bounds of a region rectangle (inside the wall faces).
	function map:Bounds(regionId: string, rectIndex: number?): (Vector3, Vector3)
		local region = self.Regions[regionId]
		local r = region.Rects[rectIndex or 1]
		return Vector3.new(r[1] * C + T / 2, region.Y, r[2] * C + T / 2), Vector3.new((r[3] + 1) * C - T / 2, region.Y + region.Height, (r[4] + 1) * C - T / 2)
	end

	function map:RegionAt(position: Vector3)
		for _, region in self.RegionList do
			if position.Y >= region.Y - 1 and position.Y <= region.Y + region.Height + 1 then
				local cx, cz = math.floor(position.X / C), math.floor(position.Z / C)
				if inRects(region.Rects, cx, cz) then
					return region
				end
			end
		end
		return nil
	end

	for floorName, floor in Layout.Floors do
		MapBuilder._buildFloor(map, floorName, floor, folders, rng)
	end
	MapBuilder._buildStairs(map, folders.Structure)
	MapBuilder._buildExterior(map, folders.Exterior, rng)
	MapBuilder._buildMenuSet(map, folders.MenuSet, rng)

	-- Patrol nodes & stalk points
	for floorName, cells in Layout.PatrolCells do
		map.PatrolNodes[floorName] = {}
		for _, cell in cells do
			table.insert(map.PatrolNodes[floorName], map:Cell(floorName, cell[1], cell[2]))
		end
	end
	for _, point in Layout.StalkPoints do
		local position = map:Cell("Ground", point.Cell[1], point.Cell[2]) + point.Offset
		local lookAt = map:Cell("Ground", point.LookCell[1], point.LookCell[2])
		table.insert(map.StalkPoints, { Name = point.Name, Position = position, LookAt = lookAt })
	end

	root.Parent = Workspace
	return map
end

---------------------------------------------------------------------------------------------
-- FLOOR GENERATION
---------------------------------------------------------------------------------------------

function MapBuilder._buildFloor(map, floorName: string, floor, folders, rng: Random)
	local Y = floor.Y
	local height = floor.Height
	local wallTop = floor.WallTop and (floor.WallTop - Y) or height
	local cells: { [string]: any } = {}
	local structure = Instance.new("Folder")
	structure.Name = floorName
	structure.Parent = folders.Structure
	local floorInfo = { Name = floorName, Y = Y, Height = height, Cells = cells }
	map.Floors[floorName] = floorInfo

	-- Register regions & cells
	for _, def in floor.Regions do
		local region = {
			Id = def.Id,
			Kind = def.Kind,
			Name = def.Name,
			Floor = floorName,
			Y = Y,
			Height = height,
			Rects = def.Rects,
			Cells = {},
			Style = STYLES[def.Kind] or STYLES.Hallway,
			NoFloor = def.NoFloor,
			NoCeiling = def.NoCeiling,
		}
		for _, r in def.Rects do
			for x = r[1], r[3] do
				for z = r[2], r[4] do
					cells[key(x, z)] = region
					table.insert(region.Cells, { x, z })
				end
			end
		end
		local first = def.Rects[1]
		region.Center = Vector3.new((first[1] + first[3] + 1) / 2 * C, Y, (first[2] + first[4] + 1) / 2 * C)
		map.Regions[def.Id] = region
		table.insert(map.RegionList, region)
	end

	-- Edge lookup
	local edges: { [string]: any } = {}
	for _, e in floor.Edges do
		if math.abs(e[1] - e[3]) + math.abs(e[2] - e[4]) ~= 1 then
			warn(("[MapBuilder] Edge %d,%d -> %d,%d is not between adjacent cells"):format(e[1], e[2], e[3], e[4]))
		else
			edges[edgeKey(e[1], e[2], e[3], e[4])] = { Type = e[5], Label = e[6] }
		end
	end

	-- Floors and ceilings
	for _, region in map.RegionList do
		if region.Floor == floorName then
			for _, cell in region.Cells do
				local x, z = cell[1], cell[2]
				local center = Vector3.new(x * C + C / 2, Y, z * C + C / 2)
				if not inRects(region.NoFloor, x, z) then
					Props.Part(structure, Vector3.new(C, 1, C), CFrame.new(center - Vector3.new(0, 0.5, 0)), vary(region.Style.Floor.Color, rng, 0.06), region.Style.Floor.Material, {
						Name = "Floor",
					})
				end
				if not inRects(region.NoCeiling, x, z) then
					local broken = (region.Kind == "Hallway" or region.Kind == "Service" or region.Kind == "BasementHall") and rng:NextNumber() < 0.18
					local ceilingY = Y + height + 0.5
					if broken then
						-- Missing tile: dark void above + a panel hanging down by one edge.
						Props.Part(structure, Vector3.new(C, 1, C), CFrame.new(center.X, ceilingY + 2, center.Z), Color3.fromRGB(14, 14, 14), M.Concrete, { Name = "Void" })
						for _, side in { -1, 1 } do
							Props.Part(structure, Vector3.new(C, 1, 2.5), CFrame.new(center.X, ceilingY, center.Z + side * 3.75), region.Style.Ceiling.Color, region.Style.Ceiling.Material)
						end
						Props.Part(structure, Vector3.new(4.5, 0.25, 4.5), CFrame.new(center.X - 1, ceilingY - 2.1, center.Z) * A(0, rng:NextNumber(0, 90), 52), region.Style.Ceiling.Color, M.Plaster, {
							CanCollide = false,
						})
						Props.Pipe(structure, Vector3.new(center.X - C / 2, ceilingY + 1, center.Z + 1.5), Vector3.new(center.X + C / 2, ceilingY + 1, center.Z + 1.5), 0.35)
						-- dangling wire
						Props.Part(structure, Vector3.new(0.06, 3, 0.06), CFrame.new(center.X + 2, ceilingY - 1.2, center.Z - 1) * A(0, 0, 8), Color3.fromRGB(20, 20, 20), M.SmoothPlastic, {
							CanCollide = false,
							CanQuery = false,
						})
					else
						Props.Part(structure, Vector3.new(C, 1, C), CFrame.new(center.X, ceilingY, center.Z), vary(region.Style.Ceiling.Color, rng, 0.05), region.Style.Ceiling.Material, {
							Name = "Ceiling",
						})
					end
				end
			end
		end
	end

	-- Lights
	for _, region in map.RegionList do
		if region.Floor == floorName then
			MapBuilder._lightRegion(region, folders.Lights, rng)
		end
	end

	-- Walls
	local processed: { [string]: boolean } = {}
	local pillarDone: { [string]: boolean } = {}
	local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for cellKey, region in cells do
		local sx, sz = string.match(cellKey, "(-?%d+),(-?%d+)")
		local x, z = tonumber(sx) :: number, tonumber(sz) :: number
		for _, d in DIRS do
			local nx, nz = x + d[1], z + d[2]
			local ek = edgeKey(x, z, nx, nz)
			if not processed[ek] then
				processed[ek] = true
				local neighbor = cells[key(nx, nz)]
				local edge = edges[ek]
				local sameRegion = neighbor == region
				if not (sameRegion and not edge) and not (edge and edge.Type == "Open") then
					MapBuilder._buildWallSegment(map, structure, folders, floorInfo, x, z, nx, nz, region, neighbor, edge, wallTop, rng, pillarDone)
				end
			end
		end
	end
end

local MODE_WEIGHTS = {
	Hallway = { Normal = 0.4, Flicker = 0.35, Broken = 0.15, Dead = 0.1 },
	Service = { Normal = 0.2, Flicker = 0.35, Broken = 0.25, Dead = 0.2 },
	BasementHall = { Normal = 0.3, Flicker = 0.4, Broken = 0.2, Dead = 0.1 },
	Room = { Normal = 0.6, Flicker = 0.3, Broken = 0.1, Dead = 0 },
	Steady = { Normal = 1 },
}

local function pickMode(weights: { [string]: number }, rng: Random): string
	local roll = rng:NextNumber()
	local acc = 0
	for _, mode in { "Normal", "Flicker", "Broken", "Dead" } do
		acc += weights[mode] or 0
		if roll <= acc then
			return mode
		end
	end
	return "Normal"
end

-- Ceiling fixtures: one per corridor cell, one per 2x2 block in rooms.
function MapBuilder._lightRegion(region, parent: Instance, rng: Random)
	local kind = region.Kind
	if kind == "Outside" then
		return
	end
	local ceiling = region.Y + region.Height
	local weights = MODE_WEIGHTS[kind] or MODE_WEIGHTS.Room
	if kind == "Security" or kind == "Generator" or kind == "StairsTop" then
		weights = MODE_WEIGHTS.Steady
	end
	local basement = region.Floor == "Basement"
	local function place(x: number, z: number, cx: number, cz: number, yaw: number)
		if region.NoCeiling and inRects(region.NoCeiling, x, z) then
			return
		end
		local pos = Vector3.new(cx, ceiling, cz)
		if kind == "Safe" then
			Props.Bulb(parent, pos - Vector3.new(0, 2.6, 0), Color3.fromRGB(255, 196, 130), "Normal", 22):SetAttribute("NoPower", true)
		elseif kind == "Tunnel" then
			Props.Bulb(parent, pos - Vector3.new(0, 2.2, 0), Color3.fromRGB(255, 200, 140), pickMode(MODE_WEIGHTS.BasementHall, rng), 18)
		else
			Props.CeilingLight(parent, pos, pickMode(weights, rng), yaw, {
				Color = basement and Color3.fromRGB(255, 226, 180) or nil,
				PanelColor = basement and Color3.fromRGB(255, 236, 200) or nil,
				Range = (kind == "Hallway" or kind == "BasementHall") and 18 or 22,
			})
		end
	end
	for _, r in region.Rects do
		local w, d = r[3] - r[1] + 1, r[4] - r[2] + 1
		local corridor = w == 1 or d == 1
		local yaw = d > w and 90 or 0
		if corridor then
			local step = (kind == "Service" or kind == "Tunnel") and 2 or 1
			local i = 0
			for x = r[1], r[3] do
				for z = r[2], r[4] do
					if i % step == 0 then
						place(x, z, x * C + C / 2, z * C + C / 2, yaw)
					end
					i += 1
				end
			end
		else
			for x = r[1], r[3], 2 do
				for z = r[2], r[4], 2 do
					local x1, z1 = math.min(x + 1, r[3]), math.min(z + 1, r[4])
					place(x, z, (x + x1 + 1) / 2 * C, (z + z1 + 1) / 2 * C, yaw)
				end
			end
		end
	end
end

-- Builds the wall between cell (x,z) [region] and (nx,nz) [neighbor or nil].
function MapBuilder._buildWallSegment(map, parent, folders, floorInfo, x, z, nx, nz, region, neighbor, edge, wallTop: number, rng: Random, pillarDone)
	local Y = floorInfo.Y
	local origin: Vector3, along: Vector3, normal: Vector3
	if nx ~= x then
		origin = Vector3.new(math.max(x, nx) * C, Y, z * C + C / 2)
		along = Vector3.zAxis
		normal = Vector3.new(x < nx and -1 or 1, 0, 0) -- points into `region`
	else
		origin = Vector3.new(x * C + C / 2, Y, math.max(z, nz) * C)
		along = Vector3.xAxis
		normal = Vector3.new(0, 0, z < nz and -1 or 1)
	end

	local styleA: Style = region.Style
	local styleB: Style = neighbor and neighbor.Style or EXTERIOR
	local outdoorA = region.Kind == "Outside"
	local exteriorB = neighbor == nil
	local edgeType = edge and edge.Type or nil

	local function slab(style: Style, sign: number, u0: number, u1: number, y0: number, y1: number, trims: boolean)
		local len = u1 - u0
		if len <= 0.01 or y1 - y0 <= 0.01 then
			return
		end
		local mid = (u0 + u1) / 2
		local function piece(b0: number, b1: number, finish: Finish)
			local lo, hi = math.max(b0, y0), math.min(b1, y1)
			if hi - lo <= 0.01 then
				return
			end
			local size = along == Vector3.xAxis and Vector3.new(len, hi - lo, T / 2) or Vector3.new(T / 2, hi - lo, len)
			local pos = origin + along * mid + Vector3.new(0, (lo + hi) / 2, 0) + normal * sign * T / 4
			Props.Part(parent, size, CFrame.new(pos), finish.Color, finish.Material, { Name = "Wall" })
		end
		piece(0, BAND, style.Lower)
		piece(BAND, wallTop, style.Upper)
		if trims and y0 <= 0.01 then
			local size = along == Vector3.xAxis and Vector3.new(len, 0.7, 0.18) or Vector3.new(0.18, 0.7, len)
			Props.Part(parent, size, CFrame.new(origin + along * mid + Vector3.new(0, 0.35, 0) + normal * sign * (T / 2 + 0.09)), style.Trim, M.Wood, {
				CanCollide = false,
				Name = "Baseboard",
			})
		end
		if trims and y0 <= BAND and y1 >= BAND then
			local size = along == Vector3.xAxis and Vector3.new(len, 0.25, 0.14) or Vector3.new(0.14, 0.25, len)
			Props.Part(parent, size, CFrame.new(origin + along * mid + Vector3.new(0, BAND, 0) + normal * sign * (T / 2 + 0.07)), style.Trim, M.Wood, {
				CanCollide = false,
				Name = "ChairRail",
			})
		end
	end

	local function panel(u0: number, u1: number, y0: number, y1: number)
		slab(styleA, 1, u0, u1, y0, y1, not outdoorA)
		slab(styleB, -1, u0, u1, y0, y1, not exteriorB and not (neighbor and neighbor.Kind == "Outside"))
	end

	local half = C / 2
	if edgeType == nil then
		panel(-half, half, 0, wallTop)
	elseif edgeType == "Window" then
		panel(-half, -WIN_W / 2, 0, wallTop)
		panel(WIN_W / 2, half, 0, wallTop)
		panel(-WIN_W / 2, WIN_W / 2, 0, WIN_SILL)
		panel(-WIN_W / 2, WIN_W / 2, WIN_TOP, wallTop)
		-- frame, glass (some broken), sill
		local center = origin + Vector3.new(0, (WIN_SILL + WIN_TOP) / 2, 0)
		local frameColor = Color3.fromRGB(60, 62, 64)
		local wcf = CFrame.lookAt(center, center + normal)
		Props.Part(parent, Vector3.new(WIN_W + 0.4, 0.3, T + 0.4), wcf * CFrame.new(0, -(WIN_TOP - WIN_SILL) / 2, 0), frameColor, M.Metal)
		Props.Part(parent, Vector3.new(WIN_W + 0.4, 0.3, T + 0.2), wcf * CFrame.new(0, (WIN_TOP - WIN_SILL) / 2, 0), frameColor, M.Metal)
		Props.Part(parent, Vector3.new(0.25, WIN_TOP - WIN_SILL, T + 0.1), wcf, frameColor, M.Metal)
		local broken = rng:NextNumber() < 0.35
		local glass = Props.Part(parent, Vector3.new(WIN_W, WIN_TOP - WIN_SILL, 0.12), wcf, Color3.fromRGB(70, 90, 100), M.Glass, {
			Transparency = 0.7,
			CanQuery = false, -- the monster can see through windows
			Name = "Glass",
		})
		if broken then
			glass.Size = Vector3.new(WIN_W, (WIN_TOP - WIN_SILL) * 0.45, 0.12)
			glass.CFrame = wcf * CFrame.new(0, -(WIN_TOP - WIN_SILL) * 0.275, 0)
			for i = 1, 3 do
				Props.Part(parent, Vector3.new(0.6, 0.05, 0.4), CFrame.new(origin + normal * rng:NextNumber(0.8, 2) + along * rng:NextNumber(-2, 2) + Vector3.new(0, 0.05, 0)) * A(0, i * 50, 0), Color3.fromRGB(110, 130, 140), M.Glass, {
					CanCollide = false,
					Transparency = 0.4,
				})
			end
		end
		-- bars on exterior windows
		if exteriorB then
			for i = -2, 2 do
				Props.Part(parent, Vector3.new(0.18, WIN_TOP - WIN_SILL, 0.18), wcf * CFrame.new(i * 1.25, 0, 0.9), Color3.fromRGB(40, 40, 42), M.Metal)
			end
		end
	else
		-- Door-like openings
		local width = edgeType == "ExitDoor" and 8 or (edgeType == "ExitGate" and 8 or DOOR_W)
		local doorHeight = DOOR_H
		panel(-half, -width / 2 - 0.45, 0, wallTop)
		panel(width / 2 + 0.45, half, 0, wallTop)
		panel(-width / 2 - 0.45, width / 2 + 0.45, doorHeight + 0.5, wallTop)
		local doorCF = CFrame.lookAt(origin, origin + normal)
		if edgeType == "ExitGate" then
			map.ExitGateCFrame = doorCF
			map.ExitGateWidth = width
		else
			local door = Doors.Create({
				CFrame = doorCF,
				Width = width,
				Height = doorHeight,
				Type = edgeType,
				Label = edge.Label,
				Parent = folders.Doors,
			})
			door.RegionA = region
			door.RegionB = neighbor
			door.Floor = floorInfo.Name
			table.insert(map.Doors, door)
			map.DoorsByType[edgeType] = map.DoorsByType[edgeType] or {}
			table.insert(map.DoorsByType[edgeType], door)
			-- plaques & emergency lamps
			if edge.Label then
				for _, sign in { 1, -1 } do
					local side = sign == 1 and region or neighbor
					if side and side.Kind ~= "Outside" then
						Props.Sign(parent, CFrame.lookAt(origin + Vector3.new(0, doorHeight + 1.6, 0) + normal * sign * (T / 2 + 0.07), origin + Vector3.new(0, doorHeight + 1.6, 0) + normal * sign * 5), edge.Label, 3.6)
					end
				end
			end
			local function isCorridor(r)
				return r ~= nil and (r.Kind == "Hallway" or r.Kind == "Service" or r.Kind == "BasementHall")
			end
			local hallSide = (isCorridor(neighbor) and not isCorridor(region)) and -1 or 1
			if edgeType ~= "Locked" then
				local lampPos = origin + Vector3.new(along.X * 3.2, doorHeight + 1.3, along.Z * 3.2) + normal * hallSide * (T / 2 + 0.3)
				Props.EmergencyLight(folders.Lights, CFrame.lookAt(lampPos, lampPos + normal * hallSide))
			end
			if edgeType == "ExitDoor" then
				local signPos = origin + Vector3.new(0, doorHeight + 1.8, 0) + normal * (T / 2 + 0.1)
				Props.ExitSign(parent, CFrame.lookAt(signPos, signPos + normal))
			end
		end
	end

	-- Pillars at both ends of the segment.
	if region.Kind ~= "Outside" and not (neighbor and neighbor.Kind == "Outside") then
		for _, s in { -1, 1 } do
			local p = origin + along * s * half
			local pk = floorInfo.Name .. key(math.floor(p.X + 0.5), math.floor(p.Z + 0.5))
			if not pillarDone[pk] then
				pillarDone[pk] = true
				Props.Part(parent, Vector3.new(1.5, wallTop, 1.5), CFrame.new(p + Vector3.new(0, wallTop / 2, 0)), Color3.fromRGB(64, 64, 62), M.Concrete, {
					Name = "Pillar",
				})
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- STAIRS
---------------------------------------------------------------------------------------------

function MapBuilder._buildStairs(map, parent: Instance)
	local s = Layout.Stairs
	local x0, x1 = s.X0 * C + T / 2, (s.X1 + 1) * C - T / 2
	local zTop, zBottom = s.TopZ * C, s.BottomZ * C
	local drop = s.TopY - s.BottomY
	local steps = math.floor(drop)
	local run = (zTop - zBottom) / steps
	local width = x1 - x0
	local cx = (x0 + x1) / 2
	local folder = Instance.new("Model")
	folder.Name = "Stairs"
	folder.Parent = parent
	for i = 1, steps do
		local top = s.TopY - i
		local h = top - s.BottomY
		if h > 0.05 then
			local zFront = zTop - (i - 1) * run
			local zc = zFront - run / 2
			Props.Part(folder, Vector3.new(width, h, run), CFrame.new(cx, s.BottomY + h / 2, zc), Color3.fromRGB(78, 78, 76), M.Concrete, {
				Name = "Step",
			})
			-- yellow safety nosing
			Props.Part(folder, Vector3.new(width, 0.08, 0.35), CFrame.new(cx, top + 0.04, zFront - 0.18), Color3.fromRGB(150, 120, 20), M.SmoothPlastic, {
				CanCollide = false,
			})
		end
	end
	-- Invisible ramp over the steps: smooth footing for players and a clean navmesh for
	-- the monster's pathfinding. (WedgePart: full height at +Z, zero at -Z.)
	local ramp = Instance.new("WedgePart")
	ramp.Name = "StairRamp"
	ramp.Anchored = true
	ramp.Transparency = 1
	ramp.Size = Vector3.new(width, drop, zTop - zBottom)
	ramp.CFrame = CFrame.new(cx, s.BottomY + drop / 2, (zTop + zBottom) / 2)
	ramp.CastShadow = false
	ramp.Parent = folder
	-- handrails
	for _, x in { x0 + 0.5, x1 - 0.5 } do
		local from = Vector3.new(x, s.TopY + 3.2, zTop)
		local to = Vector3.new(x, s.BottomY + 3.2, zBottom)
		Props.Pipe(folder, from, to, 0.15, Color3.fromRGB(90, 90, 92))
	end
	-- landing light and painted floor number
	Props.Sign(folder, CFrame.new(cx, s.BottomY + 7, zBottom - C + T / 2 + 0.1) * A(0, 180, 0), "B1 - SUB LEVEL", 5, Color3.fromRGB(150, 120, 20), Color3.fromRGB(20, 20, 20))
	map.StairsTop = Vector3.new(cx, s.TopY, zTop + 4)
	map.StairsBottom = Vector3.new(cx, s.BottomY, zBottom - 4)
end

---------------------------------------------------------------------------------------------
-- EXTERIOR: grounds around the building (seen through windows) and the riverbank exit.
---------------------------------------------------------------------------------------------

function MapBuilder._buildExterior(map, parent: Instance, rng: Random)
	local groundColor = Color3.fromRGB(36, 40, 30)
	local function ground(x0: number, z0: number, x1: number, z1: number)
		Props.Part(parent, Vector3.new(x1 - x0, 2, z1 - z0), CFrame.new((x0 + x1) / 2, -1, (z0 + z1) / 2), groundColor, M.Grass, { Name = "Ground" })
	end
	-- Building footprint x[0,200] z[10,130]; ravine hole x[40,90] z[-70,-20].
	ground(-250, -250, 0, 350)
	ground(200, -250, 450, 350)
	ground(0, 130, 200, 350)
	ground(0, -250, 40, 10)
	ground(90, -250, 200, 10)
	ground(40, -250, 90, -70)
	ground(40, -20, 90, 10)
	-- The lobby looks out onto a cracked path, fence and dead trees in the rain.
	Props.Part(parent, Vector3.new(60, 0.2, 12), CFrame.new(-30, 0.1, 65), Color3.fromRGB(70, 70, 68), M.Asphalt)
	Props.Fence(parent, Vector3.new(-70, 0, -40), Vector3.new(-70, 0, 170))
	Props.Fence(parent, Vector3.new(-70, 0, -40), Vector3.new(30, 0, -40))
	for _ = 1, 26 do
		local pos
		repeat
			pos = Vector3.new(rng:NextNumber(-220, 400), 0, rng:NextNumber(-220, 330))
		until not (pos.X > -40 and pos.X < 240 and pos.Z > -90 and pos.Z < 170)
		Props.DeadTree(parent, pos, rng)
	end
	for _ = 1, 6 do
		Props.DeadTree(parent, Vector3.new(rng:NextNumber(-65, -15), 0, rng:NextNumber(-30, 160)), rng)
	end
	-- Rain over the grounds near the windows and over the ravine.
	Props.RainEmitter(parent, CFrame.new(-30, 45, 65), Vector3.new(70, 1, 150))
	Props.RainEmitter(parent, CFrame.new(100, 45, 20), Vector3.new(200, 1, 30))
	Props.RainEmitter(parent, CFrame.new(65, 30, -45), Vector3.new(60, 1, 60))
	Props.RainEmitter(parent, CFrame.new(220, 45, 60), Vector3.new(30, 1, 100))
	-- Ground fog outside.
	Props.FogEmitter(parent, CFrame.new(-30, 2, 65), Vector3.new(60, 2, 140), 4, Color3.fromRGB(90, 100, 115))
	-- River at the bottom of the ravine.
	local outside = map.Regions.Outside
	if outside then
		local minV, maxV = map:Bounds("Outside")
		Props.Part(parent, Vector3.new(maxV.X - minV.X, 1, 16), CFrame.new((minV.X + maxV.X) / 2, outside.Y - 0.4, minV.Z + 8), Color3.fromRGB(20, 30, 34), M.Glass, {
			Transparency = 0.1,
			Reflectance = 0.3,
			CanCollide = false,
			Name = "River",
		})
		for _ = 1, 10 do
			Props.Part(parent, Vector3.new(rng:NextNumber(2, 6), rng:NextNumber(1, 4), rng:NextNumber(2, 6)), CFrame.new(rng:NextNumber(minV.X, maxV.X), outside.Y + 0.5, rng:NextNumber(minV.Z + 14, maxV.Z - 4)) * A(rng:NextNumber(0, 30), rng:NextNumber(0, 360), 0), Color3.fromRGB(60, 60, 58), M.Rock)
		end
		Props.FogEmitter(parent, CFrame.new((minV.X + maxV.X) / 2, outside.Y + 2, (minV.Z + maxV.Z) / 2), Vector3.new(40, 3, 40), 3, Color3.fromRGB(110, 120, 140))
		-- Moonlight in the ravine.
		local moon = Props.Part(parent, Vector3.new(1, 1, 1), CFrame.new((minV.X + maxV.X) / 2, outside.Y + 26, minV.Z + 10), Color3.new(), M.SmoothPlastic, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 80
		spot.Range = 45
		spot.Brightness = 1.4
		spot.Color = Color3.fromRGB(150, 170, 220)
		spot.Parent = moon
	end
	-- Atmosphere
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.42
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(40, 44, 54)
	atmosphere.Decay = Color3.fromRGB(20, 18, 24)
	atmosphere.Glare = 0
	atmosphere.Haze = 2.2
	atmosphere.Parent = Lighting
end

---------------------------------------------------------------------------------------------
-- MENU SET: an isolated corridor used as the animated main-menu backdrop.
---------------------------------------------------------------------------------------------

MapBuilder.MenuOrigin = Vector3.new(-1200, 0, 0)

function MapBuilder._buildMenuSet(map, parent: Instance, rng: Random)
	local o = MapBuilder.MenuOrigin
	local length, width, height = 130, 12, 14
	local style = STYLES.Hallway
	-- Corridor runs along -Z from the camera start.
	Props.Part(parent, Vector3.new(width, 1, length), CFrame.new(o + Vector3.new(0, -0.5, -length / 2)), style.Floor.Color, style.Floor.Material)
	Props.Part(parent, Vector3.new(width, 1, length), CFrame.new(o + Vector3.new(0, height + 0.5, -length / 2)), style.Ceiling.Color, style.Ceiling.Material)
	for _, side in { -1, 1 } do
		Props.Part(parent, Vector3.new(1, BAND, length), CFrame.new(o + Vector3.new(side * (width / 2 + 0.5), BAND / 2, -length / 2)), style.Lower.Color, style.Lower.Material)
		Props.Part(parent, Vector3.new(1, height - BAND, length), CFrame.new(o + Vector3.new(side * (width / 2 + 0.5), BAND + (height - BAND) / 2, -length / 2)), style.Upper.Color, style.Upper.Material)
		Props.Part(parent, Vector3.new(0.2, 0.7, length), CFrame.new(o + Vector3.new(side * (width / 2 - 0.1), 0.35, -length / 2)), style.Trim, M.Wood)
		-- doorways along the corridor
		for i = 1, 4 do
			local z = -i * 26
			Props.Part(parent, Vector3.new(0.3, DOOR_H, DOOR_W), CFrame.new(o + Vector3.new(side * (width / 2 - 0.05), DOOR_H / 2, z)), Color3.fromRGB(70, 54, 40), M.WoodPlanks)
			Props.Sign(parent, CFrame.lookAt(o + Vector3.new(side * (width / 2 - 0.1), DOOR_H + 1.5, z), o + Vector3.new(0, DOOR_H + 1.5, z)), "WARD " .. string.char(64 + i + (side > 0 and 4 or 0)), 3)
		end
	end
	-- back wall
	Props.Part(parent, Vector3.new(width + 2, height, 1), CFrame.new(o + Vector3.new(0, height / 2, -length - 0.5)), style.Upper.Color, style.Upper.Material)
	Props.Part(parent, Vector3.new(width + 2, height, 1), CFrame.new(o + Vector3.new(0, height / 2, 8.5)), style.Upper.Color, style.Upper.Material)
	-- lights: mostly broken, the far one flickers above where the figure stands
	for i = 0, 8 do
		local z = -8 - i * 14
		local mode = (i == 7) and "Flicker" or ((i % 3 == 1) and "Broken" or (i < 2 and "Flicker" or "Dead"))
		Props.CeilingLight(parent, o + Vector3.new(0, height, z), mode, 90, { RequiresPower = false, Brightness = (i == 7) and 2.4 or 1.2 })
	end
	-- props
	Props.Gurney(parent, CFrame.new(o + Vector3.new(-3.5, 0, -30)) * A(0, 12, 0), true)
	Props.Wheelchair(parent, CFrame.new(o + Vector3.new(3.8, 0, -52)) * A(0, -140, 0))
	Props.Debris(parent, CFrame.new(o + Vector3.new(3, 0, -70)), rng, 0.8)
	Props.Papers(parent, o + Vector3.new(0, 0, -40), 4, 14, rng)
	Props.BloodPool(parent, o + Vector3.new(-1, 0, -62), 1.4, rng)
	Props.DragMarks(parent, o + Vector3.new(-1, 0, -62), o + Vector3.new(-2, 0, -95))
	local leftWall = CFrame.lookAt(o + Vector3.new(-width / 2 + 0.05, 6, -45), o + Vector3.new(0, 6, -45))
	Props.BloodWriting(parent, leftWall, "IT SMILES", 8, rng)
	Props.Scratches(parent, CFrame.lookAt(o + Vector3.new(width / 2 - 0.05, 4, -80), o + Vector3.new(0, 4, -80)), 4, rng)
	Props.FogEmitter(parent, CFrame.new(o + Vector3.new(0, 1.5, -length / 2)), Vector3.new(width - 1, 2, length - 4), 6)
	Props.Dust(parent, CFrame.new(o + Vector3.new(0, 7, -40)), Vector3.new(width - 2, 10, 60))
	-- markers read by the client menu controller
	local function marker(name: string, cf: CFrame)
		local part = Props.Part(parent, Vector3.new(1, 1, 1), cf, Color3.new(), M.SmoothPlastic, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Name = name,
		})
		return part
	end
	marker("CameraStart", CFrame.lookAt(o + Vector3.new(0.5, 5.6, 4), o + Vector3.new(0, 5.2, -60)))
	marker("CameraEnd", CFrame.lookAt(o + Vector3.new(-0.5, 5.4, -14), o + Vector3.new(0, 5.6, -100)))
	marker("FigureFar", CFrame.lookAt(o + Vector3.new(0, 0, -105), o + Vector3.new(0, 0, 0)))
	marker("FigureNear", CFrame.lookAt(o + Vector3.new(1.5, 0, -62), o + Vector3.new(0, 0, 0)))
	map.MenuSet = parent
end

return MapBuilder
