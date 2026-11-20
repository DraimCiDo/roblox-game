--!nocheck
-- Проверка контракта сектора: в каждой модели «Сектор 0N» есть все детали, которые ищет сервер
-- (World.luau / Sector.luau), прямыми потомками и в нужном количестве.
-- Запуск: lune run scripts/map/check.luau

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local REQUIRED = {
	["Табло сектора"] = 1,
	["Заказы"] = 1,
	["Склад"] = 1,
	["Коллекции"] = 1,
	["Пульт добычи"] = 1,
	["Индикация шлюза"] = 1,
	["Опора над шахтой"] = 1,
	["Створка шлюза"] = 4,
	["Складской модуль"] = 10,
	["Точка входа в трубу"] = 1,
	["Верхняя точка подачи"] = 1,
	["Нижняя точка отвода"] = 1,
	["Сигнал подачи"] = 1,
	["Сигнал отвода"] = 1,
	["Витрина 1"] = 1,
	["Витрина 2"] = 1,
	["Витрина 3"] = 1,
	["Витрина 4"] = 1,
	["Витрина 5"] = 1,
	["Витрина 6"] = 1,
	["Витрина 7"] = 1,
	["Витрина 8"] = 1,
	["Затвор Backrooms"] = 2,
}
local CHILDREN = {
	["Заказы"] = "Матовый экран заказа",
	["Коллекции"] = "Панель каталогизации",
}

local lab = roblox.deserializeModel(fs.readFile("assets/CorpaLab.rbxm"))[1]
local problems = {}
for index = 1, 6 do
	local name = string.format("Сектор %02d", index)
	local sector = lab:FindFirstChild(name)
	if not sector then
		table.insert(problems, `{name}: нет модели`)
		continue
	end
	local counts = {}
	local spawn = false
	for _, child in sector:GetChildren() do
		if child.ClassName == "Part" then
			counts[child.Name] = (counts[child.Name] or 0) + 1
		elseif REQUIRED[child.Name] then
			-- Сервер ищет детали через FindFirstChild: тёзка другого класса может перехватить поиск.
			table.insert(problems, `{name}: «{child.Name}» есть не-деталь ({child.ClassName}) с тем же именем`)
		end
		if child:IsA("SpawnLocation") then
			spawn = true
		end
	end
	if not spawn then
		table.insert(problems, `{name}: нет SpawnLocation`)
	end
	for part, expected in REQUIRED do
		if (counts[part] or 0) ~= expected then
			table.insert(problems, `{name}: «{part}» {counts[part] or 0} вместо {expected}`)
		end
	end
	for station, child in CHILDREN do
		local host = sector:FindFirstChild(station)
		if not host or not host:FindFirstChild(child) then
			table.insert(problems, `{name}: в «{station}» нет «{child}»`)
		end
	end
end
for index = 1, 6 do
	if not lab:FindFirstChild(`Указатель сектора 0{index}`) then
		table.insert(problems, `нет «Указатель сектора 0{index}»`)
	end
end
if #problems > 0 then
	print(table.concat(problems, "\n"))
	process.exit(1)
end
print("Контракт секторов: всё на месте")
