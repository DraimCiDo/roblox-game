--!strict
-- Загрузчик модулей: require всех ModuleScript в папке,
-- затем Init() у каждого (синхронно), затем Start() у каждого (в отдельном потоке).
-- Init  — только подготовка (без yield и без вызовов других модулей).
-- Start — подписки на события, циклы, взаимодействие с другими модулями.

export type Module = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
	[string]: any,
}

local Loader = {}

function Loader.load(container: Instance): { [string]: Module }
	local modules: { [string]: Module } = {}

	for _, child in container:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok then
				modules[child.Name] = result :: any
			else
				warn(`[Loader] Не удалось загрузить {child:GetFullName()}: {result}`)
			end
		end
	end

	for name, module in modules do
		local init = module.Init
		if init then
			local ok, err = pcall(init, module)
			if not ok then
				warn(`[Loader] {name}:Init() упал: {err}`)
			end
		end
	end

	for _, module in modules do
		local start = module.Start
		if start then
			task.spawn(start, module)
		end
	end

	return modules
end

return Loader
