--!strict
-- Part, label and proximity prompt helpers of the world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local Props = {}

local STEEL = Color3.fromRGB(45, 56, 68)
local ICE = Theme.Colors.Cyan
local AMBER = Theme.Colors.Amber
local INK = Theme.Colors.Ink
local PAPER = Theme.Colors.Text
local MUTED = Theme.Colors.Muted

export type Use = (Player, string, string?) -> ()

local function part(
	parent: Instance,
	name: string,
	frame: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Anchored = true
	result.Size = size
	result.CFrame = frame
	result.Color = color
	result.Material = material or Enum.Material.Metal
	result.TopSurface = Enum.SurfaceType.Smooth
	result.BottomSurface = Enum.SurfaceType.Smooth
	result.Parent = parent
	return result
end

local function surfaceLabel(parent: BasePart, text: string, distance: number, face: Enum.NormalId?): TextLabel
	local surface = Instance.new("SurfaceGui")
	surface.Face = face or Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 72
	surface.LightInfluence = 0
	surface.MaxDistance = distance
	surface.Parent = parent
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(1, 1)
	caption.BorderSizePixel = 0
	caption.BackgroundColor3 = INK
	caption.TextColor3 = PAPER
	caption.Text = text
	caption.TextScaled = true
	caption.TextWrapped = true
	caption.FontFace = Theme.Fonts.Display
	caption.Parent = surface
	local margin = Instance.new("UIPadding")
	margin.PaddingLeft = UDim.new(0.045, 0)
	margin.PaddingRight = UDim.new(0.045, 0)
	margin.PaddingTop = UDim.new(0.08, 0)
	margin.PaddingBottom = UDim.new(0.08, 0)
	margin.Parent = caption
	return caption
end

local function prompt(
	parent: BasePart | Attachment,
	action: string,
	title: string,
	use: Use,
	command: string,
	key: string?,
	range: number?
): ProximityPrompt
	local result = parent:FindFirstChildWhichIsA("ProximityPrompt") or Instance.new("ProximityPrompt")
	result.Name = command
	result.ActionText = action
	result.ObjectText = title
	result.MaxActivationDistance = range or 9
	result.RequiresLineOfSight = false
	result.Parent = parent
	result.Triggered:Connect(function(player)
		use(player, command, key)
	end)
	return result
end

local function requirePart(parent: Instance, name: string): Part
	local child = parent:FindFirstChild(name)
	assert(child and child:IsA("Part"), `[World] {parent.Name} is missing the part «{name}»`)
	return child
end

local function authoredParts(parent: Instance, name: string): { Part }
	local found = {}
	for _, child in parent:GetChildren() do
		if child:IsA("Part") and child.Name == name then
			table.insert(found, child)
		end
	end
	return found
end

Props.ICE = ICE
Props.AMBER = AMBER
Props.INK = INK
Props.PAPER = PAPER
Props.MUTED = MUTED
Props.part = part
Props.surfaceLabel = surfaceLabel
Props.prompt = prompt
Props.requirePart = requirePart
Props.authoredParts = authoredParts
Props.STEEL = STEEL

return Props
