--!strict
-- Collections: name, the perk that boosts the bonus and the required item keys (see Items.luau).
return {
	{
		Name = "Ретроэлектроника",
		Perk = "collElectronics",
		Items = { "computer", "tv", "radio", "camera" },
	},
	{ Name = "Драгоценности", Perk = "collJewel", Items = { "gold", "glasses", "boombox", "diamond" } },
	{ Name = "Автопарк", Perk = "collCars", Items = { "rover", "coupe", "concept" } },
	{
		Name = "Лабораторные образцы",
		Perk = "collLab",
		Items = { "meteor", "crateGem", "core", "anomaly" },
	},
}
