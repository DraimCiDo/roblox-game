--!strict
-- Декор центрального зала и проверка свободного места на полу.
-- Сцена лежит в Studio, поэтому планировку зала код не знает: каждый предмет ставится только туда,
-- где под ним ровный пол, над ним есть свободная высота и нет пересечений с другими деталями.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.World)
local Decor = require(script.Parent.Decor)

local Hall = {}

local STEEL = Color3.fromRGB(98, 106, 178)
local CHROME = Color3.fromRGB(236, 238, 252)
local AMBER = Color3.fromRGB(255, 190, 52)
local RED = Color3.fromRGB(255, 80, 90)
local DARK = Color3.fromRGB(72, 78, 142)
local CLEARANCE = 9

local placed: { Vector3 } = {}

-- Можно ли поставить предмет с таким основанием: пол на нужной высоте, место свободно и над головой есть простор.
function Hall.isFree(center: Vector3, floorY: number, footprint: number): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, tagged in Workspace:GetChildren() do
		if tagged:FindFirstChildOfClass("Humanoid") then
			table.insert(ignore, tagged)
		end
	end
	params.FilterDescendantsInstances = ignore
	local down = Workspace:Raycast(Vector3.new(center.X, floorY + 6, center.Z), Vector3.new(0, -12, 0), params)
	if not down or math.abs(down.Position.Y - floorY) > 0.4 then
		return false
	end
	local up = Workspace:Raycast(Vector3.new(center.X, floorY + 0.5, center.Z), Vector3.new(0, 40, 0), params)
	if up and up.Position.Y - floorY < CLEARANCE then
		return false
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = ignore
	local box = Workspace:GetPartBoundsInBox(
		CFrame.new(center.X, floorY + 3.2, center.Z),
		Vector3.new(footprint, 5.6, footprint),
		overlap
	)
	for _, part in box do
		if part.CanCollide or part.CanQuery then
			return false
		end
	end
	for _, other in placed do
		if (other - center).Magnitude < footprint then
			return false
		end
	end
	return true
end

