--!strict
-- Слабые следы эксплуатации поверх штатной фактуры. Координаты нормализованы на грани.
type Mark = {
	Center: Vector2,
	Size: Vector2,
	Color: Color3,
	Opacity: number,
}

local WALL_MARKS: { Mark } = {
	{
		Center = Vector2.new(0.24, 0.82),
		Size = Vector2.new(0.55, 0.35),
		Color = Color3.fromRGB(51, 69, 65),
		Opacity = 0.14,
	},
	{
		Center = Vector2.new(0.75, 0.84),
		Size = Vector2.new(0.64, 0.30),
		Color = Color3.fromRGB(77, 70, 57),
		Opacity = 0.12,
	},
	{
		Center = Vector2.new(0.58, 0.52),
		Size = Vector2.new(0.26, 0.45),
		Color = Color3.fromRGB(103, 111, 93),
		Opacity = 0.08,
	},
}

local FLOOR_MARKS: { Mark } = {
	{
		Center = Vector2.new(0.50, 0.37),
		Size = Vector2.new(0.34, 0.86),
		Color = Color3.fromRGB(84, 87, 75),
		Opacity = 0.12,
	},
	{
		Center = Vector2.new(0.66, 0.70),
		Size = Vector2.new(0.27, 0.36),
		Color = Color3.fromRGB(157, 150, 127),
		Opacity = 0.10,
	},
}

local SurfaceFinish = {}

local function apply(part: Part, face: Enum.NormalId, marks: { Mark }, facingFlip: boolean): ()
	local finish = Instance.new("SurfaceGui")
	finish.Name = "Патина поверхности"
	finish.Face = face
	finish.Active = false
	finish.AlwaysOnTop = false
	finish.LightInfluence = 1
	finish.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	finish.PixelsPerStud = 14
	finish.MaxDistance = 82
	finish.ClipsDescendants = true
	finish.Parent = part

	for _, mark in marks do
		local layer = Instance.new("Frame")
		layer.Name = "Локальный след"
		layer.Active = false
		layer.AnchorPoint = Vector2.new(0.5, 0.5)
		local x = if facingFlip then 1 - mark.Center.X else mark.Center.X
		layer.Position = UDim2.fromScale(x, mark.Center.Y)
		layer.Size = UDim2.fromScale(mark.Size.X, mark.Size.Y)
		layer.BorderSizePixel = 0
		layer.BackgroundColor3 = mark.Color
		layer.Parent = finish

		local fade = Instance.new("UIGradient")
		fade.Type = Enum.GradientType.Elliptical
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - mark.Opacity),
			NumberSequenceKeypoint.new(0.40, 1 - mark.Opacity * 0.68),
			NumberSequenceKeypoint.new(0.76, 1 - mark.Opacity * 0.20),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = layer
	end
end

function SurfaceFinish.wall(part: Part, face: Enum.NormalId): ()
	apply(part, face, WALL_MARKS, face == Enum.NormalId.Right)
end

function SurfaceFinish.floor(part: Part): ()
	apply(part, Enum.NormalId.Top, FLOOR_MARKS, false)
end

return SurfaceFinish
