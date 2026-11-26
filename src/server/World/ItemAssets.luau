--!strict
-- Загружает модели предметов из Creator Store (список в docs/ITEMS.md) и готовит их к использованию в игре.
-- Если модель не загрузилась или отключена, World использует встроенную процедурную модель предмета.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)

-- Самая длинная сторона предмета в студах после масштабирования.
local LONGEST: { [string]: number } = { small = 1.7, large = 3.4, car = 5.5 }
local ATTEMPTS = 3
local STAGGER = 0.15

local ASSETS: { [string]: number } = {
	ball = 11121205756,
	trash = 135210991489701,
	bell = 105506946654233,
	bowl = 119461172048939,
	painting = 5109258069,
	fish = 98987557964407,
	dumbbell = 75044615870183,
	brush = 18640720106,
	parcel = 73021519290782,
	elfhat = 68046627,
	flower = 10842648544,
	meteor = 87463219526197,
	bin = 17561363845,
	computer = 4555982143,
	tv = 12156451086,
	fan = 12301053735,
	trophy = 1331624495,
	rockart = 8778226356,
	radio = 13713791106,
	camera = 9239732180,
	gold = 133071893713929,
	dollars = 8835683505,
	gpu = 117729454919542,
	glasses = 133738255248048,
	boombox = 1879144575,
	button = 17257298757,
	console = 10624070448,
	phone = 11428924945,
	davinci = 13018552064,
	bomb = 5033685541,
}

local ItemAssets = {}
local templates: { [string]: Model } = {}

local function bounds(parts: { BasePart }): (Vector3, Vector3)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in parts do
		local half = part.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local corner = part.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z))
					low, high = low:Min(corner), high:Max(corner)
				end
			end
		end
	end
	return low, high
end

local function isUnsafe(object: Instance): boolean
	return object:IsA("LuaSourceContainer")
		or object:IsA("Sound")
		or object:IsA("JointInstance")
		or object:IsA("WeldConstraint")
		or object:IsA("Constraint")
		or object:IsA("BodyMover")
		or object:IsA("Humanoid")
		or object:IsA("ClickDetector")
		or object:IsA("ProximityPrompt")
end

-- Оставляет только визуальные детали: без скриптов, звуков, соединений и интерактива.
local function prepare(loaded: Instance, size: string): Model?
	for _, object in loaded:GetDescendants() do
		if isUnsafe(object) then
			object:Destroy()
		end
	end
	local result = Instance.new("Model")
	local parts: { BasePart } = {}
	for _, object in loaded:GetDescendants() do
		if object:IsA("BasePart") then
			object.Anchored = true
			object.CanCollide = false
			object.CanQuery = false
			object.CanTouch = false
			object.Massless = true
			object.Parent = result
			table.insert(parts, object)
		end
	end
	loaded:Destroy()
	if #parts == 0 then
		result:Destroy()
		return nil
	end

	local low, high = bounds(parts)
	local longest = math.max(high.X - low.X, high.Y - low.Y, high.Z - low.Z)
	if longest <= 0 or longest ~= longest then
		result:Destroy()
		return nil
	end
	result.WorldPivot = CFrame.new((low + high) / 2)
	result:ScaleTo(LONGEST[size] / longest)

	-- Ставим предмет основанием на ноль, по центру: так же, как встроенные модели.
	low, high = bounds(parts)
	local shift = Vector3.new(-(low.X + high.X) / 2, -low.Y, -(low.Z + high.Z) / 2)
	for _, part in parts do
		part.CFrame += shift
	end
	result.WorldPivot = CFrame.new()
	return result
end

local function load(kind: string, assetId: number): ()
	local definition = Catalog.Items[kind]
	for attempt = 1, ATTEMPTS do
		local ok, loaded = pcall(InsertService.LoadAsset, InsertService, assetId)
		if ok and loaded then
			local template = prepare(loaded, definition.Size)
			if template then
				template.Name = kind
				template.Parent = ServerStorage:FindFirstChild("ItemTemplates")
				templates[kind] = template
				return
			end
			break
		end
		task.wait(2 ^ attempt)
	end
	warn(`[ItemAssets] Failed to load the model «{definition.Name}» ({assetId}), using the built-in one`)
end

-- Запускает фоновую загрузку моделей из Creator Store. Выключено по умолчанию: игра использует встроенные
-- детализированные модели (Shared/ItemModels). Включить: атрибут Workspace.UseStoreModels = true.
function ItemAssets.preload(): ()
	if Workspace:GetAttribute("UseStoreModels") ~= true then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "ItemTemplates"
	folder.Parent = ServerStorage
	local delay = 0
	for kind, assetId in ASSETS do
		task.delay(delay, load, kind, assetId)
		delay += STAGGER
	end
end

function ItemAssets.clone(kind: string): Model?
	local template = templates[kind]
	return if template then template:Clone() else nil
end

return ItemAssets
