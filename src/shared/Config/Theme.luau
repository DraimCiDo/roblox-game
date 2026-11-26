--!strict
-- Look of the 3D world: fonts and colors of screens, boards, signs and runtime decoration.
-- The player interface has its own theme in UiTheme.luau.
local Theme = {}

-- Both families contain Cyrillic.
Theme.Fonts = {
	Display = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy),
	Body = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold),
	Bold = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold),
	Mono = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy),
}

Theme.Colors = {
	Ink = Color3.fromRGB(24, 22, 56),
	Panel = Color3.fromRGB(54, 62, 130),
	Card = Color3.fromRGB(82, 96, 188),
	Edge = Color3.fromRGB(34, 32, 80),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(205, 213, 255),
	Cyan = Color3.fromRGB(80, 210, 255),
	Amber = Color3.fromRGB(255, 196, 56),
	Signal = Color3.fromRGB(92, 214, 72),
	Warning = Color3.fromRGB(255, 86, 94),
}

return Theme
