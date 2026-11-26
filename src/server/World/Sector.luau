--!strict
-- Детализированный декор сектора игрока: витрины, ячейки склада, панели коллекций, указатели и табло.
-- Панели, экспонаты и ячейки привязаны к деталям сцены Roblox Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ItemModels = require(ReplicatedStorage.Shared.Models.ItemModels)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Types = require(ReplicatedStorage.Shared.Types)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.World)
local Format = require(ReplicatedStorage.Shared.Util.Format)

type MakeMini = (Types.Item, boolean?) -> Model

type Cell = {
	Module: Part,
	Center: Vector3,
	Size: Vector3,
	Frame: { Part },
	Shutter: { Part },
	Items: { Model },
	Signature: string,
}

type Panel = {
	Frame: CFrame,
	Models: { Model },
	Title: TextLabel,
	Lamp: Part,
	Signature: string,
}

export type Signs = {
	OrderScreen: Part,
	StorageDesk: Part,
	CollectionDesk: Part,
	CollectionScreen: Part,
	LootControl: Part,
}

export type Kit = {
	Frame: CFrame,
	Root: Folder,
	-- Высота, на которую выставленный предмет приподнят над верхом витрины.
	Lift: { [number]: number },
	-- Поворот предмета (градусы) относительно лицевой стороны витрины.
	Yaw: { [number]: number },
	Accents: { [number]: { Part } },
	Lights: { [number]: PointLight },
	Cells: { Cell },
	Panels: { Panel },
	Info: TextLabel,
	MakeMini: MakeMini,
	OrderLabel: TextLabel,
	LootLabel: TextLabel,
	LootLamp: Part,
	StorageLabel: TextLabel,
	StorageBar: Frame,
	CollectionLabel: TextLabel,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Палитра «Лаборатория CORPA» (общая тема интерфейса и мира).
local DEEP = Theme.Colors.Panel
local STEEL = rgb(46, 54, 66)
local CHROME = rgb(176, 188, 200)
local MARBLE = rgb(214, 220, 228)
local CYAN = Theme.Colors.Cyan
local AMBER = Theme.Colors.Amber
local VIOLET = rgb(170, 132, 255)
local GREEN = Theme.Colors.Signal
local RED = Theme.Colors.Warning
local WARM = Theme.Colors.Text
local GLASS = rgb(190, 230, 245)
local PANEL_COLORS = { VIOLET, CYAN, AMBER, GREEN }
local STORAGE_PER_CELL = 5

local Sector = {}

local function brick(
	parent: Instance,
	name: string,
	frame: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Size = size
	piece.CFrame = frame
	piece.Color = color
	piece.Material = material or Enum.Material.Metal
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function cylinder(
	parent: Instance,
	name: string,
	frame: CFrame,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	local piece = brick(
		parent,
		name,
		frame * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(height, diameter, diameter),
		color,
		material
	)
	piece.Shape = Enum.PartType.Cylinder
	return piece
end

local function sign(
	piece: Part,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	scale: number?,
	distance: number?
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = scale or 60
	gui.LightInfluence = 0
	gui.MaxDistance = distance or 32
	gui.Parent = piece
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.FontFace = Theme.Fonts.Display
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.065, 0)
	padding.PaddingRight = UDim.new(0.065, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	return label
end

local function qualityColor(quality: number): Color3
	if quality >= 100 then
		return AMBER
	elseif quality >= 71 then
		return VIOLET
	elseif quality >= 50 then
		return rgb(80, 194, 255)
	elseif quality >= 21 then
		return GREEN
	end
	return rgb(160, 165, 196)
end

-- ============ Витрины ============

local function hideChildren(stand: Part): ()
	for _, child in stand:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "Табличка экспоната" then
			child.Transparency = 1
			child.CanCollide = false
		end
	end
end

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
		cylinder(folder, "Кольцо колпака", at(0.28), 0.06, 2.7, CHROME)
		local dome = brick(folder, "Колпак", at(0.28 + 0.9), Vector3.one * 3.2, GLASS, Enum.Material.Glass)
		dome.Shape = Enum.PartType.Ball
		dome.Transparency = 0.82
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
			local back = brick(
				folder,
				"Стекло",
				at(1.95) * CFrame.new(0, 0, side * halfZ),
				Vector3.new(halfX * 2, height, 0.05),
				GLASS,
				Enum.Material.Glass
			)
			back.Transparency = 0.88
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
		Vector3.new(d - 0.3, 0.03, w - 0.4),
		WARM,
		Enum.Material.Neon
	)
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
				Enum.Material.Neon
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
				Enum.Material.Neon
			)
		)
	end
	local shutter: { Part } = {}
	local door = brick(
		folder,
		"Створка",
		place(Vector3.new(front + 0.02, 0, 0)),
		Vector3.new(0.04, h - 0.12, w - 0.12),
		DEEP,
		Enum.Material.Metal
	)
	door.Transparency = 0.12
	table.insert(shutter, door)
	table.insert(
		shutter,
		brick(folder, "Замок", place(Vector3.new(front - 0.04, 0, 0)), Vector3.new(0.1, 0.34, 0.28), AMBER)
	)
	table.insert(
		shutter,
		cylinder(
			folder,
			"Дужка замка",
			place(Vector3.new(front - 0.04, 0.22, 0)) * CFrame.Angles(math.pi / 2, 0, 0),
			0.1,
			0.22,
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

local function clearItems(models: { Model }): ()
	for _, model in models do
		model:Destroy()
	end
	table.clear(models)
end

-- Масштабирует мини-модель так, чтобы она поместилась в габарит.
local function fit(model: Model, width: number, height: number): ()
	local extents = model:GetExtentsSize()
	local scale = math.min(width / math.max(extents.X, extents.Z, 0.01), height / math.max(extents.Y, 0.01), 1)
	model:ScaleTo(scale)
end

function Sector.setStorage(kit: Kit, capacity: number, inventory: { Types.Item }): ()
	for index, cell in kit.Cells do
		local built = index <= capacity / STORAGE_PER_CELL
		for _, piece in cell.Frame do
			piece.Color = if built then CYAN else RED
			piece.Transparency = if built then 0 else 0.35
		end
		for _, piece in cell.Shutter do
			piece.Transparency = if built then 1 else (if piece.Name == "Створка" then 0.12 else 0)
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
				fit(mini, 0.42, size.Y - 0.22)
				local z = (slot - 3) * (size.Z - 0.3) / STORAGE_PER_CELL
				mini:PivotTo(
					cell.Module.CFrame
						* CFrame.new(cell.Center + Vector3.new(0.05, -size.Y / 2 + 0.07, z))
						* CFrame.Angles(0, math.rad(90), 0)
				)
				table.insert(cell.Items, mini)
			end
		end
	end
end

-- ============ Коллекции ============

local PANEL_WIDTH = 3.45
local PANEL_HEIGHT = 3.12
local PANEL_GAP = 0.16

local function ghost(model: Model): ()
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") then
			object.Color = rgb(34, 42, 56)
			object.Material = Enum.Material.SmoothPlastic
			object.Transparency = 0.15
		elseif object:IsA("SurfaceGui") or object:IsA("Light") then
			object:Destroy()
		end
	end
end

local function buildPanel(
	parent: Instance,
	frame: CFrame,
	index: number,
	collection: { Name: string, Items: { string } }
): Panel
	local color = PANEL_COLORS[(index - 1) % #PANEL_COLORS + 1]
	local folder = Instance.new("Folder")
	folder.Name = `Коллекция {collection.Name}`
	folder.Parent = parent
	local function place(offset: Vector3): CFrame
		return frame * CFrame.new(offset)
	end
	brick(folder, "Корпус", frame, Vector3.new(PANEL_WIDTH, PANEL_HEIGHT, 0.28), DEEP)
	local glass = brick(
		folder,
		"Стекло",
		place(Vector3.new(0, -0.10, -0.61)),
		Vector3.new(PANEL_WIDTH - 0.16, PANEL_HEIGHT - 0.91, 0.04),
		GLASS,
		Enum.Material.Glass
	)
	glass.Transparency = 0.91
	for _, side in { -1, 1 } do
		brick(
			folder,
			"Боковина",
			place(Vector3.new(side * (PANEL_WIDTH / 2 - 0.05), -0.1, -0.27)),
			Vector3.new(0.1, PANEL_HEIGHT - 0.6, 0.68),
			STEEL
		)
	end
	local title = brick(
		folder,
		"Заголовок",
		place(Vector3.new(0, PANEL_HEIGHT / 2 - 0.31, -0.21)),
		Vector3.new(PANEL_WIDTH - 0.21, 0.51, 0.11),
		STEEL
	)
	local label = sign(title, Enum.NormalId.Front, collection.Name, WARM, 88, 27)
	local lamp = brick(
		folder,
		"Полоса состояния",
		place(Vector3.new(0, PANEL_HEIGHT / 2 - 0.61, -0.275)),
		Vector3.new(PANEL_WIDTH - 0.38, 0.05, 0.05),
		color,
		Enum.Material.SmoothPlastic
	)
	for row = 0, 1 do
		local y = PANEL_HEIGHT / 2 - 1.66 - row * 1.01
		brick(
			folder,
			"Полка",
			place(Vector3.new(0, y - 0.04, -0.28)),
			Vector3.new(PANEL_WIDTH - 0.25, 0.09, 0.7),
			STEEL
		)
	end
	return { Frame = frame, Models = {}, Title = label, Lamp = lamp, Signature = "" }
end

local function buildCollectionRack(kit: Kit, counter: Part): ()
	local frame = counter.CFrame * CFrame.new(0, 3.93, 3.03)
	local count = #Catalog.Collections
	local width = count * PANEL_WIDTH + (count - 1) * PANEL_GAP + 0.46
	brick(
		kit.Root,
		"Задняя рама коллекций",
		frame * CFrame.new(0, 0, 0.18),
		Vector3.new(width, 3.39, 0.26),
		STEEL
	)
	local heading = brick(
		kit.Root,
		"Шапка стойки коллекций",
		frame * CFrame.new(0, 1.94, -0.29),
		Vector3.new(width, 0.74, 0.58),
		DEEP
	)
	sign(heading, Enum.NormalId.Front, Texts.collectionsHeading, WARM, 78, 34)
	for _, side in { -1, 1 } do
		local x = side * (width / 2 - 0.21)
		local height = frame.Position.Y - 1.58
		brick(
			kit.Root,
			"Несущая стойка коллекций",
			frame * CFrame.new(x, -frame.Position.Y + height / 2, 0.22),
			Vector3.new(0.30, height, 0.45),
			STEEL
		)
		brick(
			kit.Root,
			"Опора коллекций",
			frame * CFrame.new(x, -frame.Position.Y + 0.07, 0.22),
			Vector3.new(0.75, 0.14, 0.83),
			DEEP
		)
	end
	for index, collection in Catalog.Collections do
		local x = (index - (count + 1) / 2) * (PANEL_WIDTH + PANEL_GAP)
		table.insert(kit.Panels, buildPanel(kit.Root, frame * CFrame.new(x, 0, 0), index, collection))
	end
end

function Sector.setCollections(kit: Kit, collections: { [string]: Types.Item }): ()
	local everything, everyOwned = 0, 0
	for index, panel in kit.Panels do
		local collection = Catalog.Collections[index]
		local ids: { string } = {}
		local owned, total = 0, 0
		for _, kind in collection.Items do
			local saved = collections[kind]
			table.insert(ids, if saved then `{kind}:{saved.Id}` else kind)
			if saved then
				owned += 1
				total += saved.Quality
			end
		end
		local complete = owned == #collection.Items
		everything += #collection.Items
		everyOwned += owned
		panel.Lamp.Color = if complete then GREEN elseif owned > 0 then AMBER else STEEL
		local suffix = if complete
			then string.format("  +%.1f%%", total / owned / 10)
			else `  {owned}/{#collection.Items}`
		panel.Title.Text = collection.Name .. suffix
		local signature = table.concat(ids, ",")
		if signature ~= panel.Signature then
			panel.Signature = signature
			clearItems(panel.Models)
			for slot, kind in collection.Items do
				local saved = collections[kind]
				local mini: Model
				if saved then
					mini = kit.MakeMini(saved, false)
				else
					mini = Instance.new("Model")
					ItemModels.build(kind, mini, { Full = false })
					ghost(mini)
				end
				mini.Parent = kit.Root
				fit(mini, 0.78, 0.77)
				local column = (slot - 1) % 2
				local row = (slot - 1) // 2
				local y = PANEL_HEIGHT / 2 - 1.66 - row * 1.01
				local frame = panel.Frame * CFrame.new((column - 0.5) * 1.58, y, -0.27)
				mini:PivotTo(frame)
				table.insert(panel.Models, mini)
			end
		end
	end
	kit.CollectionLabel.Text = Format(Texts.collectedCount, { owned = everyOwned, total = everything })
end

-- ============ Табло и индикация ============

function Sector.setInfo(kit: Kit, level: number, price: number, orders: number, maximum: number): ()
	kit.Info.Text = Format(Texts.orderInfo, { level = level, price = price, orders = orders, maximum = maximum })
end

function Sector.setDisplay(kit: Kit, slot: number, item: Types.Item?): ()
	local accents = kit.Accents[slot]
	local light = kit.Lights[slot]
	if not accents or not light then
		return
	end
	local color = if item then qualityColor(item.Quality) else CYAN
	for _, piece in accents do
		piece.Color = color
	end
	light.Color = if item then color:Lerp(WARM, 0.5) else WARM
	light.Brightness = if item then 0.75 else 0
end

function Sector.setOrder(kit: Kit, state: string?): ()
	kit.OrderLabel.Text = if state == "?"
		then Texts.stateDelivery
		elseif state then Catalog.Containers[state] or ""
		else Texts.stateNoOrder
end

local STAGE_LABELS: { [string]: string } = {
	queued = Texts.stageQueued,
	delivery = Texts.stageDelivery,
	sealed = Texts.stageSealed,
	open = Texts.stageOpen,
	clear = Texts.stageClear,
}

function Sector.setLoot(kit: Kit, stage: string?, remaining: number): ()
	local text = if stage then STAGE_LABELS[stage] or "" else Texts.padFree
	if stage == "open" then
		text ..= Format(Texts.lootLeft, { remaining = remaining })
	end
	kit.LootLabel.Text = text
	kit.LootLamp.Color = if stage == "open"
		then GREEN
		elseif stage == "clear" then AMBER
		elseif stage then CYAN
		else rgb(90, 100, 118)
end

function Sector.setStorageInfo(kit: Kit, count: number, capacity: number): ()
	kit.StorageLabel.Text = Format(Texts.storageCount, { count = count, capacity = capacity })
	local ratio = math.clamp(count / math.max(capacity, 1), 0, 1)
	kit.StorageBar.Size = UDim2.fromScale(ratio, 1)
	kit.StorageBar.BackgroundColor3 = if ratio >= 1 then RED elseif ratio >= 0.8 then AMBER else CYAN
end

local function mountedScreen(root: Folder, anchor: Part, name: string, offset: Vector3, size: Vector3): Part
	local frame = anchor.CFrame * CFrame.new(offset)
	local screen = brick(root, name, frame, size, DEEP)
	local top = anchor.Size.Y / 2
	local height = offset.Y - size.Y / 2 - top
	brick(
		root,
		"Крепление монитора",
		anchor.CFrame * CFrame.new(offset.X, top + height / 2, offset.Z + 0.07),
		Vector3.new(0.32, height + 0.08, 0.24),
		STEEL
	)
	brick(
		root,
		"Пятка крепления",
		anchor.CFrame * CFrame.new(offset.X, top + 0.14, offset.Z + 0.03),
		Vector3.new(0.94, 0.20, 0.48),
		DEEP
	)
	return screen
end

function Sector.build(
	model: Model,
	spawn: SpawnLocation,
	stands: { [number]: Part },
	storage: { Part },
	signs: Signs,
	makeMini: MakeMini
): Kit
	local root = Instance.new("Folder")
	root.Name = "Декор сектора"
	root.Parent = model
	local info = sign(signs.OrderScreen, Enum.NormalId.Front, "", WARM, 92, 19)
	signs.OrderScreen.Material = Enum.Material.SmoothPlastic
	signs.OrderScreen.Transparency = 0
	signs.OrderScreen.Color = DEEP
	info.Size = UDim2.fromScale(1, 0.69)
	local orderLabel = info:Clone()
	orderLabel.TextColor3 = rgb(145, 209, 202)
	orderLabel.Position = UDim2.fromScale(0, 0.69)
	orderLabel.Size = UDim2.fromScale(1, 0.31)
	orderLabel.Parent = info.Parent

	local storageMonitor = mountedScreen(
		root,
		signs.StorageDesk,
		"Экран склада",
		Vector3.new(1.34, signs.StorageDesk.Size.Y / 2 + 1.14, 0.81),
		Vector3.new(2.56, 1.16, 0.26)
	)
	local storageLabel = sign(storageMonitor, Enum.NormalId.Front, "", WARM, 85, 20)
	storageLabel.Size = UDim2.fromScale(1, 0.73)
	local track = Instance.new("Frame")
	track.BackgroundColor3 = STEEL
	track.BorderSizePixel = 0
	track.Position = UDim2.fromScale(0.13, 0.77)
	track.Size = UDim2.fromScale(0.74, 0.1)
	track.Parent = storageLabel.Parent
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.Parent = track

	signs.CollectionScreen.Material = Enum.Material.SmoothPlastic
	signs.CollectionScreen.Transparency = 0
	signs.CollectionScreen.Color = DEEP
	local collectionLabel = sign(signs.CollectionScreen, Enum.NormalId.Front, "", WARM, 89, 16)

	local lootMonitor = mountedScreen(
		root,
		signs.LootControl,
		"Экран добычи",
		Vector3.new(0, signs.LootControl.Size.Y / 2 + 0.53, -0.12),
		Vector3.new(2.3, 0.78, 0.24)
	)
	local lootLabel = sign(lootMonitor, Enum.NormalId.Front, "", WARM, 86, 20)
	local lootLamp = brick(
		root,
		"Сигнал экрана добычи",
		lootMonitor.CFrame * CFrame.new(0, 0.4, -0.09),
		Vector3.new(1.9, 0.07, 0.13),
		STEEL
	)
	local kit: Kit = {
		Frame = spawn.CFrame,
		Root = root,
		Lift = {},
		Yaw = {},
		Accents = {},
		Lights = {},
		Cells = {},
		Panels = {},
		Info = info,
		MakeMini = makeMini,
		OrderLabel = orderLabel,
		LootLabel = lootLabel,
		LootLamp = lootLamp,
		StorageLabel = storageLabel,
		StorageBar = fill,
		CollectionLabel = collectionLabel,
	}
	for slot, stand in stands do
		buildStand(kit, slot, stand)
	end
	for _, module in storage do
		table.insert(kit.Cells, buildCell(kit, module))
	end
	buildCollectionRack(kit, signs.CollectionDesk)

	Sector.setStorage(kit, 15, {})
	Sector.setCollections(kit, {})
	Sector.setStorageInfo(kit, 0, 15)
	Sector.setLoot(kit, nil, 0)
	Sector.setOrder(kit, nil)
	return kit
end

return Sector
