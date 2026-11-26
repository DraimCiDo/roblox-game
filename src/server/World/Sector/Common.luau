--!strict
-- Shared types, colors and part helpers of sector decoration.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local Common = {}

export type MakeMini = (Types.Item, boolean?) -> Model

export type Cell = {
	Module: Part,
	Center: Vector3,
	Size: Vector3,
	Frame: { Part },
	Shutter: { Part },
	Items: { Model },
	Signature: string,
}

export type Panel = {
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
local STEEL = rgb(120, 130, 204)
local CHROME = rgb(236, 238, 252)
local MARBLE = rgb(244, 244, 255)
local CYAN = Theme.Colors.Cyan
local AMBER = Theme.Colors.Amber
local VIOLET = rgb(170, 132, 255)
local GREEN = Theme.Colors.Signal
local RED = Theme.Colors.Warning
local WARM = Theme.Colors.Text
local GLASS = rgb(190, 230, 245)

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

Common.rgb = rgb
Common.DEEP = DEEP
Common.STEEL = STEEL
Common.CYAN = CYAN
Common.AMBER = AMBER
Common.GREEN = GREEN
Common.RED = RED
Common.WARM = WARM
Common.brick = brick
Common.sign = sign
Common.qualityColor = qualityColor
Common.CHROME = CHROME
Common.MARBLE = MARBLE
Common.VIOLET = VIOLET
Common.GLASS = GLASS
Common.cylinder = cylinder
Common.hideChildren = hideChildren
Common.clearItems = clearItems
Common.fit = fit

return Common
