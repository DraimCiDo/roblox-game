--!strict
-- Items from safes.
local Tools = require(script.Parent.Tools)
local rgb = Tools.rgb
local WHITE = Tools.WHITE
local BLACK = Tools.BLACK
local CHROME = Tools.CHROME
local GOLD = Tools.GOLD
local GOLD_DARK = Tools.GOLD_DARK
local METAL = Tools.METAL
local NEON = Tools.NEON
local GLASSY = Tools.GLASSY

local B: { [string]: (any) -> () } = {}

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

return B
