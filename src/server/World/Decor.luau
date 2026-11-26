--!strict
-- Turns the kit placeholders of the scene (parts with a KitPiece attribute) into meshes.
local AssetService = game:GetService("AssetService")

local Kit = require(script.Parent.Parent.Config.Kit)

local Decor = {}

local templates: { [string]: MeshPart | false } = {}

local function template(piece: string): MeshPart?
	local cached = templates[piece]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local entry = (Kit :: any)[piece]
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(entry.Mesh), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
		})
	end)
	if not ok then
		warn(`[Decor] Failed to load the «{piece}» mesh: {result}`)
		templates[piece] = false
		return nil
	end
	result.TextureID = entry.Texture
	result.Anchored = true
	result.CanCollide = false
	result.CanTouch = false
	result.CanQuery = false
	templates[piece] = result
	return result
end

-- Yields while meshes download: call from its own thread.
function Decor.build(root: Instance): number
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
