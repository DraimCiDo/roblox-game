--!strict
-- Storage shelves with miniatures of stored finds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Common = require(script.Parent.Common)
type Cell = Common.Cell
type Kit = Common.Kit
local DEEP = Common.DEEP
local STEEL = Common.STEEL
local CHROME = Common.CHROME
local CYAN = Common.CYAN
local AMBER = Common.AMBER
local RED = Common.RED
local WARM = Common.WARM
local brick = Common.brick
local cylinder = Common.cylinder
local clearItems = Common.clearItems

local Storage = {}

local STORAGE_PER_CELL = 5
-- Place of each find in a locker: share of the width from the middle and the level (0 floor, 1 shelf).
local SLOTS = {
	{ -0.32, 0 },
	{ 0, 0 },
	{ 0.32, 0 },
	{ -0.18, 1 },
	{ 0.18, 1 },
}

-- ============ Склад ============

-- Ячейка строится в осях самого модуля: +X — задняя стенка (в глубину стеллажа), −X — лицевая сторона.
local function buildCell(kit: Kit, module: Part): Cell
	local F = module.CFrame
	local center = Vector3.zero
	local size = module.Size
	local folder = Instance.new("Folder")
	folder.Name = "Ячейка склада"
	folder.Parent = kit.Root
	local function place(offset: Vector3): CFrame
		return F * CFrame.new(center + offset)
	end
	local d, h, w = size.X, size.Y, size.Z
	brick(folder, "Задняя стенка", place(Vector3.new(d / 2 - 0.03, 0, 0)), Vector3.new(0.06, h, w), DEEP)
	brick(folder, "Пол", place(Vector3.new(0, -h / 2 + 0.03, 0)), Vector3.new(d, 0.06, w), STEEL)
	brick(folder, "Потолок", place(Vector3.new(0, h / 2 - 0.03, 0)), Vector3.new(d, 0.06, w), STEEL)
	for _, side in { -1, 1 } do
		brick(
			folder,
			"Боковина",
			place(Vector3.new(0, 0, side * (w / 2 - 0.03))),
			Vector3.new(d, h, 0.06),
			STEEL
		)
	end
	brick(
		folder,
		"Подсветка полки",
		place(Vector3.new(0, h / 2 - 0.1, 0)),
		Vector3.new(d * 0.3, 0.04, w * 0.6),
		WARM,
		Enum.Material.SmoothPlastic
	)
	-- Two levels: three finds below, two on the glass shelf.
	local glass = brick(
		folder,
		"Полка",
		place(Vector3.new(0.1, 0.02, 0)),
		Vector3.new(d - 0.35, 0.08, w - 0.12),
		CHROME,
		Enum.Material.Glass
	)
	glass.Transparency = 0.4
	local frame: { Part } = {}
	local front = -d / 2 + 0.03
	for _, side in { -1, 1 } do
		table.insert(
			frame,
			brick(
				folder,
				"Рамка",
				place(Vector3.new(front, side * (h / 2 - 0.04), 0)),
				Vector3.new(0.06, 0.08, w),
				CYAN,
				Enum.Material.SmoothPlastic
			)
		)
		table.insert(
			frame,
			brick(
				folder,
				"Рамка",
				place(Vector3.new(front, 0, side * (w / 2 - 0.04))),
				Vector3.new(0.06, h, 0.08),
				CYAN,
				Enum.Material.SmoothPlastic
			)
		)
	end
	local shutter: { Part } = {}
	local door = brick(
		folder,
		"Створка",
		place(Vector3.new(front + 0.02, 0, 0)),
		Vector3.new(0.04, h - 0.12, w - 0.12),
		STEEL,
		Enum.Material.DiamondPlate
	)
	door.Transparency = 0
	table.insert(shutter, door)
	table.insert(
		shutter,
		brick(folder, "Замок", place(Vector3.new(front - 0.04, 0, 0)), Vector3.new(0.14, 0.7, 0.6), AMBER)
	)
	table.insert(
		shutter,
		cylinder(
			folder,
			"Дужка замка",
			place(Vector3.new(front - 0.04, 0.45, 0)) * CFrame.Angles(math.pi / 2, 0, 0),
			0.14,
			0.45,
			CHROME
		)
	)
	return {
		Module = module,
		Center = center,
		Size = size,
		Frame = frame,
		Shutter = shutter,
		Items = {},
		Signature = "",
	}
end

function Storage.setStorage(kit: Kit, capacity: number, inventory: { Types.Item }): ()
	for index, cell in kit.Cells do
		local built = index <= capacity / STORAGE_PER_CELL
		for _, piece in cell.Frame do
			piece.Color = if built then CYAN else RED
			piece.Transparency = if built then 0 else 0.35
		end
		for _, piece in cell.Shutter do
			piece.Transparency = if built then 1 else 0
		end
		cell.Module.Transparency = 1
		cell.Module.CanCollide = built

		local ids: { string } = {}
		if built then
			for slot = 1, STORAGE_PER_CELL do
				local item = inventory[(index - 1) * STORAGE_PER_CELL + slot]
				if item then
					table.insert(ids, item.Id)
				end
			end
		end
		local signature = table.concat(ids, ",")
		if signature ~= cell.Signature then
			cell.Signature = signature
			clearItems(cell.Items)
			local size = cell.Size
			for slot = 1, #ids do
				local item = inventory[(index - 1) * STORAGE_PER_CELL + slot]
				local mini = kit.MakeMini(item, false)
				mini.Parent = kit.Root
				-- Minis are tiny: grow them to fill their place.
				local extents = mini:GetExtentsSize()
				local width, height = size.Z * 0.27, size.Y / 2 - 0.3
				local scale = math.min(width / math.max(extents.X, extents.Z, 0.01), height / math.max(extents.Y, 0.01))
				mini:ScaleTo(mini:GetScale() * scale)
				local z, level = SLOTS[slot][1] * size.Z, SLOTS[slot][2]
				local floor = if level == 0 then -size.Y / 2 + 0.07 else 0.07
				mini:PivotTo(
					cell.Module.CFrame
						* CFrame.new(cell.Center + Vector3.new(0.05, floor, z))
						* CFrame.Angles(0, math.rad(90), 0)
				)
				table.insert(cell.Items, mini)
			end
		end
	end
end

Storage.buildCell = buildCell

return Storage
