--!strict
-- Items from cardboard boxes.
local Tools = require(script.Parent.Tools)
local rgb = Tools.rgb
local WHITE = Tools.WHITE
local BLACK = Tools.BLACK
local CHROME = Tools.CHROME
local GOLD = Tools.GOLD
local GOLD_DARK = Tools.GOLD_DARK
local RED = Tools.RED
local BROWN = Tools.BROWN
local PLASTIC = Tools.PLASTIC
local METAL = Tools.METAL
local NEON = Tools.NEON
local GLASSY = Tools.GLASSY
local PHI = Tools.PHI

local B: { [string]: (any) -> () } = {}

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

return B
