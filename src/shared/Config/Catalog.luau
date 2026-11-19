--!strict
export type ItemDefinition = { Name: string, Size: string, Style: string, Color: Color3 }
export type Perk = {
	Key: string,
	Name: string,
	Branch: string,
	Costs: { number },
	-- Сколько контейнеров нужно открыть, чтобы купить соответствующий уровень.
	Opened: { number },
	Parent: string?,
	Required: number?,
	Describe: (level: number) -> string,
}

local function item(name: string, style: string, color: Color3, size: string?): ItemDefinition
	return { Name = name, Size = size or "small", Style = style, Color = color }
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Catalog = {}

Catalog.Kinds = { "box", "crate", "safe", "cargo", "secret" }
Catalog.Containers = {
	box = "Картонная коробка",
	crate = "Деревянный ящик",
	safe = "Сейф",
	cargo = "Грузовой контейнер",
	secret = "Секретный контейнер",
} :: { [string]: string }
Catalog.Variants = {
	box = "Хрупкая коробка",
	crate = "Экспедиционный ящик",
	safe = "Резервный сейф",
	cargo = "Груз повышенной ценности",
	secret = "Аномальный контейнер",
} :: { [string]: string }
-- Числовые эффекты перков: одни и те же значения использует сервер и подсказки в интерфейсе.
Catalog.Effects = {
	SaleStep = 0.05,
	DeliveryStep = 0.06,
	DiscountStep = 0.04,
	QualityStep = 0.1,
	LootStep = 0.06,
	VariantBase = 5,
	VariantStep = 2,
	CollectionStep = 0.25,
	DailyStep = 0.5,
	OddsStep = 0.12,
}

-- Уровень лаборатории растёт с числом открытых контейнеров и открывает более редкие типы.
Catalog.Levels = { 0, 12, 30, 70, 130, 220, 360, 560, 840, 1250, 1800, 2600, 3600, 5000, 7000 }
Catalog.TierUnlock = { 1, 2, 4, 8, 12 }
Catalog.TierWeights = { 100, 38, 14, 4.5, 1.4 }

function Catalog.level(opened: number): number
	local level = 1
	for index, need in Catalog.Levels do
		if opened >= need then
			level = index
		end
	end
	return level
end

-- Возвращает уровень, порог его начала и порог следующего (nil на максимальном уровне).
function Catalog.levelRange(opened: number): (number, number, number?)
	local level = Catalog.level(opened)
	return level, Catalog.Levels[level], Catalog.Levels[level + 1]
end

-- Вероятности типов контейнеров в процентах: учитывают уровень лаборатории и перк шансов.
function Catalog.odds(opened: number, oddsLevel: number): { number }
	local level = Catalog.level(opened)
	local weights: { number } = {}
	local total = 0
	for tier, base in Catalog.TierWeights do
		local weight = if level < Catalog.TierUnlock[tier]
			then 0
			else base * (1 + Catalog.Effects.OddsStep * oddsLevel) ^ (tier - 1)
		weights[tier] = weight
		total += weight
	end
	for tier, weight in weights do
		weights[tier] = weight / total * 100
	end
	return weights
end

