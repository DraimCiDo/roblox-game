--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Style = require(script.Parent.Style)

type Axis = "x" | "y" | "z"

local ItemPreview = {}

-- Собирает из простых деталей объёмную иконку предмета по его стилю из каталога.
-- ghost = true рисует тёмный силуэт для пустого слота.
function ItemPreview.draw(parent: Instance, kind: string, ghost: boolean?): ViewportFrame
	local definition = Catalog.Items[kind]
	local preview = Instance.new("ViewportFrame")
	preview.Name = "Иконка"
	preview.BackgroundTransparency = 1
	preview.Ambient = Color3.fromRGB(176, 182, 214)
	preview.LightColor = Color3.fromRGB(255, 250, 236)
	preview.LightDirection = Vector3.new(-1, -2, -1)
	preview.Parent = parent

	local base = if ghost then Style.Edge else definition.Color
	local dark = base:Lerp(Color3.new(0, 0, 0), 0.55)
	local light = base:Lerp(Color3.new(1, 1, 1), 0.45)
	local accent = if ghost then Style.Track else Style.Amber

	local function put(shape: Enum.PartType, size: Vector3, position: Vector3, color: Color3, orientation: Vector3?)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Shape = shape
		part.Size = size
		part.Position = position
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		if orientation then
			part.Orientation = orientation
		end
		part.Parent = preview
	end
	local function block(size: Vector3, position: Vector3, color: Color3, orientation: Vector3?)
		put(Enum.PartType.Block, size, position, color, orientation)
	end
	local function ball(diameter: number, position: Vector3, color: Color3)
		put(Enum.PartType.Ball, Vector3.one * diameter, position, color)
	end
	-- Цилиндр Roblox вытянут вдоль оси X; поворачиваем под нужную ось.
	local function disc(axis: Axis, length: number, diameter: number, position: Vector3, color: Color3)
		local orientation = if axis == "y"
			then Vector3.new(0, 0, 90)
			elseif axis == "z" then Vector3.new(0, 90, 0)
			else nil
		put(Enum.PartType.Cylinder, Vector3.new(length, diameter, diameter), position, color, orientation)
	end

	local style = definition.Style
	if style == "ball" then
		ball(1.8, Vector3.zero, base)
		ball(0.5, Vector3.new(0.5, 0.55, 0.7), light)
	elseif style == "bell" then
		ball(1.5, Vector3.new(0, 0.1, 0), base)
		disc("y", 0.25, 1.7, Vector3.new(0, -0.55, 0), dark)
		ball(0.35, Vector3.new(0, 0.95, 0), accent)
	elseif style == "bowl" then
		disc("y", 0.9, 1.8, Vector3.zero, base)
		disc("y", 0.12, 1.5, Vector3.new(0, 0.46, 0), dark)
	elseif style == "picture" then
		block(Vector3.new(1.9, 1.5, 0.15), Vector3.zero, dark)
		block(Vector3.new(1.6, 1.2, 0.18), Vector3.zero, base)
		block(Vector3.new(0.6, 0.4, 0.2), Vector3.new(-0.3, -0.2, 0), light)
	elseif style == "fish" then
		block(Vector3.new(1.4, 0.8, 0.4), Vector3.zero, base)
		block(Vector3.new(0.6, 0.6, 0.3), Vector3.new(-0.9, 0, 0), light, Vector3.new(0, 0, 45))
		ball(0.18, Vector3.new(0.45, 0.12, 0.22), dark)
	elseif style == "dumbbell" then
		disc("x", 2.0, 0.25, Vector3.zero, dark)
		for _, x in { -0.8, 0.8 } do
			disc("x", 0.35, 1.1, Vector3.new(x, 0, 0), base)
		end
	elseif style == "brush" then
		disc("y", 1.7, 0.2, Vector3.new(0, 0.1, 0), light)
		ball(0.8, Vector3.new(0, -0.8, 0), base)
	elseif style == "block" then
		block(Vector3.new(1.6, 1.4, 1.6), Vector3.zero, base)
		block(Vector3.new(0.4, 1.42, 1.62), Vector3.zero, accent)
	elseif style == "hat" then
		disc("y", 0.35, 1.9, Vector3.new(0, -0.6, 0), base)
		disc("y", 0.45, 1.3, Vector3.new(0, -0.2, 0), base)
		disc("y", 0.45, 0.7, Vector3.new(0, 0.25, 0), light)
		ball(0.35, Vector3.new(0, 0.6, 0), accent)
	elseif style == "flower" then
		disc("y", 1.4, 0.15, Vector3.new(0, -0.4, 0), Color3.fromRGB(80, 170, 96))
		for angle = 0, 4 do
			local rad = math.rad(angle * 72)
			ball(0.6, Vector3.new(math.cos(rad) * 0.5, 0.5, math.sin(rad) * 0.5), base)
		end
		ball(0.45, Vector3.new(0, 0.5, 0), accent)
	elseif style == "screen" then
		block(Vector3.new(1.9, 1.4, 1.1), Vector3.new(0, 0.1, 0), base)
		block(Vector3.new(1.55, 1.05, 0.1), Vector3.new(0, 0.1, 0.56), dark)
		block(Vector3.new(0.8, 0.2, 0.7), Vector3.new(0, -0.7, 0), light)
	elseif style == "fan" then
		block(Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, -0.85, 0), dark)
		disc("z", 0.2, 1.8, Vector3.new(0, 0.15, 0), base)
		disc("z", 0.25, 0.4, Vector3.new(0, 0.15, 0.1), accent)
	elseif style == "radio" then
		block(Vector3.new(1.9, 1.1, 0.8), Vector3.zero, base)
		disc("z", 0.1, 0.8, Vector3.new(-0.45, 0, 0.42), dark)
		block(Vector3.new(0.05, 0.9, 0.05), Vector3.new(0.7, 0.9, 0), light, Vector3.new(0, 0, -25))
	elseif style == "camera" then
		block(Vector3.new(1.7, 1.1, 0.9), Vector3.zero, base)
		disc("z", 0.4, 0.8, Vector3.new(0, 0, 0.6), dark)
		block(Vector3.new(0.5, 0.25, 0.4), Vector3.new(-0.5, 0.65, 0), light)
	elseif style == "bar" then
		block(Vector3.new(1.9, 0.6, 1.0), Vector3.new(0, -0.15, 0), base)
		block(Vector3.new(1.4, 0.3, 0.7), Vector3.new(0, 0.3, 0), light)
	elseif style == "tower" then
		block(Vector3.new(1.0, 1.9, 1.6), Vector3.zero, base)
		block(Vector3.new(0.12, 1.5, 1.62), Vector3.new(0.3, 0, 0), dark)
		ball(0.2, Vector3.new(-0.2, 0.7, 0.82), accent)
	elseif style == "car" then
		block(Vector3.new(2.1, 0.5, 1.0), Vector3.new(0, -0.1, 0), base)
		block(Vector3.new(1.1, 0.45, 0.9), Vector3.new(-0.1, 0.35, 0), dark)
		for _, x in { -0.7, 0.7 } do
			for _, z in { -0.5, 0.5 } do
				disc("z", 0.22, 0.55, Vector3.new(x, -0.4, z), Style.Edge)
			end
		end
	elseif style == "gem" then
		block(Vector3.one * 1.1, Vector3.zero, base, Vector3.new(45, 45, 0))
		block(Vector3.one * 0.6, Vector3.zero, light, Vector3.new(45, 45, 0))
	else
		block(Vector3.one * 1.4, Vector3.zero, base)
	end

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(3.2, 2.4, 4.4), Vector3.zero)
	camera.Parent = preview
	preview.CurrentCamera = camera
	return preview
end

return ItemPreview
