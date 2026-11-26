--!strict
-- Particle effects played when loot flies out. Price: bought with coins; Opened: reward for opened containers.
-- Style picks the animation in server/Visuals/DropEffects.luau. Key is stored in player saves.
export type DropEffect = {
	Key: string,
	-- Вид анимации: sparks, confetti, fire, frost, void, gold (см. DropEffects.luau).
	Style: string,
	Name: string,
	Details: string,
	Primary: Color3,
	Secondary: Color3,
	Count: number,
	Speed: number,
	Gravity: number,
	Price: number?,
	Opened: number?,
}

local DropEffects = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

DropEffects.DefaultEffect = "standard"
DropEffects.List = {
	{
		Key = "standard",
		Style = "sparks",
		Name = "Стандартный",
		Details = "Тёплые искры. Есть у всех.",
		Primary = rgb(255, 214, 120),
		Secondary = rgb(255, 150, 70),
		Count = 24,
		Speed = 16,
		Gravity = -30,
	},
	{
		Key = "confetti",
		Style = "confetti",
		Name = "Конфетти",
		Details = "Разноцветный праздничный залп.",
		Primary = rgb(255, 99, 160),
		Secondary = rgb(91, 232, 222),
		Count = 46,
		Speed = 20,
		Gravity = -36,
		Price = 15000,
	},
	{
		Key = "inferno",
		Style = "fire",
		Name = "Огненный взрыв",
		Details = "Награда за 50 открытых контейнеров.",
		Primary = rgb(255, 120, 40),
		Secondary = rgb(255, 60, 40),
		Count = 56,
		Speed = 26,
		Gravity = -10,
		Opened = 50,
	},
	{
		Key = "frost",
		Style = "frost",
		Name = "Ледяная пыль",
		Details = "Холодное сияние и медленно падающий иней.",
		Primary = rgb(190, 240, 255),
		Secondary = rgb(110, 190, 255),
		Count = 50,
		Speed = 14,
		Gravity = -6,
		Price = 60000,
	},
	{
		Key = "void",
		Style = "void",
		Name = "Разлом пустоты",
		Details = "Награда за 200 открытых контейнеров.",
		Primary = rgb(178, 120, 255),
		Secondary = rgb(60, 20, 120),
		Count = 64,
		Speed = 18,
		Gravity = 4,
		Opened = 200,
	},
	{
		Key = "gold",
		Style = "gold",
		Name = "Золотой дождь",
		Details = "Густой золотой каскад для самых богатых.",
		Primary = rgb(255, 224, 110),
		Secondary = rgb(230, 170, 40),
		Count = 80,
		Speed = 22,
		Gravity = -44,
		Price = 250000,
	},
} :: { DropEffect }

return DropEffects
