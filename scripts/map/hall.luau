--!nocheck
-- Оформление центрального зала «Лаборатории CORPA». Запускается в Roblox Studio (режим Edit),
-- например через MCP execute_luau. Скрипт идемпотентен: удаляет прежнюю папку «Оформление зала»
-- и строит её заново, перекрашивает пол и стены зала. Игровые объекты (терминалы рейтинга, указатели,
-- точки секторов) не трогает. После запуска сцену экспортируют: File → Save to File As (.rbxlx) →
-- python scripts/export-studio-scene.py <файл>.

local LAB = workspace:FindFirstChild("CORPA — испытательная лаборатория")
assert(LAB, "Нет модели лаборатории")

local FOLDER = "Оформление зала"
local old = LAB:FindFirstChild(FOLDER)
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = FOLDER

local DISPLAY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)

local GRAPHITE = Color3.fromRGB(98, 106, 178)
local STEEL = Color3.fromRGB(236, 238, 252)
local DARK = Color3.fromRGB(52, 50, 110)
local CYAN = Color3.fromRGB(70, 196, 255)
local AMBER = Color3.fromRGB(255, 190, 52)
local TEXT = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(205, 213, 255)

local FLOOR_Y = -0.05
local CEILING_Y = 19

local function part(parent, name, size, frame, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = frame
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Декор без столкновений и теней (полосы, кольца, свет): не мешает ходить и не грузит тени.
local function trim(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function group(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = root
	return m
end

-- Кольцо из прямых сегментов в горизонтальной плоскости.
local function ring(parent, name, center, radius, width, height, segments, color, material)
	local step = 2 * math.pi / segments
	local length = 2 * radius * math.tan(step / 2) + 0.05
	for i = 0, segments - 1 do
		local a = i * step
		local at = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local frame = CFrame.lookAt(at, center) -- Z указывает к центру
		trim(part(parent, name, Vector3.new(length, height, width), frame, color, material))
	end
end

-- pixelsPerStud: TextScaled не растит текст больше 100 px, поэтому крупным надписям нужна малая плотность.
local function surfaceText(host, face, lines, pixelsPerStud)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.MaxDistance = 220
	gui.Parent = host
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	for index, line in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, line.Height, 0)
		label.Text = line.Text
		label.TextColor3 = line.Color
		label.FontFace = line.Font
		label.TextScaled = true
		label.LayoutOrder = index
		label.Parent = gui
	end
	return gui
end

-- 0. Свет сцены: неон слегка светится (Bloom), лёгкая цветокоррекция, экспозиция под тёмные материалы.
local Lighting = game:GetService("Lighting")
Lighting.ExposureCompensation = -0.35
Lighting.Ambient = Color3.fromRGB(134, 138, 170)
Lighting.OutdoorAmbient = Color3.fromRGB(126, 130, 164)
Lighting.Brightness = 1.1
local bloom = Lighting:FindFirstChild("Свечение неона") or Instance.new("BloomEffect")
bloom.Name = "Свечение неона"
bloom.Intensity = 0.3
bloom.Size = 22
bloom.Threshold = 0.92
bloom.Parent = Lighting
local grade = Lighting:FindFirstChild("Цветокоррекция") or Instance.new("ColorCorrectionEffect")
grade.Name = "Цветокоррекция"
grade.Brightness = 0.03
grade.Contrast = 0.1
grade.Saturation = 0.18
grade.TintColor = Color3.fromRGB(255, 250, 242)
grade.Parent = Lighting

-- Старая инженерка коридора под потолком зала проходила сквозь ядро и кольцо света — убираем её.
local REMOVED = {
	["Труба над коридором"] = true,
	["Сигнальная труба"] = true,
	["Хомут кабельной трубы"] = true,
	["Подвес к перекрытию"] = true,
	["Рабочий свет"] = true,
	["Корпус светильника в коридоре"] = true,
}
for _, piece in LAB:GetChildren() do
	if REMOVED[piece.Name] then
		piece:Destroy()
	end
end

-- 1. Пол и стены зала: тёмный графит вместо светлого бетона и известняка.
for _, piece in LAB:GetChildren() do
	if piece:IsA("BasePart") then
		if
			piece.Name == "Пол центрального зала"
			or piece.Name == "Боковой пол центрального зала"
			or piece.Name == "Скошенный пол центрального зала"
			or piece.Name == "Главный коридор"
		then
			piece.Material = Enum.Material.SmoothPlastic
			piece.Color = Color3.fromRGB(164, 176, 222)
			piece.Reflectance = 0
		elseif piece.Name == "Стена октагона" then
			piece.Material = Enum.Material.SmoothPlastic
			piece.Color = Color3.fromRGB(120, 140, 214)
		elseif piece.Name == "Перекрытие" or piece.Name:find("^Перекрытие ·") then
			piece.Material = Enum.Material.SmoothPlastic
			piece.Color = Color3.fromRGB(86, 96, 160)
		elseif piece.Name == "Разметка коридора" or piece.Name == "Cargo guide stripe" then
			piece.Transparency = 1
		end
	end
end

-- 2. Пол: плитка-сетка, кольцо вокруг ядра и световые дорожки к секторам и воротам.
local floor = group("Пол · разметка")
local center = Vector3.new(0, FLOOR_Y, 0)
for _, offset in { -60, -40, -20, 20, 40, 60 } do
	trim(part(floor, "Шов плитки", Vector3.new(0.12, 0.04, 160), CFrame.new(offset, FLOOR_Y + 0.02, 0), DARK))
	trim(part(floor, "Шов плитки", Vector3.new(160, 0.04, 0.12), CFrame.new(0, FLOOR_Y + 0.02, offset), DARK))
end
ring(floor, "Кольцо ядра", center + Vector3.new(0, 0.03, 0), 15, 0.35, 0.06, 64, CYAN, Enum.Material.SmoothPlastic)
ring(floor, "Внешнее кольцо", center + Vector3.new(0, 0.03, 0), 34, 0.18, 0.06, 96, STEEL, Enum.Material.SmoothPlastic)

local portals = {
	{ Key = "01", At = Vector3.new(-57, 0, 57) },
	{ Key = "02", At = Vector3.new(0, 0, 80) },
	{ Key = "03", At = Vector3.new(57, 0, 57) },
	{ Key = "04", At = Vector3.new(-57, 0, -57) },
	{ Key = "05", At = Vector3.new(0, 0, -80) },
	{ Key = "06", At = Vector3.new(57, 0, -57) },
}
for _, portal in portals do
	local dir = (portal.At * Vector3.new(1, 0, 1)).Unit
	local from, to = 16, portal.At.Magnitude - 3
	local mid = dir * (from + to) / 2
	local frame = CFrame.lookAt(Vector3.new(mid.X, FLOOR_Y + 0.03, mid.Z), Vector3.new(dir.X * to, FLOOR_Y + 0.03, dir.Z * to))
	trim(part(floor, "Дорожка к сектору " .. portal.Key, Vector3.new(0.35, 0.06, to - from), frame, CYAN, Enum.Material.SmoothPlastic))
	-- Шевроны вдоль дорожки: направление к сектору.
	for distance = 24, to - 6, 9 do
		local at = dir * distance
		local base = CFrame.lookAt(Vector3.new(at.X, FLOOR_Y + 0.03, at.Z), Vector3.new(at.X + dir.X, FLOOR_Y + 0.03, at.Z + dir.Z))
		for side = -1, 1, 2 do
			trim(
				part(
					floor,
					"Шеврон",
					Vector3.new(0.25, 0.05, 1.8),
					base * CFrame.new(side * 0.65, 0, 0.35) * CFrame.Angles(0, math.rad(side * 40), 0),
					CYAN:Lerp(DARK, 0.45),
					Enum.Material.SmoothPlastic
				)
			)
		end
	end
end
-- Дорожка к закрытым воротам (запад) — янтарная, «служебная».
trim(
	part(floor, "Дорожка к воротам", Vector3.new(60, 0.06, 0.35), CFrame.new(-46, FLOOR_Y + 0.03, 0), AMBER:Lerp(DARK, 0.3), Enum.Material.SmoothPlastic)
)

-- 3. Ядро CORPA в центре: подиум, светящаяся колонна, кольца-обручи и кольцо света под потолком.
local core = group("Ядро CORPA")
local vertical = CFrame.Angles(0, 0, math.rad(90))
part(core, "Подиум ядра", Vector3.new(0.9, 20, 20), CFrame.new(0, FLOOR_Y + 0.45, 0) * vertical, GRAPHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
part(core, "Ступень подиума", Vector3.new(0.5, 24, 24), CFrame.new(0, FLOOR_Y + 0.25, 0) * vertical, DARK, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
ring(core, "Кромка подиума", Vector3.new(0, FLOOR_Y + 0.92, 0), 10, 0.25, 0.08, 48, CYAN, Enum.Material.SmoothPlastic)
part(core, "Цоколь колонны", Vector3.new(2.2, 7, 7), CFrame.new(0, FLOOR_Y + 2, 0) * vertical, STEEL, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
local column = trim(
	part(core, "Колонна энергии", Vector3.new(CEILING_Y - 3, 3.2, 3.2), CFrame.new(0, FLOOR_Y + 3 + (CEILING_Y - 3) / 2, 0) * vertical, CYAN, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
)
column.Transparency = 0.25
local glow = Instance.new("PointLight")
glow.Color = CYAN
glow.Range = 26
glow.Brightness = 2.2
glow.Parent = column
part(core, "Оголовок колонны", Vector3.new(1.2, 6, 6), CFrame.new(0, CEILING_Y - 0.6, 0) * vertical, STEEL, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
for index, height in { 5.5, 10, 14.5 } do
	local radius = 3.4 + index * 0.6
	ring(core, "Обруч ядра", Vector3.new(0, height, 0), radius, 0.3, 0.3, 32, if index == 2 then AMBER else STEEL, if index == 2 then Enum.Material.SmoothPlastic else Enum.Material.SmoothPlastic)
end
ring(core, "Кольцо света", Vector3.new(0, CEILING_Y - 0.25, 0), 13, 0.9, 0.2, 64, CYAN, Enum.Material.SmoothPlastic)
ring(core, "Корпус кольца света", Vector3.new(0, CEILING_Y - 0.1, 0), 13, 1.6, 0.25, 64, DARK, Enum.Material.SmoothPlastic)

-- 4. Колонны в углах восьмиугольника с вертикальной подсветкой.
local columns = group("Колонны зала")
for k = 0, 7 do
	local a = math.rad(22.5 + 45 * k)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local at = dir * 83.5
	local foot = CFrame.lookAt(Vector3.new(at.X, FLOOR_Y, at.Z), Vector3.new(0, FLOOR_Y, 0))
	Kit.place(columns, "column", foot, CEILING_Y)
	local solid = part(columns, "Колонна", Vector3.new(4, CEILING_Y, 4), foot * CFrame.new(0, CEILING_Y / 2, 0), STEEL)
	solid.Transparency = 1
end

-- 5. Таблички «СЕКТОР 0N» над порталами (на стене над проёмом, лицом в зал).
local signs = group("Таблички секторов")
for _, portal in portals do
	local dir = (portal.At * Vector3.new(1, 0, 1)).Unit
	local at = dir * (portal.At.Magnitude + 0.45)
	local frame = CFrame.lookAt(Vector3.new(at.X, 15.3, at.Z), Vector3.new(0, 15.3, 0))
	local plate = part(signs, "Табличка сектора " .. portal.Key, Vector3.new(16, 5, 0.2), frame, DARK, Enum.Material.SmoothPlastic)
	trim(part(signs, "Рамка таблички", Vector3.new(16.6, 0.18, 0.12), frame * CFrame.new(0, 2.55, -0.12), CYAN, Enum.Material.SmoothPlastic))
	trim(part(signs, "Рамка таблички", Vector3.new(16.6, 0.18, 0.12), frame * CFrame.new(0, -2.55, -0.12), CYAN, Enum.Material.SmoothPlastic))
	surfaceText(plate, Enum.NormalId.Front, {
		{ Text = "СЕКТОР", Color = MUTED, Font = BOLD, Height = 0.32 },
		{ Text = portal.Key, Color = CYAN, Font = DISPLAY, Height = 0.6 },
	}, 30)
end

-- 6. Логотип на восточной стене и служебная надпись над западными воротами.
local brand = group("Логотип")
local eastFrame = CFrame.lookAt(Vector3.new(80.9, 10.5, 0), Vector3.new(0, 10.5, 0))
local logo = part(brand, "Панель логотипа", Vector3.new(44, 11, 0.25), eastFrame, DARK, Enum.Material.SmoothPlastic)
for _, y in { 5.65, -5.65 } do
	trim(part(brand, "Рамка логотипа", Vector3.new(45, 0.22, 0.12), eastFrame * CFrame.new(0, y, -0.15), CYAN, Enum.Material.SmoothPlastic))
end
for _, x in { -22.4, 22.4 } do
	trim(part(brand, "Рамка логотипа", Vector3.new(0.22, 11.5, 0.12), eastFrame * CFrame.new(x, 0, -0.15), CYAN, Enum.Material.SmoothPlastic))
end
surfaceText(logo, Enum.NormalId.Front, {
	{ Text = "CORPA", Color = TEXT, Font = DISPLAY, Height = 0.6 },
	{ Text = "ИСПЫТАТЕЛЬНАЯ ЛАБОРАТОРИЯ · ГОРИЗОНТ −1", Color = CYAN, Font = BOLD, Height = 0.22 },
}, 14)
local westFrame = CFrame.lookAt(Vector3.new(-80.9, 15.5, 0), Vector3.new(0, 15.5, 0))
local service = part(brand, "Табличка служебного крыла", Vector3.new(26, 3.2, 0.2), westFrame, DARK, Enum.Material.SmoothPlastic)
trim(part(brand, "Рамка служебного крыла", Vector3.new(26.6, 0.16, 0.12), westFrame * CFrame.new(0, -1.7, -0.12), AMBER, Enum.Material.SmoothPlastic))
surfaceText(service, Enum.NormalId.Front, {
	{ Text = "КРЫЛО Б · ДОСТУП ОГРАНИЧЕН", Color = AMBER, Font = DISPLAY, Height = 0.8 },
}, 36)

root.Parent = LAB
local count = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
return `Оформление зала: {count} деталей`
