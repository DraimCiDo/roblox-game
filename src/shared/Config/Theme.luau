--!strict
-- Общая тема «Лаборатория CORPA»: шрифты и базовые цвета для интерфейса игрока (Style)
-- и для надписей в мире (экраны терминалов, табло, указатели), чтобы всё было в одном стиле.
local Theme = {}

-- Шрифты с кириллицей (проверены в Studio): Jura — техничные заголовки, Roboto Condensed — текст,
-- Roboto Mono — цифры-показания.
Theme.Fonts = {
	Display = Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Medium),
	Bold = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold),
	Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
}

Theme.Colors = {
	Ink = Color3.fromRGB(6, 9, 14),
	Panel = Color3.fromRGB(14, 19, 27),
	Card = Color3.fromRGB(22, 30, 41),
	Edge = Color3.fromRGB(48, 68, 88),
	Text = Color3.fromRGB(232, 242, 250),
	Muted = Color3.fromRGB(134, 154, 175),
	Cyan = Color3.fromRGB(72, 222, 255),
	Amber = Color3.fromRGB(255, 184, 64),
	Signal = Color3.fromRGB(74, 232, 152),
	Warning = Color3.fromRGB(255, 86, 106),
}

return Theme
