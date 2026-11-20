--!strict
-- Декор центрального зала и проверка свободного места на полу.
-- Сцена лежит в Studio, поэтому планировку зала код не знает: каждый предмет ставится только туда,
-- где под ним ровный пол, над ним есть свободная высота и нет пересечений с другими деталями.
local Workspace = game:GetService("Workspace")

local Hall = {}

local STEEL = Color3.fromRGB(52, 62, 76)
local CHROME = Color3.fromRGB(196, 204, 214)
local CYAN = Color3.fromRGB(91, 232, 222)
local GREEN = Color3.fromRGB(80, 235, 130)
local AMBER = Color3.fromRGB(255, 181, 86)
local RED = Color3.fromRGB(255, 80, 90)
local DARK = Color3.fromRGB(36, 42, 54)
local CRATE = Color3.fromRGB(150, 112, 70)
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

local SIDEWAYS = CFrame.Angles(0, 0, math.rad(90))

local function planter(parent: Instance, at: Vector3): ()
	local model = group(parent, "Кадка")
	local tub = Vector3.new(1.6, 3.2, 3.2)
	part(model, "Кадка", Enum.PartType.Cylinder, tub, CFrame.new(at + Vector3.new(0, 0.8, 0)) * SIDEWAYS, STEEL)
	local soil = Vector3.new(0.2, 2.8, 2.8)
	local soilFrame = CFrame.new(at + Vector3.new(0, 1.55, 0)) * SIDEWAYS
	part(model, "Земля", Enum.PartType.Cylinder, soil, soilFrame, Color3.fromRGB(70, 52, 38), Enum.Material.Ground)
	for index = 1, 5 do
		local angle = index * math.pi * 2 / 5
		local offset = Vector3.new(math.cos(angle) * 0.7, 2.5, math.sin(angle) * 0.7)
		local leafColor = GREEN:Lerp(STEEL, 0.4)
		local leafSize = Vector3.new(1.3, 1.9, 1.3)
		part(model, "Лист", Enum.PartType.Ball, leafSize, CFrame.new(at + offset), leafColor, Enum.Material.Grass)
	end
end

local function bench(parent: Instance, at: Vector3, facing: CFrame): ()
	local model = group(parent, "Скамья")
	local base = CFrame.new(at) * facing.Rotation
	local block = Enum.PartType.Block
	part(model, "Сиденье", block, Vector3.new(5.4, 0.4, 1.7), base * CFrame.new(0, 1.3, 0), CHROME, Enum.Material.Metal)
	part(model, "Спинка", block, Vector3.new(5.4, 1.2, 0.3), base * CFrame.new(0, 2.1, 0.75), STEEL)
	for _, x in { -2.3, 2.3 } do
		part(model, "Опора", block, Vector3.new(0.4, 1.3, 1.5), base * CFrame.new(x, 0.65, 0), STEEL)
	end
	local glow = Vector3.new(5, 0.1, 0.12)
	part(model, "Подсветка", block, glow, base * CFrame.new(0, 1.0, -0.8), CYAN, Enum.Material.Neon)
end

local function crates(parent: Instance, at: Vector3): ()
	local model = group(parent, "Штабель ящиков")
	local block = Enum.PartType.Block
	local lower = CFrame.new(at + Vector3.new(0, 1.5, 0))
	part(model, "Ящик", block, Vector3.one * 3, lower, CRATE, Enum.Material.Wood)
	local upper = CFrame.new(at + Vector3.new(0.2, 4.1, 0)) * CFrame.Angles(0, math.rad(20), 0)
	part(model, "Ящик", block, Vector3.one * 2.2, upper, CRATE:Lerp(AMBER, 0.2), Enum.Material.Wood)
	local label = CFrame.new(at + Vector3.new(0, 1.9, -1.52))
	part(model, "Маркировка", block, Vector3.new(1.4, 0.4, 0.1), label, AMBER, Enum.Material.Neon)