local function part(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Shape = shape
	result.Size = size
	result.CFrame = frame
	result.Color = color
	result.Material = material or Enum.Material.SmoothPlastic
	result.Anchored = true
	result.CanQuery = false
	result.CanTouch = false
	result.Parent = parent
	return result
end

local function group(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- A kit mesh with a simple invisible box that players bump into.
local function prop(parent: Instance, name: string, piece: string, foot: CFrame, height: number, box: Vector3): ()
	local model = group(parent, name)
	local frame = foot * CFrame.new(0, box.Y / 2, 0)
	local solid = part(model, "Основание", Enum.PartType.Block, box, frame, STEEL)
	solid.Transparency = 1
	solid.CastShadow = false
	-- Nothing to bump into until there is something to see.
	solid.CanCollide = false
	Decor.place(model, piece, foot, height, function()
		solid.CanCollide = true
	end)
end

local PROPS = {
	{ Name = "Кадка", Piece = "plant", Height = 5, Box = Vector3.new(3, 2, 3) },
	{ Name = "Скамья", Piece = "bench", Height = 3.4, Box = Vector3.new(3.6, 1.8, 2.4) },
	{ Name = "Штабель ящиков", Piece = "crates", Height = 5.5, Box = Vector3.new(3.4, 5.5, 3.2) },
	{
		Name = "Информационная стела",
		Piece = "terminal",
		Height = 6.5,
		Box = Vector3.new(3.4, 6.5, 3),
	},
}

-- Расставляет декор кольцами вокруг центра зала; всё, что не проходит проверку места, пропускается.
function Hall.Decorate(center: Vector3, floorY: number): number
	local folder = Instance.new("Folder")
	folder.Name = "Декор зала"
	folder.Parent = Workspace
	local count = 0
	local index = 0
	-- Кольца декора начинаются за подиумом ядра CORPA (радиус 12) и кольцом разметки.
	for _, radius in { 21, 29, 44, 62 } do
		local around = if radius > 50 then 12 else 8
		for slot = 0, around - 1 do
			index += 1
			local angle = (slot + (radius % 2) * 0.5) / around * math.pi * 2 + radius * 0.13
			local at = Vector3.new(center.X + math.cos(angle) * radius, floorY, center.Z + math.sin(angle) * radius)
			local kind = PROPS[(index % #PROPS) + 1]
			if Hall.isFree(at, floorY, 4.5) then
				table.insert(placed, at)
				count += 1
				local foot = CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z))
				prop(folder, kind.Name, kind.Piece, foot, kind.Height, kind.Box)
			end
		end
	end
	return count
end

-- Закрытые ворота в западном торце зала: заготовка под будущую зону. Встают перед сервисными панелями стены
-- (стена зала на x = -82, её внутренняя грань — на -81.1) и никого не блокируют: стена и так сплошная.
function Hall.Gate(floorY: number): ()
	local folder = Instance.new("Folder")
	folder.Name = "Закрытые ворота"
	folder.Parent = Workspace
	local block = Enum.PartType.Block
	local x = -80.3
	local function at(y: number, z: number): CFrame
		return CFrame.new(x, floorY + y, z)
	end
	local backing = part(folder, "Проём ворот", block, Vector3.new(0.4, 15, 30), at(7.5, 0), DARK)
	backing.CanCollide = true
	for _, side in { -1, 1 } do
		-- Предупреждающие полосы по низу и верху проёма.
		for _, y in { 0.7, 14.2 } do
			part(folder, "Полоса", block, Vector3.new(0.45, 0.7, 29), at(y, side * 0.1), AMBER)
		end
		part(folder, "Стойка", block, Vector3.new(1.2, 15.6, 1.6), at(7.8, side * 15.6), CHROME)
		Decor.place(
			folder,
			"crates",
			CFrame.lookAt(Vector3.new(x + 2.4, floorY, side * 10.5), Vector3.new(0, floorY, side * 10.5)),
			5.5
		)
	end
	part(folder, "Верхняя балка", block, Vector3.new(1.2, 1, 32.8), at(15.6, 0), CHROME)
	-- Круглая дверь хранилища: задняя часть утоплена в проём.
	local doorway = CFrame.lookAt(Vector3.new(x + 1.6, floorY, 0), Vector3.new(0, floorY, 0))
	local door = part(
		folder,
		"Дверь хранилища",
		block,
		Vector3.new(11, 13, 4),
		doorway * CFrame.new(0, 6.5, 0),
		DARK
	)
	door.CanCollide = true
	door.Transparency = 1
	Decor.place(folder, "gate", doorway, 13.4)
	local lamp = part(
		folder,
		"Сигнал замка",
		block,
		Vector3.new(0.5, 0.6, 3),
		at(14.9, 0) + Vector3.xAxis * 0.4,
		RED,
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color = RED
	light.Range = 12
	light.Brightness = 1.2
	light.Parent = lamp
	local plate = part(folder, "Табличка ворот", block, Vector3.new(0.3, 2.4, 15), at(17.8, 0), DARK)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Right
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 60
	surface.LightInfluence = 0
	surface.MaxDistance = 90
	surface.Parent = plate
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(1, 1)
	caption.BackgroundTransparency = 1
	caption.Text = Texts.gateClosed
	caption.TextColor3 = AMBER
	caption.FontFace = Theme.Fonts.Display
	caption.TextScaled = true
	caption.Parent = surface
	-- Лампа замка тихо мигает: ворота «живые».
	task.spawn(function()
		while lamp.Parent do
			light.Brightness = 0.4
			lamp.Material = Enum.Material.SmoothPlastic
			task.wait(0.9)
			light.Brightness = 1.2
			lamp.Material = Enum.Material.Neon
			task.wait(1.1)
		end
	end)
end

-- Занято ли место декором: пятна мини-игры не должны попадать под предметы.
function Hall.nearDecor(position: Vector3, distance: number): boolean
	for _, other in placed do
		if (other - position).Magnitude < distance then
			return true
		end
	end
	return false
end

return Hall
