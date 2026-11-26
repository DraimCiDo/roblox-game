--!strict
-- Items from wooden crates.
local Tools = require(script.Parent.Tools)
local rgb = Tools.rgb
local WHITE = Tools.WHITE
local BLACK = Tools.BLACK
local GRAY = Tools.GRAY
local CHROME = Tools.CHROME
local GOLD = Tools.GOLD
local GOLD_DARK = Tools.GOLD_DARK
local RED = Tools.RED
local METAL = Tools.METAL
local NEON = Tools.NEON
local GLASSY = Tools.GLASSY

local B: { [string]: (any) -> () } = {}

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

return B
