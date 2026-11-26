--!nocheck
-- Cartoon mesh kit of the lab, generated in Roblox Studio (assets belong to the owner account).
-- place() adds a decorative mesh: no collision of its own, the plain parts around it keep the walls solid.

local KIT = {
	wall = {
		Mesh = "rbxassetid://125998160271247",
		Texture = "rbxassetid://102824701407012",
		Size = { 7.364, 10.49, 2 },
	},
	column = {
		Mesh = "rbxassetid://77446341796831",
		Texture = "rbxassetid://77947076056682",
		Size = { 3.994, 7.479, 4 },
	},
	pipe = {
		Mesh = "rbxassetid://105098420818470",
		Texture = "rbxassetid://84931594860050",
		Size = { 4.833, 3.695, 3 },
	},
	shelf = {
		Mesh = "rbxassetid://107123260222124",
		Texture = "rbxassetid://112777548451550",
		Size = { 8.559, 6.608, 4 },
	},
	terminal = {
		Mesh = "rbxassetid://129775451727305",
		Texture = "rbxassetid://81507311520159",
		Size = { 4.079, 7, 3.635 },
	},
	pedestal = {
		Mesh = "rbxassetid://114929213359813",
		Texture = "rbxassetid://99417088462608",
		Size = { 4.999, 2.77, 5 },
	},
}

local Kit = {}

-- foot: CFrame of the bottom centre; the front of the mesh looks along its LookVector.
function Kit.place(parent, name, foot, height)
	local entry = assert(KIT[name], `unknown kit piece {name}`)
	local original = Vector3.new(entry.Size[1], entry.Size[2], entry.Size[3])
	local size = original * (height / original.Y)
	local part = Instance.new("MeshPart")
	part.Name = `Декор: {name}`
	part.MeshId = entry.Mesh
	part.TextureID = entry.Texture
	part.InitialSize = original
	part.Size = size
	part.CFrame = foot * CFrame.new(0, size.Y / 2, 0)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CollisionFidelity = Enum.CollisionFidelity.Box
	part.Parent = parent
	return part
end

return Kit
