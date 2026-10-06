--[[
	Procedural prop library. Every prop is assembled from anchored parts, so the map
	looks detailed without any uploaded meshes or textures. Wall graffiti, blood and
	scratch marks are drawn with SurfaceGuis (LightInfluence = 1 so they sit in the
	darkness instead of glowing).
]]

local CollectionService = game:GetService("CollectionService")

local Props = {}

local rad = math.rad

local function A(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end
Props.A = A

local METAL = Color3.fromRGB(92, 96, 100)
local DARK_METAL = Color3.fromRGB(48, 50, 54)
local RUST = Color3.fromRGB(96, 58, 38)
local WOOD = Color3.fromRGB(86, 62, 44)
local BLOOD = Color3.fromRGB(78, 6, 6)
local DRIED_BLOOD = Color3.fromRGB(52, 10, 8)
local PAPER = Color3.fromRGB(196, 190, 170)

Props.Colors = { METAL = METAL, DARK_METAL = DARK_METAL, RUST = RUST, WOOD = WOOD, BLOOD = BLOOD, PAPER = PAPER }

-- Generic anchored part.
function Props.Part(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3?,
	material: Enum.Material?,
	extra: { [string]: any }?
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color or METAL
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if size.Magnitude < 2.5 then
		part.CastShadow = false
	end
	if extra then
		for k, v in extra do
			(part :: any)[k] = v
		end
	end
	part.Parent = parent
	return part
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
Props.Model = model

-- Non-colliding decoration (papers, decals, wires).
local function flat(parent, size, cf, color, material)
	return Props.Part(parent, size, cf, color, material, { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
end

---------------------------------------------------------------------------------------------
-- LIGHTING FIXTURES
---------------------------------------------------------------------------------------------

-- Ceiling fluorescent tube. `ceiling` = point on the ceiling surface.
-- mode: Normal | Flicker | Broken | Dead. Light behaviour is animated client-side
-- (LightController) from these attributes.
function Props.CeilingLight(parent: Instance, ceiling: Vector3, mode: string, yaw: number?, options: { [string]: any }?)
	options = options or {}
	local opts = options :: { [string]: any }
	local m = model(parent, "Fluorescent")
	local hanging = mode == "Broken" and (opts.Hanging ~= false)
	local base = CFrame.new(ceiling) * A(0, yaw or 0, 0)
	if hanging then
		base = base * CFrame.new(1.4, -1.6, 0) * A(0, 0, 32)
		flat(m, Vector3.new(0.05, 1.8, 0.05), CFrame.new(ceiling + Vector3.new(-0.2, -0.9, 0)), DARK_METAL)
	end
	Props.Part(m, Vector3.new(4.2, 0.35, 1.3), base * CFrame.new(0, -0.18, 0), Color3.fromRGB(150, 150, 145), Enum.Material.Metal, { CanCollide = false })
	local panel = Props.Part(m, Vector3.new(3.8, 0.12, 0.9), base * CFrame.new(0, -0.4, 0), Color3.fromRGB(40, 42, 44), Enum.Material.SmoothPlastic, {
		CanCollide = false,
		Name = "Panel",
	})
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 115
	light.Range = opts.Range or 20
	light.Brightness = 0
	light.Color = opts.Color or Color3.fromRGB(214, 228, 255)
	light.Shadows = true
	light.Enabled = false
	light.Parent = panel
	m:SetAttribute("Mode", mode)
	m:SetAttribute("Brightness", opts.Brightness or 1.6)
	m:SetAttribute("LitColor", opts.PanelColor or Color3.fromRGB(226, 236, 255))
	m:SetAttribute("Seed", math.random() * 1000)
	if opts.RequiresPower == false then
		m:SetAttribute("NoPower", true)
	end
	CollectionService:AddTag(m, "HorrorLight")
	return m
end

-- Small red battery-powered emergency lamp above doors. On when the main power is out.
function Props.EmergencyLight(parent: Instance, cframe: CFrame)
	local m = model(parent, "EmergencyLight")
	Props.Part(m, Vector3.new(1.4, 0.6, 0.5), cframe, DARK_METAL, Enum.Material.Metal, { CanCollide = false })
	local lens = Props.Part(m, Vector3.new(1.0, 0.35, 0.2), cframe * CFrame.new(0, 0, -0.3), Color3.fromRGB(120, 10, 10), Enum.Material.Neon, {
		CanCollide = false,
		Name = "Panel",
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 40, 30)
	light.Range = 12
	light.Brightness = 0
	light.Shadows = false
	light.Parent = lens
	m:SetAttribute("Mode", "Emergency")
	m:SetAttribute("Brightness", 0.9)
	m:SetAttribute("LitColor", Color3.fromRGB(255, 30, 20))
	m:SetAttribute("Seed", math.random() * 1000)
	CollectionService:AddTag(m, "HorrorLight")
	return m
end

-- Desk lamp / bare bulb with a warm colour. Used in the safe room.
function Props.Bulb(parent: Instance, position: Vector3, color: Color3, mode: string, range: number?)
	local m = model(parent, "Bulb")
	flat(m, Vector3.new(0.06, 1.4, 0.06), CFrame.new(position + Vector3.new(0, 0.9, 0)), Color3.fromRGB(20, 20, 20))
	local bulb = Props.Part(m, Vector3.new(0.6, 0.6, 0.6), CFrame.new(position), Color3.fromRGB(60, 50, 40), Enum.Material.SmoothPlastic, {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Name = "Panel",
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 16
	light.Brightness = 0
	light.Shadows = true
	light.Parent = bulb
	m:SetAttribute("Mode", mode)
	m:SetAttribute("Brightness", 1.2)
	m:SetAttribute("LitColor", color)
	m:SetAttribute("Seed", math.random() * 1000)
	CollectionService:AddTag(m, "HorrorLight")
	return m
end

---------------------------------------------------------------------------------------------
-- FURNITURE
---------------------------------------------------------------------------------------------

function Props.Desk(parent: Instance, cf: CFrame, color: Color3?)
	local m = model(parent, "Desk")
	local c = color or WOOD
	Props.Part(m, Vector3.new(6, 0.3, 3), cf * CFrame.new(0, 3.1, 0), c, Enum.Material.Wood)
	for _, x in { -2.7, 2.7 } do
		Props.Part(m, Vector3.new(0.4, 2.95, 2.8), cf * CFrame.new(x, 1.48, 0), c, Enum.Material.Wood)
	end
	Props.Part(m, Vector3.new(1.8, 2.4, 2.6), cf * CFrame.new(1.6, 1.6, 0), c, Enum.Material.Wood)
	for i = 0, 2 do
		flat(m, Vector3.new(1.5, 0.6, 0.05), cf * CFrame.new(1.6, 2.4 - i * 0.75, -1.32), Color3.fromRGB(60, 44, 30), Enum.Material.Wood)
	end
	return m
end

function Props.Chair(parent: Instance, cf: CFrame, toppled: boolean?)
	local m = model(parent, "Chair")
	local base = cf
	if toppled then
		base = cf * CFrame.new(0, 0.9, 0) * A(-90, 0, 0) * CFrame.new(0, -0.9, 0)
	end
	Props.Part(m, Vector3.new(2, 0.25, 2), base * CFrame.new(0, 1.9, 0), DARK_METAL, Enum.Material.Fabric)
	Props.Part(m, Vector3.new(2, 2.2, 0.25), base * CFrame.new(0, 3.1, 0.9) * A(-6, 0, 0), DARK_METAL, Enum.Material.Fabric)
	for _, x in { -0.85, 0.85 } do
		for _, z in { -0.85, 0.85 } do
			Props.Part(m, Vector3.new(0.15, 1.8, 0.15), base * CFrame.new(x, 0.9, z), METAL, Enum.Material.Metal)
		end
	end
	return m
end

function Props.FilingCabinet(parent: Instance, cf: CFrame, openDrawer: boolean?)
	local m = model(parent, "FilingCabinet")
	Props.Part(m, Vector3.new(2, 5, 2.4), cf * CFrame.new(0, 2.5, 0), Color3.fromRGB(80, 86, 80), Enum.Material.Metal)
	for i = 0, 3 do
		local z = (openDrawer and i == 1) and -1.2 or 0
		Props.Part(m, Vector3.new(1.8, 1.05, 0.15), cf * CFrame.new(0, 0.7 + i * 1.2, -1.25 + z), Color3.fromRGB(90, 96, 90), Enum.Material.Metal)
		flat(m, Vector3.new(0.6, 0.12, 0.12), cf * CFrame.new(0, 0.9 + i * 1.2, -1.36 + z), DARK_METAL, Enum.Material.Metal)
	end
	if openDrawer then
		flat(m, Vector3.new(1.6, 0.5, 2.2), cf * CFrame.new(0, 1.8, -1.2), Color3.fromRGB(70, 76, 70), Enum.Material.Metal)
	end
	return m
end

function Props.Shelf(parent: Instance, cf: CFrame, rng: Random, width: number?)
	local m = model(parent, "Shelf")
	local w = width or 7
	for _, x in { -w / 2 + 0.15, w / 2 - 0.15 } do
		for _, z in { -0.9, 0.9 } do
			Props.Part(m, Vector3.new(0.3, 9, 0.3), cf * CFrame.new(x, 4.5, z), RUST, Enum.Material.CorrodedMetal)
		end
	end
	for level = 0, 3 do
		local y = 0.6 + level * 2.6
		Props.Part(m, Vector3.new(w, 0.2, 2.1), cf * CFrame.new(0, y, 0), DARK_METAL, Enum.Material.Metal)
		local x = -w / 2 + 0.8
		while x < w / 2 - 0.8 do
			if rng:NextNumber() < 0.7 then
				local size = Vector3.new(rng:NextNumber(0.9, 1.6), rng:NextNumber(0.8, 1.9), rng:NextNumber(1.1, 1.8))
				Props.Part(
					m,
					size,
					cf * CFrame.new(x, y + 0.1 + size.Y / 2, rng:NextNumber(-0.2, 0.2)) * A(0, rng:NextNumber(-12, 12), 0),
					Color3.fromRGB(130 + rng:NextInteger(-20, 20), 104 + rng:NextInteger(-15, 15), 70),
					Enum.Material.Cardboard
				)
			end
			x += rng:NextNumber(1.3, 1.9)
		end
	end
	return m
end

function Props.Bed(parent: Instance, cf: CFrame, bloody: boolean?, restraints: boolean?)
	local m = model(parent, "Bed")
	Props.Part(m, Vector3.new(3.4, 0.3, 7), cf * CFrame.new(0, 2, 0), METAL, Enum.Material.Metal)
	Props.Part(m, Vector3.new(3.2, 0.6, 6.6), cf * CFrame.new(0, 2.45, 0), Color3.fromRGB(150, 150, 140), Enum.Material.Fabric)
	Props.Part(m, Vector3.new(2.2, 0.4, 1.2), cf * CFrame.new(0, 2.95, 2.6), Color3.fromRGB(170, 168, 160), Enum.Material.Fabric)
	Props.Part(m, Vector3.new(3.4, 2.4, 0.2), cf * CFrame.new(0, 3, 3.5), METAL, Enum.Material.Metal)
	for _, x in { -1.55, 1.55 } do
		for _, z in { -3.3, 3.3 } do
			Props.Part(m, Vector3.new(0.2, 2, 0.2), cf * CFrame.new(x, 1, z), METAL, Enum.Material.Metal)
		end
	end
	if bloody then
		flat(m, Vector3.new(1.6, 0.05, 2.2), cf * CFrame.new(0.3, 2.77, 0.4) * A(0, 20, 0), BLOOD, Enum.Material.SmoothPlastic)
		flat(m, Vector3.new(0.5, 1.4, 0.05), cf * CFrame.new(1.72, 2.2, 0.6), BLOOD)
	end
	if restraints then
		for _, z in { -2, 0.5, 2.2 } do
			flat(m, Vector3.new(3.5, 0.15, 0.35), cf * CFrame.new(0, 2.8, z), Color3.fromRGB(70, 50, 30), Enum.Material.Leather)
		end
	end
	return m
end

function Props.Gurney(parent: Instance, cf: CFrame, sheet: boolean?)
	local m = model(parent, "Gurney")
	Props.Part(m, Vector3.new(2.6, 0.25, 6.5), cf * CFrame.new(0, 3, 0), METAL, Enum.Material.Metal)
	for _, x in { -1.1, 1.1 } do
		for _, z in { -2.9, 2.9 } do
			Props.Part(m, Vector3.new(0.15, 2.6, 0.15), cf * CFrame.new(x, 1.6, z), METAL, Enum.Material.Metal)
			Props.Part(m, Vector3.new(0.3, 0.5, 0.5), cf * CFrame.new(x, 0.25, z), DARK_METAL, Enum.Material.Rubber, {
				Shape = Enum.PartType.Cylinder,
			})
		end
	end
	if sheet then
		-- A sheet draped over something body-shaped.
		Props.Part(m, Vector3.new(2.5, 0.5, 6.2), cf * CFrame.new(0, 3.35, 0), Color3.fromRGB(190, 188, 178), Enum.Material.Fabric)
		Props.Part(m, Vector3.new(1.2, 0.7, 1.2), cf * CFrame.new(0, 3.6, 2.4), Color3.fromRGB(190, 188, 178), Enum.Material.Fabric, {
			Shape = Enum.PartType.Ball,
		})
		flat(m, Vector3.new(0.9, 0.05, 1.4), cf * CFrame.new(0.4, 3.62, -0.5), DRIED_BLOOD)
		flat(m, Vector3.new(0.4, 0.05, 0.4), cf * CFrame.new(-0.6, 0.03, -1.4), BLOOD)
	end
	return m
end

function Props.Wheelchair(parent: Instance, cf: CFrame): Model
	local m = model(parent, "Wheelchair")
	Props.Part(m, Vector3.new(2, 0.25, 2), cf * CFrame.new(0, 2, 0), DARK_METAL, Enum.Material.Fabric)
	Props.Part(m, Vector3.new(2, 2, 0.2), cf * CFrame.new(0, 3.1, 1) * A(-10, 0, 0), DARK_METAL, Enum.Material.Fabric)
	for _, x in { -1.15, 1.15 } do
		Props.Part(m, Vector3.new(0.15, 2.8, 2.8), cf * CFrame.new(x, 1.4, 0.3), Color3.fromRGB(40, 40, 40), Enum.Material.Rubber, {
			Shape = Enum.PartType.Cylinder,
		})
		Props.Part(m, Vector3.new(0.12, 0.12, 2.2), cf * CFrame.new(x, 2.6, 0), METAL, Enum.Material.Metal)
	end
	return m
end

function Props.Crate(parent: Instance, cf: CFrame, size: number?)
	local s = size or 3
	local m = model(parent, "Crate")
	Props.Part(m, Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), Color3.fromRGB(100, 76, 50), Enum.Material.WoodPlanks)
	for _, y in { 0.15, s - 0.15 } do
		flat(m, Vector3.new(s + 0.1, 0.25, s + 0.1), cf * CFrame.new(0, y, 0), Color3.fromRGB(70, 52, 34), Enum.Material.Wood)
	end
	return m
end

function Props.Barrel(parent: Instance, cf: CFrame, color: Color3?, toppled: boolean?)
	local m = model(parent, "Barrel")
	local rot = toppled and (CFrame.new(0, 1.2, 0) * A(0, 0, 0)) or (CFrame.new(0, 1.9, 0) * A(0, 0, 90))
	Props.Part(m, Vector3.new(3.8, 2.4, 2.4), cf * rot, color or Color3.fromRGB(60, 80, 60), Enum.Material.CorrodedMetal, {
		Shape = Enum.PartType.Cylinder,
	})
	return m
end

function Props.Locker(parent: Instance, cf: CFrame, open: boolean?)
	local m = model(parent, "Locker")
	Props.Part(m, Vector3.new(2.2, 7, 2), cf * CFrame.new(0, 3.5, 0), Color3.fromRGB(70, 84, 96), Enum.Material.Metal)
	local door = open and (CFrame.new(-1.1, 3.5, -1) * A(0, -70, 0) * CFrame.new(1, 0, 0)) or CFrame.new(0, 3.5, -1.02)
	Props.Part(m, Vector3.new(2, 6.8, 0.1), cf * door, Color3.fromRGB(78, 92, 104), Enum.Material.Metal)
	for i = 0, 3 do
		flat(m, Vector3.new(1.2, 0.1, 0.05), cf * door * CFrame.new(0, 2.6 - i * 0.3, -0.06), DARK_METAL)
	end
	return m
end

function Props.VendingMachine(parent: Instance, cf: CFrame)
	local m = model(parent, "VendingMachine")
	Props.Part(m, Vector3.new(4, 7.5, 3), cf * CFrame.new(0, 3.75, 0), Color3.fromRGB(110, 20, 20), Enum.Material.Metal)
	local glass = Props.Part(m, Vector3.new(2.6, 5, 0.1), cf * CFrame.new(-0.5, 4.3, -1.52), Color3.fromRGB(30, 60, 70), Enum.Material.Glass, {
		Transparency = 0.4,
		Name = "Panel",
	})
	for row = 0, 4 do
		for col = 0, 3 do
			flat(m, Vector3.new(0.4, 0.6, 0.4), cf * CFrame.new(-1.4 + col * 0.6, 2.4 + row * 0.95, -1.2), Color3.fromHSV((row * 4 + col) / 20, 0.6, 0.6))
		end
	end
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Color = Color3.fromRGB(170, 230, 255)
	light.Range = 10
	light.Brightness = 0
	light.Angle = 120
	light.Parent = glass
	m:SetAttribute("Mode", "Flicker")
	m:SetAttribute("Brightness", 0.8)
	m:SetAttribute("LitColor", Color3.fromRGB(150, 210, 230))
	m:SetAttribute("Seed", math.random() * 1000)
	m:SetAttribute("KeepMaterial", true)
	CollectionService:AddTag(m, "HorrorLight")
	return m
end

function Props.Sofa(parent: Instance, cf: CFrame)
	local m = model(parent, "Sofa")
	local c = Color3.fromRGB(70, 60, 48)
	Props.Part(m, Vector3.new(7, 1.4, 3), cf * CFrame.new(0, 1.3, 0), c, Enum.Material.Fabric)
	Props.Part(m, Vector3.new(7, 2.4, 0.9), cf * CFrame.new(0, 2.6, 1.1), c, Enum.Material.Fabric)
	for _, x in { -3.2, 3.2 } do
		Props.Part(m, Vector3.new(0.8, 2.2, 3), cf * CFrame.new(x, 1.6, 0), c, Enum.Material.Fabric)
	end
	flat(m, Vector3.new(1.4, 0.05, 1), cf * CFrame.new(-1.5, 2.02, -0.4) * A(0, 30, 0), Color3.fromRGB(40, 30, 25))
	return m
end

function Props.Table(parent: Instance, cf: CFrame, w: number?, d: number?)
	local m = model(parent, "Table")
	local width, depth = w or 5, d or 3
	Props.Part(m, Vector3.new(width, 0.25, depth), cf * CFrame.new(0, 3, 0), Color3.fromRGB(120, 116, 104), Enum.Material.Wood)
	for _, x in { -width / 2 + 0.3, width / 2 - 0.3 } do
		for _, z in { -depth / 2 + 0.3, depth / 2 - 0.3 } do
			Props.Part(m, Vector3.new(0.2, 2.9, 0.2), cf * CFrame.new(x, 1.45, z), METAL, Enum.Material.Metal)
		end
	end
	return m
end

function Props.Monitor(parent: Instance, cf: CFrame, text: string?, lit: boolean?)
	local m = model(parent, "Monitor")
	Props.Part(m, Vector3.new(2.4, 1.9, 1.6), cf * CFrame.new(0, 1.1, 0.2), Color3.fromRGB(180, 176, 160), Enum.Material.SmoothPlastic)
	local screen = Props.Part(m, Vector3.new(2, 1.5, 0.05), cf * CFrame.new(0, 1.15, -0.62), Color3.fromRGB(10, 14, 12), Enum.Material.SmoothPlastic, {
		Name = "Screen",
	})
	if text then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = lit and 0 or 1
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 80
		gui.Parent = screen
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(6, 20, 14)
		label.TextColor3 = Color3.fromRGB(120, 255, 170)
		label.Font = Enum.Font.Code
		label.TextScaled = true
		label.Text = text
		label.TextTransparency = lit and 0.15 or 0.6
		label.Parent = gui
		if lit then
			local glow = Instance.new("SurfaceLight")
			glow.Face = Enum.NormalId.Front
			glow.Color = Color3.fromRGB(90, 220, 150)
			glow.Range = 7
			glow.Brightness = 0.6
			glow.Parent = screen
		end
	end
	return m
end

function Props.Generator(parent: Instance, cf: CFrame)
	local m = model(parent, "Generator")
	Props.Part(m, Vector3.new(9, 5, 5), cf * CFrame.new(0, 2.5, 0), Color3.fromRGB(70, 82, 64), Enum.Material.Metal)
	Props.Part(m, Vector3.new(9.6, 0.6, 5.6), cf * CFrame.new(0, 0.3, 0), DARK_METAL, Enum.Material.DiamondPlate)
	Props.Part(m, Vector3.new(3, 3, 3), cf * CFrame.new(-2.5, 6.2, 0), Color3.fromRGB(60, 70, 56), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	Props.Part(m, Vector3.new(0.8, 6, 0.8), cf * CFrame.new(3.2, 7.5, 1.2), RUST, Enum.Material.CorrodedMetal)
	for i = 0, 5 do
		flat(m, Vector3.new(0.15, 3.5, 4.6), cf * CFrame.new(1 + i * 0.5, 2.6, 0), DARK_METAL, Enum.Material.Metal)
	end
	-- warning stripes
	for i = 0, 4 do
		flat(m, Vector3.new(1, 0.05, 0.8), cf * CFrame.new(-4 + i * 2, 0.62, -2.6) * A(0, 45, 0), Color3.fromRGB(200, 170, 20))
	end
	return m
end

function Props.Boiler(parent: Instance, cf: CFrame)
	local m = model(parent, "Boiler")
	Props.Part(m, Vector3.new(10, 5, 5), cf * CFrame.new(0, 6.2, 0) * A(0, 0, 90), RUST, Enum.Material.CorrodedMetal, {
		Shape = Enum.PartType.Cylinder,
	})
	Props.Part(m, Vector3.new(6, 1.2, 6), cf * CFrame.new(0, 0.6, 0), DARK_METAL, Enum.Material.Concrete)
	Props.Part(m, Vector3.new(1.2, 4, 1.2), cf * CFrame.new(0, 11.5, 0), RUST, Enum.Material.CorrodedMetal, { Shape = Enum.PartType.Cylinder })
	local dial = Props.Part(m, Vector3.new(0.2, 1.2, 1.2), cf * CFrame.new(0, 5.5, -2.6) * A(0, 90, 0), Color3.fromRGB(220, 210, 180), Enum.Material.SmoothPlastic, {
		Shape = Enum.PartType.Cylinder,
	})
	dial.CanCollide = false
	return m
end

-- Straight pipe between two points.
function Props.Pipe(parent: Instance, from: Vector3, to: Vector3, radius: number?, color: Color3?)
	local r = radius or 0.5
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local dir = to - from
	local cf
	if math.abs(dir.Unit.Y) > 0.99 then
		cf = CFrame.new(mid) * A(0, 0, 90) -- vertical: cylinder axis (X) -> world Y
	else
		cf = CFrame.lookAt(mid, to) * A(0, 90, 0) -- cylinder axis (X) -> look direction
	end
	local pipe = Props.Part(parent, Vector3.new(length, r * 2, r * 2), cf, color or RUST, Enum.Material.CorrodedMetal, {
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
	})
	return pipe
end

function Props.IVStand(parent: Instance, cf: CFrame)
	local m = model(parent, "IVStand")
	Props.Part(m, Vector3.new(0.15, 6.5, 0.15), cf * CFrame.new(0, 3.25, 0), METAL, Enum.Material.Metal)
	Props.Part(m, Vector3.new(1.6, 0.15, 1.6), cf * CFrame.new(0, 0.1, 0), METAL, Enum.Material.Metal)
	Props.Part(m, Vector3.new(0.6, 1, 0.3), cf * CFrame.new(0.4, 5.9, 0), Color3.fromRGB(150, 40, 40), Enum.Material.Glass, {
		Transparency = 0.3,
	})
	flat(m, Vector3.new(0.05, 3.5, 0.05), cf * CFrame.new(0.45, 3.7, 0), Color3.fromRGB(180, 180, 180))
	return m
end

function Props.Curtain(parent: Instance, cf: CFrame, width: number, torn: boolean?)
	local m = model(parent, "Curtain")
	Props.Part(m, Vector3.new(width, 0.15, 0.15), cf * CFrame.new(0, 9, 0), METAL, Enum.Material.Metal, { CanCollide = false })
	local panels = math.floor(width / 1.2)
	for i = 0, panels - 1 do
		if not (torn and i % 3 == 1) then
			local height = torn and (5 + (i % 2) * 2) or 7.5
			Props.Part(
				m,
				Vector3.new(1.25, height, 0.08),
				cf * CFrame.new(-width / 2 + 0.6 + i * 1.2, 9 - height / 2, (i % 2) * 0.25) * A(0, (i % 2 == 0) and 10 or -10, 0),
				Color3.fromRGB(120, 150, 140),
				Enum.Material.Fabric,
				{ CanCollide = false, CastShadow = true }
			)
		end
	end
	return m
end

function Props.Bench(parent: Instance, cf: CFrame)
	local m = model(parent, "Bench")
	Props.Part(m, Vector3.new(6, 0.3, 1.8), cf * CFrame.new(0, 1.8, 0), WOOD, Enum.Material.Wood)
	Props.Part(m, Vector3.new(6, 1.6, 0.25), cf * CFrame.new(0, 2.8, 0.8), WOOD, Enum.Material.Wood)
	for _, x in { -2.6, 2.6 } do
		Props.Part(m, Vector3.new(0.25, 1.7, 1.6), cf * CFrame.new(x, 0.85, 0), DARK_METAL, Enum.Material.Metal)
	end
	return m
end

function Props.DeadPlant(parent: Instance, cf: CFrame)
	local m = model(parent, "DeadPlant")
	Props.Part(m, Vector3.new(1.8, 1.8, 1.8), cf * CFrame.new(0, 0.9, 0), Color3.fromRGB(110, 70, 50), Enum.Material.Slate)
	for i = 0, 4 do
		flat(m, Vector3.new(0.08, 2.2, 0.08), cf * CFrame.new(0, 2.6, 0) * A(20, i * 72, 0) * CFrame.new(0, 0.6, 0), Color3.fromRGB(70, 56, 40), Enum.Material.Wood)
	end
	return m
end

-- Clock frozen at 2:13.
function Props.Clock(parent: Instance, cf: CFrame)
	local m = model(parent, "Clock")
	Props.Part(m, Vector3.new(0.2, 2, 2), cf * A(0, 90, 0), Color3.fromRGB(200, 196, 180), Enum.Material.SmoothPlastic, {
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
	})
	flat(m, Vector3.new(0.08, 0.6, 0.05), cf * CFrame.new(0, 0, -0.12) * A(0, 0, -66) * CFrame.new(0, 0.28, 0), Color3.new())
	flat(m, Vector3.new(0.06, 0.85, 0.05), cf * CFrame.new(0, 0, -0.13) * A(0, 0, -78) * CFrame.new(0, 0.4, 0), Color3.new())
	return m
end

function Props.Cart(parent: Instance, cf: CFrame, rng: Random)
	local m = model(parent, "Cart")
	for _, y in { 0.9, 2.6 } do
		Props.Part(m, Vector3.new(2.4, 0.15, 3.6), cf * CFrame.new(0, y, 0), METAL, Enum.Material.Metal)
	end
	for _, x in { -1.1, 1.1 } do
		for _, z in { -1.7, 1.7 } do
			Props.Part(m, Vector3.new(0.12, 2.6, 0.12), cf * CFrame.new(x, 1.4, z), METAL, Enum.Material.Metal)
		end
	end
	for i = 1, 4 do
		flat(m, Vector3.new(0.3, 0.7, 0.3), cf * CFrame.new(rng:NextNumber(-0.8, 0.8), 3.05, rng:NextNumber(-1.3, 1.3)), Color3.fromRGB(150, 140, 120), Enum.Material.Glass)
	end
	return m
end

-- Porcelain doll in a little white dress (sits on chairs in the therapy room).
function Props.Doll(parent: Instance, cf: CFrame)
	local m = model(parent, "Doll")
	local skin = Color3.fromRGB(226, 218, 206)
	flat(m, Vector3.new(0.8, 0.9, 0.6), cf * CFrame.new(0, 0.45, 0), Color3.fromRGB(220, 216, 204), Enum.Material.Fabric)
	flat(m, Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(0, 1.2, 0), skin, Enum.Material.SmoothPlastic).Shape = Enum.PartType.Ball
	flat(m, Vector3.new(0.66, 0.5, 0.66), cf * CFrame.new(0, 1.35, 0.06), Color3.fromRGB(20, 16, 14), Enum.Material.Fabric)
	for _, x in { -0.12, 0.12 } do
		flat(m, Vector3.new(0.1, 0.1, 0.05), cf * CFrame.new(x, 1.22, -0.29), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	end
	flat(m, Vector3.new(0.18, 0.03, 0.04), cf * CFrame.new(0, 1.07, -0.29), Color3.fromRGB(120, 10, 10), Enum.Material.SmoothPlastic)
	for _, x in { -0.45, 0.45 } do
		flat(m, Vector3.new(0.15, 0.6, 0.15), cf * CFrame.new(x, 0.55, -0.1) * A(-30, 0, 0), skin, Enum.Material.SmoothPlastic)
		flat(m, Vector3.new(0.17, 0.17, 0.6), cf * CFrame.new(x * 0.5, 0.1, -0.35), skin, Enum.Material.SmoothPlastic)
	end
	return m
end

function Props.RockingHorse(parent: Instance, cf: CFrame)
	local m = model(parent, "RockingHorse")
	local wood = Color3.fromRGB(150, 110, 70)
	for _, x in { -0.6, 0.6 } do
		Props.Part(m, Vector3.new(0.2, 0.3, 4.4), cf * CFrame.new(x, 0.3, 0), Color3.fromRGB(110, 40, 30), Enum.Material.Wood)
	end
	Props.Part(m, Vector3.new(1, 1, 2.6), cf * CFrame.new(0, 1.9, 0), wood, Enum.Material.Wood)
	Props.Part(m, Vector3.new(0.7, 1.2, 1.2), cf * CFrame.new(0, 2.8, -1.3) * A(-25, 0, 0), wood, Enum.Material.Wood)
	for _, x in { -0.35, 0.35 } do
		for _, z in { -0.9, 0.9 } do
			Props.Part(m, Vector3.new(0.25, 1.4, 0.25), cf * CFrame.new(x, 0.95, z), wood, Enum.Material.Wood)
		end
	end
	return m
end

-- Collapsed debris pile (rubble + bent pipe), used as chase obstacles.
function Props.Debris(parent: Instance, cf: CFrame, rng: Random, scale: number?)
	local s = scale or 1
	local m = model(parent, "Debris")
	for _ = 1, 6 do
		local size = Vector3.new(rng:NextNumber(0.8, 2.4), rng:NextNumber(0.5, 1.5), rng:NextNumber(0.8, 2.4)) * s
		Props.Part(
			m,
			size,
			cf * CFrame.new(rng:NextNumber(-1.8, 1.8) * s, size.Y / 2, rng:NextNumber(-1.8, 1.8) * s) * A(rng:NextNumber(-20, 20), rng:NextNumber(0, 180), rng:NextNumber(-20, 20)),
			Color3.fromRGB(100 + rng:NextInteger(-15, 15), 98, 92),
			Enum.Material.Concrete
		)
	end
	Props.Part(m, Vector3.new(0.3, 0.3, 6 * s), cf * CFrame.new(0, 1.4 * s, 0) * A(25, 40, 0), RUST, Enum.Material.CorrodedMetal)
	return m
end

-- Collapsed ceiling panel leaning across a corridor (an obstacle you weave around).
function Props.FallenPanel(parent: Instance, cf: CFrame)
	local m = model(parent, "FallenPanel")
	Props.Part(m, Vector3.new(4.5, 0.4, 9), cf * CFrame.new(0, 3.5, 0) * A(0, 0, 50), Color3.fromRGB(120, 118, 110), Enum.Material.Plaster)
	Props.Part(m, Vector3.new(0.3, 0.3, 8), cf * CFrame.new(1.2, 5, 0) * A(0, 0, 50), RUST, Enum.Material.CorrodedMetal)
	return m
end

function Props.Chain(parent: Instance, top: Vector3, length: number)
	local m = model(parent, "Chain")
	local links = math.floor(length / 0.5)
	for i = 0, links - 1 do
		flat(m, Vector3.new(0.12, 0.55, 0.3), CFrame.new(top - Vector3.new(0, i * 0.5 + 0.25, 0)) * A(0, (i % 2) * 90, 0), DARK_METAL, Enum.Material.Metal)
	end
	return m
end

function Props.Puddle(parent: Instance, position: Vector3, size: Vector2, color: Color3?)
	return Props.Part(parent, Vector3.new(size.X, 0.06, size.Y), CFrame.new(position + Vector3.new(0, 0.03, 0)), color or Color3.fromRGB(26, 34, 36), Enum.Material.Glass, {
		CanCollide = false,
		CanQuery = false,
		Reflectance = 0.25,
		Transparency = 0.15,
		CastShadow = false,
	})
end

function Props.BloodPool(parent: Instance, position: Vector3, radius: number, rng: Random)
	local m = model(parent, "BloodPool")
	flat(m, Vector3.new(0.05, radius * 2, radius * 2), CFrame.new(position + Vector3.new(0, 0.04, 0)) * A(0, 0, 90), BLOOD, Enum.Material.Glass).Shape =
		Enum.PartType.Cylinder
	for _ = 1, 5 do
		local r = radius * rng:NextNumber(0.15, 0.4)
		local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * radius * rng:NextNumber(0.9, 1.6)
		flat(m, Vector3.new(0.05, r * 2, r * 2), CFrame.new(position + offset + Vector3.new(0, 0.04, 0)) * A(0, 0, 90), BLOOD, Enum.Material.Glass).Shape =
			Enum.PartType.Cylinder
	end
	return m
end

-- Trail of dragged blood along the floor.
function Props.DragMarks(parent: Instance, from: Vector3, to: Vector3)
	local m = model(parent, "DragMarks")
	local dir = (to - from)
	local length = dir.Magnitude
	local cf = CFrame.lookAt(from, to)
	for i = 0, math.floor(length / 1.5) do
		local width = 0.8 + math.sin(i * 1.7) * 0.3
		flat(m, Vector3.new(width, 0.05, 1.7), cf * CFrame.new(math.sin(i * 0.9) * 0.3, 0.04, -i * 1.5), DRIED_BLOOD, Enum.Material.SmoothPlastic)
	end
	return m
end

function Props.Papers(parent: Instance, center: Vector3, spread: number, count: number, rng: Random)
	local m = model(parent, "Papers")
	for _ = 1, count do
		flat(
			m,
			Vector3.new(0.85, 0.03, 1.1),
			CFrame.new(center + Vector3.new(rng:NextNumber(-spread, spread), 0.03, rng:NextNumber(-spread, spread))) * A(rng:NextNumber(-3, 3), rng:NextNumber(0, 360), 0),
			PAPER:Lerp(Color3.fromRGB(150, 140, 110), rng:NextNumber()),
			Enum.Material.SmoothPlastic
		)
	end
	return m
end

---------------------------------------------------------------------------------------------
-- WALL ART (SurfaceGui based)
---------------------------------------------------------------------------------------------

-- Creates an invisible plate on a wall. `cf` must face OUT of the wall (LookVector = wall normal).
function Props.WallCanvas(parent: Instance, cf: CFrame, size: Vector2): (Part, SurfaceGui)
	local plate = flat(parent, Vector3.new(size.X, size.Y, 0.05), cf, Color3.new(), Enum.Material.SmoothPlastic)
	plate.Transparency = 1
	plate.Name = "Canvas"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 1
	gui.Brightness = 1
	gui.Parent = plate
	return plate, gui
end

local function frame(parent: Instance, pos: UDim2, size: UDim2, color: Color3, rotation: number?, transparency: number?, round: boolean?)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Rotation = rotation or 0
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
	end
	f.Parent = parent
	return f
end

function Props.BloodWriting(parent: Instance, cf: CFrame, text: string, width: number, rng: Random?)
	local _, gui = Props.WallCanvas(parent, cf, Vector2.new(width, width * 0.3))
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.8)
	label.Font = Enum.Font.Creepster
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = BLOOD
	label.Rotation = rng and rng:NextNumber(-4, 4) or -2
	label.Parent = gui
	-- drips under the letters
	local r = rng or Random.new(#text)
	for _ = 1, math.max(3, #text // 2) do
		local x = r:NextNumber(0.05, 0.95)
		local length = r:NextNumber(0.15, 0.5)
		local drip = frame(gui, UDim2.fromScale(x, 0.62 + length / 2), UDim2.new(0, 3, length, 0), BLOOD, 0, 0.1)
		frame(drip, UDim2.fromScale(0.5, 1), UDim2.fromOffset(7, 7), BLOOD, 0, 0, true)
	end
	return gui
end

function Props.Scratches(parent: Instance, cf: CFrame, size: number, rng: Random)
	local _, gui = Props.WallCanvas(parent, cf, Vector2.new(size, size))
	for set = 1, rng:NextInteger(1, 3) do
		local cx, cy = rng:NextNumber(0.25, 0.75), rng:NextNumber(0.25, 0.75)
		local rot = rng:NextNumber(-35, 35)
		for i = 0, 3 do
			local offset = (i - 1.5) * 0.06
			local length = rng:NextNumber(0.35, 0.6)
			frame(
				gui,
				UDim2.fromScale(cx + offset * math.cos(math.rad(rot)), cy + offset * math.sin(math.rad(rot))),
				UDim2.new(0, 4, length, 0),
				Color3.fromRGB(26, 20, 16),
				rot + rng:NextNumber(-4, 4),
				0.15 + set * 0.05
			)
		end
	end
	return gui
end

function Props.BloodSmear(parent: Instance, cf: CFrame, size: Vector2, rng: Random, handprints: boolean?)
	local _, gui = Props.WallCanvas(parent, cf, size)
	for _ = 1, rng:NextInteger(4, 8) do
		frame(
			gui,
			UDim2.fromScale(rng:NextNumber(0.2, 0.8), rng:NextNumber(0.2, 0.7)),
			UDim2.fromScale(rng:NextNumber(0.1, 0.5), rng:NextNumber(0.04, 0.12)),
			rng:NextNumber() > 0.5 and BLOOD or DRIED_BLOOD,
			rng:NextNumber(-60, 60),
			rng:NextNumber(0, 0.4),
			true
		)
	end
	for _ = 1, rng:NextInteger(2, 6) do
		local x = rng:NextNumber(0.2, 0.8)
		local length = rng:NextNumber(0.2, 0.5)
		frame(gui, UDim2.fromScale(x, 0.5 + length / 2), UDim2.new(0, 4, length, 0), BLOOD, 0, 0.1)
	end
	if handprints then
		for i = 0, rng:NextInteger(1, 3) do
			local hx, hy = 0.2 + i * 0.22, rng:NextNumber(0.3, 0.6)
			local palm = frame(gui, UDim2.fromScale(hx, hy), UDim2.fromOffset(26, 30), BLOOD, rng:NextNumber(-20, 20), 0.05, true)
			for f = 0, 3 do
				frame(palm, UDim2.new(0.12 + f * 0.25, 0, -0.45, 0), UDim2.fromOffset(6, 20), BLOOD, (f - 1.5) * 8, 0.05, true)
			end
			frame(palm, UDim2.new(1.1, 0, 0.3, 0), UDim2.fromOffset(6, 16), BLOOD, 50, 0.05, true)
		end
	end
	return gui
end

-- Room signs / door plaques.
function Props.Sign(parent: Instance, cf: CFrame, text: string, width: number?, color: Color3?, textColor: Color3?, glow: boolean?)
	local w = width or 4
	local plate = Props.Part(parent, Vector3.new(w, w * 0.25, 0.12), cf, color or Color3.fromRGB(38, 54, 48), Enum.Material.SmoothPlastic, {
		CanCollide = false,
		Name = "Sign",
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = glow and 0 or 1
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.Font = Enum.Font.Arimo
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(220, 215, 200)
	label.Parent = gui
	return plate
end

-- Lit red EXIT sign (uses neon + a small light so it reads in the dark).
function Props.ExitSign(parent: Instance, cf: CFrame, text: string?)
	local sign = Props.Sign(parent, cf, text or "EXIT", 3, Color3.fromRGB(30, 8, 8), Color3.fromRGB(255, 40, 30), true)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Color = Color3.fromRGB(255, 30, 20)
	light.Range = 8
	light.Brightness = 0.7
	light.Parent = sign
	return sign
end

---------------------------------------------------------------------------------------------
-- PARTICLES / WEATHER
---------------------------------------------------------------------------------------------

-- Low drifting fog. Tagged so clients can disable it on Low graphics.
function Props.FogEmitter(parent: Instance, cf: CFrame, size: Vector3, density: number?, color: Color3?)
	local box = flat(parent, size, cf, Color3.new(), Enum.Material.SmoothPlastic)
	box.Transparency = 1
	box.Name = "FogVolume"
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(120, 125, 130))
	emitter.LightInfluence = 1
	emitter.LightEmission = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 11) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.86),
		NumberSequenceKeypoint.new(0.7, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(8, 14)
	emitter.Rate = density or 2
	emitter.Speed = NumberRange.new(0.3, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 10)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-8, 8)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Parent = box
	CollectionService:AddTag(emitter, "AmbientParticles")
	return emitter
end

function Props.RainEmitter(parent: Instance, cf: CFrame, size: Vector3)
	local box = flat(parent, size, cf, Color3.new(), Enum.Material.SmoothPlastic)
	box.Transparency = 1
	box.Name = "Rain"
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 165, 190))
	emitter.LightInfluence = 0.6
	emitter.Size = NumberSequence.new(0.08)
	emitter.Squash = NumberSequence.new(-3.5)
	emitter.Transparency = NumberSequence.new(0.55)
	emitter.Lifetime = NumberRange.new(0.8, 1.1)
	emitter.Rate = 220
	emitter.Speed = NumberRange.new(70, 85)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(4, 4)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Parent = box
	CollectionService:AddTag(emitter, "AmbientParticles")
	return emitter
end

function Props.Steam(parent: Instance, position: Vector3, direction: Vector3?)
	local att = Instance.new("Attachment")
	att.WorldCFrame = CFrame.lookAt(position, position + (direction or Vector3.yAxis))
	att.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(180, 180, 180))
	emitter.LightInfluence = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 4) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.Rate = 12
	emitter.Speed = NumberRange.new(4, 7)
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Parent = att
	CollectionService:AddTag(emitter, "AmbientParticles")
	return emitter
end

function Props.Dust(parent: Instance, cf: CFrame, size: Vector3)
	local box = flat(parent, size, cf, Color3.new(), Enum.Material.SmoothPlastic)
	box.Transparency = 1
	box.Name = "Dust"
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 190, 170))
	emitter.LightInfluence = 1
	emitter.Size = NumberSequence.new(0.06)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(6, 10)
	emitter.Rate = 6
	emitter.Speed = NumberRange.new(0.1, 0.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Parent = box
	CollectionService:AddTag(emitter, "AmbientParticles")
	return emitter
end

---------------------------------------------------------------------------------------------
-- EXTERIOR
---------------------------------------------------------------------------------------------

function Props.DeadTree(parent: Instance, position: Vector3, rng: Random)
	local m = model(parent, "DeadTree")
	local height = rng:NextNumber(18, 30)
	local trunkColor = Color3.fromRGB(38, 32, 28)
	Props.Part(m, Vector3.new(1.6, height, 1.6), CFrame.new(position + Vector3.new(0, height / 2, 0)) * A(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)), trunkColor, Enum.Material.Wood)
	for _ = 1, rng:NextInteger(4, 7) do
		local y = rng:NextNumber(height * 0.45, height * 0.95)
		local length = rng:NextNumber(4, 9)
		local yaw = rng:NextNumber(0, 360)
		local pitch = rng:NextNumber(25, 60)
		Props.Part(
			m,
			Vector3.new(0.5, length, 0.5),
			CFrame.new(position + Vector3.new(0, y, 0)) * A(0, yaw, 0) * A(pitch, 0, 0) * CFrame.new(0, length / 2, 0),
			trunkColor,
			Enum.Material.Wood,
			{ CanCollide = false }
		)
	end
	return m
end

function Props.Fence(parent: Instance, from: Vector3, to: Vector3)
	local m = model(parent, "Fence")
	local dir = to - from
	local length = dir.Magnitude
	local cf = CFrame.lookAt(from, to)
	local posts = math.floor(length / 8)
	for i = 0, posts do
		Props.Part(m, Vector3.new(0.4, 10, 0.4), cf * CFrame.new(0, 5, -i * 8), DARK_METAL, Enum.Material.Metal)
	end
	Props.Part(m, Vector3.new(0.1, 9, length), cf * CFrame.new(0, 5, -length / 2), Color3.fromRGB(80, 80, 80), Enum.Material.Metal, {
		Transparency = 0.82,
	})
	for _, y in { 9.6, 5, 0.6 } do
		Props.Part(m, Vector3.new(0.15, 0.15, length), cf * CFrame.new(0, y, -length / 2), DARK_METAL, Enum.Material.Metal)
	end
	return m
end

return Props
