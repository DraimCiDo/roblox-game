--!nocheck
-- Places kit pieces into the scene as invisible placeholders. Rojo cannot sync a MeshPart's mesh into
-- Studio, so the server creates the meshes from these placeholders (src/server/World/Decor.luau).
-- KIT is the table of src/server/Config/Kit.luau, passed in by build.luau.

local Kit = {}

-- foot: CFrame of the bottom centre; the front of the mesh looks along its LookVector.
function Kit.place(parent, name, foot, height)
	local entry = assert(KIT[name], `unknown kit piece {name}`)
	local original = Vector3.new(entry.Size[1], entry.Size[2], entry.Size[3])
	local size = original * (height / original.Y)
	local mark = Instance.new("Part")
	mark.Name = `Декор: {name}`
	mark.Size = size
	mark.CFrame = foot * CFrame.new(0, size.Y / 2, 0)
	mark.Transparency = 1
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanTouch = false
	mark.CanQuery = false
	mark.CastShadow = false
	mark:SetAttribute("KitPiece", name)
	mark.Parent = parent
	return mark
end

return Kit
