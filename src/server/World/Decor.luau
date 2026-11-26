--!strict
-- Creates the cartoon kit meshes: from the placeholders of the scene (KitPiece attribute) and on demand.
local AssetService = game:GetService("AssetService")

local Kit = require(script.Parent.Parent.Config.Kit)

local Decor = {}

local ATTEMPTS = 3

local templates: { [string]: MeshPart } = {}

-- A failed download is not cached: the next request for the piece tries again.
local function template(piece: string): MeshPart?
	local cached = templates[piece]
	if cached then
		return cached
	end
	local entry = (Kit :: any)[piece]
	if not entry then
		warn(`[Decor] Unknown kit piece «{piece}»`)
		return nil
	end
	for attempt = 1, ATTEMPTS do
		local ok, result = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri(entry.Mesh), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
			})
		end)
		if ok then
			result.TextureID = entry.Texture
			if entry.Color then
				result.Color = entry.Color
				result.Material = entry.Material
			end
			result.Anchored = true
			result.CanCollide = false
			result.CanTouch = false
			result.CanQuery = false
			templates[piece] = result
			return result
		end
		if attempt == ATTEMPTS then
			warn(`[Decor] Failed to load the «{piece}» mesh: {result}`)
		else
			task.wait(attempt * 2)
		end
	end
	return nil
end

-- Puts a piece with its bottom centre at `foot`, scaled to `height`. The mesh appears once downloaded.
function Decor.place(parent: Instance, piece: string, foot: CFrame, height: number, placed: (() -> ())?): ()
	task.spawn(function()
		local source = template(piece)
		if source then
			local mesh = source:Clone()
			local native = (Kit :: any)[piece].Size
			mesh.Name = `Декор: {piece}`
			mesh.Size = Vector3.new(native[1], native[2], native[3]) * (height / native[2])
			mesh.CFrame = foot * CFrame.new(0, height / 2, 0)
			mesh.Parent = parent
			if placed then
				placed()
			end
		end
	end)
end

-- The widened sectors reach into the voxel landscape around them: empty each room.
local function clearRooms(root: Instance): ()
	for _, sector in root:GetChildren() do
		local ceiling = sector:FindFirstChild("Потолок сектора", true)
		if ceiling and ceiling:IsA("BasePart") then
			local height = ceiling.Position.Y
			-- A little past the walls: voxels are 4 studs and would otherwise poke through them.
			local size = Vector3.new(ceiling.Size.X + 6, height + 2, ceiling.Size.Z + 4)
			local frame = ceiling.CFrame - Vector3.new(0, height / 2, 0)
			workspace.Terrain:FillBlock(frame, size, Enum.Material.Air)
		end
	end
end

-- The hall is taller than the cave it was carved in: empty everything under its ceiling.
local function clearHall(root: Instance): ()
	local ceiling = root:FindFirstChild("Перекрытие")
	if ceiling and ceiling:IsA("BasePart") then
		local height = ceiling.Position.Y
		local center = CFrame.new(ceiling.Position.X, height / 2, ceiling.Position.Z)
		workspace.Terrain:FillCylinder(center, height, 80, Enum.Material.Air)
	end
end

-- Yields while meshes download: call from its own thread.
function Decor.build(root: Instance): number
	clearRooms(root)
	clearHall(root)
	local built = 0
	for _, mark in root:GetDescendants() do
		local piece = mark:GetAttribute("KitPiece")
		if not mark:IsA("BasePart") or type(piece) ~= "string" then
			continue
		end
		local source = template(piece)
		if source then
			local mesh = source:Clone()
			mesh.Name = mark.Name
			mesh.Size = mark.Size
			mesh.CFrame = mark.CFrame
			mesh.Parent = mark.Parent
			mark:Destroy()
			built += 1
		end
	end
	return built
end

return Decor
