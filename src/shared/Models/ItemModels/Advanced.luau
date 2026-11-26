--!strict
-- Items from cargo and secret containers and variants.
local Tools = require(script.Parent.Tools)
type Tools = Tools.Tools
local rgb = Tools.rgb
local GRAY = Tools.GRAY
local CHROME = Tools.CHROME
local RED = Tools.RED
local METAL = Tools.METAL
local NEON = Tools.NEON
local GLASSY = Tools.GLASSY

local B: { [string]: (any) -> () } = {}

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

return B
