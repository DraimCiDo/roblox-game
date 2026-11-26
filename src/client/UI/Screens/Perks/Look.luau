--!strict
-- Colors and icons of the perk tree.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.UiTheme)
local Icons = require(script.Parent.Parent.Parent.Icons)

local Look = {}

Look.BranchColors = {
	logistics = Theme.Colors.Purple,
	storage = Theme.Colors.Blue,
	trade = Theme.Colors.Green,
	luck = Theme.Colors.Orange,
	mastery = Theme.Colors.Red,
	collections = Theme.Colors.Pink,
	lockpick = Theme.Colors.Yellow,
} :: { [string]: Color3 }

Look.Icons = {
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
} :: { [string]: Icons.IconName }

return Look
