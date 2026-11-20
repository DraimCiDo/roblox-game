--!nocheck
-- Оформление шести секторов и соединительных переходов «Лаборатории CORPA» в одном стиле с залом.
-- Запускается в Roblox Studio (Edit), например через MCP execute_luau. Идемпотентен: перекрашивает
-- детали по именам и пересоздаёт папки «Оформление сектора» в каждом секторе и «Оформление переходов».
-- Игровые объекты (витрины, складские модули, створки, терминалы, точки маршрута) не трогает.

local LAB = workspace:FindFirstChild("CORPA — испытательная лаборатория")
assert(LAB, "Нет модели лаборатории")

local CYAN = Color3.fromRGB(72, 222, 255)
local AMBER = Color3.fromRGB(255, 184, 64)
local FLOOR = Color3.fromRGB(42, 47, 54)
local WALL = Color3.fromRGB(40, 47, 57)
local PANEL = Color3.fromRGB(30, 36, 44)
local DARK = Color3.fromRGB(18, 22, 28)
local FABRIC = Color3.fromRGB(34, 48, 58)

-- Направления от центра зала на порталы шести секторов.
local PORTALS = {
	Vector3.new(-1, 0, 1).Unit,
	Vector3.new(0, 0, 1),
	Vector3.new(1, 0, 1).Unit,
	Vector3.new(-1, 0, -1).Unit,
	Vector3.new(0, 0, -1),
	Vector3.new(1, 0, -1).Unit,
}

-- Перекраска по имени детали: {материал, цвет, отражение}.
local RESTYLE = {
	["Бортовая стена внешнего сектора"] = { Enum.Material.Metal, WALL },
	["Торцевая стена внешнего сектора"] = { Enum.Material.Metal, WALL },
	["Передняя стена внешнего сектора"] = { Enum.Material.Metal, WALL },
	["Перемычка над входом в сектор"] = { Enum.Material.Metal, PANEL },
	["Кровля внешнего сектора"] = { Enum.Material.SmoothPlastic, DARK },
	["Настил · Задняя галерея"] = { Enum.Material.SmoothPlastic, FLOOR },
	["Настил · Вход и приёмка"] = { Enum.Material.SmoothPlastic, FLOOR },
	["Настил · Сервисный проход"] = { Enum.Material.SmoothPlastic, FLOOR },
	["Настил · Выставочный проход"] = { Enum.Material.SmoothPlastic, FLOOR },
	["Панель верхнего пояса"] = { Enum.Material.Metal, PANEL },
	["Задник сервисного поста"] = { Enum.Material.Metal, PANEL },
	["Задник выставочной ниши"] = { Enum.Material.Fabric, FABRIC },
	["Тыловая панель каталогизации"] = { Enum.Material.Fabric, FABRIC },
	-- Шахта отвода «уходит в Backrooms»: обои, ковролин на дне.
	["Продольная стенка шахты"] = { Enum.Material.Fabric, Color3.fromRGB(190, 186, 112) },
	["Поперечная стенка шахты"] = { Enum.Material.Fabric, Color3.fromRGB(190, 186, 112) },
	["Днище шахты"] = { Enum.Material.Fabric, Color3.fromRGB(176, 162, 118) },
	-- Переходы между залом и секторами.
	["Стена соединительного перехода"] = { Enum.Material.Metal, WALL },
	["Матовая панель перехода"] = { Enum.Material.Metal, PANEL },
	["Простенок прохода"] = { Enum.Material.Metal, WALL },
	["Настил соединительной галереи"] = { Enum.Material.SmoothPlastic, FLOOR },
	["Перекрытие соединительной галереи"] = { Enum.Material.SmoothPlastic, DARK },
	["Минеральная панель портала"] = { Enum.Material.Metal, PANEL },
	["Вставка входного портала"] = { Enum.Material.Metal, PANEL },
	["Верхняя вставка входного портала"] = { Enum.Material.Metal, PANEL },
	["Бетонный цоколь"] = { Enum.Material.Metal, DARK },
}

local function restyle(container)
	local changed = 0
	for _, piece in container:GetDescendants() do
		local rule = piece:IsA("BasePart") and RESTYLE[piece.Name]
		if rule then
			piece.Material = rule[1]
			piece.Color = rule[2]
			piece.Reflectance = rule[3] or 0
			changed += 1
		end
	end
	return changed
end

