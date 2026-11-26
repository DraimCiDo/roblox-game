--!strict
-- Детализированные 3D-модели предметов из деталей Roblox. Начало координат — центр основания,
-- лицевая сторона смотрит в -Z. Используется и миром (сервер), и иконками интерфейса (клиент).
local Catalog = require(script.Parent.Parent.Catalog)

type Axis = "x" | "y" | "z"

export type Options = {
	-- true — полная детализация для мира; false — упрощённая для маленьких иконок.
	Full: boolean?,
}

type Tools = {
	Block: (number, number, number, number, number, number, Color3, Enum.Material?, Vector3?) -> Part,
	Ball: (number, number, number, number, Color3, Enum.Material?) -> Part,
	Cyl: (number, number, number, Axis, number, number, Color3, Enum.Material?, Vector3?) -> Part,
	-- Тонкий диск, «наклеенный» на поверхность: лежит в точке и смотрит нормалью к целевой точке.
	Disc: (Vector3, Vector3, number, number, Color3, Enum.Material?) -> Part,
	Text: (Part, Enum.NormalId, string, Color3) -> (),
	Full: boolean,
	Tint: Color3,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local WHITE = rgb(240, 240, 236)
local BLACK = rgb(24, 26, 30)
local GRAY = rgb(88, 94, 104)
local CHROME = rgb(205, 212, 222)
local GOLD = rgb(246, 196, 70)
local GOLD_DARK = rgb(196, 146, 40)
local RED = rgb(214, 62, 62)
local BROWN = rgb(120, 82, 52)
local PLASTIC = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon
local GLASSY = Enum.Material.Glass

local ItemModels = {}

local function makeTools(parent: Instance, full: boolean, tint: Color3): Tools
	local function part(
		shape: Enum.PartType,
		size: Vector3,
		frame: CFrame,
		color: Color3,
		material: Enum.Material?
	): Part
		local piece = Instance.new("Part")
		piece.Name = "Деталь"
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Shape = shape
		piece.Size = size
		piece.CFrame = frame
		piece.Color = color
		piece.Material = material or PLASTIC
		if material == METAL then
			piece.Reflectance = 0.12
		end
		piece.Parent = parent
		return piece
	end
	local function rotation(rot: Vector3?): CFrame
		if not rot then
			return CFrame.identity
		end
		return CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	end
	local tools = {} :: Tools
	tools.Full = full
	tools.Tint = tint
	tools.Block = function(x, y, z, sx, sy, sz, color, material, rot)
		return part(Enum.PartType.Block, Vector3.new(sx, sy, sz), CFrame.new(x, y, z) * rotation(rot), color, material)
	end
	tools.Ball = function(x, y, z, d, color, material)
		return part(Enum.PartType.Ball, Vector3.one * d, CFrame.new(x, y, z), color, material)
	end
	tools.Cyl = function(x, y, z, axis, length, d, color, material, rot)
		local turn = if axis == "y"
			then CFrame.Angles(0, 0, math.pi / 2)
			elseif axis == "z" then CFrame.Angles(0, math.pi / 2, 0)
			else CFrame.identity
		return part(
			Enum.PartType.Cylinder,
			Vector3.new(length, d, d),
			CFrame.new(x, y, z) * rotation(rot) * turn,
			color,
			material
		)
	end
	tools.Disc = function(position, target, d, thickness, color, material)
		local frame = CFrame.lookAt(position, target) * CFrame.Angles(0, math.pi / 2, 0)
		return part(Enum.PartType.Cylinder, Vector3.new(thickness, d, d), frame, color, material)
	end
	tools.Text = function(owner, face, text, color)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 80
		gui.Parent = owner
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.Parent = gui
	end
	return tools
end

local PHI = (1 + math.sqrt(5)) / 2

-- ============ Коробка ============

local B: { [string]: (Tools) -> () } = {}

B.ball = function(t)
	local center = Vector3.new(0, 0.75, 0)
	t.Ball(0, 0.75, 0, 1.5, WHITE)
	local vertices = {
		Vector3.new(0, 1, PHI),
		Vector3.new(0, -1, PHI),
		Vector3.new(0, 1, -PHI),
		Vector3.new(0, -1, -PHI),
		Vector3.new(1, PHI, 0),
		Vector3.new(-1, PHI, 0),
		Vector3.new(1, -PHI, 0),
		Vector3.new(-1, -PHI, 0),
		Vector3.new(PHI, 0, 1),
		Vector3.new(-PHI, 0, 1),
		Vector3.new(PHI, 0, -1),
		Vector3.new(-PHI, 0, -1),
	}
	for _, vertex in vertices do
		local spot = center + vertex.Unit * 0.735
		t.Disc(spot, center, 0.5, 0.06, BLACK)
	end
	if t.Full then
		t.Ball(-0.35, 1.25, -0.5, 0.22, rgb(255, 255, 255), GLASSY).Transparency = 0.6
	end
end

B.trash = function(t)
	local bag = rgb(34, 38, 46)
	t.Ball(0, 0.62, 0, 1.25, bag)
	t.Ball(0.3, 0.5, 0.2, 0.85, bag)
	t.Ball(-0.35, 0.48, -0.25, 0.8, bag)
	t.Cyl(0, 1.2, 0, "y", 0.45, 0.55, bag)
	t.Cyl(0, 1.5, 0, "y", 0.22, 0.28, rgb(60, 66, 78))
	t.Ball(0, 1.68, 0, 0.36, bag)
	t.Block(0.22, 1.82, 0, 0.1, 0.46, 0.1, bag, nil, Vector3.new(0, 0, -28))
	t.Block(-0.22, 1.82, 0, 0.1, 0.46, 0.1, bag, nil, Vector3.new(0, 0, 28))
	if t.Full then
		t.Ball(-0.2, 0.95, -0.45, 0.3, rgb(255, 255, 255), GLASSY).Transparency = 0.75
		t.Block(0.15, 0.4, -0.62, 0.5, 0.06, 0.04, rgb(52, 58, 70), nil, Vector3.new(0, 0, 18))
	end
end

B.bell = function(t)
	t.Cyl(0, 0.07, 0, "y", 0.14, 1.6, rgb(150, 156, 166), METAL)
	t.Cyl(0, 0.2, 0, "y", 0.14, 1.45, CHROME, METAL)
	t.Cyl(0, 0.34, 0, "y", 0.14, 1.28, CHROME, METAL)
	t.Cyl(0, 0.48, 0, "y", 0.14, 1.02, CHROME, METAL)
	t.Cyl(0, 0.6, 0, "y", 0.12, 0.68, CHROME, METAL)
	t.Ball(0, 0.62, 0, 0.62, CHROME, METAL)
	t.Cyl(0, 0.82, 0, "y", 0.1, 0.2, GOLD_DARK, METAL)
	t.Ball(0, 0.92, 0, 0.3, GOLD, METAL)
	if t.Full then
		t.Block(0, 0.02, -0.55, 0.5, 0.05, 0.26, RED)
		t.Cyl(0.5, 0.14, -0.1, "y", 0.07, 0.18, GOLD_DARK, METAL)
	end
end

B.bowl = function(t)
	local color = t.Tint
	t.Cyl(0, 0.04, 0, "y", 0.08, 1.15, rgb(60, 110, 140))
	t.Cyl(0, 0.16, 0, "y", 0.16, 1.4, color)
	t.Cyl(0, 0.34, 0, "y", 0.2, 1.62, color)
	t.Cyl(0, 0.54, 0, "y", 0.2, 1.8, color)
	t.Cyl(0, 0.66, 0, "y", 0.06, 1.88, WHITE)
	t.Cyl(0, 0.62, 0, "y", 0.06, 1.55, BROWN)
	for index = 1, 9 do
		local angle = index * 2.4
		local radius = 0.1 + (index % 4) * 0.17
		t.Ball(
			math.cos(angle) * radius,
			0.7,
			math.sin(angle) * radius,
			0.2,
			if index % 2 == 0 then rgb(150, 98, 54) else rgb(96, 62, 36)
		)
	end
	-- Лапка на лицевой стороне.
	local target = Vector3.new(0, 0.38, 0)
	t.Disc(Vector3.new(0, 0.36, -0.77), target, 0.32, 0.04, WHITE)
	for _, offset in { -0.2, -0.07, 0.07, 0.2 } do
		t.Disc(Vector3.new(offset, 0.58, -0.81), Vector3.new(offset, 0.58, 0), 0.12, 0.04, WHITE)
	end
end

B.painting = function(t)
	t.Block(0, 0.04, 0.12, 1.5, 0.08, 0.55, rgb(80, 56, 40), Enum.Material.Wood)
	t.Block(0, 0.9, 0.04, 1.6, 1.45, 0.06, rgb(46, 30, 70))
	t.Block(0, 1.25, 0.0, 1.46, 0.55, 0.04, rgb(70, 54, 120))
	t.Block(0, 0.8, 0.0, 1.46, 0.42, 0.04, rgb(70, 130, 150))
	t.Block(0, 0.42, 0.0, 1.46, 0.36, 0.04, rgb(180, 150, 210))
	t.Ball(0, 0.95, -0.04, 0.62, rgb(246, 246, 250), PLASTIC).Transparency = 0.15
	t.Ball(-0.1, 1.0, -0.33, 0.1, BLACK)
	t.Ball(0.1, 1.0, -0.33, 0.1, BLACK)
	t.Block(0, 0.88, -0.35, 0.14, 0.04, 0.03, BLACK)
	for _, bar in
		{
			{ 0, 1.66, 1.7, 0.16 },
			{ 0, 0.14, 1.7, 0.16 },
		}
	do
		t.Block(bar[1], bar[2], 0, bar[3], bar[4], 0.14, GOLD, METAL)
	end
	for _, side in { -0.77, 0.77 } do
		t.Block(side, 0.9, 0, 0.16, 1.6, 0.14, GOLD, METAL)
	end
	if t.Full then
		for _, star in { { -0.5, 1.4 }, { 0.5, 1.35 }, { 0.35, 0.6 }, { -0.45, 0.55 } } do
			t.Ball(star[1], star[2], -0.03, 0.07, rgb(255, 255, 200), NEON)
		end
	end
end

B.fish = function(t)
	local orange = t.Tint
	local sizes = { { 0.55, 0.62 }, { 0.2, 0.9 }, { -0.1, 1.0 }, { -0.4, 0.84 }, { -0.68, 0.6 } }
	for _, ball in sizes do
		t.Ball(ball[1], 0.8, 0, ball[2], orange)
	end
	t.Ball(0.68, 0.84, 0, 0.5, rgb(240, 150, 90))
	-- Белые полосы.
	t.Cyl(0.05, 0.8, 0, "x", 0.12, 0.96, WHITE).Transparency = 0.05
	t.Cyl(-0.3, 0.8, 0, "x", 0.1, 0.88, WHITE).Transparency = 0.05
	-- Хвост и плавники.
	t.Block(-0.98, 0.95, 0, 0.5, 0.5, 0.1, orange, nil, Vector3.new(0, 0, 40))
	t.Block(-0.98, 0.65, 0, 0.5, 0.5, 0.1, orange, nil, Vector3.new(0, 0, -40))
	t.Block(0.0, 1.35, 0, 0.7, 0.36, 0.08, rgb(240, 120, 60), nil, Vector3.new(0, 0, 18))
	t.Block(0.15, 0.4, 0, 0.5, 0.3, 0.08, rgb(240, 120, 60), nil, Vector3.new(0, 0, -30))
	for _, side in { -1, 1 } do
		t.Ball(0.76, 0.9, side * 0.2, 0.2, WHITE)
		t.Ball(0.82, 0.9, side * 0.23, 0.1, BLACK)
		t.Block(0.1, 0.72, side * 0.46, 0.36, 0.2, 0.06, rgb(255, 160, 100), nil, Vector3.new(0, side * 20, 0))
	end
	t.Block(0, 0.12, 0, 0.5, 0.24, 0.4, rgb(70, 70, 80), Enum.Material.Slate)
end

B.dumbbell = function(t)
	t.Cyl(0, 0.62, 0, "x", 1.9, 0.18, CHROME, METAL)
	for _, side in { -1, 1 } do
		t.Cyl(side * 0.55, 0.62, 0, "x", 0.12, 0.34, CHROME, METAL)
		t.Cyl(side * 0.68, 0.62, 0, "x", 0.2, 1.0, rgb(40, 42, 48))
		t.Cyl(side * 0.86, 0.62, 0, "x", 0.16, 0.8, rgb(52, 55, 62))
		t.Cyl(side * 0.98, 0.62, 0, "x", 0.08, 0.34, CHROME, METAL)
		if t.Full then
			t.Disc(Vector3.new(side * 0.78, 0.62, -0.5), Vector3.new(side * 0.78, 0.62, 0), 0.22, 0.03, GOLD, METAL)
		end
	end
	t.Block(0, 0.06, 0, 2.0, 0.12, 0.7, rgb(44, 46, 52))
end

B.brush = function(t)
	t.Cyl(0, 0.2, 0, "y", 0.4, 0.78, WHITE)
	t.Cyl(0, 0.44, 0, "y", 0.06, 0.88, rgb(220, 224, 230))
	t.Cyl(0, 1.05, 0, "y", 1.3, 0.12, rgb(214, 218, 224))
	t.Cyl(0, 1.74, 0, "y", 0.12, 0.2, WHITE)
	t.Ball(0, 0.62, 0, 0.55, rgb(70, 180, 210))
	for index = 1, 12 do
		local angle = index * math.pi / 6
		t.Block(
			math.cos(angle) * 0.25,
			0.62,
			math.sin(angle) * 0.25,
			0.05,
			0.05,
			0.4,
			rgb(60, 160, 190),
			nil,
			Vector3.new(0, -math.deg(angle) + 90, 0)
		)
	end
	if t.Full then
		t.Disc(Vector3.new(0, 0.3, -0.4), Vector3.new(0, 0.3, 0), 0.3, 0.03, rgb(200, 206, 214))
	end
end

B.parcel = function(t)
	t.Block(0, 0.65, 0, 1.5, 1.3, 1.5, rgb(184, 136, 86), Enum.Material.Fabric)
	t.Block(0, 1.3, 0, 1.54, 0.05, 0.4, rgb(246, 198, 72))
	t.Block(0, 0.65, -0.76, 0.4, 1.3, 0.04, rgb(246, 198, 72))
	t.Block(0.46, 0.7, -0.77, 0.62, 0.42, 0.03, WHITE)
	if t.Full then
		for index = 1, 6 do
			t.Block(0.24 + index * 0.08, 0.7, -0.79, 0.02 + (index % 3) * 0.015, 0.3, 0.02, BLACK)
		end
		t.Block(-0.45, 0.4, -0.77, 0.4, 0.3, 0.03, RED)
		t.Cyl(0.7, 0.04, -0.7, "y", 0.04, 0.3, rgb(120, 90, 60))
	end
end

B.elfhat = function(t)
	local green = rgb(64, 150, 84)
	t.Cyl(0, 0.14, 0, "y", 0.28, 1.55, WHITE, Enum.Material.Fabric)
	local layers = { { 0.4, 1.3 }, { 0.62, 1.1 }, { 0.84, 0.9 }, { 1.06, 0.72 }, { 1.28, 0.54 }, { 1.5, 0.38 } }
	for index, layer in layers do
		t.Cyl(0, layer[1], 0, "y", 0.24, layer[2], if index % 2 == 0 then RED else green, Enum.Material.Fabric)
	end
	t.Block(0.32, 1.72, 0, 0.3, 0.2, 0.26, green, Enum.Material.Fabric, Vector3.new(0, 0, -45))
	t.Block(0.62, 1.58, 0, 0.3, 0.2, 0.26, RED, Enum.Material.Fabric, Vector3.new(0, 0, -75))
	t.Ball(0.82, 1.4, 0, 0.3, GOLD, METAL)
	if t.Full then
		t.Ball(0.82, 1.4, 0, 0.12, GOLD_DARK, METAL)
		for angle = 0, 5 do
			local a = angle * math.pi / 3
			t.Ball(math.cos(a) * 0.7, 0.3, math.sin(a) * 0.7, 0.18, rgb(246, 246, 240), Enum.Material.Fabric)
		end
	end
end

-- ============ Деревянный ящик ============

B.flower = function(t)
	local petal = t.Tint
	t.Cyl(0, 0.2, 0, "y", 0.4, 0.8, rgb(176, 98, 70), Enum.Material.Slate)
	t.Cyl(0, 0.42, 0, "y", 0.07, 0.9, rgb(196, 116, 84), Enum.Material.Slate)
	t.Cyl(0, 0.46, 0, "y", 0.05, 0.72, rgb(70, 46, 30))
	t.Cyl(0, 0.95, 0, "y", 1.0, 0.07, rgb(70, 140, 70))
	t.Block(0.22, 0.75, 0, 0.5, 0.06, 0.24, rgb(80, 156, 80), nil, Vector3.new(0, 0, 25))
	t.Block(-0.22, 0.95, 0, 0.5, 0.06, 0.24, rgb(80, 156, 80), nil, Vector3.new(0, 0, -25))
	for index = 0, 7 do
		local angle = index * math.pi / 4
		t.Ball(math.cos(angle) * 0.34, 1.62, math.sin(angle) * 0.34, 0.42, petal)
	end
	t.Ball(0, 1.64, 0, 0.4, GOLD_DARK)
	if t.Full then
		for index = 0, 5 do
			local angle = index * math.pi / 3
			t.Ball(math.cos(angle) * 0.11, 1.84, math.sin(angle) * 0.11, 0.08, rgb(150, 100, 30))
		end
	end
end

B.meteor = function(t)
	local rock = rgb(78, 66, 62)
	t.Ball(0, 0.62, 0, 1.2, rock, Enum.Material.Slate)
	t.Ball(0.35, 0.5, 0.2, 0.9, rgb(92, 78, 72), Enum.Material.Slate)
	t.Ball(-0.4, 0.45, -0.1, 0.8, rgb(66, 56, 54), Enum.Material.Slate)
	t.Ball(0.1, 0.95, -0.3, 0.6, rgb(86, 72, 66), Enum.Material.Slate)
	t.Block(0.1, 0.58, -0.6, 0.7, 0.05, 0.06, rgb(255, 120, 40), NEON, Vector3.new(0, 0, 20))
	t.Block(-0.2, 0.9, -0.55, 0.5, 0.05, 0.06, rgb(255, 150, 60), NEON, Vector3.new(0, 0, -30))
	t.Block(0.4, 0.3, -0.45, 0.4, 0.05, 0.06, rgb(255, 100, 30), NEON, Vector3.new(0, 20, 50))
	if t.Full then
		for index = 1, 7 do
			t.Ball(
				math.cos(index * 1.1) * 0.55,
				0.5 + math.sin(index * 2) * 0.3,
				math.sin(index * 1.1) * 0.55,
				0.14,
				rgb(46, 40, 40),
				Enum.Material.Slate
			)
		end
	end
end

B.bin = function(t)
	local metal = rgb(120, 140, 130)
	t.Cyl(0, 0.07, 0, "y", 0.14, 0.9, GRAY, METAL)
	t.Cyl(0, 0.7, 0, "y", 1.2, 1.1, metal, METAL)
	for _, y in { 0.35, 0.7, 1.05 } do
		t.Cyl(0, y, 0, "y", 0.06, 1.16, rgb(96, 112, 104), METAL)
	end
	t.Cyl(0, 1.36, 0, "y", 0.12, 1.22, rgb(96, 112, 104), METAL)
	t.Cyl(0, 1.48, 0, "y", 0.12, 0.9, metal, METAL)
	t.Cyl(0, 1.58, 0, "y", 0.08, 0.3, GRAY, METAL)
	for _, side in { -1, 1 } do
		t.Cyl(side * 0.58, 1.0, 0, "z", 0.2, 0.1, GRAY, METAL)
	end
	if t.Full then
		for index = 1, 6 do
			local angle = index * math.pi / 3
			t.Disc(
				Vector3.new(math.cos(angle) * 0.56, 0.7, math.sin(angle) * 0.56),
				Vector3.new(0, 0.7, 0),
				0.16,
				0.03,
				rgb(60, 70, 66)
			)
		end
	end
end

B.computer = function(t)
	local beige = rgb(214, 204, 178)
	t.Block(0, 0.14, 0.05, 1.5, 0.28, 1.1, beige)
	t.Block(0, 0.82, 0.05, 1.4, 1.05, 1.1, beige)
	t.Block(0, 0.85, -0.42, 1.15, 0.86, 0.2, rgb(40, 44, 40))
	t.Block(0, 0.85, -0.54, 1.0, 0.72, 0.04, rgb(30, 70, 40), GLASSY)
	t.Block(0, 0.85, 0.5, 1.0, 0.8, 0.5, rgb(190, 180, 156), nil, nil)
	t.Block(0, 0.05, -0.95, 1.5, 0.1, 0.45, beige)
	t.Block(0, 0.12, -0.95, 1.4, 0.06, 0.32, rgb(60, 62, 66))
	if t.Full then
		for row = 0, 2 do
			t.Block(0, 0.14, -1.05 + row * 0.07, 1.3, 0.03, 0.02, rgb(230, 230, 224))
		end
		for line = 0, 3 do
			t.Block(-0.2, 1.1 - line * 0.15, -0.56, 0.5 - line * 0.07, 0.04, 0.02, rgb(120, 255, 140), NEON)
		end
		t.Block(0.45, 0.18, -0.58, 0.4, 0.04, 0.04, rgb(30, 30, 34))
		t.Ball(0.62, 0.22, -0.58, 0.07, rgb(100, 255, 100), NEON)
	end
end

B.tv = function(t)
	local wood = rgb(142, 96, 62)
	t.Block(0, 1.05, 0, 2.6, 1.95, 1.7, wood, Enum.Material.WoodPlanks)
	t.Block(0, 1.15, -0.85, 1.9, 1.45, 0.1, rgb(24, 26, 28))
	t.Block(0, 1.15, -0.92, 1.72, 1.28, 0.05, rgb(60, 96, 100), GLASSY)
	t.Block(0.98, 1.2, -0.88, 0.5, 1.4, 0.06, rgb(40, 34, 30))
	for index = 0, 2 do
		t.Cyl(0.98, 1.65 - index * 0.38, -0.93, "z", 0.06, 0.28, GOLD_DARK, METAL)
	end
	for index = 0, 5 do
		t.Block(0.98, 0.62 + index * 0.06, -0.92, 0.36, 0.025, 0.02, rgb(20, 18, 16))
	end
	for _, x in { -1.0, 1.0 } do
		t.Block(x, 0.06, -0.55, 0.3, 0.12, 0.3, rgb(60, 44, 32))
		t.Block(x, 0.06, 0.55, 0.3, 0.12, 0.3, rgb(60, 44, 32))
	end
	t.Cyl(-0.45, 2.45, 0, "y", 1.1, 0.04, CHROME, METAL, Vector3.new(0, 0, 25))
	t.Cyl(0.45, 2.45, 0, "y", 1.1, 0.04, CHROME, METAL, Vector3.new(0, 0, -25))
	t.Ball(0, 2.0, 0, 0.3, rgb(30, 30, 34))
	if t.Full then
		t.Block(-0.55, 1.5, -0.97, 0.7, 0.04, 0.02, rgb(220, 255, 255), NEON, Vector3.new(0, 0, 18)).Transparency = 0.5
	end
end

B.fan = function(t)
	t.Cyl(0, 0.07, 0, "y", 0.14, 1.2, rgb(70, 130, 150))
	t.Cyl(0, 0.9, 0, "y", 1.5, 0.14, CHROME, METAL)
	t.Cyl(0, 1.7, 0.1, "z", 0.5, 0.5, rgb(70, 130, 150))
	t.Cyl(0, 1.7, -0.2, "z", 0.1, 0.16, CHROME, METAL)
	for index = 0, 2 do
		local angle = index * 120
		t.Block(0, 1.7, -0.26, 0.3, 0.62, 0.05, rgb(190, 225, 235), GLASSY, Vector3.new(0, 0, angle + 20)).Transparency =
			0.35
	end
	t.Ball(0, 1.7, -0.3, 0.2, CHROME, METAL)
	for _, d in { 1.35, 0.95, 0.55 } do
		local ring = t.Cyl(0, 1.7, -0.38, "z", 0.03, d, rgb(60, 66, 76), METAL)
		ring.Transparency = 0.45
	end
	if t.Full then
		for index = 0, 7 do
			t.Block(0, 1.7, -0.38, 0.03, 1.4, 0.03, rgb(60, 66, 76), METAL, Vector3.new(0, 0, index * 22.5))
		end
		t.Cyl(0.18, 0.15, -0.3, "y", 0.06, 0.16, rgb(240, 90, 80))
	end
end

B.trophy = function(t)
	t.Block(0, 0.1, 0, 1.2, 0.2, 1.2, rgb(60, 44, 34), Enum.Material.Wood)
	t.Block(0, 0.3, 0, 0.9, 0.2, 0.9, rgb(80, 58, 44), Enum.Material.Wood)
	t.Block(0, 0.34, -0.46, 0.6, 0.16, 0.03, GOLD, METAL)
	t.Cyl(0, 0.55, 0, "y", 0.12, 0.7, GOLD, METAL)
	t.Cyl(0, 0.85, 0, "y", 0.5, 0.2, GOLD, METAL)
	t.Ball(0, 0.85, 0, 0.36, GOLD_DARK, METAL)
	t.Cyl(0, 1.15, 0, "y", 0.14, 0.7, GOLD, METAL)
	t.Cyl(0, 1.3, 0, "y", 0.2, 0.95, GOLD, METAL)
	t.Cyl(0, 1.5, 0, "y", 0.2, 1.2, GOLD, METAL)
	t.Cyl(0, 1.7, 0, "y", 0.2, 1.32, GOLD, METAL)
	t.Cyl(0, 1.82, 0, "y", 0.05, 1.2, GOLD_DARK, METAL)
	for _, side in { -1, 1 } do
		for _, spot in { { 0.78, 1.68 }, { 0.92, 1.5 }, { 0.78, 1.32 } } do
			t.Ball(side * spot[1], spot[2], 0, 0.18, GOLD, METAL)
		end
	end
	if t.Full then
		t.Block(0, 2.1, 0, 0.3, 0.3, 0.3, GOLD_DARK, METAL, Vector3.new(0, 45, 0))
		t.Block(0, 1.5, -0.62, 0.5, 0.3, 0.02, rgb(240, 220, 150), METAL)
	end
end

B.rockart = function(t)
	t.Block(0, 0.04, 0.1, 1.5, 0.08, 0.5, rgb(60, 44, 34), Enum.Material.Wood)
	t.Block(0, 0.9, 0.04, 1.6, 1.45, 0.06, rgb(210, 196, 160))
	t.Block(0, 1.2, 0.0, 1.46, 0.6, 0.04, rgb(130, 170, 210))
	t.Block(0, 0.55, 0.0, 1.46, 0.6, 0.04, rgb(150, 190, 130))
	t.Ball(0, 0.85, -0.12, 0.85, rgb(120, 124, 130), Enum.Material.Slate)
	t.Ball(-0.18, 0.95, -0.46, 0.14, WHITE)
	t.Ball(0.18, 0.95, -0.46, 0.14, WHITE)
	t.Ball(-0.18, 0.95, -0.52, 0.06, BLACK)
	t.Ball(0.18, 0.95, -0.52, 0.06, BLACK)
	t.Block(0.18, 1.08, -0.48, 0.22, 0.05, 0.04, rgb(60, 50, 44), nil, Vector3.new(0, 0, 18))
	t.Block(-0.18, 1.06, -0.48, 0.22, 0.05, 0.04, rgb(60, 50, 44), nil, Vector3.new(0, 0, -6))
	for _, bar in { { 0, 1.66, 1.7, 0.16 }, { 0, 0.14, 1.7, 0.16 } } do
		t.Block(bar[1], bar[2], 0, bar[3], bar[4], 0.14, rgb(70, 50, 36), Enum.Material.Wood)
	end
	for _, side in { -0.77, 0.77 } do
		t.Block(side, 0.9, 0, 0.16, 1.6, 0.14, rgb(70, 50, 36), Enum.Material.Wood)
	end
end

B.radio = function(t)
	local wood = rgb(138, 92, 58)
	t.Block(0, 0.55, 0, 1.9, 1.1, 0.8, wood, Enum.Material.WoodPlanks)
	t.Block(-0.4, 0.55, -0.41, 0.95, 0.8, 0.04, rgb(54, 40, 32))
	for index = 0, 6 do
		t.Block(-0.4, 0.2 + index * 0.1, -0.44, 0.85, 0.03, 0.02, rgb(150, 120, 80))
	end
	t.Block(0.55, 0.78, -0.41, 0.6, 0.3, 0.04, rgb(240, 226, 180))
	t.Block(0.55, 0.78, -0.44, 0.04, 0.24, 0.02, RED)
	for _, x in { 0.35, 0.75 } do
		t.Cyl(x, 0.34, -0.44, "z", 0.1, 0.26, GOLD_DARK, METAL)
	end
	t.Cyl(0.6, 1.1, 0.2, "y", 0.04, 0.1, CHROME, METAL)
	t.Cyl(0.7, 1.55, 0.2, "y", 1.0, 0.04, CHROME, METAL, Vector3.new(0, 0, -18))
	t.Block(0, 1.14, 0, 0.9, 0.06, 0.12, rgb(100, 64, 40), Enum.Material.Wood)
end

B.camera = function(t)
	t.Block(0, 0.55, 0.05, 1.8, 1.0, 0.8, rgb(36, 38, 42))
	t.Block(-0.62, 0.52, -0.25, 0.46, 0.94, 0.34, rgb(30, 32, 36))
	t.Block(0, 1.18, 0.1, 0.55, 0.3, 0.4, rgb(36, 38, 42))
	t.Block(0.55, 1.12, 0.05, 0.45, 0.16, 0.3, rgb(50, 52, 58))
	t.Cyl(0.15, 0.62, -0.5, "z", 0.5, 0.95, rgb(26, 28, 32))
	t.Cyl(0.15, 0.62, -0.78, "z", 0.2, 0.82, rgb(52, 54, 60), METAL)
	t.Cyl(0.15, 0.62, -0.9, "z", 0.08, 0.64, rgb(40, 60, 90), GLASSY)
	t.Cyl(0.15, 0.62, -0.94, "z", 0.02, 0.3, rgb(120, 170, 255), NEON).Transparency = 0.4
	t.Cyl(0.15, 0.62, -0.64, "z", 0.06, 0.9, RED)
	if t.Full then
		t.Cyl(0.7, 0.9, -0.28, "z", 0.06, 0.2, rgb(200, 204, 210), METAL)
		t.Block(0, 0.32, -0.35, 1.3, 0.04, 0.02, rgb(70, 72, 78))
		t.Block(-0.9, 0.7, 0.1, 0.05, 0.9, 0.18, rgb(70, 50, 36), Enum.Material.Fabric)
		t.Block(0.9, 0.7, 0.1, 0.05, 0.9, 0.18, rgb(70, 50, 36), Enum.Material.Fabric)
	end
end

-- ============ Сейф ============

B.gold = function(t)
	local bar = t.Block(0, 0.3, 0, 1.9, 0.6, 0.85, GOLD, METAL)
	bar.Reflectance = 0.35
	t.Block(0, 0.7, 0, 1.5, 0.14, 0.5, GOLD, METAL).Reflectance = 0.35
	for _, side in { -1, 1 } do
		t.Block(side * 0.96, 0.32, 0, 0.14, 0.56, 0.7, GOLD_DARK, METAL, Vector3.new(0, 0, side * 14))
		t.Block(0, 0.3, side * 0.44, 1.8, 0.5, 0.06, GOLD_DARK, METAL, Vector3.new(side * -14, 0, 0))
	end
	local stamp = t.Block(0, 0.77, 0, 1.0, 0.02, 0.34, GOLD_DARK, METAL)
	t.Text(stamp, Enum.NormalId.Top, "999.9", rgb(120, 80, 20))
	if t.Full then
		t.Block(0, 0.02, 0, 2.0, 0.04, 0.95, GOLD_DARK, METAL)
	end
end

B.dollars = function(t)
	local bill = rgb(120, 168, 110)
	for stack = 0, 4 do
		t.Block(
			0,
			0.1 + stack * 0.19,
			0,
			1.7,
			0.18,
			0.85,
			bill,
			Enum.Material.Fabric,
			Vector3.new(0, (stack % 3 - 1) * 4, 0)
		)
	end
	t.Block(0, 0.58, 0, 0.36, 0.98, 0.9, rgb(246, 238, 200))
	local top = t.Block(0, 1.07, 0, 1.64, 0.03, 0.82, rgb(132, 182, 120), Enum.Material.Fabric)
	t.Text(top, Enum.NormalId.Top, "$100", rgb(40, 80, 40))
	if t.Full then
		t.Block(0, 0.58, -0.43, 0.36, 0.98, 0.02, rgb(220, 60, 60))
		for index = 0, 3 do
			t.Block(0.6, 0.15 + index * 0.19, -0.43, 0.5, 0.04, 0.02, rgb(90, 130, 90))
		end
	end
end

B.gpu = function(t)
	local pcb = rgb(30, 90, 60)
	t.Block(0, 0.32, 0, 2.0, 0.1, 0.92, pcb)
	t.Block(0, 0.7, 0.02, 1.9, 0.62, 0.8, rgb(36, 38, 44))
	t.Block(0, 0.7, 0.0, 1.9, 0.62, 0.78, rgb(36, 38, 44), METAL)
	for _, x in { -0.5, 0.5 } do
		t.Cyl(x, 0.7, -0.4, "z", 0.06, 0.62, rgb(20, 22, 26))
		for blade = 0, 6 do
			t.Block(x, 0.7, -0.44, 0.07, 0.28, 0.02, rgb(70, 74, 82), nil, Vector3.new(0, 0, blade * 51))
		end
		t.Cyl(x, 0.7, -0.46, "z", 0.04, 0.14, rgb(150, 156, 166), METAL)
	end
	t.Block(0, 1.03, 0, 1.9, 0.04, 0.78, rgb(180, 186, 196), METAL)
	t.Block(0, 0.2, 0.05, 1.3, 0.06, 0.12, GOLD, METAL)
	t.Block(0.95, 0.52, 0.0, 0.1, 1.0, 0.9, rgb(160, 166, 176), METAL)
	t.Block(0, 0.7, -0.43, 1.4, 0.04, 0.02, rgb(120, 255, 170), NEON)
	if t.Full then
		for index = 0, 7 do
			t.Block(-0.8 + index * 0.23, 0.12, 0.02, 0.04, 0.2, 0.08, rgb(40, 44, 40))
		end
		for _, y in { 0.45, 0.6, 0.75 } do
			t.Block(0.95, y, 0.0, 0.11, 0.05, 0.5, rgb(50, 54, 60))
		end
		t.Block(-0.2, 0.9, -0.41, 0.6, 0.1, 0.02, rgb(250, 250, 250))
	end
end

B.glasses = function(t)
	for _, side in { -1, 1 } do
		t.Cyl(side * 0.42, 0.52, -0.02, "z", 0.08, 0.78, GOLD, METAL)
		t.Cyl(side * 0.42, 0.52, -0.06, "z", 0.06, 0.64, rgb(18, 20, 24), GLASSY)
		t.Block(side * 0.42, 0.78, -0.03, 0.62, 0.05, 0.08, GOLD, METAL)
		t.Block(side * 0.9, 0.5, 0.35, 0.06, 0.06, 0.78, GOLD, METAL)
		t.Ball(side * 0.9, 0.5, 0.74, 0.1, GOLD, METAL)
	end
	t.Block(0, 0.58, -0.02, 0.2, 0.08, 0.08, GOLD, METAL)
	t.Block(0, 0.06, 0.2, 0.9, 0.1, 0.6, rgb(40, 42, 48))
	if t.Full then
		for _, side in { -1, 1 } do
			t.Block(side * 0.42, 0.56, -0.1, 0.42, 0.06, 0.02, rgb(255, 255, 255), GLASSY).Transparency = 0.6
		end
		t.Block(0, 0.06, -0.22, 0.6, 0.02, 0.02, GOLD, METAL)
	end
end

B.boombox = function(t)
	local ice = rgb(120, 220, 238)
	t.Block(0, 0.7, 0, 2.2, 1.2, 0.8, rgb(54, 66, 78), METAL)
	t.Block(0, 1.35, 0, 1.4, 0.12, 0.16, CHROME, METAL)
	t.Block(0, 1.12, 0, 0.12, 0.5, 0.12, CHROME, METAL)
	for _, side in { -0.7, 0.7 } do
		t.Cyl(side, 0.62, -0.41, "z", 0.1, 0.84, rgb(30, 34, 40), METAL)
		t.Cyl(side, 0.62, -0.47, "z", 0.08, 0.6, rgb(44, 50, 58), METAL)
		t.Cyl(side, 0.62, -0.52, "z", 0.05, 0.22, ice, GLASSY)
		t.Block(side, 1.04, -0.42, 0.8, 0.05, 0.03, ice, GLASSY)
	end
	t.Block(0, 0.82, -0.41, 0.7, 0.4, 0.04, rgb(24, 28, 32))
	t.Block(0, 0.82, -0.44, 0.56, 0.26, 0.02, ice, GLASSY).Transparency = 0.35
	for index = 0, 3 do
		t.Block(-0.24 + index * 0.16, 0.4, -0.42, 0.1, 0.1, 0.05, rgb(190, 196, 206), METAL)
	end
	for _, spot in { { -0.95, 1.0 }, { 0.95, 1.0 }, { 0, 0.35 }, { -0.95, 0.3 } } do
		t.Block(spot[1], spot[2], -0.43, 0.22, 0.22, 0.04, ice, GLASSY, Vector3.new(0, 0, 45)).Transparency = 0.15
	end
end

B.button = function(t)
	local silver = rgb(200, 206, 216)
	t.Block(0, 0.1, 0.1, 1.6, 0.2, 0.5, rgb(60, 62, 68))
	t.Block(0, 0.95, 0.0, 1.9, 1.5, 0.12, silver, METAL).Reflectance = 0.3
	t.Block(0, 0.95, -0.07, 1.6, 1.2, 0.05, rgb(150, 156, 168), METAL)
	t.Block(0, 0.95, -0.11, 1.0, 0.72, 0.04, rgb(210, 40, 40))
	t.Block(0.05, 0.95, -0.15, 0.42, 0.42, 0.03, WHITE, nil, Vector3.new(0, 0, 45))
	t.Block(-0.12, 0.95, -0.15, 0.2, 0.42, 0.03, WHITE)
	if t.Full then
		for _, corner in { { -0.85, 0.3 }, { 0.85, 0.3 }, { -0.85, 1.6 }, { 0.85, 1.6 } } do
			t.Ball(corner[1], corner[2], -0.08, 0.12, rgb(120, 126, 138), METAL)
		end
	end
end

B.console = function(t)
	local white = rgb(244, 246, 250)
	t.Block(0, 0.12, 0, 1.0, 0.24, 1.1, rgb(220, 222, 228))
	t.Block(0, 1.0, 0, 0.5, 1.7, 1.0, rgb(20, 22, 28))
	t.Block(-0.33, 1.0, 0, 0.2, 1.7, 1.0, white, nil, Vector3.new(0, 0, 4))
	t.Block(0.33, 1.0, 0, 0.2, 1.7, 1.0, white, nil, Vector3.new(0, 0, -4))
	t.Block(-0.52, 1.0, 0, 0.14, 1.6, 0.9, white)
	t.Block(0.52, 1.0, 0, 0.14, 1.6, 0.9, white)
	t.Block(0, 1.85, 0, 0.9, 0.08, 0.9, white)
	t.Block(0, 0.2, 0, 0.9, 0.08, 0.92, rgb(30, 34, 44))
	t.Block(0, 1.0, -0.5, 0.06, 1.55, 0.02, rgb(60, 150, 255), NEON)
	if t.Full then
		t.Block(0, 1.55, -0.52, 0.34, 0.06, 0.03, rgb(40, 42, 48))
		t.Ball(0.18, 1.4, -0.52, 0.07, rgb(120, 255, 160), NEON)
		for index = 0, 5 do
			t.Block(0, 0.45 + index * 0.18, -0.505, 0.4, 0.02, 0.01, rgb(50, 54, 60))
		end
	end
end

B.phone = function(t)
	local body = rgb(52, 62, 132)
	t.Block(0, 0.6, 0.0, 1.0, 1.9, 0.16, rgb(20, 22, 30), nil, Vector3.new(-12, 0, 0))
	t.Block(0, 0.62, -0.09, 0.9, 1.78, 0.04, rgb(14, 20, 40), GLASSY, Vector3.new(-12, 0, 0))
	t.Block(0, 0.58, 0.09, 0.96, 1.86, 0.04, body, METAL, Vector3.new(-12, 0, 0))
	t.Block(0.1, 1.15, 0.15, 0.62, 0.62, 0.06, rgb(30, 34, 60), nil, Vector3.new(-12, 0, 0))
	for _, spot in { { -0.05, 1.3 }, { 0.25, 1.3 }, { -0.05, 1.0 }, { 0.25, 1.0 } } do
		t.Cyl(spot[1], spot[2], 0.2, "z", 0.04, 0.22, rgb(18, 20, 26), METAL, Vector3.new(-12, 0, 0))
	end
	t.Block(0.5, 0.8, 0.0, 0.05, 0.5, 0.06, rgb(180, 190, 220), METAL, Vector3.new(-12, 0, 0))
	t.Block(0, 0.05, 0.4, 0.9, 0.1, 0.9, rgb(40, 42, 48))
	if t.Full then
		t.Block(0, 0.98, -0.11, 0.7, 0.06, 0.01, rgb(120, 200, 255), NEON, Vector3.new(-12, 0, 0)).Transparency = 0.4
		t.Text(
			t.Block(-0.1, 0.5, -0.115, 0.6, 0.16, 0.01, rgb(14, 20, 40), nil, Vector3.new(-12, 0, 0)),
			Enum.NormalId.Front,
			"POCO",
			rgb(255, 210, 60)
		)
	end
end

B.davinci = function(t)
	t.Block(0, 0.06, 0.2, 2.6, 0.12, 0.8, rgb(60, 44, 34), Enum.Material.Wood)
	t.Block(0, 1.55, 0.06, 2.4, 2.9, 0.08, rgb(56, 40, 26))
	-- Фон: небо и холмы.
	t.Block(0, 2.4, 0.0, 2.2, 1.2, 0.05, rgb(150, 166, 140))
	t.Block(0, 1.7, 0.0, 2.2, 0.6, 0.05, rgb(110, 124, 96))
	t.Block(0, 1.0, 0.0, 2.2, 1.3, 0.05, rgb(76, 58, 40))
	-- Фигура.
	t.Block(0, 1.2, -0.06, 1.15, 1.2, 0.06, rgb(40, 34, 28))
	t.Ball(0, 1.95, -0.12, 0.62, rgb(212, 170, 130))
	t.Ball(0, 2.1, -0.1, 0.76, rgb(48, 30, 20))
	t.Block(-0.34, 1.7, -0.1, 0.22, 0.9, 0.06, rgb(48, 30, 20))
	t.Block(0.34, 1.7, -0.1, 0.22, 0.9, 0.06, rgb(48, 30, 20))
	t.Ball(0, 1.95, -0.2, 0.48, rgb(222, 180, 140))
	t.Ball(-0.1, 2.0, -0.42, 0.07, rgb(50, 36, 24))
	t.Ball(0.1, 2.0, -0.42, 0.07, rgb(50, 36, 24))
	t.Block(0, 1.84, -0.43, 0.14, 0.03, 0.02, rgb(140, 60, 56))
	t.Block(0, 1.35, -0.1, 0.9, 0.4, 0.06, rgb(212, 170, 130), nil, nil)
	t.Block(0, 1.0, -0.1, 1.0, 0.5, 0.06, rgb(30, 50, 40))
	-- Рама.
	for _, bar in { { 0, 2.98, 2.7, 0.22 }, { 0, 0.14, 2.7, 0.22 } } do
		t.Block(bar[1], bar[2], 0, bar[3], bar[4], 0.18, GOLD, METAL)
	end
	for _, side in { -1.24, 1.24 } do
		t.Block(side, 1.56, 0, 0.22, 3.0, 0.18, GOLD, METAL)
	end
	if t.Full then
		for _, corner in { { -1.24, 2.98 }, { 1.24, 2.98 }, { -1.24, 0.14 }, { 1.24, 0.14 } } do
			t.Ball(corner[1], corner[2], -0.1, 0.3, GOLD_DARK, METAL)
		end
	end
end

B.bomb = function(t)
	t.Ball(0, 0.72, 0, 1.45, rgb(34, 36, 44), METAL).Reflectance = 0.15
	t.Ball(-0.3, 1.0, -0.5, 0.36, rgb(110, 114, 126), GLASSY).Transparency = 0.7
	t.Cyl(0, 1.42, 0, "y", 0.22, 0.46, rgb(70, 72, 80), METAL)
	t.Cyl(0, 1.58, 0, "y", 0.12, 0.3, rgb(52, 54, 60), METAL)
	t.Cyl(0.08, 1.78, 0, "y", 0.3, 0.07, rgb(210, 190, 140), nil, Vector3.new(0, 0, -18))
	t.Cyl(0.2, 1.98, 0, "y", 0.2, 0.07, rgb(210, 190, 140), nil, Vector3.new(0, 0, -40))
	t.Ball(0.3, 2.1, 0, 0.26, rgb(255, 190, 60), NEON)
	t.Ball(0.3, 2.1, 0, 0.14, rgb(255, 250, 200), NEON)
	local spark = Instance.new("PointLight")
	spark.Color = rgb(255, 180, 70)
	spark.Range = 6
	spark.Brightness = 1
	spark.Parent = t.Ball(0.3, 2.12, 0, 0.05, rgb(255, 200, 80), NEON)
	if t.Full then
		t.Disc(Vector3.new(0, 0.72, -0.73), Vector3.new(0, 0.72, 0), 0.5, 0.03, rgb(230, 230, 230))
		t.Block(-0.1, 0.84, -0.76, 0.1, 0.08, 0.02, BLACK)
		t.Block(0.1, 0.84, -0.76, 0.1, 0.08, 0.02, BLACK)
		t.Block(0, 0.62, -0.76, 0.26, 0.05, 0.02, BLACK)
	end
end

-- ============ Грузовой и секретный контейнеры, вариации ============

local function wheel(t: Tools, x: number, y: number, z: number, d: number)
	t.Cyl(x, y, z, "x", d * 0.34, d, rgb(26, 28, 32))
	local side = if x > 0 then 1 else -1
	t.Cyl(x + side * d * 0.14, y, z, "x", d * 0.08, d * 0.62, CHROME, METAL)
	t.Cyl(x + side * d * 0.2, y, z, "x", d * 0.04, d * 0.2, GRAY, METAL)
end

B.rover = function(t)
	local body = t.Tint
	t.Block(0, 0.9, 0, 2.0, 0.7, 3.6, body, METAL)
	t.Block(0, 1.4, 0.5, 1.7, 0.6, 1.8, rgb(40, 44, 52))
	t.Block(0, 1.42, -0.42, 1.5, 0.55, 0.05, rgb(80, 150, 190), GLASSY, Vector3.new(-20, 0, 0))
	t.Block(0, 1.2, -1.82, 1.8, 0.4, 0.2, rgb(220, 224, 230))
	for _, x in { -1.05, 1.05 } do
		for _, z in { -1.2, 0, 1.2 } do
			wheel(t, x, 0.5, z, 1.0)
		end
	end
	t.Cyl(0.3, 2.2, 1.0, "y", 0.8, 0.07, CHROME, METAL)
	t.Cyl(0.3, 2.68, 1.0, "z", 0.5, 0.5, CHROME, METAL).Transparency = 0.2
	t.Block(-0.6, 1.9, 0.9, 0.5, 0.08, 0.34, rgb(40, 60, 120), GLASSY)
	for _, x in { -0.6, 0.6 } do
		t.Ball(x, 1.0, -1.82, 0.26, rgb(255, 250, 200), NEON)
	end
	if t.Full then
		t.Block(0, 1.28, 1.6, 1.2, 0.5, 0.5, rgb(60, 64, 72))
		for index = 0, 3 do
			t.Block(-0.5 + index * 0.33, 1.0, -1.83, 0.16, 0.05, 0.02, rgb(40, 44, 50))
		end
	end
end

B.coupe = function(t)
	local paint = t.Tint
	t.Block(0, 0.62, 0, 1.9, 0.5, 4.4, paint, METAL)
	t.Block(0, 0.95, 0.2, 1.7, 0.4, 2.0, paint, METAL, Vector3.new(0, 0, 0))
	t.Block(0, 1.1, -0.4, 1.5, 0.5, 0.06, rgb(30, 50, 70), GLASSY, Vector3.new(-32, 0, 0))
	t.Block(0, 1.18, 0.6, 1.5, 0.4, 1.3, rgb(30, 50, 70), GLASSY)
	t.Block(0, 1.3, 1.25, 1.7, 0.3, 0.7, paint, METAL, Vector3.new(24, 0, 0))
	t.Block(0, 0.55, -2.2, 1.9, 0.2, 0.2, rgb(30, 32, 36))
	for _, x in { -0.95, 0.95 } do
		for _, z in { -1.45, 1.45 } do
			wheel(t, x, 0.45, z, 0.9)
		end
		t.Ball(x * 0.6, 0.72, -2.2, 0.26, rgb(255, 250, 220), NEON)
		t.Block(x * 0.62, 0.7, 2.2, 0.5, 0.14, 0.04, rgb(255, 40, 40), NEON)
	end
	t.Block(0, 1.55, 1.9, 1.7, 0.08, 0.5, rgb(24, 26, 30))
	for _, x in { -0.7, 0.7 } do
		t.Block(x, 1.42, 1.9, 0.08, 0.3, 0.3, rgb(24, 26, 30))
	end
	if t.Full then
		t.Block(0, 0.78, -2.22, 0.6, 0.14, 0.02, rgb(30, 32, 36))
		for _, x in { -1.0, 1.0 } do
			t.Block(x, 0.8, 0, 0.05, 0.1, 1.2, rgb(240, 240, 236))
		end
	end
end

B.robot = function(t)
	local plate = t.Tint
	t.Block(0, 0.3, 0, 2.2, 0.6, 1.8, rgb(54, 58, 66), METAL)
	for _, x in { -0.9, 0.9 } do
		t.Cyl(x, 0.3, 0, "x", 0.5, 0.62, rgb(30, 32, 36))
		t.Cyl(x, 0.3, 0, "x", 0.3, 0.38, GRAY, METAL)
	end
	t.Block(0, 1.55, 0, 1.6, 1.6, 1.2, plate, METAL)
	t.Block(0, 1.6, -0.62, 1.0, 0.7, 0.04, rgb(24, 40, 60), GLASSY)
	t.Block(0, 1.6, -0.66, 0.7, 0.3, 0.02, rgb(100, 220, 255), NEON)
	t.Block(0, 1.0, -0.62, 1.2, 0.2, 0.04, rgb(40, 44, 50))
	t.Ball(0, 2.62, 0, 0.9, rgb(210, 214, 222), METAL)
	t.Block(0, 2.6, -0.4, 0.62, 0.22, 0.12, rgb(80, 240, 255), NEON)
	t.Cyl(0, 3.2, 0, "y", 0.4, 0.06, CHROME, METAL)
	t.Ball(0, 3.46, 0, 0.18, RED, NEON)
	for _, side in { -1, 1 } do
		t.Cyl(side * 1.0, 1.95, 0, "x", 0.3, 0.4, GRAY, METAL)
		t.Block(side * 1.28, 1.35, 0, 0.3, 1.2, 0.34, plate, METAL)
		t.Block(side * 1.28, 0.65, -0.1, 0.5, 0.26, 0.5, rgb(54, 58, 66), METAL)
		t.Block(side * 1.4, 0.6, -0.45, 0.1, 0.2, 0.4, CHROME, METAL)
	end
end

B.crateGem = function(t)
	local quartz = t.Tint
	t.Block(0, 0.1, 0, 1.5, 0.2, 1.3, rgb(60, 56, 70), Enum.Material.Slate)
	for _, shard in
		{
			{ 0, 0.8, 0, 0.5, 1.4, 0.5, 0, 0 },
			{ 0.4, 0.55, 0.1, 0.36, 0.9, 0.36, 18, 20 },
			{ -0.4, 0.5, -0.05, 0.34, 0.8, 0.34, -16, 30 },
			{ 0.12, 0.4, -0.38, 0.3, 0.6, 0.3, 40, 0 },
			{ -0.2, 0.42, 0.35, 0.3, 0.64, 0.3, -30, 10 },
		}
	do
		local piece = t.Block(
			shard[1],
			shard[2],
			shard[3],
			shard[4],
			shard[5],
			shard[6],
			quartz,
			GLASSY,
			Vector3.new(shard[7], shard[8], 0)
		)
		piece.Transparency = 0.15
		t.Block(
			shard[1],
			shard[2] + shard[5] / 2,
			shard[3],
			shard[4] * 0.7,
			0.24,
			shard[6] * 0.7,
			rgb(255, 255, 255),
			GLASSY,
			Vector3.new(shard[7], shard[8] + 45, 0)
		).Transparency =
			0.5
	end
end

B.diamond = function(t)
	local ice = t.Tint
	local function gem(y: number, size: number, rot: number)
		t.Block(0, y, 0, size, size, size, ice, GLASSY, Vector3.new(0, rot, 0)).Transparency = 0.1
	end
	t.Block(0, 0.1, 0, 1.3, 0.2, 1.3, rgb(50, 56, 70), METAL)
	t.Block(0, 0.7, 0, 0.9, 0.9, 0.9, ice, GLASSY, Vector3.new(45, 0, 45)).Transparency = 0.1
	t.Block(0, 0.7, 0, 0.9, 0.9, 0.9, ice, GLASSY, Vector3.new(45, 45, 0)).Transparency = 0.1
	t.Block(0, 1.0, 0, 0.9, 0.5, 0.9, rgb(235, 250, 255), GLASSY, Vector3.new(0, 45, 0)).Transparency = 0.2
	gem(0.7, 0.55, 20)
	if t.Full then
		for index = 0, 3 do
			local a = index * math.pi / 2
			t.Ball(math.cos(a) * 0.7, 0.55, math.sin(a) * 0.7, 0.12, rgb(255, 255, 255), NEON)
		end
	end
end

B.core = function(t)
	local glow = t.Tint
	t.Cyl(0, 0.1, 0, "y", 0.2, 1.6, rgb(40, 44, 56), METAL)
	t.Cyl(0, 0.3, 0, "y", 0.2, 1.2, rgb(60, 64, 80), METAL)
	t.Ball(0, 1.7, 0, 1.5, glow, NEON).Transparency = 0.1
	t.Ball(0, 1.7, 0, 0.8, rgb(255, 255, 255), NEON)
	for index, tilt in { Vector3.new(0, 0, 0), Vector3.new(60, 0, 0), Vector3.new(0, 0, 60) } do
		t.Cyl(0, 1.7, 0, "y", 0.07, 2.4 + index * 0.1, rgb(220, 200, 255), NEON, tilt).Transparency = 0.3
	end
	for _, side in { -1, 1 } do
		t.Block(side * 0.7, 0.8, 0, 0.12, 1.0, 0.12, rgb(60, 64, 80), METAL, Vector3.new(0, 0, side * -18))
	end
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = t.Ball(0, 1.7, 0, 0.1, glow, NEON)
end

B.concept = function(t)
	local paint = t.Tint
	t.Block(0, 0.55, 0, 2.0, 0.34, 4.8, paint, METAL, nil)
	t.Block(0, 0.9, 0.3, 1.5, 0.44, 2.6, rgb(26, 30, 40), GLASSY, nil)
	t.Block(0, 1.0, 0.3, 1.1, 0.3, 1.8, paint, METAL)
	t.Block(0, 0.62, -2.6, 1.4, 0.2, 0.7, paint, METAL, Vector3.new(-12, 0, 0))
	t.Block(0, 1.25, 2.2, 2.0, 0.1, 0.6, rgb(24, 26, 34))
	for _, x in { -0.8, 0.8 } do
		t.Block(x, 1.05, 2.2, 0.08, 0.4, 0.4, rgb(24, 26, 34))
		t.Block(x, 0.72, -2.4, 0.4, 0.05, 1.0, rgb(255, 255, 255), NEON)
		t.Block(x * 1.02, 0.55, 0, 0.06, 0.06, 4.4, rgb(120, 250, 220), NEON)
	end
	for _, x in { -1.05, 1.05 } do
		for _, z in { -1.6, 1.6 } do
			wheel(t, x, 0.45, z, 0.9)
		end
	end
	if t.Full then
		t.Block(0, 0.72, 2.45, 1.7, 0.08, 0.04, rgb(255, 80, 120), NEON)
		t.Block(0, 0.4, 0, 1.8, 0.06, 4.0, rgb(40, 255, 200), NEON).Transparency = 0.7
	end
end

B.anomaly = function(t)
	local green = t.Tint
	t.Cyl(0, 0.08, 0, "y", 0.16, 1.4, rgb(44, 54, 56), METAL)
	for index, shard in
		{
			{ 0, 1.0, 0, 0.5, 1.2 },
			{ 0.5, 1.3, 0.1, 0.34, 0.8 },
			{ -0.5, 0.9, -0.2, 0.3, 0.7 },
			{ 0.1, 1.7, 0.4, 0.26, 0.6 },
			{ -0.3, 1.5, 0.3, 0.22, 0.5 },
		}
	do
		local part = t.Block(
			shard[1],
			shard[2],
			shard[3],
			shard[4],
			shard[5],
			shard[4],
			green,
			NEON,
			Vector3.new(index * 14, index * 33, index * 21)
		)
		part.Transparency = 0.2
	end
	t.Ball(0, 1.1, 0, 0.5, rgb(240, 255, 240), NEON)
	local light = Instance.new("PointLight")
	light.Color = green
	light.Range = 10
	light.Brightness = 1
	light.Parent = t.Ball(0, 1.1, 0, 0.1, green, NEON)
end

B.prism = function(t)
	local color = t.Tint
	t.Block(0, 0.08, 0, 1.4, 0.16, 1.0, rgb(50, 54, 66), METAL)
	t.Block(0, 0.7, 0, 0.8, 1.1, 0.8, color, GLASSY, Vector3.new(0, 30, 0)).Transparency = 0.2
	t.Block(0, 1.3, 0, 0.5, 0.3, 0.5, rgb(255, 255, 255), GLASSY, Vector3.new(0, 30, 0)).Transparency = 0.4
	t.Block(0.3, 0.7, -0.5, 1.0, 0.05, 0.02, rgb(255, 120, 120), NEON, Vector3.new(0, 0, -12))
	t.Block(0.3, 0.6, -0.5, 1.0, 0.05, 0.02, rgb(120, 255, 160), NEON, Vector3.new(0, 0, -6))
	t.Block(0.3, 0.5, -0.5, 1.0, 0.05, 0.02, rgb(120, 160, 255), NEON, Vector3.new(0, 0, 0))
end

-- Строит модель предмета внутри parent (обычно Model). Неизвестный тип рисуется нейтральным кубом.
function ItemModels.build(kind: string, parent: Instance, options: Options?): ()
	local definition = Catalog.Items[kind]
	local full = if options and options.Full ~= nil then options.Full else true
	local tools = makeTools(parent, full, if definition then definition.Color else GRAY)
	local builder = B[kind]
	if builder then
		builder(tools)
	else
		tools.Block(0, 0.7, 0, 1.4, 1.4, 1.4, tools.Tint)
	end
end

return ItemModels
