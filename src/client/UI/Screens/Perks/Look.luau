--!strict
-- Colors and icons of the perk tree.

local Icons = require(script.Parent.Parent.Parent.Icons)
local Style = require(script.Parent.Parent.Parent.Style)

local Look = {}

-- Карта навыков — «экран прибора»: почти чёрный графит, стальные рельсы связей.
local BOARD = Color3.fromRGB(8, 12, 18)
local PANEL = Color3.fromRGB(20, 28, 38)
local RAIL = Color3.fromRGB(58, 74, 90)
local BRANCH_COLORS: { [string]: Color3 } = {
	logistics = Style.Violet,
	storage = Style.Cyan,
	trade = Style.Signal,
	luck = Style.Amber,
	mastery = Style.Warning,
	collections = Color3.fromRGB(244, 140, 224),
	lockpick = Color3.fromRGB(120, 214, 255),
}
local PERK_ICONS: { [string]: Icons.IconName } = {
	orders = "box",
	delivery = "arrow",
	express = "bolt",
	discount = "tag",
	cashback = "coin",
	daily = "gift",
	grant = "gem",
	storage = "grid",
	quickCollect = "magnet",
	recycler = "cycle",
	gallery = "frame",
	sale = "coin",
	quickSell = "bolt",
	bulk = "stack",
	haggle = "scale",
	jackpot = "dice",
	junk = "tag",
	odds = "star",
	quality = "eye",
	floor = "stack",
	perfect = "gem",
	rarity = "sparkle",
	bonusLoot = "plus",
	variant = "ticket",
	variantLoot = "plus",
	crateLuck = "target",
	safeLuck = "target",
	cargoLuck = "target",
	secretLuck = "target",
	boxMaster = "medal",
	crateMaster = "medal",
	safeMaster = "medal",
	cargoMaster = "medal",
	secretMaster = "medal",
	collection = "grid",
	collElectronics = "screen",
	collJewel = "gem",
	collCars = "frame",
	collLab = "sparkle",
	museum = "frame",
	steady = "lock",
	slow = "clock",
}

Look.BOARD = BOARD
Look.PANEL = PANEL
Look.RAIL = RAIL
Look.BRANCH_COLORS = BRANCH_COLORS
Look.PERK_ICONS = PERK_ICONS

return Look