end

local function totem(parent: Instance, at: Vector3): ()
	local model = group(parent, "Информационная стела")
	local block = Enum.PartType.Block
	part(model, "Стела", block, Vector3.new(2.2, 7, 0.8), CFrame.new(at + Vector3.new(0, 3.5, 0)), STEEL)
	local screenFrame = CFrame.new(at + Vector3.new(0, 4.4, -0.45))
	local screen = part(model, "Экран", block, Vector3.new(1.6, 3.4, 0.1), screenFrame, CYAN, Enum.Material.Neon)
	screen.Transparency = 0.35
	local light = Instance.new("PointLight")
	light.Color = CYAN
	light.Range = 14
	light.Brightness = 0.8
	light.Parent = screen
end

-- Расставляет декор кольцами вокруг центра зала; всё, что не проходит проверку места, пропускается.
function Hall.Decorate(center: Vector3, floorY: number): number
	local folder = Instance.new("Folder")
	folder.Name = "Декор зала"
	folder.Parent = Workspace
	local kinds = { "planter", "bench", "crates", "totem" }
	local count = 0
	local index = 0
	for _, radius in { 13, 21, 29 } do
		local around = 8
		for slot = 0, around - 1 do
			index += 1
			local angle = (slot + (radius % 2) * 0.5) / around * math.pi * 2 + radius * 0.13
			local at = Vector3.new(center.X + math.cos(angle) * radius, floorY, center.Z + math.sin(angle) * radius)
			local kind = kinds[(index % #kinds) + 1]
			local footprint = if kind == "bench" then 6.5 else 4.5
			if Hall.isFree(at, floorY, footprint) then
				table.insert(placed, at)
				count += 1
				if kind == "planter" then
					planter(folder, at)
				elseif kind == "bench" then
					bench(folder, at, CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z)))
				elseif kind == "crates" then
					crates(folder, at)
				else
					totem(folder, at)
				end
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
	for _, side in { -1, 1 } do
		local leafSize = Vector3.new(0.4, 10.6, 14.2)
		local leaf = part(folder, "Створка ворот", block, leafSize, at(5.4, side * 7.2), DARK, Enum.Material.Metal)
		leaf.CanCollide = true
		-- Предупреждающие полосы по низу и верху створки.
		for _, y in { 0.7, 10.2 } do
			part(folder, "Полоса", block, Vector3.new(0.45, 0.7, 13.6), at(y, side * 7.2), AMBER, Enum.Material.Metal)
		end
		for rib = -2, 2 do
			local ribFrame = at(5.4, side * 7.2 + rib * 2.6)
			part(folder, "Ребро", block, Vector3.new(0.5, 8.6, 0.25), ribFrame, STEEL, Enum.Material.Metal)
		end
	end
	local frameColor = CHROME:Lerp(STEEL, 0.5)
	part(folder, "Верхняя балка", block, Vector3.new(0.9, 1, 31.2), at(11.4, 0), frameColor, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		part(folder, "Стойка", block, Vector3.new(0.9, 11.4, 1), at(5.7, side * 15.4), frameColor, Enum.Material.Metal)
	end
	part(folder, "Замок", block, Vector3.new(0.8, 1.8, 2.2), at(5.4, 0), CHROME, Enum.Material.Metal)
	local lamp = part(folder, "Сигнал замка", block, Vector3.new(0.3, 0.5, 1.4), at(6.8, 0), RED, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = RED
	light.Range = 12
	light.Brightness = 1.2
	light.Parent = lamp
	local plate = part(folder, "Табличка ворот", block, Vector3.new(0.3, 2.4, 13), at(14, 0), DARK, Enum.Material.Metal)
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
	caption.Text = "ЗАКРЫТО · СКОРО ОТКРОЕТСЯ"
	caption.TextColor3 = AMBER
	caption.Font = Enum.Font.GothamBold
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
