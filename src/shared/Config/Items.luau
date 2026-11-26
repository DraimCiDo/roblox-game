--!strict
-- Every item: display name, size (small, large or car), preview model style and color.
-- The key is stored in player saves: never rename it. Prices and drop weights are in server/Config/Loot.luau.
export type ItemDefinition = { Name: string, Size: string, Style: string, Color: Color3 }

local function item(name: string, style: string, color: Color3, size: string?): ItemDefinition
	return { Name = name, Size = size or "small", Style = style, Color = color }
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

return {
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
