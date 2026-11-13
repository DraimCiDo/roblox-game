--!strict
local TableUtil = {}

-- Глубокая копия таблицы (без метатаблиц).
function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value :: any do
		copy[key] = TableUtil.deepCopy(inner)
	end
	return copy :: any
end

-- Дополняет target недостающими ключами из template (для новых полей в сохранениях).
function TableUtil.reconcile(target: { [any]: any }, template: { [any]: any }): { [any]: any }
	for key, value in template do
		if target[key] == nil then
			target[key] = TableUtil.deepCopy(value)
		elseif type(target[key]) == "table" and type(value) == "table" then
			TableUtil.reconcile(target[key], value)
		end
	end
	return target
end

return TableUtil
