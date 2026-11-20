--!nocheck
-- Сборка карты без Studio: загружает assets/CorpaLab.rbxm и assets/CorpaLighting.rbxm,
-- запускает над ними сборщики оформления (hall.luau, sectors.luau) и записывает файлы обратно.
-- Rojo (rojo serve) сам подхватит изменённые .rbxm и обновит сцену в открытом Studio.
--
-- Запуск из корня репозитория: lune run scripts/map/build.luau
-- Сборщики идемпотентны: повторный запуск даёт тот же результат.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local LAB_FILE = "assets/CorpaLab.rbxm"
local LIGHTING_FILE = "assets/CorpaLighting.rbxm"
local BUILDERS = { "scripts/map/hall.luau", "scripts/map/sectors.luau" }

local game = roblox.Instance.new("DataModel")
local workspace = game:GetService("Workspace")

local labRoots = roblox.deserializeModel(fs.readFile(LAB_FILE))
assert(#labRoots == 1, "В CorpaLab.rbxm ожидается одна модель лаборатории")
local lab = labRoots[1]
-- В файле модель хранится под своим именем; в плейсе Rojo называет её по ключу проекта.
local storedName = lab.Name
lab.Name = "CORPA — испытательная лаборатория"
lab.Parent = workspace

local lightingRoots = roblox.deserializeModel(fs.readFile(LIGHTING_FILE))
assert(#lightingRoots == 1 and lightingRoots[1].ClassName == "Lighting", "В CorpaLighting.rbxm ожидается Lighting")
local lighting = lightingRoots[1]
lighting.Parent = game

-- Окружение сборщиков: те же глобальные имена, что и в Studio.
local environment = {
	game = game,
	workspace = workspace,
	Instance = roblox.Instance,
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	Color3 = roblox.Color3,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	Font = roblox.Font,
	ColorSequence = roblox.ColorSequence,
	NumberSequence = roblox.NumberSequence,
}
setmetatable(environment, { __index = getfenv and getfenv(0) or _G })

for _, path in BUILDERS do
	local chunk = luau.load(fs.readFile(path), { debugName = path, environment = environment })
	print(`[{path}]`, chunk())
end

lab.Name = storedName
fs.writeFile(LAB_FILE, roblox.serializeModel({ lab }))
fs.writeFile(LIGHTING_FILE, roblox.serializeModel({ lighting }))
print("Записано:", LAB_FILE, LIGHTING_FILE)
