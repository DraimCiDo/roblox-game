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
	-- Дополнительные условия: уровни других навыков, которые нужно изучить заранее.
	Needs: { { Key: string, Level: number } }?,
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
	CashbackStep = 0.03,
	RecyclerStep = 15,
	BulkStep = 0.05,
	HaggleStep = 0.04,
	JunkStep = 0.1,
	RarityStep = 0.12,
	PerfectStep = 0.015,
	FloorStep = 5,
	VariantLootStep = 1,
	TierLuckStep = 0.25,
	MasteryStep = 0.1,
	SpecialtyStep = 0.25,
	GalleryStep = 0.003,
	MuseumStep = 0.05,
	SteadyStep = 0.12,
	SlowStep = 0.08,
	GrantStep = 0.04,
	JackpotStep = 0.02,
	ExpressStep = 0.08,
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

-- Навыки, повышающие вероятность ящика, сейфа, грузового и секретного контейнеров (индекс = тип контейнера).
Catalog.TierLuckPerks = { "", "crateLuck", "safeLuck", "cargoLuck", "secretLuck" }

-- Вероятности типов контейнеров в процентах: учитывают уровень лаборатории и навыки шансов.
function Catalog.odds(opened: number, perks: { [string]: number }): { number }
	local level = Catalog.level(opened)
	local weights: { number } = {}
	local total = 0
	for tier, base in Catalog.TierWeights do
		local weight = 0
		if level >= Catalog.TierUnlock[tier] then
			weight = base * (1 + Catalog.Effects.OddsStep * (perks.odds or 0)) ^ (tier - 1)
			local luck = Catalog.TierLuckPerks[tier]
			if luck ~= "" then
				weight *= 1 + Catalog.Effects.TierLuckStep * (perks[luck] or 0)
			end
		end
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
Catalog.DisplaySizes = { "small", "small", "small", "small", "small", "small", "large", "car" }
-- <PERKS:BEGIN> Блок создаётся scripts/gen_perks.py, вручную не править.
Catalog.Branches = {
	{ Key = "logistics", Name = "Логистика" },
	{ Key = "storage", Name = "Склад" },
	{ Key = "trade", Name = "Торговля" },
	{ Key = "luck", Name = "Удача" },
	{ Key = "mastery", Name = "Мастерство" },
	{ Key = "collections", Name = "Коллекции" },
	{ Key = "lockpick", Name = "Взлом" },
}
local E = Catalog.Effects
Catalog.Perks = {
	{
		Key = "orders",
		Name = "Очередь",
		Branch = "logistics",
		Costs = { 19200, 70000, 240000, 740000 },
		Opened = { 6, 40, 200, 700 },
		Describe = function(level)
			return `Заказов одновременно: {1 + level}`
		end,
	},
	{
		Key = "delivery",
		Name = "Быстрая доставка",
		Branch = "logistics",
		Costs = { 41000, 140000, 280000, 560000, 1700000 },
		Opened = { 15, 70, 220, 520, 1000 },
		Parent = "orders",
		Required = 1,
		Describe = function(level)
			return `Доставка быстрее на {math.round(level * E.DeliveryStep * 100)}%`
		end,
	},
	{
		Key = "express",
		Name = "Срочная доставка",
		Branch = "logistics",
		Costs = { 120000, 240000, 740000, 1500000 },
		Opened = { 150, 400, 900, 1800 },
		Parent = "delivery",
		Required = 3,
		Describe = function(level)
			return `{math.round(level * E.ExpressStep * 100)}% шанс мгновенной доставки`
		end,
	},
	{
		Key = "discount",
		Name = "Скидка на заказы",
		Branch = "logistics",
		Costs = { 150000, 500000, 1500000, 3100000, 6200000 },
		Opened = { 60, 220, 560, 1100, 1900 },
		Parent = "delivery",
		Required = 2,
		Describe = function(level)
			return `Заказы дешевле на {math.round(level * E.DiscountStep * 100)}%`
		end,
	},
	{
		Key = "cashback",
		Name = "Кэшбэк",
		Branch = "logistics",
		Costs = { 230000, 450000, 1400000, 2800000 },
		Opened = { 120, 400, 1000, 2000 },
		Parent = "discount",
		Required = 2,
		Describe = function(level)
			return `Возврат {math.round(level * E.CashbackStep * 100)}% цены каждого заказа`
		end,
	},
	{
		Key = "daily",
		Name = "Щедрая награда",
		Branch = "logistics",
		Costs = { 17500, 60000, 190000 },
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
		Costs = { 11200, 22000, 82000, 160000, 560000, 1100000, 2200000 },
		Opened = { 0, 8, 20, 50, 110, 220, 420 },
		Describe = function(level)
			return `{15 + level * 5} мест на складе`
		end,
	},
	{
		Key = "quickCollect",
		Name = "Быстрый сбор",
		Branch = "storage",
		Costs = { 20000 },
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
		Key = "recycler",
		Name = "Утилизатор",
		Branch = "storage",
		Costs = { 73000, 250000, 500000, 1500000 },
		Opened = { 60, 200, 520, 1100 },
		Parent = "quickCollect",
		Required = 1,
		Describe = function(level)
			return `Находки качества до {level * E.RecyclerStep} продаются сами`
		end,
	},
	{
		Key = "gallery",
		Name = "Галерея",
		Branch = "storage",
		Costs = { 58000, 200000, 400000, 1200000, 2500000 },
		Opened = { 30, 120, 380, 900, 1800 },
		Parent = "storage",
		Required = 3,
		Describe = function(level)
			return `Витрины приносят {string.format("%.1f", level * E.GalleryStep * 100)}% цены экспоната в минуту`
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
		Key = "bulk",
		Name = "Оптовик",
		Branch = "trade",
		Costs = { 150000, 300000, 930000, 1900000 },
		Opened = { 150, 420, 900, 1700 },
		Parent = "quickSell",
		Required = 1,
		Describe = function(level)
			return `Быстрая продажа +{math.round(level * E.BulkStep * 100)}% к цене`
		end,
	},
	{
		Key = "haggle",
		Name = "Торг",
		Branch = "trade",
		Costs = { 70000, 240000, 480000, 1500000, 3000000 },
		Opened = { 40, 140, 360, 800, 1500 },
		Parent = "sale",
		Required = 4,
		Describe = function(level)
			return `+{math.round(level * E.HaggleStep * 100)}% к цене находок качества 71+`
		end,
	},
	{
		Key = "jackpot",
		Name = "Джекпот",
		Branch = "trade",
		Costs = { 190000, 380000, 1200000, 2400000 },
		Opened = { 180, 500, 1100, 2200 },
		Parent = "haggle",
		Required = 2,
		Describe = function(level)
			return `{math.round(level * E.JackpotStep * 100)}% шанс удвоить выручку с предмета`
		end,
	},
	{
		Key = "junk",
		Name = "Старьёвщик",
		Branch = "trade",
		Costs = { 41000, 140000, 280000, 870000 },
		Opened = { 25, 90, 260, 640 },
		Parent = "sale",
		Required = 2,
		Describe = function(level)
			return `+{math.round(level * E.JunkStep * 100)}% к цене находок качества до 49`
		end,
	},
	{
		Key = "odds",
		Name = "Редкие контейнеры",
		Branch = "luck",
		Costs = { 19200, 70000, 240000, 480000, 1500000, 3000000 },
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
		Key = "floor",
		Name = "Строгий отбор",
		Branch = "luck",
		Costs = { 130000, 260000, 810000, 1600000 },
		Opened = { 90, 300, 700, 1400 },
		Parent = "quality",
		Required = 2,
		Describe = function(level)
			return `Качество находок не ниже {level * E.FloorStep}`
		end,
	},
	{
		Key = "perfect",
		Name = "Перфекционист",
		Branch = "luck",
		Costs = { 200000, 620000, 1200000, 3600000 },
		Opened = { 220, 700, 1500, 2800 },
		Parent = "quality",
		Required = 3,
		Describe = function(level)
			return `+{string.format("%.1f", level * E.PerfectStep * 100)}% шанс идеального качества`
		end,
	},
	{
		Key = "rarity",
		Name = "Редкая добыча",
		Branch = "luck",
		Costs = { 64000, 220000, 440000, 1400000, 2700000 },
		Opened = { 60, 200, 520, 1100, 2000 },
		Parent = "quality",
		Required = 1,
		Describe = function(level)
			return `Редкие предметы чаще на {math.round(level * E.RarityStep * 100)}%`
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
	{
		Key = "variantLoot",
		Name = "Богатые вариации",
		Branch = "luck",
		Costs = { 460000, 930000 },
		Opened = { 900, 2400 },
		Parent = "variant",
		Required = 2,
		Describe = function(level)
			return `+{level * E.VariantLootStep} предмет в контейнерах-вариациях`
		end,
	},
	{
		Key = "crateLuck",
		Name = "Охотник за ящиками",
		Branch = "mastery",
		Costs = { 47000, 160000, 320000, 990000 },
		Opened = { 30, 120, 330, 700 },
		Parent = "odds",
		Required = 2,
		Describe = function(level)
			return `Ящики выпадают чаще на {math.round(level * E.TierLuckStep * 100)}%`
		end,
	},
	{
		Key = "safeLuck",
		Name = "Охотник за сейфами",
		Branch = "mastery",
		Costs = { 140000, 280000, 870000, 1700000 },
		Opened = { 120, 400, 900, 1800 },
		Parent = "crateLuck",
		Required = 2,
		Describe = function(level)
			return `Сейфы выпадают чаще на {math.round(level * E.TierLuckStep * 100)}%`
		end,
	},
	{
		Key = "cargoLuck",
		Name = "Охотник за грузом",
		Branch = "mastery",
		Costs = { 230000, 700000, 1400000, 4000000 },
		Opened = { 400, 1100, 2200, 3800 },
		Parent = "safeLuck",
		Required = 2,
		Describe = function(level)
			return `Грузовые чаще на {math.round(level * E.TierLuckStep * 100)}%`
		end,
	},
	{
		Key = "secretLuck",
		Name = "Охотник за тайнами",
		Branch = "mastery",
		Costs = { 540000, 1600000, 3100000, 6300000 },
		Opened = { 1200, 2600, 4400, 6600 },
		Parent = "cargoLuck",
		Required = 2,
		Describe = function(level)
			return `Секретные чаще на {math.round(level * E.TierLuckStep * 100)}%`
		end,
	},
	{
		Key = "boxMaster",
		Name = "Знаток коробок",
		Branch = "mastery",
		Costs = { 29000, 100000, 200000, 620000 },
		Opened = { 20, 80, 240, 600 },
		Parent = "sale",
		Required = 2,
		Describe = function(level)
			return `+{math.round(level * E.MasteryStep * 100)}% к цене находок из коробок`
		end,
	},
	{
		Key = "crateMaster",
		Name = "Знаток ящиков",
		Branch = "mastery",
		Costs = { 100000, 200000, 620000, 1200000 },
		Opened = { 80, 260, 640, 1300 },
		Parent = "boxMaster",
		Required = 2,
		Needs = { { Key = "crateLuck", Level = 1 } },
		Describe = function(level)
			return `+{math.round(level * E.MasteryStep * 100)}% к цене находок из ящиков`
		end,
	},
	{
		Key = "safeMaster",
		Name = "Знаток сейфов",
		Branch = "mastery",
		Costs = { 170000, 530000, 1100000, 3100000 },
		Opened = { 300, 800, 1700, 3000 },
		Parent = "crateMaster",
		Required = 2,
		Needs = { { Key = "safeLuck", Level = 1 } },
		Describe = function(level)
			return `+{math.round(level * E.MasteryStep * 100)}% к цене находок из сейфов`
		end,
	},
	{
		Key = "cargoMaster",
		Name = "Знаток груза",
		Branch = "mastery",
		Costs = { 400000, 810000, 2300000, 4700000 },
		Opened = { 900, 2000, 3600, 5600 },
		Parent = "safeMaster",
		Required = 2,
		Needs = { { Key = "cargoLuck", Level = 1 } },
		Describe = function(level)
			return `+{math.round(level * E.MasteryStep * 100)}% к цене находок из грузовых`
		end,
	},
	{
		Key = "secretMaster",
		Name = "Знаток тайн",
		Branch = "mastery",
		Costs = { 620000, 1800000, 3600000, 7200000 },
		Opened = { 2400, 4200, 6000, 8000 },
		Parent = "cargoMaster",
		Required = 2,
		Needs = { { Key = "secretLuck", Level = 1 } },
		Describe = function(level)
			return `+{math.round(level * E.MasteryStep * 100)}% к цене находок из секретных`
		end,
	},
	{
		Key = "collection",
		Name = "Эксперт коллекций",
		Branch = "collections",
		Costs = { 120000, 370000, 740000, 1500000 },
		Opened = { 250, 600, 1200, 2100 },
		Parent = "sale",
		Required = 5,
		Describe = function(level)
			return `Бонус коллекций ×{1 + level * E.CollectionStep}`
		end,
	},
	{
		Key = "collElectronics",
		Name = "Знаток электроники",
		Branch = "collections",
		Costs = { 130000, 400000, 810000 },
		Opened = { 350, 800, 1500 },
		Parent = "collection",
		Required = 1,
		Describe = function(level)
			return `Бонус «Ретроэлектроники» ×{1 + level * E.SpecialtyStep}`
		end,
	},
	{
		Key = "collJewel",
		Name = "Знаток драгоценностей",
		Branch = "collections",
		Costs = { 150000, 460000, 930000 },
		Opened = { 500, 1100, 1900 },
		Parent = "collection",
		Required = 1,
		Describe = function(level)
			return `Бонус «Драгоценностей» ×{1 + level * E.SpecialtyStep}`
		end,
	},
	{
		Key = "collCars",
		Name = "Знаток автопарка",
		Branch = "collections",
		Costs = { 280000, 560000, 1600000 },
		Opened = { 900, 1700, 2800 },
		Parent = "collection",
		Required = 2,
		Describe = function(level)
			return `Бонус «Автопарка» ×{1 + level * E.SpecialtyStep}`
		end,
	},
	{
		Key = "collLab",
		Name = "Знаток образцов",
		Branch = "collections",
		Costs = { 330000, 650000, 1900000 },
		Opened = { 1300, 2300, 3600 },
		Parent = "collection",
		Required = 2,
		Describe = function(level)
			return `Бонус «Лабораторных образцов» ×{1 + level * E.SpecialtyStep}`
		end,
	},
	{
		Key = "museum",
		Name = "Музейный фонд",
		Branch = "collections",
		Costs = { 310000, 620000, 1800000, 3600000 },
		Opened = { 700, 1500, 2600, 4000 },
		Parent = "collection",
		Required = 3,
		Needs = { { Key = "gallery", Level = 2 } },
		Describe = function(level)
			return `Каждая полная коллекция даёт +{math.round(level * E.MuseumStep * 100)}% к доходу галереи`
		end,
	},
	{
		Key = "steady",
		Name = "Твёрдая рука",
		Branch = "lockpick",
		Costs = { 120000, 370000, 740000, 1500000 },
		Opened = { 200, 600, 1300, 2400 },
		Parent = "safeLuck",
		Required = 1,
		Describe = function(level)
			return `Зелёная зона сейфа шире на {math.round(level * E.SteadyStep * 100)}%`
		end,
	},
	{
		Key = "slow",
		Name = "Замедление",
		Branch = "lockpick",
		Costs = { 170000, 530000, 1500000 },
		Opened = { 500, 1300, 2600 },
		Parent = "steady",
		Required = 2,
		Describe = function(level)
			return `Указатель сейфа медленнее на {math.round(level * E.SlowStep * 100)}%`
		end,
	},
	{
		Key = "grant",
		Name = "Научный грант",
		Branch = "logistics",
		Costs = { 300000, 930000, 1900000, 5400000 },
		Opened = { 300, 800, 1700, 3200 },
		Parent = "cashback",
		Required = 2,
		Describe = function(level)
			return `Улучшения навыков дешевле на {math.round(level * E.GrantStep * 100)}%`
		end,
	},
} :: { Perk }
-- <PERKS:END>

local perkIndex: { [string]: Perk } = {}
for _, perk in Catalog.Perks do
	perkIndex[perk.Key] = perk
end

function Catalog.perk(key: string): Perk?
	return perkIndex[key]
end

-- Стоимость следующего уровня навыка с учётом навыка «Научный грант».
function Catalog.perkCost(perk: Perk, level: number, perks: { [string]: number }): number?
	local base = perk.Costs[level + 1]
	if not base then
		return nil
	end
	return math.round(base * (1 - Catalog.Effects.GrantStep * (perks.grant or 0)) / 10) * 10
end

-- Проверка условий открытия уровня навыка: родитель, дополнительные навыки и число открытых контейнеров.
-- Возвращает причину отказа или nil, если навык доступен.
function Catalog.perkLock(perk: Perk, level: number, perks: { [string]: number }, opened: number): string?
	if perk.Parent and (perks[perk.Parent] or 0) < (perk.Required or 1) then
		local parent = perkIndex[perk.Parent]
		return `Нужен «{if parent then parent.Name else perk.Parent}» · ур. {perk.Required or 1}`
	end
	if perk.Needs then
		for _, need in perk.Needs do
			if (perks[need.Key] or 0) < need.Level then
				local other = perkIndex[need.Key]
				return `Нужен «{if other then other.Name else need.Key}» · ур. {need.Level}`
			end
		end
	end
	local need = perk.Opened[level + 1]
	if need and opened < need then
		return `Откройте {need} контейнеров · сейчас {opened}`
	end
	return nil
end

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
