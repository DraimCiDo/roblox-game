--!strict
-- Creates the cartoon kit meshes: from the placeholders of the scene (KitPiece attribute) and on demand.
local AssetService = game:GetService("AssetService")

local Kit = require(script.Parent.Parent.Config.Kit)

local Decor = {}

local ATTEMPTS = 3

-- One mesh of a piece. `At` is its centre above the bottom centre of the whole piece, at native size.
type Mesh = {
	Mesh: string,
	Texture: string,
	Size: { number },
	At: { number },
	Color: Color3?,
	Material: Enum.Material?,
}

local templates: { [string]: MeshPart } = {}

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

-- A failed download is not cached: the next request for the mesh tries again.
local function template(data: Mesh): MeshPart?
	local cached = templates[data.Mesh]
	if cached then
		return cached
	end
	for attempt = 1, ATTEMPTS do
		local ok, result = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri(data.Mesh), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
			})
		end)
		if ok then
			result.TextureID = data.Texture
			if data.Color then
				result.Color = data.Color
				result.Material = data.Material :: Enum.Material
			end
			result.Anchored = true
			result.CanCollide = false
			result.CanTouch = false
			result.CanQuery = false
			templates[data.Mesh] = result
			return result
		end
		if attempt == ATTEMPTS then
			warn(`[Decor] Failed to load the mesh {data.Mesh}: {result}`)
		else
			task.wait(attempt * 2)
		end
	end
	return nil
end

-- Builds all meshes of a piece around `center`, stretched to `size`. Nothing appears unless all have loaded.
local function assemble(
	parent: Instance,
	name: string,
	piece: string,
	center: CFrame,
	size: Vector3,
	solid: boolean?
): boolean
	local entry = (Kit :: any)[piece]
	if not entry then
		warn(`[Decor] Unknown kit piece «{piece}»`)
		return false
	end
	local native = vector(entry.Size)
	local single = { Mesh = entry.Mesh, Texture = entry.Texture, Size = entry.Size, At = { 0, native.Y / 2, 0 } }
	local list: { Mesh } = entry.Parts or { single }
	if not entry.Parts then
		(single :: any).Color = entry.Color;
		(single :: any).Material = entry.Material
	end
	local sources: { MeshPart } = {}
	for _, data in list do
		local source = template(data)
		if not source then
			return false
		end
		table.insert(sources, source)
	end
	local scale = size / native
	for index, data in list do
		local mesh = sources[index]:Clone()
		mesh.Name = name
		mesh.CanCollide = solid == true
		mesh.Size = vector(data.Size) * scale
		mesh.CFrame = center * CFrame.new((vector(data.At) - Vector3.new(0, native.Y / 2, 0)) * scale)
		mesh.Parent = parent
	end
	return true
end

-- Puts a piece with its bottom centre at `foot`, scaled to `height`. It appears once downloaded.
function Decor.place(parent: Instance, piece: string, foot: CFrame, height: number, placed: (() -> ())?): ()
	task.spawn(function()
		local entry = (Kit :: any)[piece]
		local size = if entry then vector(entry.Size) * (height / entry.Size[2]) else Vector3.zero
		if assemble(parent, `Декор: {piece}`, piece, foot * CFrame.new(0, height / 2, 0), size) and placed then
			placed()
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
		-- Pieces of the scene are solid: nobody walks into them and the camera stays outside.
		if assemble(mark.Parent :: Instance, mark.Name, piece, mark.CFrame, mark.Size, true) then
			mark:Destroy()
			built += 1
		end
	end
	return built
end

return Decor
