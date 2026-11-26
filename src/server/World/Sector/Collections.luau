--!strict
-- Collection rack.
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
local STEEL = Common.STEEL
local CYAN = Common.CYAN
local AMBER = Common.AMBER
local VIOLET = Common.VIOLET
local GREEN = Common.GREEN
local WARM = Common.WARM
local GLASS = Common.GLASS
local brick = Common.brick
local sign = Common.sign
local clearItems = Common.clearItems
local fit = Common.fit

local Collections = {}

local PANEL_COLORS = { VIOLET, CYAN, AMBER, GREEN }

-- ============ Коллекции ============

local PANEL_WIDTH = 3.45
local PANEL_HEIGHT = 3.12
local PANEL_GAP = 0.16

local function ghost(model: Model): ()
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") then
			object.Color = rgb(130, 142, 205)
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

Collections.buildCollectionRack = buildCollectionRack

return Collections
