--!strict
-- Item condition names and colors by quality (1-100): the first entry whose Max is not below the quality wins.
return {
	{ Max = 20, Name = "Плохое", Color = Color3.fromRGB(160, 165, 196) },
	{ Max = 49, Name = "Изношенное", Color = Color3.fromRGB(110, 214, 134) },
	{ Max = 70, Name = "Нормальное", Color = Color3.fromRGB(80, 194, 255) },
	{ Max = 99, Name = "Хорошее", Color = Color3.fromRGB(190, 124, 255) },
	{ Max = 100, Name = "Идеальное", Color = Color3.fromRGB(255, 200, 60) },
}
