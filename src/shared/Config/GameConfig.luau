--!strict
local Types = require(script.Parent.Parent.Types)

local DEFAULT_DATA: Types.PlayerData = {
	Version = 2,
	Coins = 2500,
	Earned = 0,
	Opened = 0,
	TutorialDone = false,
	VolumeUi = 0.6,
	VolumeWorld = 0.6,
	StarterGranted = false,
	Inventory = {},
	Collections = {},
	Displays = {},
	Perks = {},
	Orders = {},
	DailyClaim = -1,
	Effect = "standard",
	Effects = {},
}

return table.freeze({
	DataStoreName = "PlayerData_v1",
	DataSchemaVersion = 2,
	DefaultData = table.freeze(DEFAULT_DATA),
	AutosaveInterval = 45,
	MaxPlayers = 6,
	OrderPrice = 2500,
	DailySeconds = 900,
	-- Награда за одно вымытое пятно в мини-игре «Мытьё полов».
	MopReward = 10,
})
