--!nocheck
-- Сектор игрока «Лаборатории CORPA», собранный с нуля по одному шаблону для всех шести секторов.
-- Запускается из build.luau (Lune) или в Studio. Идемпотентен: полностью пересоздаёт содержимое
-- моделей «Сектор 01…06» (сохраняя SpawnLocation) по их текущему положению.
--
-- Система координат шаблона: начало — центр шлюза на уровне пола, +Z — к задней стене (Backrooms),
-- −Z — ко входу из перехода, +X — правое крыло (витрины), −X — левое (склад). Высота 0…19.2.
-- Детали с именами из контракта сервера (World.luau / Sector.luau) лежат прямо в модели сектора:
-- лицевая сторона станций, витрин, прилавка и табличек (−Z детали) смотрит в проход; у складских
-- модулей +X — задняя стенка (в стену).

local LAB = workspace:FindFirstChild("CORPA — испытательная лаборатория")
assert(LAB, "Нет модели лаборатории")

local UP = Vector3.new(0, 1, 0)

-- Палитра «Лаборатория CORPA».
local FLOOR = Color3.fromRGB(164, 176, 222)
local WALL = Color3.fromRGB(120, 140, 214)
local GRAPHITE = Color3.fromRGB(98, 106, 178)
local STEEL = Color3.fromRGB(236, 238, 252)
local DARK = Color3.fromRGB(52, 50, 110)
local CEILING = Color3.fromRGB(86, 96, 160)
local CYAN = Color3.fromRGB(70, 196, 255)
local AMBER = Color3.fromRGB(255, 190, 52)
local VIOLET = Color3.fromRGB(186, 124, 255)
local GLASS = Color3.fromRGB(196, 228, 240)
local LAMP = Color3.fromRGB(255, 244, 214)
-- Backrooms (уровень 0).
local WALLPAPER = Color3.fromRGB(196, 190, 116)
local CARPET = Color3.fromRGB(184, 170, 128)
local TILE = Color3.fromRGB(216, 212, 182)
local LAMP_OFF = Color3.fromRGB(70, 66, 52)

local DISPLAY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)

local SHAFT = 9.2 -- полуширина шлюза (площадка 18.4)
local CEIL = 24 -- потолок сектора
local WIDEN = 5 -- how much each side wing is wider than the original 26.6 half width
local function wing(x)
	return x + math.sign(x) * WIDEN
end
local PIPE_FLOOR = 11.0 -- низ трубы подачи
local PIPE_TOP = 18.95 -- верх трубы
local PIPE_HALF = 8.1 -- полуширина трубы (грузовой контейнер 14 в ширину)
local HOOD_BACK = 10.2 -- задняя грань колпака над шлюзом
local DOOR_Z = 18.6 -- фасад камеры Backrooms
local BACK_Z = 30.6 -- внутренняя грань задней стены

local function findPart(container, name)
	for _, piece in container:GetChildren() do
		if piece:IsA("BasePart") and piece.Name == name then
			return piece
		end
	end
	return nil
end

