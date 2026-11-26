--!strict
-- Детализированные 3D-модели предметов из деталей Roblox. Начало координат — центр основания,
-- лицевая сторона смотрит в -Z. Используется и миром (сервер), и иконками интерфейса (клиент).
local Catalog = require(script.Parent.Parent.Catalog)
local Tools = require(script.Tools)
local Box = require(script.Box)
local Crate = require(script.Crate)
local Safe = require(script.Safe)
local Advanced = require(script.Advanced)

export type Options = Tools.Options

local ItemModels = {}

local B: { [string]: (any) -> () } = {}
for _, group in { Box, Crate, Safe, Advanced } do
	for kind, builder in group do
		B[kind] = builder
	end
end

-- Строит модель предмета внутри parent (обычно Model). Неизвестный тип рисуется нейтральным кубом.
function ItemModels.build(kind: string, parent: Instance, options: Options?): ()
	local definition = Catalog.Items[kind]
	local full = if options and options.Full ~= nil then options.Full else true
	local tools = Tools.makeTools(parent, full, if definition then definition.Color else Tools.GRAY)
	local builder = B[kind]
	if builder then
		builder(tools)
	else
		tools.Block(0, 0.7, 0, 1.4, 1.4, 1.4, tools.Tint)
	end
end

return ItemModels
