--!strict
local Style = require(script.Parent.Style)

export type IconName =
	"coin"
	| "star"
	| "gift"
	| "lock"
	| "box"
	| "grid"
	| "screen"
	| "arrow"
	| "bolt"
	| "tag"
	| "cycle"
	| "frame"
	| "stack"
	| "scale"
	| "dice"
	| "eye"
	| "sparkle"
	| "plus"
	| "ticket"
	| "target"
	| "medal"
	| "clock"
	| "gem"
	| "magnet"
	| "check"
	| "gear"

local Icons = {}

-- Иконки собраны из простых фигур без внешних ассетов, поэтому одинаково чётко выглядят на любом экране.
local function shape(
	parent: Instance,
	color: Color3,
	x: number,
	y: number,
	width: number,
	height: number,
	radius: number?,
	rotation: number?
): Frame
	local piece = Instance.new("Frame")
	piece.BorderSizePixel = 0
	piece.BackgroundColor3 = color
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Position = UDim2.fromScale(x, y)
	piece.Size = UDim2.fromScale(width, height)
	piece.Rotation = rotation or 0
	if radius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(radius, 0)
		corner.Parent = piece
	end
	Style.outline(piece, Style.Edge, 2)
	piece.Parent = parent
	return piece
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighter(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function Icons.draw(parent: Instance, name: IconName, color: Color3?, accent: Color3?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Иконка"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = holder
	holder.Parent = parent

	local main = color or Style.Amber
	local second = accent or Style.Text
	if name == "coin" then
		shape(holder, main, 0.5, 0.5, 0.94, 0.94, 0.5)
		shape(holder, darker(main, 0.18), 0.5, 0.5, 0.66, 0.66, 0.5)
		shape(holder, lighter(main, 0.45), 0.5, 0.5, 0.26, 0.26, 0.08, 45)
	elseif name == "star" then
		shape(holder, main, 0.5, 0.5, 0.62, 0.62, 0.06, 0)
		shape(holder, main, 0.5, 0.5, 0.62, 0.62, 0.06, 45)
		shape(holder, lighter(main, 0.5), 0.5, 0.5, 0.3, 0.3, 0.5)
	elseif name == "gift" then
		shape(holder, main, 0.5, 0.64, 0.72, 0.46, 0.1)
		shape(holder, lighter(main, 0.25), 0.5, 0.4, 0.84, 0.2, 0.12)
		shape(holder, second, 0.5, 0.58, 0.14, 0.7, 0.1)
		shape(holder, second, 0.38, 0.2, 0.22, 0.2, 0.5, 0)
		shape(holder, second, 0.62, 0.2, 0.22, 0.2, 0.5, 0)
	elseif name == "lock" then
		shape(holder, lighter(main, 0.2), 0.3, 0.32, 0.12, 0.34, 0.3)
		shape(holder, lighter(main, 0.2), 0.7, 0.32, 0.12, 0.34, 0.3)
		shape(holder, lighter(main, 0.2), 0.5, 0.17, 0.52, 0.14, 0.4)
		shape(holder, main, 0.5, 0.66, 0.76, 0.5, 0.14)
		shape(holder, darker(main, 0.5), 0.5, 0.64, 0.12, 0.12, 0.5)
		shape(holder, darker(main, 0.5), 0.5, 0.74, 0.06, 0.16, 0.2)
	elseif name == "box" then
		shape(holder, main, 0.5, 0.6, 0.76, 0.56, 0.08)
		shape(holder, lighter(main, 0.25), 0.5, 0.3, 0.86, 0.18, 0.1)
		shape(holder, second, 0.5, 0.6, 0.14, 0.56, 0.1)
	elseif name == "grid" then
		for _, x in { 0.28, 0.72 } do
			for _, y in { 0.28, 0.72 } do
				shape(holder, main, x, y, 0.38, 0.38, 0.2)
			end
		end
	elseif name == "arrow" then
		shape(holder, main, 0.5, 0.62, 0.3, 0.6, 0.1)
		shape(holder, main, 0.5, 0.3, 0.62, 0.62, 0.08, 45)
	elseif name == "bolt" then
		shape(holder, main, 0.56, 0.3, 0.34, 0.6, 0.1, 22)
		shape(holder, main, 0.44, 0.7, 0.34, 0.6, 0.1, 22)
		shape(holder, lighter(main, 0.4), 0.5, 0.5, 0.5, 0.18, 0.2, 22)
	elseif name == "tag" then
		shape(holder, main, 0.5, 0.5, 0.62, 0.62, 0.12, 45)
		shape(holder, second, 0.5, 0.36, 0.2, 0.2, 0.5)
	elseif name == "cycle" then
		shape(holder, main, 0.5, 0.5, 0.74, 0.74, 0.5)
		shape(holder, darker(main, 0.7), 0.5, 0.5, 0.46, 0.46, 0.5)
		shape(holder, second, 0.78, 0.28, 0.26, 0.26, 0.1, 45)
	elseif name == "frame" then
		shape(holder, main, 0.5, 0.5, 0.84, 0.7, 0.08)
		shape(holder, darker(main, 0.6), 0.5, 0.5, 0.62, 0.48, 0.05)
		shape(holder, second, 0.38, 0.55, 0.2, 0.2, 0.5)
		shape(holder, second, 0.62, 0.46, 0.2, 0.3, 0.1, 30)
	elseif name == "stack" then
		for index = 0, 2 do
			shape(
				holder,
				if index == 1 then lighter(main, 0.25) else main,
				0.5,
				0.26 + index * 0.24,
				0.78 - index * 0.1,
				0.2,
				0.2
			)
		end
	elseif name == "scale" then
		shape(holder, main, 0.5, 0.52, 0.12, 0.62, 0.2)
		shape(holder, main, 0.5, 0.26, 0.8, 0.1, 0.3)
		shape(holder, second, 0.2, 0.52, 0.28, 0.2, 0.5)
		shape(holder, second, 0.8, 0.52, 0.28, 0.2, 0.5)
		shape(holder, main, 0.5, 0.86, 0.5, 0.1, 0.3)
	elseif name == "dice" then
		shape(holder, main, 0.5, 0.5, 0.74, 0.74, 0.2, 12)
		for _, spot in { { 0.34, 0.34 }, { 0.66, 0.34 }, { 0.5, 0.5 }, { 0.34, 0.66 }, { 0.66, 0.66 } } do
			shape(holder, darker(main, 0.7), spot[1], spot[2], 0.13, 0.13, 0.5)
		end
	elseif name == "eye" then
		shape(holder, main, 0.5, 0.5, 0.9, 0.52, 0.5)
		shape(holder, second, 0.5, 0.5, 0.36, 0.36, 0.5)
		shape(holder, darker(main, 0.8), 0.5, 0.5, 0.18, 0.18, 0.5)
	elseif name == "sparkle" then
		shape(holder, main, 0.5, 0.5, 0.2, 0.84, 0.5)
		shape(holder, main, 0.5, 0.5, 0.84, 0.2, 0.5)
		shape(holder, lighter(main, 0.35), 0.5, 0.5, 0.3, 0.3, 0.1, 45)
	elseif name == "plus" then
		shape(holder, main, 0.5, 0.5, 0.26, 0.8, 0.2)
		shape(holder, main, 0.5, 0.5, 0.8, 0.26, 0.2)
	elseif name == "ticket" then
		shape(holder, main, 0.5, 0.5, 0.86, 0.56, 0.16)
		shape(holder, darker(main, 0.6), 0.5, 0.5, 0.06, 0.4, 0.3)
		shape(holder, second, 0.3, 0.5, 0.18, 0.18, 0.5)
	elseif name == "target" then
		shape(holder, main, 0.5, 0.5, 0.9, 0.9, 0.5)
		shape(holder, darker(main, 0.65), 0.5, 0.5, 0.62, 0.62, 0.5)
		shape(holder, second, 0.5, 0.5, 0.36, 0.36, 0.5)
		shape(holder, darker(main, 0.65), 0.5, 0.5, 0.14, 0.14, 0.5)
	elseif name == "medal" then
		shape(holder, second, 0.34, 0.2, 0.2, 0.4, 0.1, -20)
		shape(holder, second, 0.66, 0.2, 0.2, 0.4, 0.1, 20)
		shape(holder, main, 0.5, 0.62, 0.58, 0.58, 0.5)
		shape(holder, lighter(main, 0.4), 0.5, 0.62, 0.3, 0.3, 0.5)
	elseif name == "clock" then
		shape(holder, main, 0.5, 0.5, 0.88, 0.88, 0.5)
		shape(holder, darker(main, 0.7), 0.5, 0.5, 0.7, 0.7, 0.5)
		shape(holder, second, 0.5, 0.36, 0.08, 0.3, 0.4)
		shape(holder, second, 0.62, 0.5, 0.26, 0.08, 0.4)
	elseif name == "gem" then
		shape(holder, main, 0.5, 0.5, 0.56, 0.56, 0.1, 45)
		shape(holder, lighter(main, 0.4), 0.5, 0.38, 0.26, 0.26, 0.1, 45)
	elseif name == "magnet" then
		shape(holder, main, 0.3, 0.45, 0.22, 0.7, 0.2)
		shape(holder, main, 0.7, 0.45, 0.22, 0.7, 0.2)
		shape(holder, main, 0.5, 0.24, 0.66, 0.2, 0.4)
		shape(holder, second, 0.3, 0.82, 0.22, 0.14, 0.2)
		shape(holder, second, 0.7, 0.82, 0.22, 0.14, 0.2)
	elseif name == "gear" then
		for index = 0, 3 do
			shape(holder, main, 0.5, 0.5, 0.2, 0.92, 0.25, index * 45)
		end
		shape(holder, main, 0.5, 0.5, 0.7, 0.7, 0.5)
		shape(holder, darker(main, 0.75), 0.5, 0.5, 0.3, 0.3, 0.5)
	elseif name == "check" then
		shape(holder, main, 0.36, 0.62, 0.2, 0.46, 0.2, -45)
		shape(holder, main, 0.62, 0.5, 0.2, 0.74, 0.2, 40)
	else
		shape(holder, main, 0.5, 0.44, 0.84, 0.58, 0.1)
		shape(holder, darker(main, 0.6), 0.5, 0.44, 0.7, 0.44, 0.06)
		shape(holder, second, 0.38, 0.44, 0.16, 0.2, 0.2)
		shape(holder, second, 0.62, 0.44, 0.16, 0.2, 0.2)
		shape(holder, main, 0.5, 0.82, 0.34, 0.1, 0.4)
	end
	return holder
end

return Icons
