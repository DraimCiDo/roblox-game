--!nocheck
-- Оформление соединительных переходов между залом и секторами «Лаборатории CORPA».
-- Запускается из build.luau (Lune) или в Studio. Идемпотентен: перекрашивает детали переходов по именам
-- и пересоздаёт папку «Оформление переходов». Сами сектора собирает sector.luau.

local LAB = workspace:FindFirstChild("CORPA — испытательная лаборатория")
assert(LAB, "Нет модели лаборатории")

local AMBER = Color3.fromRGB(255, 184, 64)
local FLOOR = Color3.fromRGB(42, 47, 54)
local WALL = Color3.fromRGB(40, 47, 57)
local PANEL = Color3.fromRGB(30, 36, 44)
local DARK = Color3.fromRGB(18, 22, 28)

-- Направления от центра зала на порталы шести секторов.
local PORTALS = {
	Vector3.new(-1, 0, 1).Unit,
	Vector3.new(0, 0, 1),
	Vector3.new(1, 0, 1).Unit,
	Vector3.new(-1, 0, -1).Unit,
	Vector3.new(0, 0, -1),
	Vector3.new(1, 0, -1).Unit,
}

-- Перекраска по имени детали: {материал, цвет}.
local RESTYLE = {
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

-- Неоновая полоса у пола по внутренней стороне стены перехода.
local function wallStrip(parent, wall, center, color)
	local size = wall.Size
	local axes = {
		{ Vector = wall.CFrame.RightVector, Size = size.X },
		{ Vector = wall.CFrame.LookVector, Size = size.Z },
	}
	table.sort(axes, function(a, b)
		return a.Size < b.Size
	end)
	local normal, along = axes[1], axes[2]
	local position = wall.CFrame.Position
	local inward = normal.Vector
	if (center - position):Dot(inward) < 0 then
		inward = -inward
	end
	local bottom = position.Y - size.Y / 2
	local at = Vector3.new(position.X, math.max(bottom, 0) + 0.35, position.Z) + inward * (normal.Size / 2 + 0.06)
	trim(parent, "Подсветка стены", Vector3.new(0.12, 0.18, along.Size - 1), CFrame.lookAt(at, at + along.Vector), color)
end

local old = LAB:FindFirstChild("Оформление переходов")
if old then
	old:Destroy()
end
local routes = Instance.new("Folder")
routes.Name = "Оформление переходов"
local changed = 0
for _, piece in LAB:GetChildren() do
	local rule = piece:IsA("BasePart") and RESTYLE[piece.Name]
	if rule then
		piece.Material = rule[1]
		piece.Color = rule[2]
		piece.Reflectance = 0
		changed += 1
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
		wallStrip(routes, piece, best * bestDot + Vector3.new(0, piece.CFrame.Position.Y, 0), AMBER)
	end
end
routes.Parent = LAB
return `Переходы: перекрашено {changed}, полос {#routes:GetChildren()}`
