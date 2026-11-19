--!strict
-- Детализированный декор сектора игрока: витрины, ячейки склада, панели коллекций, указатели и табло.
-- Всё строится в локальных координатах сектора (система координат спавна), поэтому одинаково работает
-- во всех шести секторах. Сцена из Studio остаётся основой; здесь только наполнение.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local ItemModels = require(ReplicatedStorage.Shared.ItemModels)
local Types = require(ReplicatedStorage.Shared.Types)

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
	Center: Vector3,
	Models: { Model },
	Title: TextLabel,
	Lamp: Part,
	Signature: string,
}

export type Kit = {
	Frame: CFrame,
	Root: Folder,
	-- Высота, на которую выставленный предмет приподнят над верхом витрины.
	Lift: { [number]: number },
	-- Поворот предмета на витрине (градусы), чтобы лицевая сторона смотрела на посетителей.
	Yaw: { [number]: number },
	Accents: { [number]: { Part } },
	Lights: { [number]: PointLight },
	Cells: { Cell },
	Panels: { Panel },
	Info: TextLabel,
	MakeMini: MakeMini,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local DEEP = rgb(20, 26, 36)
local STEEL = rgb(52, 62, 76)
local CHROME = rgb(196, 204, 214)
local MARBLE = rgb(232, 234, 238)
local CYAN = rgb(91, 232, 222)
local AMBER = rgb(255, 181, 86)
local VIOLET = rgb(178, 120, 255)
local GREEN = rgb(80, 235, 130)
local RED = rgb(255, 80, 90)
local WARM = rgb(255, 232, 190)
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

local function sign(piece: Part, face: Enum.NormalId, text: string, color: Color3, scale: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = scale or 60
	gui.LightInfluence = 0
	gui.Parent = piece
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
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
	local F = kit.Frame
	local local_ = F:PointToObjectSpace(stand.Position)
	local top = local_.Y + stand.Size.Y / 2
	local size = Catalog.DisplaySizes[slot]
	local folder = Instance.new("Folder")
	folder.Name = `Витрина {slot}`
	folder.Parent = kit.Root
	hideChildren(stand)
	local at = function(dy: number): CFrame
		return F * CFrame.new(local_.X, top + dy, local_.Z)
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
			F * CFrame.new(local_.X, local_.Y - stand.Size.Y / 2 + 0.06, local_.Z),
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

local function buildCell(kit: Kit, module: Part): Cell
	local F = kit.Frame
	local center = F:PointToObjectSpace(module.Position)
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
					kit.Frame
						* CFrame.new(cell.Center + Vector3.new(0.05, -size.Y / 2 + 0.07, z))
						* CFrame.Angles(0, math.rad(90), 0)
				)
				table.insert(cell.Items, mini)
			end
		end
	end
end

-- ============ Коллекции ============

local PANEL_WIDTH = 3.6
local PANEL_HEIGHT = 3.4
local PANEL_Y = 5.0
local PANEL_Z = -44.2

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

local function buildPanel(kit: Kit, index: number, collection: { Name: string, Items: { string } }): Panel
	local F = kit.Frame
	local count = #Catalog.Collections
	local x = (index - (count + 1) / 2) * (PANEL_WIDTH + 0.4) - 6.6
	local center = Vector3.new(x, PANEL_Y, PANEL_Z)
	local color = PANEL_COLORS[(index - 1) % #PANEL_COLORS + 1]
	local folder = Instance.new("Folder")
	folder.Name = `Коллекция {collection.Name}`
	folder.Parent = kit.Root
	local function place(offset: Vector3): CFrame
		return F * CFrame.new(center + offset)
	end
	brick(folder, "Основа", place(Vector3.zero), Vector3.new(PANEL_WIDTH, PANEL_HEIGHT, 0.3), DEEP)
	local glass = brick(
		folder,
		"Стекло",
		place(Vector3.new(0, 0, 0.2)),
		Vector3.new(PANEL_WIDTH, PANEL_HEIGHT, 0.04),
		GLASS,
		Enum.Material.Glass
	)
	glass.Transparency = 0.9
	for _, side in { -1, 1 } do
		brick(
			folder,
			"Кромка",
			place(Vector3.new(side * (PANEL_WIDTH / 2 - 0.04), 0, 0.18)),
			Vector3.new(0.08, PANEL_HEIGHT, 0.08),
			color,
			Enum.Material.Neon
		)
		brick(
			folder,
			"Кромка",
			place(Vector3.new(0, side * (PANEL_HEIGHT / 2 - 0.04), 0.18)),
			Vector3.new(PANEL_WIDTH, 0.08, 0.08),
			color,
			Enum.Material.Neon
		)
	end
	local title = brick(
		folder,
		"Заголовок",
		place(Vector3.new(0, PANEL_HEIGHT / 2 - 0.4, 0.17)),
		Vector3.new(PANEL_WIDTH - 0.3, 0.55, 0.06),
		STEEL
	)
	local label = sign(title, Enum.NormalId.Back, collection.Name, WARM, 80)
	local lamp = brick(
		folder,
		"Индикатор",
		place(Vector3.new(PANEL_WIDTH / 2 - 0.3, PANEL_HEIGHT / 2 - 0.4, 0.22)),
		Vector3.new(0.18, 0.18, 0.06),
		RED,
		Enum.Material.Neon
	)
	for row = 0, 1 do
		local y = PANEL_HEIGHT / 2 - 1.55 - row * 1.25
		brick(
			folder,
			"Полка",
			place(Vector3.new(0, y - 0.03, 0.05)),
			Vector3.new(PANEL_WIDTH - 0.5, 0.06, 0.4),
			STEEL
		)
		brick(
			folder,
			"Подсветка полки",
			place(Vector3.new(0, y - 0.01, 0.24)),
			Vector3.new(PANEL_WIDTH - 0.5, 0.025, 0.03),
			color,
			Enum.Material.Neon
		)
	end
	return { Center = center, Models = {}, Title = label, Lamp = lamp, Signature = "" }
end

function Sector.setCollections(kit: Kit, collections: { [string]: Types.Item }): ()
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
		panel.Lamp.Color = if complete then GREEN elseif owned > 0 then AMBER else RED
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
				fit(mini, 1.0, 0.95)
				local column = (slot - 1) % 2
				local row = (slot - 1) // 2
				local y = PANEL_HEIGHT / 2 - 1.55 - row * 1.25
				local frame = kit.Frame
					* CFrame.new(panel.Center + Vector3.new((column - 0.5) * 1.6, y, 0.05))
					* CFrame.Angles(0, math.rad(180), 0)
				mini:PivotTo(frame)
				table.insert(panel.Models, mini)
			end
		end
	end
end

-- ============ Указатели, кольцо зоны добычи, табло ============

local function standSign(kit: Kit, text: string, color: Color3, position: Vector3, yaw: number, width: number): ()
	local F = kit.Frame
	local frame = F * CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0)
	local folder = Instance.new("Folder")
	folder.Name = `Указатель {text}`
	folder.Parent = kit.Root
	local board = brick(folder, "Табличка", frame, Vector3.new(width, 1.3, 0.16), DEEP)
	local label = sign(board, Enum.NormalId.Front, text, color, 70)
	label.Name = "Надпись"
	brick(
		folder,
		"Кромка",
		frame * CFrame.new(0, 0.62, -0.02),
		Vector3.new(width, 0.07, 0.2),
		color,
		Enum.Material.Neon
	)
	brick(
		folder,
		"Кромка",
		frame * CFrame.new(0, -0.62, -0.02),
		Vector3.new(width, 0.07, 0.2),
		color,
		Enum.Material.Neon
	)
	for _, side in { -1, 1 } do
		local height = position.Y - 0.2
		brick(
			folder,
			"Опора",
			F
				* CFrame.new(position.X, height / 2, position.Z)
				* CFrame.Angles(0, math.rad(yaw), 0)
				* CFrame.new(side * (width / 2 - 0.2), 0, 0),
			Vector3.new(0.18, height, 0.18),
			STEEL
		)
	end
end

local function buildPadRing(kit: Kit): ()
	local folder = Instance.new("Folder")
	folder.Name = "Зона открытия"
	folder.Parent = kit.Root
	local center = Vector3.new(-6, 0.4, -17)
	for index = 0, 47 do
		local angle = index * math.pi * 2 / 48
		local frame = kit.Frame
			* CFrame.new(center + Vector3.new(math.cos(angle) * 7.6, 0, math.sin(angle) * 7.6))
			* CFrame.Angles(0, -angle + math.pi / 2, 0)
		brick(
			folder,
			"Дуга",
			frame,
			Vector3.new(1.0, 0.04, 0.16),
			if index % 2 == 0 then AMBER else CYAN,
			Enum.Material.Neon
		)
	end
end

function Sector.setInfo(kit: Kit, level: number, price: number, orders: number, maximum: number): ()
	kit.Info.Text = `УР. {level}  ·  ЗАКАЗ {price}\nОЧЕРЕДЬ {orders}/{maximum}`
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
	light.Brightness = if item then 1.4 else 0
end

function Sector.build(
	model: Model,
	spawn: SpawnLocation,
	stands: { [number]: Part },
	storage: { Part },
	makeMini: MakeMini
): Kit
	local root = Instance.new("Folder")
	root.Name = "Декор сектора"
	root.Parent = model
	local kit: Kit = {
		Frame = spawn.CFrame,
		Root = root,
		Lift = {},
		Yaw = {},
		Accents = {},
		Lights = {},
		Cells = {},
		Panels = {},
		Info = Instance.new("TextLabel"),
		MakeMini = makeMini,
	}
	for slot, stand in stands do
		buildStand(kit, slot, stand)
	end
	for _, module in storage do
		table.insert(kit.Cells, buildCell(kit, module))
	end
	for index, collection in Catalog.Collections do
		table.insert(kit.Panels, buildPanel(kit, index, collection))
	end

	standSign(kit, "ВИТРИНЫ", CYAN, Vector3.new(-19.2, 7.2, -21), -90, 6)
	standSign(kit, "СКЛАД", AMBER, Vector3.new(13.4, 9.2, -18.6), 90, 4.6)
	standSign(kit, "ДОБЫЧА", GREEN, Vector3.new(3.2, 4.6, -12.6), 90, 4.2)
	standSign(kit, "КОЛЛЕКЦИИ", VIOLET, Vector3.new(-6.6, 8.6, -43.6), 180, 8)
	buildPadRing(kit)

	-- Табло над терминалом заказов: уровень лаборатории, цена и очередь.
	local board = brick(
		root,
		"Табло заказов",
		kit.Frame * CFrame.new(10.4, 4.3, -3.5) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(4.4, 1.2, 0.14),
		DEEP
	)
	kit.Info = sign(board, Enum.NormalId.Front, "", CYAN, 70)
	brick(
		root,
		"Кромка табло",
		board.CFrame * CFrame.new(0, 0.6, -0.02),
		Vector3.new(4.4, 0.06, 0.18),
		CYAN,
		Enum.Material.Neon
	)
	for _, side in { -1, 1 } do
		brick(
			root,
			"Опора табло",
			kit.Frame * CFrame.new(10.4, 2.15, -3.5 + side * 2.0),
			Vector3.new(0.16, 4.3, 0.16),
			STEEL
		)
	end

	Sector.setStorage(kit, 15, {})
	Sector.setCollections(kit, {})
	return kit
end

return Sector