-- Строитель одного сектора: F — мировая система шаблона.
local function buildSector(model, F, spawn)
	local function world(cf)
		return F * cf
	end
	-- Деталь в координатах шаблона. facing — направление лицевой стороны (−Z детали) в шаблоне.
	local function place(at, facing)
		if facing then
			return CFrame.lookAt(at, at + facing)
		end
		return CFrame.new(at)
	end
	local function part(parent, name, size, cf, color, material, solid)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = world(cf)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if solid == false then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
		p.Parent = parent
		return p
	end
	local function glow(parent, name, size, cf, color)
		local p = part(parent, name, size, cf, color, Enum.Material.SmoothPlastic, false)
		p.CastShadow = false
		return p
	end
	local function label(host, face, lines, pixels)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = pixels or 40
		gui.LightInfluence = 0
		gui.MaxDistance = 120
		gui.Parent = host
		local list = Instance.new("UIListLayout")
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = gui
		for index, line in lines do
			local text = Instance.new("TextLabel")
			text.BackgroundTransparency = 1
			text.Size = UDim2.new(1, 0, line[3], 0)
			text.Text = line[1]
			text.TextColor3 = line[2]
			text.FontFace = line[4] or DISPLAY
			text.TextScaled = true
			text.LayoutOrder = index
			text.Parent = gui
		end
	end
	-- Заполняющий свет вниз: при тёмных материалах одного серверного света светильников мало.
	local function downlight(host, brightness, range, angle)
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Color = Color3.fromRGB(226, 240, 255)
		light.Brightness = brightness
		light.Range = range
		light.Angle = angle
		light.Shadows = false
		light.Parent = host
		return host
	end
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = model
		return f
	end
	local V = Vector3.new

	-- ===== Оболочка: пол с проёмом шлюза, стены, потолок =====
	local shell = folder("Оболочка сектора")
	local floorParts = {
		{ V(53.2 + WIDEN * 2, 1, 31.5 - SHAFT), V(0, -0.55, -(31.5 + SHAFT) / 2) },
		{ V(53.2 + WIDEN * 2, 1, 31.5 - SHAFT), V(0, -0.55, (31.5 + SHAFT) / 2) },
		{ V(26.6 + WIDEN - SHAFT, 1, SHAFT * 2), V(-(26.6 + WIDEN + SHAFT) / 2, -0.55, 0) },
		{ V(26.6 + WIDEN - SHAFT, 1, SHAFT * 2), V((26.6 + WIDEN + SHAFT) / 2, -0.55, 0) },
	}
	for _, slab in floorParts do
		part(shell, "Пол сектора", slab[1], place(slab[2]), FLOOR)
	end
	-- Checker floor around the shaft.
	local tileX, tileZ = (53.2 + WIDEN * 2) / 8, 63 / 8
	for i = 0, 7 do
		for j = 0, 7 do
			local x, z = (i - 3.5) * tileX, (j - 3.5) * tileZ
			local overShaft = math.abs(x) - tileX / 2 < SHAFT and math.abs(z) - tileZ / 2 < SHAFT
			if (i + j) % 2 == 0 and not overShaft then
				glow(shell, "Плитка пола", V(tileX, 0.02, tileZ), place(V(x, -0.04, z)), Color3.fromRGB(145, 156, 208))
			end
		end
	end
	for _, side in { -1, 1 } do
		part(shell, "Стена сектора", V(1.1, CEIL + 0.6, 63.4), place(V(wing(side * 26.65), CEIL / 2, 0.15)), WALL, Enum.Material.SmoothPlastic)
		part(shell, "Фронтальная стена", V(16.4 + WIDEN, CEIL + 0.6, 1.1), place(V(side * (18.15 + WIDEN / 2), CEIL / 2, -30.93)), WALL, Enum.Material.SmoothPlastic)
		-- Рёбра стен.
		for z = -24, 24, 8 do
			part(shell, "Ребро стены", V(0.5, CEIL, 0.6), place(V(wing(side * 25.85), CEIL / 2, z)), GRAPHITE, Enum.Material.SmoothPlastic)
		end
		glow(shell, "Подсветка стены", V(0.1, 0.18, 61), place(V(wing(side * 26.05), 0.35, 0)), CYAN)
		glow(shell, "Подсветка стены", V(0.1, 0.14, 61), place(V(wing(side * 26.05), 14.2, 0)), CYAN)
	end
	part(shell, "Перемычка входа", V(20, CEIL - 11.65 + 0.6, 1.16), place(V(0, (11.65 + CEIL + 0.6) / 2, -30.9)), WALL, Enum.Material.SmoothPlastic)
	part(shell, "Задняя стена", V(53.2 + WIDEN * 2, CEIL + 0.6, 1.4), place(V(0, CEIL / 2, 31.3)), WALL, Enum.Material.SmoothPlastic)
	glow(shell, "Подсветка стены", V(52 + WIDEN * 2, 0.18, 0.1), place(V(0, 0.35, 30.55)), CYAN)
	part(shell, "Потолок сектора", V(53.9 + WIDEN * 2, 1, 63), place(V(0, CEIL + 0.5, 0)), CEILING)
	-- Арка входа: неоновый контур проёма изнутри.
	for _, side in { -1, 1 } do
		glow(shell, "Арка входа", V(0.25, 11.6, 0.2), place(V(side * 10.05, 5.8, -30.3)), CYAN)
	end
	glow(shell, "Арка входа", V(20.3, 0.25, 0.2), place(V(0, 11.6, -30.3)), CYAN)
	glow(shell, "Коврик входа", V(8, 0.03, 0.18), place(V(0, 0.02, -27.6)), CYAN)
	glow(shell, "Коврик входа", V(8, 0.03, 0.18), place(V(0, 0.02, -22.4)), CYAN)

	-- Свет потолка (сервер добавляет SurfaceLight вниз): светящиеся панели.
	for _, at in { V(-17, 0, -14), V(17, 0, -14), V(-17, 0, 10), V(17, 0, 10), V(0, 0, -21) } do
		downlight(part(model, "Светильник рабочей зоны", V(7.3, 0.14, 1.3), place(V(at.X, CEIL - 0.1, at.Z)), LAMP, Enum.Material.Neon, false), 1.5, 26, 120)
	end

	-- ===== Вход: табло владельца, спавн =====
	local board = part(model, "Табло сектора", V(7.6, 2.52, 0.39), place(V(0, 9, -30.9), V(0, 0, 1)), DARK, Enum.Material.SmoothPlastic)
	board.CanCollide = false
	glow(shell, "Рамка табло", V(7.9, 0.12, 0.45), place(V(0, 10.3, -30.9)), CYAN)
	glow(shell, "Рамка табло", V(7.9, 0.12, 0.45), place(V(0, 7.7, -30.9)), CYAN)
	spawn.CFrame = world(place(V(0, 0.2, -25.5), V(0, 0, 1)))
	spawn.Transparency = 1
	spawn.CanCollide = false

	-- ===== Шлюз: площадка над шахтой, створки, опора, сигналы =====
	local bay = folder("Бокс открытия")
	for _, x in { -4.4, 4.4 } do
		part(model, "Створка шлюза", V(8.8, 0.65, 17.6), place(V(x, -0.35, 0)), STEEL, Enum.Material.SmoothPlastic)
		part(model, "Створка шлюза", V(8.8, 0.65, 17.6), place(V(x, 10.63, 0)), STEEL, Enum.Material.SmoothPlastic)
	end
	local support = part(model, "Опора над шахтой", V(18.4, 1.43, 18.4), place(V(0, -0.69, 0)), DARK, Enum.Material.SmoothPlastic)
	support.Transparency = 1
	part(model, "Индикация шлюза", V(3.85, 0.07, 0.21), place(V(0, 0.05, -9.44)), CYAN, Enum.Material.Neon, false)
	part(model, "Сигнал отвода", V(1.32, 0.13, 0.18), place(V(0, 0.22, -9.62)), AMBER, Enum.Material.Neon, false)
	part(model, "Сигнал подачи", V(1.32, 0.16, 0.22), place(V(0, 11.35, -9.95)), CYAN, Enum.Material.Neon, false)
	local outlet = part(model, "Верхняя точка подачи", V(0.25, 0.25, 0.25), place(V(0, 11.3, 0)), DARK, Enum.Material.SmoothPlastic, false)
	outlet.Transparency = 1
	local disposal = part(model, "Нижняя точка отвода", V(0.25, 0.25, 0.25), place(V(0, -12.72, 0)), DARK, Enum.Material.SmoothPlastic, false)
	disposal.Transparency = 1
	-- Окантовка площадки: стальная рама и янтарная кромка опасной зоны.
	for _, side in { -1, 1 } do
		part(bay, "Рама площадки", V(SHAFT * 2 + 2.4, 0.08, 1.2), place(V(0, 0.0, side * (SHAFT + 0.6))), STEEL, Enum.Material.SmoothPlastic, false)
		part(bay, "Рама площадки", V(1.2, 0.08, SHAFT * 2), place(V(side * (SHAFT + 0.6), 0.0, 0)), STEEL, Enum.Material.SmoothPlastic, false)
		glow(bay, "Кромка шлюза", V(SHAFT * 2 + 0.2, 0.05, 0.14), place(V(0, 0.05, side * (SHAFT + 0.05))), AMBER)
		glow(bay, "Кромка шлюза", V(0.14, 0.05, SHAFT * 2 + 0.2), place(V(side * (SHAFT + 0.05), 0.05, 0)), AMBER)
	end
	-- Колонны колпака и направляющие створок.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local at = V(sx * 10.0, CEIL / 2, sz * 10.0)
			part(bay, "Колонна шлюза", V(1, CEIL, 1), place(at), GRAPHITE, Enum.Material.SmoothPlastic)
			glow(bay, "Подсветка колонны", V(0.12, CEIL - 2, 0.12), place(at + V(-sx * 0.52, 0, -sz * 0.52)), CYAN)
		end
		part(bay, "Рельс створок", V(0.9, 0.8, 20), place(V(sx * 9.6, 11.6, 0)), STEEL, Enum.Material.SmoothPlastic)
		part(bay, "Рельс створок", V(0.5, 0.5, 20), place(V(sx * 9.6, 0.25, 0)), STEEL, Enum.Material.SmoothPlastic, false)
	end
	part(bay, "Поперечина колпака", V(20.6, 0.8, 0.8), place(V(0, 11.6, -10.0)), STEEL, Enum.Material.SmoothPlastic)
	-- Колпак подачи: стеклянные стенки над площадкой, сзади — стык с трубой.
	for _, sx in { -1, 1 } do
		local pane = part(bay, "Стекло колпака", V(0.1, PIPE_TOP - 12, 19.2), place(V(sx * 9.95, (12 + PIPE_TOP) / 2, 0)), GLASS, Enum.Material.Glass, false)
		pane.Transparency = 0.8
	end
	local front = part(bay, "Стекло колпака", V(19.2, PIPE_TOP - 12, 0.1), place(V(0, (12 + PIPE_TOP) / 2, -9.95)), GLASS, Enum.Material.Glass, false)
	front.Transparency = 0.8
	part(bay, "Крыша колпака", V(20.6, 0.25, 20.6), place(V(0, PIPE_TOP + 0.1, 0)), GRAPHITE, Enum.Material.SmoothPlastic, false)
	-- Шахта отвода в стиле Backrooms — видна только при открытых нижних створках.
	for _, side in { -1, 1 } do
		part(bay, "Обои шахты", V(0.5, 13.3, 18.5), place(V(side * 9.0, -6.7, 0)), WALLPAPER, Enum.Material.Fabric)
		part(bay, "Обои шахты", V(18.5, 13.3, 0.5), place(V(0, -6.7, side * 9.0)), WALLPAPER, Enum.Material.Fabric)
	end
	part(bay, "Ковролин шахты", V(18.5, 0.7, 18.5), place(V(0, -13.8, 0)), CARPET, Enum.Material.Fabric)
	local shaftLamp = part(bay, "Лампа шахты", V(3, 0.1, 1.4), place(V(0, -8.5, 0)), TILE, Enum.Material.Neon, false)
	shaftLamp.Transparency = 1
	local shaftLight = Instance.new("PointLight")
	shaftLight.Color = Color3.fromRGB(255, 236, 170)
	shaftLight.Range = 11
	shaftLight.Brightness = 1.2
	shaftLight.Shadows = true
	shaftLight.Parent = shaftLamp

	-- Пульт добычи — у переднего левого угла площадки, лицом ко входу.
	part(model, "Пульт добычи", V(1.45, 2.2, 1.18), place(V(-7.4, 1.1, -12.6), V(0, 0, -1)), GRAPHITE, Enum.Material.SmoothPlastic)
	glow(bay, "Подсветка пульта", V(1.5, 0.08, 0.1), place(V(-7.4, 0.12, -13.22)), CYAN)

	-- ===== Труба подачи: стеклянный тоннель от камеры Backrooms к колпаку =====
	local pipe = folder("Труба подачи")
	local pipeLength = DOOR_Z - HOOD_BACK
	local pipeMid = (DOOR_Z + HOOD_BACK) / 2
	part(pipe, "Настил трубы", V(PIPE_HALF * 2, 0.3, pipeLength), place(V(0, PIPE_FLOOR - 0.15, pipeMid)), STEEL, Enum.Material.SmoothPlastic)
	for _, sx in { -1, 1 } do
		local pane = part(pipe, "Стекло трубы", V(0.1, PIPE_TOP - PIPE_FLOOR, pipeLength), place(V(sx * PIPE_HALF, (PIPE_FLOOR + PIPE_TOP) / 2, pipeMid)), GLASS, Enum.Material.Glass, false)
		pane.Transparency = 0.78
		glow(pipe, "Кромка трубы", V(0.12, 0.12, pipeLength), place(V(sx * PIPE_HALF, PIPE_FLOOR + 0.05, pipeMid)), CYAN)
		glow(pipe, "Кромка трубы", V(0.12, 0.12, pipeLength), place(V(sx * PIPE_HALF, PIPE_TOP - 0.05, pipeMid)), CYAN)
	end
	local roof = part(pipe, "Стекло трубы", V(PIPE_HALF * 2, 0.1, pipeLength), place(V(0, PIPE_TOP, pipeMid)), GLASS, Enum.Material.Glass, false)
	roof.Transparency = 0.78
	for z = HOOD_BACK + 1.5, DOOR_Z - 1, 2.6 do
		for _, sx in { -1, 1 } do
			part(pipe, "Кольцо трубы", V(0.5, PIPE_TOP - PIPE_FLOOR + 0.6, 0.5), place(V(sx * (PIPE_HALF + 0.3), (PIPE_FLOOR + PIPE_TOP) / 2, z)), GRAPHITE, Enum.Material.SmoothPlastic, false)
		end
		part(pipe, "Кольцо трубы", V(PIPE_HALF * 2 + 1.1, 0.5, 0.5), place(V(0, PIPE_TOP + 0.3, z)), GRAPHITE, Enum.Material.SmoothPlastic, false)
		part(pipe, "Кольцо трубы", V(PIPE_HALF * 2 + 1.1, 0.5, 0.5), place(V(0, PIPE_FLOOR - 0.45, z)), GRAPHITE, Enum.Material.SmoothPlastic, false)
	end
	-- Опоры трубы до пола (по краям, не мешая проходу к лаборатории).
	for _, sx in { -1, 1 } do
		part(pipe, "Опора трубы", V(0.8, PIPE_FLOOR - 0.3, 0.8), place(V(sx * (PIPE_HALF + 0.4), (PIPE_FLOOR - 0.3) / 2, pipeMid)), GRAPHITE, Enum.Material.SmoothPlastic)
	end

	-- ===== Камера Backrooms: глухая, открывается затвором только при доставке =====
	local rooms = folder("Камера Backrooms")
	-- Фасад камеры (тёмный металл) с проёмом под трубу.
	for _, sx in { -1, 1 } do
		part(rooms, "Фасад камеры", V(9, CEIL - PIPE_FLOOR + 0.4, 0.6), place(V(sx * 12.6, (PIPE_FLOOR - 0.4 + CEIL) / 2, DOOR_Z)), WALL, Enum.Material.SmoothPlastic)
	end
	part(rooms, "Фасад камеры", V(16.2, CEIL - PIPE_TOP, 0.6), place(V(0, (PIPE_TOP + CEIL) / 2, DOOR_Z)), WALL, Enum.Material.SmoothPlastic)
	glow(rooms, "Контур затвора", V(16.6, 0.16, 0.2), place(V(0, PIPE_TOP + 0.08, DOOR_Z - 0.4)), AMBER)
	for _, sx in { -1, 1 } do
		glow(rooms, "Контур затвора", V(0.16, PIPE_TOP - PIPE_FLOOR, 0.2), place(V(sx * 8.2, (PIPE_FLOOR + PIPE_TOP) / 2, DOOR_Z - 0.4)), AMBER)
	end
	-- Створки затвора (сервер раздвигает их на свою ширину). Надпись движется вместе со створкой.
	for _, sx in { -1, 1 } do
		local door = part(model, "Затвор Backrooms", V(8, PIPE_TOP - PIPE_FLOOR, 0.4), place(V(sx * 4, (PIPE_FLOOR + PIPE_TOP) / 2, DOOR_Z - 0.6), V(0, 0, -1)), GRAPHITE, Enum.Material.SmoothPlastic)
		door.CanCollide = false
		label(door, Enum.NormalId.Front, {
			{ if sx < 0 then "ЗАТВОР" else "УРОВЕНЬ 0", AMBER, 0.28 },
			{ "НЕ ВХОДИТЬ", AMBER:Lerp(DARK, 0.35), 0.18, BOLD },
		}, 30)
	end
	-- Корпус камеры: пол (ковролин сверху, тёмный потолок лаборатории снизу), стены, потолок.
	local depth = BACK_Z - DOOR_Z - 0.3
	local roomMid = (DOOR_Z + 0.3 + BACK_Z) / 2
	part(rooms, "Ковролин", V(24, 0.2, depth), place(V(0, PIPE_FLOOR + 0.1, roomMid)), CARPET, Enum.Material.Fabric)
	part(rooms, "Перекрытие лаборатории", V(25, 0.5, depth + 0.6), place(V(0, PIPE_FLOOR - 0.25, roomMid)), GRAPHITE, Enum.Material.SmoothPlastic)
	for _, sx in { -1, 1 } do
		part(rooms, "Обшивка камеры", V(0.4, CEIL - PIPE_FLOOR, depth), place(V(sx * 12.3, (PIPE_FLOOR + CEIL) / 2, roomMid)), WALL, Enum.Material.SmoothPlastic)
		part(rooms, "Обои", V(0.1, PIPE_TOP - PIPE_FLOOR, depth), place(V(sx * 12.05, (PIPE_FLOOR + PIPE_TOP) / 2, roomMid)), WALLPAPER, Enum.Material.Fabric)
	end
	part(rooms, "Обои", V(24, PIPE_TOP - PIPE_FLOOR, 0.1), place(V(0, (PIPE_FLOOR + PIPE_TOP) / 2, BACK_Z - 0.05)), WALLPAPER, Enum.Material.Fabric)
	for _, x in { -6.5, 5.5 } do
		part(rooms, "Проём", V(3.2, 5.6, 0.05), place(V(x, PIPE_FLOOR + 3, BACK_Z - 0.12)), WALLPAPER:Lerp(Color3.new(0, 0, 0), 0.55), Enum.Material.Fabric, false)
	end
	part(rooms, "Простенок", V(2.6, PIPE_TOP - PIPE_FLOOR, 2.6), place(V(-7, (PIPE_FLOOR + PIPE_TOP) / 2, roomMid + 2)), WALLPAPER, Enum.Material.Fabric)
	part(rooms, "Потолок «Армстронг»", V(24, 0.15, depth), place(V(0, PIPE_TOP, roomMid)), TILE)
	for z = DOOR_Z + 2, BACK_Z - 1, 2.8 do
		part(rooms, "Профиль потолка", V(24, 0.05, 0.1), place(V(0, PIPE_TOP - 0.1, z)), TILE:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.SmoothPlastic, false)
	end
	for _, x in { -5, 5 } do
		for _, z in { DOOR_Z + 3.5, BACK_Z - 3.5 } do
			local lamp = part(model, "Лампа Backrooms", V(2.6, 0.08, 1.3), place(V(x, PIPE_TOP - 0.12, z)), LAMP_OFF, Enum.Material.SmoothPlastic, false)
			lamp.CastShadow = false
			if x < 0 then
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 240, 186)
				light.Range = 16
				light.Brightness = 1.6
				light.Enabled = false
				light.Parent = lamp
			end
		end
	end
	-- Контейнер появляется в центре камеры на уровне трубы (тот же поворот, что у точки подачи — без разворота в полёте).
	local entry = part(model, "Точка входа в трубу", V(0.25, 0.25, 0.25), place(V(0, 11.3, roomMid + 0.5)), DARK, Enum.Material.SmoothPlastic, false)
	entry.Transparency = 1

	-- ===== Лаборатория коллекций под камерой =====
	local lab = folder("Лаборатория коллекций")
	for _, sx in { -1, 1 } do
		part(lab, "Колонна лаборатории", V(0.9, PIPE_FLOOR - 0.5, 0.9), place(V(sx * 12.3, (PIPE_FLOOR - 0.5) / 2, DOOR_Z)), GRAPHITE, Enum.Material.SmoothPlastic)
		glow(lab, "Подсветка колонны", V(0.1, PIPE_FLOOR - 2, 0.1), place(V(sx * 12.3 - sx * 0.47, (PIPE_FLOOR - 0.5) / 2, DOOR_Z - 0.47)), VIOLET)
	end
	glow(lab, "Контур лаборатории", V(24, 0.03, 0.14), place(V(0, 0.02, DOOR_Z - 0.2)), VIOLET)
	local counter = part(model, "Коллекции", V(8.1, 2.24, 2.7), place(V(0, 1.12, 23.4), V(0, 0, -1)), GRAPHITE, Enum.Material.SmoothPlastic)
	part(counter, "Столешница", V(8.3, 0.18, 2.9), place(V(0, 2.3, 23.4), V(0, 0, -1)), STEEL, Enum.Material.SmoothPlastic)
	glow(counter, "Подсветка прилавка", V(8.1, 0.08, 0.1), place(V(0, 0.15, 22.03)), VIOLET)
	local catalog = part(counter, "Панель каталогизации", V(1.5, 0.5, 0.28), place(V(-2.6, 2.75, 22.6), V(0, 0, -1)) * CFrame.Angles(math.rad(22), 0, 0), DARK, Enum.Material.SmoothPlastic, false)
	catalog.CanQuery = false
	downlight(part(model, "Светильник рабочей зоны", V(7.3, 0.14, 1.3), place(V(0, PIPE_FLOOR - 0.6, 24)), LAMP, Enum.Material.Neon, false), 1.3, 14, 120)

	-- ===== Левое крыло: автоматизированный склад =====
	-- Не «Склад»: так называется деталь-станция, которую сервер ищет через FindFirstChild.
	local store = folder("Зона склада")
	local columns = { 6.4, 9.54 }
	for row = 0, 4 do
		for _, z in columns do
			-- Задняя стенка ячейки (+X модуля) — в стену: лицевая сторона модуля смотрит в +Z, правый вектор −X.
			part(model, "Складской модуль", V(1.4, 1.4, 2.6), place(V(wing(-25.2), 0.8 + row * 1.55, z), V(0, 0, 1)), STEEL, Enum.Material.SmoothPlastic)
		end
	end
	for _, z in { 4.9, 7.97, 11.04 } do
		part(store, "Стойка стеллажа", V(0.6, 8.4, 0.25), place(V(wing(-24.6), 4.2, z)), GRAPHITE, Enum.Material.SmoothPlastic)
		glow(store, "Подсветка стеллажа", V(0.08, 8, 0.08), place(V(wing(-24.28), 4.2, z)), AMBER)
	end
	part(store, "Козырёк стеллажа", V(2.4, 0.3, 6.6), place(V(wing(-25.1), 8.55, 7.97)), GRAPHITE, Enum.Material.SmoothPlastic)
	part(store, "Портал манипулятора", V(0.4, 0.4, 7.4), place(V(wing(-23.6), 9.2, 7.97)), STEEL, Enum.Material.SmoothPlastic, false)
	part(store, "Каретка манипулятора", V(1.2, 0.9, 1.2), place(V(wing(-23.6), 8.6, 9.0)), AMBER:Lerp(DARK, 0.3), Enum.Material.SmoothPlastic, false)
	glow(store, "Контур склада", V(0.14, 0.03, 14), place(V(wing(-14.8), 0.02, 8)), AMBER)
	glow(store, "Контур склада", V(11, 0.03, 0.14), place(V(wing(-20.3), 0.02, 1)), AMBER)
	glow(store, "Контур склада", V(11, 0.03, 0.14), place(V(wing(-20.3), 0.02, 15)), AMBER)
	part(model, "Склад", V(5.8, 2.04, 2.55), place(V(wing(-20.6), 1.02, 7.97), V(1, 0, 0)), GRAPHITE, Enum.Material.SmoothPlastic)
	glow(store, "Подсветка стола", V(0.1, 0.08, 5.8), place(V(wing(-19.3), 0.15, 7.97)), AMBER)
	local storagePanel = part(model, "Панель склада", V(9, 1.8, 0.3), place(V(wing(-25.4), 14.9, 7.97), V(1, 0, 0)), DARK, Enum.Material.SmoothPlastic, false)
	storagePanel.CanQuery = false
	downlight(part(model, "Рассеиватель сервисного поста", V(0.4, 0.1, 6), place(V(wing(-22.6), 7.2, 7.97)), LAMP, Enum.Material.Neon, false), 1.1, 12, 100)

	-- ===== Правое крыло: галерея витрин =====
	local gallery = folder("Галерея витрин")
	for slot = 1, 6 do
		local z = -15 + (slot - 1) * 5.6
		part(model, `Витрина {slot}`, V(3.4, 1.3, 3.5), place(V(wing(22.6), 0.65, z), V(-1, 0, 0)), GRAPHITE, Enum.Material.SmoothPlastic)
		part(gallery, "Ниша витрины", V(0.3, 6, 4.6), place(V(wing(25.9), 3.6, z)), DARK, Enum.Material.SmoothPlastic)
		glow(gallery, "Подсветка ниши", V(0.08, 5.6, 0.08), place(V(wing(25.7), 3.6, z - 2.35)), CYAN)
	end
	part(model, "Витрина 7", V(5, 1.3, 5.5), place(V(wing(21.6), 0.65, 21.5), V(-1, 0, 0)), GRAPHITE, Enum.Material.SmoothPlastic)
	for _, z in { -12.2, -1, 10.2, 21.5 } do
		downlight(part(model, "Рассеиватель витрин", V(0.5, 0.12, 6.9), place(V(wing(22.7), 7.2, z)), LAMP, Enum.Material.Neon, false), 1.0, 12, 100)
	end
	part(gallery, "Карниз галереи", V(1.4, 0.3, 46), place(V(wing(25.4), 7.4, 3.5)), GRAPHITE, Enum.Material.SmoothPlastic, false)
	glow(gallery, "Контур галереи", V(0.14, 0.03, 44), place(V(wing(19.6), 0.02, 3.5)), CYAN)
	local displayPanel = part(model, "Панель экспозиции", V(11, 1.8, 0.3), place(V(wing(25.4), 14.9, 3.5), V(-1, 0, 0)), DARK, Enum.Material.SmoothPlastic, false)
	displayPanel.CanQuery = false

	-- ===== Вход: терминал заказов справа, автостенд слева =====
	local desk = folder("Пост заказов")
	local terminal = part(model, "Заказы", V(4.55, 2.36, 2.35), place(V(wing(20.2), 1.18, -24.2), V(-1, 0, 0)), GRAPHITE, Enum.Material.SmoothPlastic)
	local screenCF = place(V(wing(20.6), 3.75, -24.2), V(-1, 0, 0)) * CFrame.Angles(math.rad(19), 0, 0)
	part(terminal, "Рама экрана заказа", V(3.9, 1.3, 0.3), screenCF * CFrame.new(0, 0, 0.18), STEEL, Enum.Material.SmoothPlastic, false)
	part(terminal, "Матовый экран заказа", V(3.47, 0.96, 0.07), screenCF, DARK, Enum.Material.SmoothPlastic, false)
	glow(desk, "Подсветка поста", V(0.1, 0.08, 4.5), place(V(wing(19.0), 0.15, -24.2)), CYAN)
	local orderPanel = part(model, "Панель заказов", V(8, 1.8, 0.3), place(V(wing(25.4), 14.9, -21), V(-1, 0, 0)), DARK, Enum.Material.SmoothPlastic, false)
	orderPanel.CanQuery = false
	downlight(part(model, "Рассеиватель сервисного поста", V(0.4, 0.1, 5), place(V(wing(22.6), 7.2, -24.2)), LAMP, Enum.Material.Neon, false), 1.1, 12, 100)
	part(model, "Витрина 8", V(8, 1.3, 5.94), place(V(wing(-17), 0.65, -22.5), V(1, 0, 0)), GRAPHITE, Enum.Material.SmoothPlastic)
	glow(desk, "Контур автостенда", V(6.6, 0.03, 0.14), place(V(wing(-17), 0.02, -27.3)), AMBER)
	glow(desk, "Контур автостенда", V(6.6, 0.03, 0.14), place(V(wing(-17), 0.02, -17.7)), AMBER)

	-- ===== Cartoon kit =====
	local kit = folder("Набор")
	local function foot(at, facing)
		return world(place(at, facing))
	end
	for _, side in { -1, 1 } do
		local inward = V(-side, 0, 0)
		local x = wing(side * 25.9)
		local panels = if side == 1 then { -13, 17.5, 27 } else { -24, -13, 17.5, 27 }
		for _, z in panels do
			Kit.place(kit, "wall", foot(V(x - side * 0.3, 0, z), inward), 13)
		end
		Kit.place(kit, "column", foot(V(wing(side * 25), 0, -29.5), V(0, 0, 1)), 14)
		Kit.place(kit, "column", foot(V(wing(side * 25), 0, 29.5), V(0, 0, -1)), 14)
		for _, px in { 13, 20 } do
			Kit.place(kit, "wall", foot(V(side * px, 0, 30.2), V(0, 0, -1)), 11)
		end
		for _, px in { 15, 23 } do
			Kit.place(kit, "wall", foot(V(side * px, 0, -29.7), V(0, 0, 1)), 11)
		end
	end
	-- Two continuous pipe runs high on each side wall, with joint collars.
	local PIPE_GREEN = Color3.fromRGB(86, 214, 120)
	local function pipeRun(x, y, diameter)
		local along = CFrame.Angles(0, math.rad(90), 0)
		glow(kit, "Труба стены", V(61.6, diameter, diameter), place(V(x, y, 0)) * along, PIPE_GREEN).Shape = Enum.PartType.Cylinder
		for z = -28, 28, 14 do
			glow(kit, "Хомут трубы", V(0.8, diameter + 0.45, diameter + 0.45), place(V(x, y, z)) * along, STEEL).Shape = Enum.PartType.Cylinder
		end
	end
	for _, side in { -1, 1 } do
		local x = wing(side * 25.2)
		pipeRun(x, 17, 1.3)
		pipeRun(x, 19, 0.8)
	end

	-- Order terminal beside its desk, shelves by the storage, pedestals under the displays.
	Kit.place(kit, "terminal", foot(V(wing(20.2), 0, -19.6), V(-1, 0, 0)), 7)
	Kit.place(kit, "shelf", foot(V(wing(-24), 0, -2.5), V(1, 0, 0)), 9)
	for slot = 1, 6 do
		Kit.place(kit, "pedestal", foot(V(wing(22.6), 0, -15 + (slot - 1) * 5.6), V(-1, 0, 0)), 1.5)
	end
end

local report = {}
for index = 1, 6 do
	local model = LAB:FindFirstChild(string.format("Сектор %02d", index))
	if model then
		local outlet = findPart(model, "Верхняя точка подачи")
		local entry = findPart(model, "Точка входа в трубу")
		assert(outlet and entry, `{model.Name}: нет точек трубы — не из чего вычислить систему сектора`)
		local origin = outlet.CFrame.Position * Vector3.new(1, 0, 1)
		local toward = entry.CFrame.Position * Vector3.new(1, 0, 1)
		local back = (toward - origin).Unit
		local right = UP:Cross(back)
		local F = CFrame.fromMatrix(origin, right, UP, back)
		local spawn = nil
		for _, child in model:GetChildren() do
			if child:IsA("SpawnLocation") then
				spawn = child
			end
		end
		assert(spawn, `{model.Name}: нет SpawnLocation`)
		for _, child in model:GetChildren() do
			if child ~= spawn then
				child:Destroy()
			end
		end
		buildSector(model, F, spawn)
		local parts = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		table.insert(report, `{model.Name}: {parts} деталей`)
	end
end
return table.concat(report, "\n")
