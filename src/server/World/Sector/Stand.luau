--!strict
-- Display stands.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Common = require(script.Parent.Common)
type Kit = Common.Kit
local STEEL = Common.STEEL
local CHROME = Common.CHROME
local MARBLE = Common.MARBLE
local CYAN = Common.CYAN
local AMBER = Common.AMBER
local VIOLET = Common.VIOLET
local WARM = Common.WARM
local GLASS = Common.GLASS
local brick = Common.brick
local rgb = Common.rgb
local cylinder = Common.cylinder
local hideChildren = Common.hideChildren

local Stand = {}

local function buildStand(kit: Kit, slot: number, stand: Part): ()
	local top = stand.Size.Y / 2
	local size = Catalog.DisplaySizes[slot]
	local folder = Instance.new("Folder")
	folder.Name = `Витрина {slot}`
	folder.Parent = kit.Root
	hideChildren(stand)
	local at = function(dy: number): CFrame
		return stand.CFrame * CFrame.new(0, top + dy, 0)
	end

	local accent = if size == "small" then CYAN elseif size == "large" then VIOLET else AMBER
	local accents: { Part } = {}
	local glow = Instance.new("PointLight")
	glow.Color = WARM
	glow.Range = 11
	glow.Brightness = 0

	if size == "small" then
		cylinder(folder, "Основание", at(0.06), 0.12, 3.0, STEEL)
		local ring = cylinder(folder, "Подсветка", at(0.14), 0.05, 2.74, accent, Enum.Material.Neon)
		table.insert(accents, ring)
		glow.Parent = ring
		cylinder(folder, "Диск", at(0.2), 0.12, 2.5, MARBLE, Enum.Material.Marble)
		local brass = rgb(255, 202, 84)
		cylinder(folder, "Кольцо колпака", at(0.28), 0.1, 2.85, brass)
		local case = cylinder(folder, "Колпак", at(1.65), 2.7, 2.75, GLASS, Enum.Material.Glass)
		case.Transparency = 0.86
		case.CanCollide = true
		cylinder(folder, "Крышка колпака", at(3.1), 0.2, 2.9, brass)
		cylinder(folder, "Шишка", at(3.35), 0.3, 0.5, brass)
		kit.Lift[slot] = 0.26
	elseif size == "large" then
		brick(folder, "Основание", at(0.07), Vector3.new(stand.Size.X - 0.3, 0.14, stand.Size.Z - 0.3), STEEL)
		brick(
			folder,
			"Платформа",
			at(0.17),
			Vector3.new(stand.Size.X - 0.7, 0.06, stand.Size.Z - 0.7),
			MARBLE,
			Enum.Material.Marble
		)
		local halfX, halfZ = (stand.Size.X - 0.7) / 2, (stand.Size.Z - 0.7) / 2
		for _, side in { -1, 1 } do
			table.insert(
				accents,
				brick(
					folder,
					"Рамка",
					at(0.21) * CFrame.new(side * halfX, 0, 0),
					Vector3.new(0.1, 0.05, halfZ * 2),
					accent,
					Enum.Material.Neon
				)
			)
			table.insert(
				accents,
				brick(
					folder,
					"Рамка",
					at(0.21) * CFrame.new(0, 0, side * halfZ),
					Vector3.new(halfX * 2, 0.05, 0.1),
					accent,
					Enum.Material.Neon
				)
			)
			for _, depth in { -1, 1 } do
				brick(
					folder,
					"Стойка",
					at(1.95) * CFrame.new(side * halfX, 0, depth * halfZ),
					Vector3.new(0.14, 3.8, 0.14),
					CHROME
				)
			end
		end
		glow.Parent = accents[1]
		local height = 3.8
		for _, side in { -1, 1 } do
			local wall = brick(
				folder,
				"Стекло",
				at(1.95) * CFrame.new(side * halfX, 0, 0),
				Vector3.new(0.05, height, halfZ * 2),
				GLASS,
				Enum.Material.Glass
			)
			wall.Transparency = 0.88
			wall.CanCollide = true
			local back = brick(
				folder,
				"Стекло",
				at(1.95) * CFrame.new(0, 0, side * halfZ),
				Vector3.new(halfX * 2, height, 0.05),
				GLASS,
				Enum.Material.Glass
			)
			back.Transparency = 0.88
			back.CanCollide = true
		end
		brick(folder, "Крыша", at(3.9), Vector3.new(halfX * 2 + 0.2, 0.1, halfZ * 2 + 0.2), STEEL)
		kit.Lift[slot] = 0.2
	else
		cylinder(folder, "Поворотный круг", at(0.1), 0.2, 6.0, STEEL)
		cylinder(folder, "Покрытие", at(0.22), 0.06, 5.5, MARBLE, Enum.Material.Marble)
		local ring = cylinder(folder, "Подсветка", at(0.19), 0.04, 5.8, accent, Enum.Material.Neon)
		table.insert(accents, ring)
		glow.Parent = ring
		for index = 0, 7 do
			local angle = index * math.pi / 4
			local mark = brick(
				folder,
				"Метка",
				at(0.26) * CFrame.new(math.cos(angle) * 2.5, 0, math.sin(angle) * 2.5) * CFrame.Angles(0, -angle, 0),
				Vector3.new(0.7, 0.03, 0.14),
				accent,
				Enum.Material.Neon
			)
			table.insert(accents, mark)
		end
		kit.Lift[slot] = 0.26
	end
	-- Контур основания светится цветом витрины.
	table.insert(
		accents,
		brick(
			folder,
			"Контур",
			stand.CFrame * CFrame.new(0, -top + 0.06, 0),
			Vector3.new(stand.Size.X + 0.1, 0.05, stand.Size.Z + 0.1),
			accent,
			Enum.Material.Neon
		)
	)
	kit.Yaw[slot] = if slot <= 6 then -90 else 180
	kit.Accents[slot] = accents
	kit.Lights[slot] = glow
end

Stand.buildStand = buildStand

return Stand
