--!strict
local Style = require(script.Parent.Style)

local Preview = {}

local palette: { [string]: Color3 } = {
	box = Color3.fromRGB(186, 137, 90),
	crate = Color3.fromRGB(151, 106, 73),
	safe = Color3.fromRGB(112, 151, 173),
	cargo = Color3.fromRGB(65, 139, 145),
	secret = Color3.fromRGB(111, 98, 157),
}

function Preview.color(kind: string): Color3
	return palette[kind] or Style.Amber
end

function Preview.draw(parent: Instance, kind: string): ViewportFrame
	local preview = Instance.new("ViewportFrame")
	preview.Name = "Контейнер"
	preview.BackgroundTransparency = 1
	preview.Ambient = Color3.fromRGB(171, 187, 207)
	preview.LightColor = Color3.fromRGB(233, 243, 238)
	preview.LightDirection = Vector3.new(-1, -2, -1)
	preview.Parent = parent

	local body = Preview.color(kind)
	local metal = Color3.fromRGB(58, 69, 79)
	local light = if kind == "secret" then Color3.fromRGB(193, 156, 247) else Style.Amber
	local width = if kind == "cargo" then 3.5 else 2.55
	local function piece(size: Vector3, pos: Vector3, color: Color3): Part
		local part = Instance.new("Part")
		part.Size, part.Position, part.Color = size, pos, color
		part.Anchored = true
		part.Parent = preview
		return part
	end

	piece(Vector3.new(width, 1.8, 1.9), Vector3.zero, body)
	if kind == "box" then
		piece(Vector3.new(0.54, 0.022, 1.92), Vector3.new(0, 0.91, 0), Style.Amber)
		piece(Vector3.new(0.54, 0.35, 0.025), Vector3.new(0, 0.74, 0.953), Style.Amber)
	elseif kind == "safe" then
		piece(Vector3.new(2.03, 1.44, 0.13), Vector3.new(0, 0, 0.99), metal)
		local dial = piece(Vector3.new(0.22, 0.63, 0.63), Vector3.new(0, 0.08, 1.15), light)
		dial.Shape = Enum.PartType.Cylinder
		dial.Orientation = Vector3.new(0, 90, 0)
	else
		for _, x in { -width / 2 + 0.12, width / 2 - 0.12 } do
			piece(Vector3.new(0.19, 1.87, 1.98), Vector3.new(x, 0, 0), metal)
		end
		for _, y in { -0.78, 0.78 } do
			piece(Vector3.new(width, 0.13, 2), Vector3.new(0, y, 0), metal)
		end
		if kind == "cargo" then
			for x = -1.25, 1.25, 0.5 do
				piece(Vector3.new(0.13, 1.43, 0.065), Vector3.new(x, 0, 0.98), metal)
			end
		end
		piece(Vector3.new(0.45, 0.22, 0.09), Vector3.new(0, 0.08, 0.992), light)
	end

	local camera = Instance.new("Camera")
	camera.FieldOfView = 37
	camera.CFrame = CFrame.lookAt(Vector3.new(4.1, 2.9, 5.9), Vector3.zero)
	camera.Parent = preview
	preview.CurrentCamera = camera
	return preview
end

return Preview
