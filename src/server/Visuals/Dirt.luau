--!strict
-- A dirty spot of the mopping job: separate pieces of mud that get scrubbed away and a hologram marker above.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Decor = require(script.Parent.Parent.World.Decor)

export type Chunk = { Model: Model, Position: Vector3, Progress: number }
export type Spot = { Model: Model, Center: Vector3, Marker: Model, Chunks: { Chunk } }

local Dirt = {}

-- Client animates the models with this tag (spinning and bobbing).
Dirt.MARKER_TAG = "MopMarker"

local SPREAD = 2.6
local HOLOGRAM = Color3.fromRGB(90, 230, 255)
local rng = Random.new()

local function neon(parent: Instance, name: string, size: Vector3, frame: CFrame, transparency: number): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.CFrame = frame
	result.Color = HOLOGRAM
	result.Material = Enum.Material.Neon
	result.Transparency = transparency
	result.Anchored = true
	result.CanCollide = false
	result.CanQuery = false
	result.CanTouch = false
	result.CastShadow = false
	result.Parent = parent
	return result
end

local function marker(parent: Instance, center: Vector3, radius: number, caption: string): Model
	local model = Instance.new("Model")
	model.Name = "Метка"

	-- Dashed ring on the floor showing where to step in.
	for index = 0, 15 do
		local angle = index / 16 * math.pi * 2
		local at = center + Vector3.new(math.cos(angle) * radius, 0.2, math.sin(angle) * radius)
		neon(
			model,
			"Кольцо",
			Vector3.new(radius * 0.25, 0.12, 0.25),
			CFrame.lookAt(at, center + Vector3.yAxis * 0.2),
			0.2
		)
	end
	local diamond = CFrame.new(center + Vector3.yAxis * 4.2) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	local gem = neon(model, "Ромб", Vector3.one * 0.6, diamond, 0.4)

	local light = Instance.new("PointLight")
	light.Color = HOLOGRAM
	light.Range = 10
	light.Brightness = 0.8
	light.Parent = gem

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(180, 34)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	billboard.MaxDistance = 80
	billboard.LightInfluence = 0
	billboard.Parent = gem
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = caption
	text.TextColor3 = HOLOGRAM
	text.TextStrokeTransparency = 0.2
	text.TextScaled = true
	text.FontFace = Theme.Fonts.Display
	text.Parent = billboard

	model.PrimaryPart = gem
	CollectionService:AddTag(model, Dirt.MARKER_TAG)
	model.Parent = parent
	return model
end

local function chunk(parent: Instance, piece: string, at: Vector3, height: number): Chunk
	local model = Instance.new("Model")
	model.Name = "Грязь"
	model.Parent = parent
	Decor.place(model, piece, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), height)
	return { Model = model, Position = at, Progress = 0 }
end

-- `center` lies on the floor; `count` pieces of mud are spread around it.
function Dirt.spawn(parent: Instance, center: Vector3, count: number, markerRadius: number, caption: string): Spot
	local model = Instance.new("Model")
	model.Name = "Грязное пятно"
	model.Parent = parent
	local chunks = { chunk(model, "mud", center, rng:NextNumber(0.3, 0.38)) }
	for index = 2, count do
		local angle = (index + rng:NextNumber(-0.35, 0.35)) / (count - 1) * math.pi * 2
		local distance = rng:NextNumber(SPREAD * 0.45, SPREAD)
		-- Different heights keep overlapping pieces from flickering.
		local lift = (index % 4) * 0.008
		local at = center + Vector3.new(math.cos(angle) * distance, lift, math.sin(angle) * distance)
		if index % 3 == 0 then
			table.insert(chunks, chunk(model, "clump", at, rng:NextNumber(0.35, 0.55)))
		else
			table.insert(chunks, chunk(model, "mud", at, rng:NextNumber(0.16, 0.24)))
		end
	end
	return { Model = model, Center = center, Marker = marker(model, center, markerRadius, caption), Chunks = chunks }
end

-- A piece fades while it is being scrubbed.
function Dirt.fade(piece: Chunk, share: number): ()
	for _, child in piece.Model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Transparency = math.clamp(share, 0, 1) * 0.65
		end
	end
end

return Dirt
