--!strict
local Style = require(script.Parent.Parent.UI.Style)

local Preview = {}

local palette: { [string]: Color3 } = {
	box = Color3.fromRGB(190, 140, 88),
	crate = Color3.fromRGB(158, 110, 68),
	safe = Color3.fromRGB(96, 112, 130),
	cargo = Color3.fromRGB(62, 110, 150),
	secret = Color3.fromRGB(146, 87, 208),
}

local TAPE = Color3.fromRGB(246, 198, 72)
local WOOD_DARK = Color3.fromRGB(96, 66, 44)
local STEEL = Color3.fromRGB(45, 56, 68)
local BRASS = Color3.fromRGB(232, 184, 74)
local OBSIDIAN = Color3.fromRGB(34, 26, 58)
local VIOLET = Color3.fromRGB(146, 87, 208)

function Preview.color(kind: string): Color3
	return palette[kind] or Style.Amber
end

-- Упрощённая копия серверных моделей контейнеров для 3D-превью в терминале.
function Preview.draw(parent: Instance, kind: string): ViewportFrame
	local preview = Instance.new("ViewportFrame")
	preview.Name = "Контейнер"
	preview.BackgroundTransparency = 1
	preview.Ambient = Color3.fromRGB(176, 182, 214)
	preview.LightColor = Color3.fromRGB(255, 250, 236)
	preview.LightDirection = Vector3.new(-1, -2, -1)
	preview.Parent = parent

	local function piece(
		size: Vector3,
		position: Vector3,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): Part
		local part = Instance.new("Part")
		part.Size, part.Position, part.Color = size, position, color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Shape = shape or Enum.PartType.Block
		part.Anchored = true
		part.CanCollide = false
		part.Parent = preview
		return part
	end

	local body = Preview.color(kind)
	local target = Vector3.zero
	local distance = 1
	if kind == "box" then
		piece(Vector3.new(2.4, 1.5, 2.4), Vector3.zero, body, Enum.Material.Fabric)
		piece(
			Vector3.new(1.2, 0.06, 2.4),
			Vector3.new(-0.6, 0.78, 0),
			Color3.fromRGB(214, 168, 112),
			Enum.Material.Fabric
		)
		piece(
			Vector3.new(1.2, 0.06, 2.4),
			Vector3.new(0.6, 0.78, 0),
			Color3.fromRGB(214, 168, 112),
			Enum.Material.Fabric
		)
		piece(Vector3.new(0.4, 0.04, 2.5), Vector3.new(0, 0.83, 0), TAPE)
		piece(Vector3.new(0.4, 0.7, 0.04), Vector3.new(0, 0.45, -1.22), TAPE)
		piece(Vector3.new(0.9, 0.55, 0.03), Vector3.new(0.5, 0.0, -1.22), Color3.fromRGB(240, 238, 228))
	elseif kind == "crate" then
		for layer = 0, 4 do
			local tone = if layer % 2 == 0 then body else body:Lerp(Color3.new(0, 0, 0), 0.12)
			piece(Vector3.new(2.5, 0.3, 2.5), Vector3.new(0, -0.9 + layer * 0.32, 0), tone, Enum.Material.WoodPlanks)
		end
		for _, x in { -1.2, 1.2 } do
			for _, z in { -1.2, 1.2 } do
				piece(Vector3.new(0.34, 1.7, 0.34), Vector3.new(x, -0.1, z), WOOD_DARK, Enum.Material.Wood)
			end
		end
		piece(Vector3.new(2.6, 0.1, 2.6), Vector3.new(0, 0.82, 0), body, Enum.Material.WoodPlanks)
		for _, x in { -0.7, 0.7 } do
			piece(
				Vector3.new(0.26, 1.5, 0.06),
				Vector3.new(x, -0.1, -1.27),
				Color3.fromRGB(122, 132, 146),
				Enum.Material.Metal
			)
			piece(Vector3.new(0.42, 0.28, 0.08), Vector3.new(x, 0.25, -1.3), BRASS, Enum.Material.Metal)
		end
	elseif kind == "safe" then
		piece(Vector3.new(2.7, 0.18, 2.7), Vector3.new(0, -0.95, 0), STEEL, Enum.Material.DiamondPlate)
		piece(Vector3.new(2.5, 1.9, 2.4), Vector3.new(0, 0.05, 0), body, Enum.Material.Metal)
		piece(
			Vector3.new(2.1, 1.5, 0.12),
			Vector3.new(0, 0.05, -1.24),
			Color3.fromRGB(122, 138, 156),
			Enum.Material.Metal
		)
		piece(Vector3.new(0.12, 0.8, 0.12), Vector3.new(0, 0.05, -1.36), BRASS, Enum.Material.Metal)
		piece(Vector3.new(0.8, 0.12, 0.12), Vector3.new(0, 0.05, -1.36), BRASS, Enum.Material.Metal)
		local wheel = piece(
			Vector3.new(0.14, 0.9, 0.9),
			Vector3.new(0.3, 0.05, -1.32),
			BRASS,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		wheel.Orientation = Vector3.new(0, 90, 0)
		for index = 0, 2 do
			local lamp = Color3.fromRGB(255, 70, 80)
			piece(Vector3.new(0.12, 0.12, 0.05), Vector3.new(-0.6 + index * 0.2, 0.68, -1.31), lamp, Enum.Material.Neon)
		end
	elseif kind == "cargo" then
		piece(Vector3.new(3.6, 1.8, 2.2), Vector3.zero, body, Enum.Material.Metal)
		for x = -1.5, 1.5, 0.5 do
			piece(Vector3.new(0.12, 1.7, 0.06), Vector3.new(x, 0, -1.13), STEEL, Enum.Material.Metal)
		end
		for _, x in { -1.75, 1.75 } do
			for _, y in { -0.85, 0.85 } do
				piece(Vector3.new(0.22, 0.22, 2.3), Vector3.new(x, y, 0), STEEL, Enum.Material.Metal)
			end
		end
		for _, x in { -0.35, 0.35 } do
			piece(Vector3.new(0.16, 0.8, 0.08), Vector3.new(x, 0, -1.16), BRASS, Enum.Material.Metal)
		end
		piece(Vector3.new(0.2, 0.3, 0.08), Vector3.new(0, 0.1, -1.17), Color3.fromRGB(91, 232, 222), Enum.Material.Neon)
	else
		target = Vector3.new(0, 0.55, 0)
		distance = 1.25
		piece(Vector3.new(2.2, 1.7, 2.2), Vector3.new(0, -0.35, 0), OBSIDIAN, Enum.Material.Slate)
		for _, x in { -1.12, 1.12 } do
			for _, z in { -1.12, 1.12 } do
				piece(Vector3.new(0.07, 1.7, 0.07), Vector3.new(x, -0.35, z), VIOLET, Enum.Material.Neon)
			end
		end
		piece(Vector3.one * 0.7, Vector3.new(0, 1.05, 0), VIOLET, Enum.Material.Neon, Enum.PartType.Ball)
		local ring = piece(
			Vector3.new(0.04, 1.4, 1.4),
			Vector3.new(0, 1.05, 0),
			Color3.fromRGB(228, 196, 255),
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		ring.Orientation = Vector3.new(30, 0, 90)
		ring.Transparency = 0.4
	end

	local camera = Instance.new("Camera")
	camera.FieldOfView = 37
	camera.CFrame = CFrame.lookAt(target + Vector3.new(4.1, 2.9, 5.9) * distance, target)
	camera.Parent = preview
	preview.CurrentCamera = camera
	return preview
end

return Preview
