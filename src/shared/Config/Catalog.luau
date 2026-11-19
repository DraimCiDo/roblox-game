--!strict
export type ItemDefinition = { Name: string, Size: string, Style: string, Color: Color3 }
export type Perk = { Key: string, Name: string, Costs: { number }, Parent: string?, Required: number? }

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
Catalog.Odds = {
	{ 100, 0, 0, 0, 0 },
	{ 91, 9, 0, 0, 0 },
	{ 82, 15, 3, 0, 0 },
	{ 73, 20, 6, 1, 0 },
	{ 62, 24, 10, 3, 1 },
	{ 51, 28, 13, 6, 2 },
}
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
Catalog.Perks = {
	{ Key = "storage", Name = "Склад", Costs = { 2500, 6000, 15000, 35000, 80000, 160000, 300000 } },
	{ Key = "orders", Name = "Очередь", Costs = { 5000, 20000, 70000, 200000 } },
	{ Key = "odds", Name = "Шансы", Costs = { 3500, 12000, 35000, 100000, 260000 } },
	{ Key = "sale", Name = "Бонус продажи", Costs = { 4000, 12000, 35000, 90000, 220000 } },
	{ Key = "quickCollect", Name = "Быстрый сбор", Costs = { 18000 }, Parent = "storage", Required = 2 },
	{ Key = "quickSell", Name = "Быстрая продажа", Costs = { 25000 }, Parent = "sale", Required = 2 },
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
