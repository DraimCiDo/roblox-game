--!strict
-- Collection hall: one museum cabinet per collection, behind the counter.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ItemModels = require(ReplicatedStorage.Shared.Models.ItemModels)
local Types = require(ReplicatedStorage.Shared.Types)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.World)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Common = require(script.Parent.Common)
type Panel = Common.Panel
type Kit = Common.Kit
local rgb = Common.rgb
local DEEP = Common.DEEP
local CYAN = Common.CYAN
local AMBER = Common.AMBER
local VIOLET = Common.VIOLET
local GREEN = Common.GREEN
local WARM = Common.WARM
local GLASS = Common.GLASS
local brick = Common.brick
local sign = Common.sign
local clearItems = Common.clearItems

local Collections = {}

local PANEL_COLORS = { VIOLET, CYAN, AMBER, GREEN }

-- ============ Коллекции ============

local WIDTH = 4.9
local GAP = 0.45
local HEIGHT = 8.2
-- Tops of the two shelves a cabinet shows its finds on, above the floor.
local SHELVES = { 4.45, 1.35 }
local ITEM_WIDTH = 1.9
local ITEM_HEIGHT = 2.1

local WOOD = rgb(150, 96, 58)
local DARK_WOOD = rgb(104, 66, 44)
local BRASS = rgb(255, 202, 84)

-- Panes are SmoothPlastic: see-through finds are not drawn behind the Glass material.
local function ghost(model: Model): ()
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") then
			object.Color = rgb(130, 142, 205)
			object.Material = Enum.Material.SmoothPlastic
			object.Transparency = 0.25
		elseif object:IsA("SurfaceGui") or object:IsA("Light") then
			object:Destroy()
		end
	end
end

-- `frame` is on the floor under the middle of the cabinet, its front looks along -Z.
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
	local function box(
		name: string,
		x: number,
		y: number,
		z: number,
		size: Vector3,
		tint: Color3,
		material: Enum.Material
	): Part
		return brick(folder, name, frame * CFrame.new(x, y, z), size, tint, material)
	end
	local wood, metal = Enum.Material.WoodPlanks, Enum.Material.Metal
	-- One invisible box keeps players out of the whole cabinet.
	local solid = box("Преграда", 0, HEIGHT / 2, 0, Vector3.new(WIDTH + 0.2, HEIGHT, 1.95), WOOD, wood)
	solid.Transparency = 1
	solid.CanCollide = true
	box("Цоколь", 0, 0.62, 0, Vector3.new(WIDTH, 1.24, 1.9), DARK_WOOD, wood).CanCollide = true
	box("Кант цоколя", 0, 1.29, 0, Vector3.new(WIDTH + 0.1, 0.1, 2), BRASS, metal)
	for _, x in { -1.1, 1.1 } do
		box("Ящик", x, 0.62, -0.98, Vector3.new(1.9, 0.8, 0.08), WOOD, wood)
		box("Ручка", x, 0.62, -1.05, Vector3.new(0.5, 0.12, 0.08), BRASS, metal)
	end
	-- Velvet back in the colour of the collection.
	local velvet = color:Lerp(rgb(24, 20, 60), 0.6)
	box("Задник", 0, 4.3, 0.75, Vector3.new(WIDTH - 0.3, 5.9, 0.2), velvet, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		box("Боковина", side * (WIDTH / 2 - 0.15), 4.3, 0, Vector3.new(0.3, 5.9, 1.7), WOOD, wood)
		box("Кант", side * (WIDTH / 2 - 0.15), 4.3, -0.89, Vector3.new(0.14, 5.9, 0.08), BRASS, metal)
	end
	box("Карниз", 0, 7.55, 0, Vector3.new(WIDTH + 0.2, 0.6, 2), DARK_WOOD, wood)
	box("Кант карниза", 0, 7.22, -0.95, Vector3.new(WIDTH + 0.2, 0.1, 0.12), BRASS, metal)
	local title = box("Заголовок", 0, HEIGHT + 0.25, -0.7, Vector3.new(WIDTH - 0.1, 0.8, 0.2), DEEP, metal)
	local label = sign(title, Enum.NormalId.Front, collection.Name, WARM, 70, 40)
	local lamp =
		box("Полоса состояния", 0, 7.12, -0.75, Vector3.new(WIDTH - 0.8, 0.1, 0.2), color, metal)
	local shelf = box(
		"Полка",
		0,
		SHELVES[1] - 0.06,
		0,
		Vector3.new(WIDTH - 0.5, 0.12, 1.5),
		GLASS,
		Enum.Material.SmoothPlastic
	)
	shelf.Transparency = 0.5
	box("Кант полки", 0, SHELVES[1] - 0.06, -0.78, Vector3.new(WIDTH - 0.5, 0.14, 0.08), BRASS, metal)
	local front =
		box("Стекло", 0, 4.25, -0.88, Vector3.new(WIDTH - 0.6, 5.8, 0.05), GLASS, Enum.Material.SmoothPlastic)
	front.Transparency = 0.95
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 8
	light.Brightness = 0.7
	light.Angle = 110
	light.Color = rgb(255, 236, 200)
	light.Parent = lamp
	return { Frame = frame, Models = {}, Title = label, Lamp = lamp, Signature = "" }
end

local function buildCollectionRack(kit: Kit, counter: Part): ()
	local floor = -counter.Size.Y / 2
	local frame = counter.CFrame * CFrame.new(0, floor, 5.4)
	local count = #Catalog.Collections
	local width = count * WIDTH + (count - 1) * GAP
	local heading = brick(
		kit.Root,
		"Шапка стойки коллекций",
		frame * CFrame.new(0, HEIGHT + 1.25, -0.75),
		Vector3.new(width * 0.6, 1, 0.3),
		DEEP,
		Enum.Material.Metal
	)
	sign(heading, Enum.NormalId.Front, Texts.collectionsHeading, BRASS, 60, 60)
	for index, collection in Catalog.Collections do
		local x = (index - (count + 1) / 2) * (WIDTH + GAP)
		table.insert(kit.Panels, buildPanel(kit.Root, frame * CFrame.new(x, 0, 0), index, collection))
	end
end

-- Scales a mini to its place and stands it on the shelf, whatever its pivot is.
local function seat(mini: Model, target: CFrame): ()
	local extents = mini:GetExtentsSize()
	local scale = math.min(ITEM_WIDTH / math.max(extents.X, extents.Z, 0.01), ITEM_HEIGHT / math.max(extents.Y, 0.01))
	mini:ScaleTo(mini:GetScale() * scale)
	mini:PivotTo(target)
	local box, size = mini:GetBoundingBox()
	local bottom = box.Position - Vector3.yAxis * (size.Y / 2)
	mini:PivotTo(mini:GetPivot() + (target.Position - bottom))
end

function Collections.setCollections(kit: Kit, collections: { [string]: Types.Item }): ()
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
		panel.Lamp.Color = if complete then GREEN elseif owned > 0 then AMBER else BRASS
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
				local column = (slot - 1) % 2
				local row = (slot - 1) // 2 + 1
				seat(mini, panel.Frame * CFrame.new((column - 0.5) * 2.2, SHELVES[row] or SHELVES[2], -0.1))
				table.insert(panel.Models, mini)
			end
		end
	end
	kit.CollectionLabel.Text = Format(Texts.collectedCount, { owned = everyOwned, total = everything })
end

Collections.buildCollectionRack = buildCollectionRack

return Collections
