--!strict
-- Looks of the mopping job: the stand with a bucket and the mop held by a character.
local Mop = {}

local HANDLE = Color3.fromRGB(236, 238, 252)
local HEAD = Color3.fromRGB(255, 190, 52)
local STRANDS = Color3.fromRGB(205, 222, 255)
local BUCKET = Color3.fromRGB(70, 196, 255)
local STAND = Color3.fromRGB(98, 106, 178)

-- How far in front of the character the mop head touches the floor.
local REACH = 3

local function part(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	frame: CFrame,
	color: Color3
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Shape = shape
	result.Size = size
	result.CFrame = frame
	result.Color = color
	result.Material = Enum.Material.SmoothPlastic
	result.Anchored = true
	result.CanCollide = false
	result.CanQuery = false
	result.CanTouch = false
	result.Parent = parent
	return result
end

-- A cylinder lies along its X axis.
local function rod(parent: Instance, name: string, from: Vector3, to: Vector3, width: number, color: Color3): Part
	local middle = (from + to) / 2
	local frame = CFrame.lookAt(middle, to) * CFrame.Angles(0, math.rad(90), 0)
	return part(parent, name, Enum.PartType.Cylinder, Vector3.new((to - from).Magnitude, width, width), frame, color)
end

-- The mop head and its strands, centred on the floor point of `frame`.
local function head(parent: Instance, frame: CFrame): Part
	local block = Enum.PartType.Block
	local pad = part(parent, "Насадка", block, Vector3.new(2.4, 0.35, 0.9), frame * CFrame.new(0, 0.4, 0), HEAD)
	for index = -4, 4 do
		local strand = frame * CFrame.new(index * 0.27, 0.12, 0.05 * (index % 2))
		part(parent, "Ворс", block, Vector3.new(0.2, 0.24, 1.15), strand, STRANDS)
	end
	return pad
end

function Mop.station(parent: Instance, foot: CFrame): Part
	local block = Enum.PartType.Block
	local base = part(
		parent,
		"Стойка со шваброй",
		block,
		Vector3.new(3, 0.4, 3),
		foot * CFrame.new(0, 0.2, 0),
		STAND
	)
	base.CanQuery = true
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local pail = foot * CFrame.new(-0.7, 1.15, 0) * upright
	part(parent, "Ведро", Enum.PartType.Cylinder, Vector3.new(1.5, 1.6, 1.6), pail, BUCKET)
	local water = foot * CFrame.new(-0.7, 1.93, 0) * upright
	part(parent, "Вода", Enum.PartType.Cylinder, Vector3.new(0.05, 1.35, 1.35), water, STRANDS)
	local at = foot * CFrame.new(0.7, 0.4, 0)
	head(parent, at)
	rod(
		parent,
		"Черенок",
		(at * CFrame.new(0, 0.5, 0)).Position,
		(at * CFrame.new(0, 4.6, 0)).Position,
		0.22,
		HANDLE
	)
	return base
end

-- Where the hands end up in the arm pose of the client (MopController), relative to the root.
local function hands(character: Model, root: BasePart): Vector3
	local upper = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
	if not upper or not upper:IsA("BasePart") then
		return Vector3.new(0.1, -0.7, -1.2)
	end
	local lower = character:FindFirstChild("RightLowerArm")
	local hand = character:FindFirstChild("RightHand")
	local length = upper.Size.Y * 0.8
	if lower and lower:IsA("BasePart") and hand and hand:IsA("BasePart") then
		length = upper.Size.Y + lower.Size.Y * 0.8 + hand.Size.Y / 2
	end
	local shoulder = root.CFrame:PointToObjectSpace(upper.Position).Y + upper.Size.Y / 2
	local angle = math.rad(55)
	return Vector3.new(0.1, shoulder - length * math.cos(angle), -length * math.sin(angle))
end

-- Puts a mop into the character's hands: welded to the root so the head always slides on the floor.
-- Returns the model and the head part, whose position the server reads while cleaning.
function Mop.equip(character: Model): (Model?, Part?)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return nil, nil
	end
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else humanoid.HipHeight
	local floor = -(root.Size.Y / 2 + legs)

	local model = Instance.new("Model")
	model.Name = "Швабра в руках"
	local held = hands(character, root)
	local foot = root.CFrame * CFrame.new(0, floor, -math.max(REACH, -held.Z + 1.7))
	local pad = head(model, foot)
	local low = (foot * CFrame.new(0, 0.5, 0)).Position
	local grip = root.CFrame:PointToWorldSpace(held)
	-- The handle sticks out a little above the hands.
	rod(model, "Черенок", grip + (grip - low).Unit * 0.5, low, 0.22, HANDLE)

	for _, piece in model:GetChildren() do
		if piece:IsA("BasePart") then
			piece.Massless = true
			piece.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = piece
			weld.Parent = piece
		end
	end
	model.Parent = character
	return model, pad
end

return Mop