Catalog.Items = {
	ball = item("Футбольный мяч", "ball", rgb(232, 235, 224)),
	trash = item("Мусорный мешок", "ball", rgb(62, 66, 71)),
	bell = item("Звонок", "bell", rgb(230, 191, 101)),
	bowl = item("Миска", "bowl", rgb(88, 173, 207)),
	painting = item("Картина", "picture", rgb(70, 130, 150)),
	fish = item("Рыба", "fish", rgb(224, 135, 70)),
	dumbbell = item("Гантеля", "dumbbell", rgb(116, 140, 151)),
	brush = item("Туалетный ёршик", "brush", rgb(216, 218, 221)),
	parcel = item("Коробка", "block", rgb(177, 131, 78)),
	elfhat = item("Шляпа эльфа", "hat", rgb(89, 160, 96)),
	flower = item("Цветок", "flower", rgb(231, 125, 159)),
	meteor = item("Метеорит", "ball", rgb(153, 99, 72)),
	bin = item("Урна", "bowl", rgb(93, 121, 108)),
	computer = item("Старый компьютер", "screen", rgb(201, 190, 170)),
	tv = item("Ретро ТВ", "screen", rgb(175, 131, 105), "large"),
	fan = item("Вентилятор", "fan", rgb(111, 168, 184)),
	trophy = item("Трофей", "bell", rgb(244, 191, 65)),
	rockart = item("Скала — картина", "picture", rgb(120, 104, 88)),
	radio = item("Радио", "radio", rgb(158, 118, 87)),
	camera = item("Камера", "camera", rgb(77, 85, 98)),
	gold = item("Золотой слиток", "bar", rgb(255, 196, 57)),
	dollars = item("Доллары", "block", rgb(107, 166, 111)),
	gpu = item("Видеокарта", "fan", rgb(114, 125, 148)),
	glasses = item("Золотые очки", "dumbbell", rgb(232, 184, 74)),
	boombox = item("Алмазный магнитофон", "radio", rgb(105, 211, 232)),
	button = item("Серебряная кнопка", "picture", rgb(193, 208, 223)),
	console = item("PlayStation 5", "tower", rgb(220, 222, 226)),
	phone = item("Poco X3 Turbo Max", "screen", rgb(104, 111, 176)),
	davinci = item("Картина да Винчи", "picture", rgb(190, 132, 62), "large"),
	bomb = item("Бомба", "ball", rgb(52, 56, 64)),
	rover = item("Лабораторный ровер", "car", rgb(231, 166, 73), "car"),
	coupe = item("Спортивное купе", "car", rgb(75, 180, 175), "car"),
	robot = item("Робот-сортировщик", "tower", rgb(98, 139, 199), "large"),
	crateGem = item("Образец кварца", "gem", rgb(215, 156, 232)),
	diamond = item("Алмаз", "gem", rgb(115, 233, 250)),
	core = item("Энергетическое ядро", "ball", rgb(199, 103, 246), "large"),
	concept = item("Экспериментальный автомобиль", "car", rgb(208, 108, 239), "car"),
	anomaly = item("Аномальный образец", "gem", rgb(117, 248, 162)),
	prism = item("Лабораторная призма", "gem", rgb(247, 148, 116)),
} :: { [string]: ItemDefinition }
Catalog.Collections = {
	{ Name = "Ретроэлектроника", Items = { "computer", "tv", "radio", "camera" } },
	{ Name = "Драгоценности", Items = { "gold", "glasses", "boombox", "diamond" } },
	{ Name = "Автопарк", Items = { "rover", "coupe", "concept" } },
	{ Name = "Лабораторные образцы", Items = { "meteor", "crateGem", "core", "anomaly" } },
}
Catalog.DisplaySizes = { "small", "small", "small", "small", "small", "small", "large", "car" }
Catalog.Branches = {
	{ Key = "logistics", Name = "Логистика" },
	{ Key = "storage", Name = "Склад" },
	{ Key = "trade", Name = "Торговля" },
	{ Key = "luck", Name = "Удача" },
}
local E = Catalog.Effects
Catalog.Perks = {
	{
		Key = "orders",
		Name = "Очередь",
		Branch = "logistics",
		Costs = { 16000, 58000, 200000, 620000 },
		Opened = { 6, 40, 200, 700 },
		Describe = function(level)
			return `Заказов одновременно: {1 + level}`
		end,
	},
	{
		Key = "delivery",
		Name = "Быстрая доставка",
		Branch = "logistics",
		Costs = { 26000, 90000, 180000, 360000, 1100000 },
		Opened = { 15, 70, 220, 520, 1000 },
		Parent = "orders",
		Required = 1,
		Describe = function(level)
			return `Доставка быстрее на {math.round(level * E.DeliveryStep * 100)}%`
		end,
	},
	{
		Key = "discount",
		Name = "Скидка на заказы",
		Branch = "logistics",
		Costs = { 64000, 220000, 680000, 1400000, 2700000 },
		Opened = { 60, 220, 560, 1100, 1900 },
		Parent = "delivery",
		Required = 2,
		Describe = function(level)
			return `Заказы дешевле на {math.round(level * E.DiscountStep * 100)}%`
		end,
	},
	{
		Key = "daily",
		Name = "Щедрая награда",
		Branch = "logistics",
		Costs = { 15000, 50000, 150000 },
		Opened = { 40, 300, 1000 },
		Parent = "orders",
		Required = 1,
		Describe = function(level)
			return `Ежедневная награда ×{1 + level * E.DailyStep}`
		end,
	},
	{
		Key = "storage",
		Name = "Склад",
		Branch = "storage",
		Costs = { 10000, 20000, 70000, 140000, 480000, 960000, 1900000 },
		Opened = { 0, 8, 20, 50, 110, 220, 420 },
		Describe = function(level)
			return `{15 + level * 5} мест на складе`
		end,
	},
	{
		Key = "quickCollect",
		Name = "Быстрый сбор",
		Branch = "storage",
		Costs = { 17500 },
		Opened = { 25 },
		Parent = "storage",
		Required = 2,
		Describe = function(level)
			return if level > 0
				then "Вся добыча на склад одним действием"
				else "Сбор всей добычи одним действием"
		end,
	},
	{
		Key = "sale",
		Name = "Бонус продажи",
		Branch = "trade",
		Costs = { 8000, 16000, 58000, 120000, 400000, 800000, 1600000, 3200000, 9900000, 20000000 },
		Opened = { 0, 5, 18, 45, 90, 160, 270, 430, 650, 950 },
		Describe = function(level)
			return `+{math.round(level * E.SaleStep * 100)}% к цене продажи`
		end,
	},
	{
		Key = "quickSell",
		Name = "Быстрая продажа",
		Branch = "trade",
		Costs = { 40000 },
		Opened = { 80 },
		Parent = "sale",
		Required = 3,
		Describe = function(level)
			return if level > 0
				then "Вся добыча продаётся одним действием"
				else "Продажа всей добычи одним действием"
		end,
	},
	{
		Key = "collection",
		Name = "Эксперт коллекций",
		Branch = "trade",
		Costs = { 120000, 370000, 740000, 1500000 },
		Opened = { 250, 600, 1200, 2100 },
		Parent = "sale",
		Required = 5,
		Describe = function(level)
			return `Бонус коллекций ×{1 + level * E.CollectionStep}`
		end,
	},
	{
		Key = "odds",
		Name = "Редкие контейнеры",
		Branch = "luck",
		Costs = { 19000, 70000, 240000, 480000, 1500000, 3000000 },
		Opened = { 10, 40, 130, 340, 760, 1500 },
		Describe = function(level)
			return `Редкие типы чаще · ступень {level}`
		end,
	},
	{
		Key = "quality",
		Name = "Удачный осмотр",
		Branch = "luck",
		Costs = { 64000, 220000, 440000, 1400000, 2700000 },
		Opened = { 40, 130, 300, 640, 1200 },
		Parent = "odds",
		Required = 2,
		Describe = function(level)
			return `{math.round(level * E.QualityStep * 100)}% шанс взять лучшее из двух качеств`
		end,
	},
	{
		Key = "bonusLoot",
		Name = "Двойная находка",
		Branch = "luck",
		Costs = { 150000, 300000, 930000, 1900000 },
		Opened = { 100, 320, 800, 1600 },
		Parent = "quality",
		Required = 2,
		Describe = function(level)
			return `{math.round(level * E.LootStep * 100)}% шанс лишнего предмета`
		end,
	},
	{
		Key = "variant",
		Name = "Особые заказы",
		Branch = "luck",
		Costs = { 140000, 280000, 870000, 1700000 },
		Opened = { 170, 520, 1200, 2300 },
		Parent = "bonusLoot",
		Required = 1,
		Describe = function(level)
			return `Шанс вариации контейнера {E.VariantBase + level * E.VariantStep}%`
		end,
	},
} :: { Perk }

function Catalog.condition(quality: number): string
	if quality <= 20 then
		return "Плохое"
	elseif quality <= 49 then
		return "Изношенное"
	elseif quality <= 70 then
		return "Нормальное"
	elseif quality <= 99 then
		return "Хорошее"
	end
	return "Идеальное"
end

return Catalog
