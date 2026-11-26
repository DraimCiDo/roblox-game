--!strict
-- Детализированный декор сектора игрока: витрины, ячейки склада, панели коллекций, указатели и табло.
-- Панели, экспонаты и ячейки привязаны к деталям сцены Roblox Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.World)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Collections = require(script.Collections)
local Common = require(script.Common)
local Stand = require(script.Stand)
local Storage = require(script.Storage)
type MakeMini = Common.MakeMini
type Signs = Common.Signs
type Kit = Common.Kit
local rgb = Common.rgb
local DEEP = Common.DEEP
local STEEL = Common.STEEL
local CYAN = Common.CYAN
local AMBER = Common.AMBER
local GREEN = Common.GREEN
local RED = Common.RED
local WARM = Common.WARM
local brick = Common.brick
local sign = Common.sign
local qualityColor = Common.qualityColor
local buildStand = Stand.buildStand
local buildCell = Storage.buildCell
local buildCollectionRack = Collections.buildCollectionRack

local Sector = {}

Sector.setCollections = Collections.setCollections

Sector.setStorage = Storage.setStorage

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
	local info = sign(signs.OrderScreen, Enum.NormalId.Front, "", WARM, 92, 55)
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