local function trim(parent, name, size, frame, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = frame
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Parent = parent
	return p
end

-- Неоновые полосы по внутренней стороне стены: плинтус и пояс на средней высоте.
local function wallStrips(parent, wall, center, floorY, heights, color)
	local size = wall.Size
	-- Самая тонкая ось — толщина стены, длинная горизонтальная — длина полосы.
	local axes = {
		{ Vector = wall.CFrame.RightVector, Size = size.X },
		{ Vector = wall.CFrame.LookVector, Size = size.Z },
	}
	table.sort(axes, function(a, b)
		return a.Size < b.Size
	end)
	local normal, along = axes[1], axes[2]
	local inward = normal.Vector
	if (center - wall.CFrame.Position):Dot(inward) < 0 then
		inward = -inward
	end
	local bottom = wall.CFrame.Position.Y - size.Y / 2
	local top = wall.CFrame.Position.Y + size.Y / 2
	for _, height in heights do
		local y = math.max(bottom, floorY) + height
		if y < top - 0.3 then
			local at = Vector3.new(wall.CFrame.Position.X, y, wall.CFrame.Position.Z) + inward * (normal.Size / 2 + 0.06)
			local frame = CFrame.lookAt(at, at + along.Vector)
			trim(parent, "Подсветка стены", Vector3.new(0.12, 0.18, along.Size - 1), frame, color)
		end
	end
end

-- Backrooms (уровень 0): жёлто-зелёные обои, бежевый ковролин, потолок с люминесцентными панелями.
local WALLPAPER = Color3.fromRGB(196, 190, 116)
local CARPET = Color3.fromRGB(184, 170, 128)
local CEILING = Color3.fromRGB(216, 212, 182)
local FLUORESCENT = Color3.fromRGB(255, 251, 228)

local function solid(parent, name, size, frame, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = frame
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function findPart(container, name)
	for _, piece in container:GetDescendants() do
		if piece:IsA("BasePart") and piece.Name == name then
			return piece
		end
	end
	return nil
end

-- Камера Backrooms в дальнем конце трубы подачи: контейнер появляется там и по трубе едет к шлюзу.
-- Координаты — в системе сектора: начало над шлюзом («Верхняя точка подачи»), ось along — к задней стене.
local function backroomsChamber(sector, folder)
	local outlet = findPart(sector, "Верхняя точка подачи")
	local entry = findPart(sector, "Точка входа в трубу")
	local back = findPart(sector, "Торцевая стена внешнего сектора")
	if not (outlet and entry and back) then
		return
	end
	local origin = outlet.CFrame.Position
	local toward = entry.CFrame.Position
	local frame = CFrame.lookAt(origin, Vector3.new(toward.X, origin.Y, toward.Z))
	-- Внутренняя грань задней стены вдоль оси сектора.
	local backAlong = frame:PointToObjectSpace(back.CFrame.Position).Z * -1 - back.Size.Z / 2 - 0.15
	local function at(across, worldY, along)
		return frame * CFrame.new(across, worldY - origin.Y, -along)
	end
	local first, last = backAlong - 12.2, backAlong
	local mid, depth = (first + last) / 2, last - first
	local bottom, top = 11.1, 18.8
	local height = top - bottom
	local room = Instance.new("Model")
	room.Name = "Камера Backrooms"
	room.Parent = folder
	solid(room, "Ковролин", Vector3.new(19, 0.2, depth), at(0, bottom, mid), CARPET, Enum.Material.Fabric)
	solid(room, "Потолок «Армстронг»", Vector3.new(19, 0.2, depth), at(0, top, mid), CEILING, Enum.Material.SmoothPlastic)
	-- Боковые стенки стеклянные: из задней галереи видно освещённую комнату и выезжающий контейнер.
	for _, across in { -9.6, 9.6 } do
		local pane = solid(room, "Стекло камеры", Vector3.new(0.15, height, depth), at(across, (bottom + top) / 2, mid), Color3.fromRGB(200, 230, 240), Enum.Material.Glass)
		pane.Transparency = 0.75
	end
	solid(room, "Обои", Vector3.new(19.4, height, 0.2), at(0, (bottom + top) / 2, last), WALLPAPER, Enum.Material.Fabric)
	-- Тёмные проёмы в дальней стене: лабиринт продолжается дальше.
	for _, across in { -5.5, 4.5 } do
		solid(room, "Проём", Vector3.new(3.2, 5.6, 0.1), at(across, bottom + 2.9, last - 0.15), WALLPAPER:Lerp(Color3.new(0, 0, 0), 0.55), Enum.Material.Fabric)
	end
	-- Простенок посреди комнаты — характерная «бесконечная» планировка.
	solid(room, "Простенок", Vector3.new(2.6, height, 2.6), at(-4.8, (bottom + top) / 2, mid + 2.2), WALLPAPER, Enum.Material.Fabric)
	-- Сетка потолочных плит и люминесцентные панели.
	for along = first + 2, last - 1, 3 do
		solid(room, "Профиль потолка", Vector3.new(19, 0.06, 0.12), at(0, top - 0.12, along), CEILING:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.SmoothPlastic)
	end
	for _, across in { -4.5, 4.5 } do
		for _, along in { first + 3, first + 9 } do
			local lamp = solid(room, "Люминесцентная панель", Vector3.new(2.6, 0.1, 1.3), at(across, top - 0.14, along), FLUORESCENT, Enum.Material.Neon)
			lamp.CastShadow = false
		end
	end
	local light = Instance.new("PointLight")
	light.Name = "Гул ламп"
	light.Color = Color3.fromRGB(255, 240, 186)
	light.Range = 16
	light.Brightness = 1.6
	light.Parent = room:FindFirstChild("Потолок «Армстронг»")
	-- Торец трубы больше не глухой: он открывается в Backrooms.
	local cap = findPart(sector, "Крышка торца трубопровода")
	if cap then
		cap.Transparency = 1
		cap.CanCollide = false
	end
	-- Контейнер появляется в центре комнаты Backrooms (разрыв помещается между полом и потолком).
	entry.CFrame = at(0, (bottom + top) / 2, mid + 1)

	-- Тёплый жёлтый свет на дне шахты отвода: контейнеры уходят обратно в Backrooms.
	local disposal = findPart(sector, "Нижняя точка отвода")
	if disposal then
		local glow = solid(folder, "Свет Backrooms в шахте", Vector3.new(6, 0.1, 3), disposal.CFrame * CFrame.new(0, 4, 0), FLUORESCENT, Enum.Material.Neon)
		glow.Transparency = 1
		local shaftLight = Instance.new("PointLight")
		shaftLight.Color = Color3.fromRGB(255, 236, 170)
		shaftLight.Range = 11
		shaftLight.Brightness = 1.2
		-- С тенями: свет остаётся в шахте и не пересвечивает площадку сквозь закрытые створки.
		shaftLight.Shadows = true
		shaftLight.Parent = glow
	end
end

local report = {}
for index = 1, 6 do
	local sector = LAB:FindFirstChild(string.format("Сектор %02d", index))
	if sector then
		local old = sector:FindFirstChild("Оформление сектора")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "Оформление сектора"
		local changed = restyle(sector)
		-- Центр сектора — над шлюзом (без Model:GetBoundingBox, которого нет в Lune).
		local outlet = findPart(sector, "Верхняя точка подачи")
		local center = if outlet then outlet.CFrame.Position else Vector3.new(0, 0, 0)
		local spawn = nil
		for _, piece in sector:GetDescendants() do
			if piece:IsA("SpawnLocation") then
				spawn = piece
				break
			end
		end
		local floorY = if spawn then spawn.CFrame.Position.Y - spawn.Size.Y / 2 else 0
		for _, wall in sector:GetDescendants() do
			if
				wall:IsA("BasePart")
				and (
					wall.Name == "Бортовая стена внешнего сектора"
					or wall.Name == "Торцевая стена внешнего сектора"
					or wall.Name == "Передняя стена внешнего сектора"
				)
			then
				wallStrips(folder, wall, center, floorY, { 0.35, 9.5 }, CYAN)
			end
		end
		backroomsChamber(sector, folder)
		folder.Parent = sector
		table.insert(report, `{sector.Name}: перекрашено {changed}, полос {#folder:GetChildren()}`)
	end
end

-- Переходы: перекраска и янтарные полосы у пола (служебная зона между залом и сектором).
local oldRoutes = LAB:FindFirstChild("Оформление переходов")
if oldRoutes then
	oldRoutes:Destroy()
end
local routes = Instance.new("Folder")
routes.Name = "Оформление переходов"
local changedRoutes = 0
for _, piece in LAB:GetChildren() do
	local rule = piece:IsA("BasePart") and RESTYLE[piece.Name]
	if rule then
		piece.Material = rule[1]
		piece.Color = rule[2]
		piece.Reflectance = rule[3] or 0
		changedRoutes += 1
	end
	if piece:IsA("BasePart") and piece.Name == "Стена соединительного перехода" then
		-- Ось перехода идёт от центра зала к порталу сектора; «внутрь» — к ближайшей точке этой оси.
		local flat = piece.CFrame.Position * Vector3.new(1, 0, 1)
		local best, bestDot = nil, -math.huge
		for _, portal in PORTALS do
			local dot = flat:Dot(portal)
			if dot > bestDot then
				best, bestDot = portal, dot
			end
		end
		wallStrips(routes, piece, best * bestDot + Vector3.new(0, piece.CFrame.Position.Y, 0), 0, { 0.35 }, AMBER)
	end
end
routes.Parent = LAB
table.insert(report, `Переходы: перекрашено {changedRoutes}, полос {#routes:GetChildren()}`)
return table.concat(report, "\n")
