--!strict
-- Глобальные настройки игры. Никаких секретов: этот модуль реплицируется клиенту.
local Types = require(script.Parent.Parent.Types)

local DEFAULT_DATA: Types.PlayerData = {
	Version = 1,
	Coins = 0,
}

local GameConfig = table.freeze({
	-- Меняйте имя хранилища/версию схемы только вместе с миграцией (скилл datastore-change)
	DataStoreName = "PlayerData_v1",
	DataSchemaVersion = 1,
	DefaultData = table.freeze(DEFAULT_DATA),
	AutosaveInterval = 120,
})

return GameConfig
