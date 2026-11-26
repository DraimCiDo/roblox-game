--!strict
-- Colors and part builders shared by item models. Origin: center of the base, front faces -Z.
local Tools = {}

export type Axis = "x" | "y" | "z"

export type Options = {
	-- true — полная детализация для мира; false — упрощённая для маленьких иконок.
	Full: boolean?,
}

export type Tools = {
	Block: (number, number, number, number, number, number, Color3, Enum.Material?, Vector3?) -> Part,
	Ball: (number, number, number, number, Color3, Enum.Material?) -> Part,
	Cyl: (number, number, number, Axis, number, number, Color3, Enum.Material?, Vector3?) -> Part,
	-- Тонкий диск, «наклеенный» на поверхность: лежит в точке и смотрит нормалью к целевой точке.
	Disc: (Vector3, Vector3, number, number, Color3, Enum.Material?) -> Part,
	Text: (Part, Enum.NormalId, string, Color3) -> (),
	Full: boolean,
	Tint: Color3,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local WHITE = rgb(240, 240, 236)
local BLACK = rgb(24, 26, 30)
local GRAY = rgb(88, 94, 104)
local CHROME = rgb(205, 212, 222)
local GOLD = rgb(246, 196, 70)
local GOLD_DARK = rgb(196, 146, 40)
local RED = rgb(214, 62, 62)
local BROWN = rgb(120, 82, 52)
local PLASTIC = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon
local GLASSY = Enum.Material.Glass

local function makeTools(parent: Instance, full: boolean, tint: Color3): Tools
	local function part(
		shape: Enum.PartType,
		size: Vector3,
		frame: CFrame,
		color: Color3,
		material: Enum.Material?
	): Part
		local piece = Instance.new("Part")
		piece.Name = "Деталь"
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Shape = shape
		piece.Size = size
		piece.CFrame = frame
		piece.Color = color
		piece.Material = material or PLASTIC
		if material == METAL then
			piece.Reflectance = 0.12
		end
		piece.Parent = parent
		return piece
	end
	local function rotation(rot: Vector3?): CFrame
		if not rot then
			return CFrame.identity
		end
		return CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	end
	local tools = {} :: Tools
	tools.Full = full
	tools.Tint = tint
	tools.Block = function(x, y, z, sx, sy, sz, color, material, rot)
		return part(Enum.PartType.Block, Vector3.new(sx, sy, sz), CFrame.new(x, y, z) * rotation(rot), color, material)
	end
	tools.Ball = function(x, y, z, d, color, material)
		return part(Enum.PartType.Ball, Vector3.one * d, CFrame.new(x, y, z), color, material)
	end
	tools.Cyl = function(x, y, z, axis, length, d, color, material, rot)
		local turn = if axis == "y"
			then CFrame.Angles(0, 0, math.pi / 2)
			elseif axis == "z" then CFrame.Angles(0, math.pi / 2, 0)
			else CFrame.identity
		return part(
			Enum.PartType.Cylinder,
			Vector3.new(length, d, d),
			CFrame.new(x, y, z) * rotation(rot) * turn,
			color,
			material
		)
	end
	tools.Disc = function(position, target, d, thickness, color, material)
		local frame = CFrame.lookAt(position, target) * CFrame.Angles(0, math.pi / 2, 0)
		return part(Enum.PartType.Cylinder, Vector3.new(thickness, d, d), frame, color, material)
	end
	tools.Text = function(owner, face, text, color)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 80
		gui.Parent = owner
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.Parent = gui
	end
	return tools
end

local PHI = (1 + math.sqrt(5)) / 2

Tools.rgb = rgb
Tools.WHITE = WHITE
Tools.BLACK = BLACK
Tools.GRAY = GRAY
Tools.CHROME = CHROME
Tools.GOLD = GOLD
Tools.GOLD_DARK = GOLD_DARK
Tools.RED = RED
Tools.BROWN = BROWN
Tools.PLASTIC = PLASTIC
Tools.METAL = METAL
Tools.NEON = NEON
Tools.GLASSY = GLASSY
Tools.makeTools = makeTools
Tools.PHI = PHI

return Tools
