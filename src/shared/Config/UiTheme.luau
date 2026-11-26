--!strict
-- Look of the player interface (cartoon style). World signs use Config/Theme instead.
-- Fonts must contain Cyrillic: Montserrat and Nunito do, most "game" fonts do not.
local function font(family: string, weight: Enum.FontWeight): Font
	return Font.new(`rbxasset://fonts/families/{family}.json`, weight)
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

return {
	Fonts = {
		Display = font("Montserrat", Enum.FontWeight.Heavy),
		Body = font("Nunito", Enum.FontWeight.Bold),
		Bold = font("Nunito", Enum.FontWeight.ExtraBold),
		Numbers = font("Montserrat", Enum.FontWeight.Heavy),
	},
	Colors = {
		-- Surfaces, from the outline and text shadow to raised cards.
		Ink = rgb(24, 22, 56),
		Panel = rgb(62, 72, 150),
		Card = rgb(82, 96, 188),
		Track = rgb(40, 44, 98),
		Edge = rgb(34, 32, 80),
		-- Text.
		Text = rgb(255, 255, 255),
		Muted = rgb(205, 213, 255),
		-- Accents.
		Blue = rgb(54, 182, 255),
		Yellow = rgb(255, 202, 44),
		Green = rgb(92, 214, 72),
		Red = rgb(255, 86, 94),
		Purple = rgb(186, 112, 255),
		Pink = rgb(255, 120, 190),
		Orange = rgb(255, 146, 52),
	},
	-- Corner radius in pixels.
	Radius = { Small = 8, Medium = 14, Large = 22 },
	-- Dark outline thickness in pixels.
	Stroke = { Thin = 2, Thick = 3 },
	-- Smallest height of anything tapped with a finger.
	TouchSize = 44,
}
