--!strict
-- Cartoon mesh kit of the lab, generated in Roblox Studio (assets belong to the owner account).
-- Size is the native size of the mesh; pieces are scaled to the height asked for by the map builders.
-- Used by scripts/map/kit.luau (placeholders in the scene) and World/Decor.luau (meshes at runtime).
return {
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
	reactor = {
		Mesh = "rbxassetid://92208032363128",
		Texture = "rbxassetid://96121073071684",
		Size = { 13.899, 20, 13.873 },
	},
	gate = {
		Mesh = "rbxassetid://111944891260146",
		Texture = "rbxassetid://104495328030278",
		Size = { 5.565, 6.803, 3 },
	},
	crates = {
		Mesh = "rbxassetid://82488677714928",
		Texture = "rbxassetid://95510977292541",
		Size = { 3.294, 5, 3.03 },
	},
	plant = {
		Mesh = "rbxassetid://105485218945505",
		Texture = "rbxassetid://114610613080386",
		Size = { 4, 4.363, 3.981 },
	},
	bench = {
		Mesh = "rbxassetid://135246518125180",
		Texture = "rbxassetid://131949955634027",
		Size = { 3.434, 3, 2.394 },
	},
	-- Dirt of the mopping job. Size sets the proportions the mesh is stretched to: flat and wide.
	-- No texture: the generated ones looked pale, a mud material reads better.
	mud = {
		Mesh = "rbxassetid://100360730243009",
		Texture = "",
		Color = Color3.fromRGB(150, 104, 64),
		Material = Enum.Material.Mud,
		Size = { 5, 0.4, 5 },
	},
	clump = {
		Mesh = "rbxassetid://82030224166452",
		Texture = "",
		Color = Color3.fromRGB(118, 80, 50),
		Material = Enum.Material.Mud,
		Size = { 1.6, 0.6, 1.5 },
	},
	-- Pieces of several meshes: `At` is the centre of a mesh above the bottom centre of the piece.
	counter = {
		Size = { 4.749, 3.2, 2.822 },
		Parts = {
			{
				Mesh = "rbxassetid://102019052078116",
				Texture = "rbxassetid://87820524277039",
				Size = { 4.687, 3.2, 2.779 },
				At = { -0.007, 1.6, -0.016 },
			},
			{
				Mesh = "rbxassetid://139542725271168",
				Texture = "rbxassetid://138916334306435",
				Size = { 4.749, 0.421, 2.822 },
				At = { 0, 2.361, 0 },
			},
		},
	},
	arm = {
		Size = { 2.764, 5.163, 4 },
		Parts = {
			{
				Mesh = "rbxassetid://126397535397492",
				Texture = "rbxassetid://105489271632508",
				Size = { 2.764, 1.067, 2.791 },
				At = { 0, 0.534, 0.333 },
			},
			{
				Mesh = "rbxassetid://72564723184329",
				Texture = "rbxassetid://74853238897328",
				Size = { 1.631, 4.711, 3.034 },
				At = { 0.002, 2.808, 0.483 },
			},
			{
				Mesh = "rbxassetid://74619867443782",
				Texture = "rbxassetid://101623512574341",
				Size = { 1.021, 2.647, 1.284 },
				At = { 0, 2.68, -1.358 },
			},
		},
	},
}
