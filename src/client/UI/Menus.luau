--!strict
-- Title, caption, accent color and icon of every menu.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Icons)
local Style = require(script.Parent.Style)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.UI)

local Menus = {}

local TITLES: { [string]: string } = {
	terminal = Texts.titleTerminal,
	inventory = Texts.titleInventory,
	collections = Texts.titleCollections,
	loot = Texts.titleLoot,
	perks = Texts.titlePerks,
	daily = Texts.titleDaily,
	dial = Texts.titleDial,
	settings = Texts.titleSettings,
}
local CAPTIONS: { [string]: string } = {
	terminal = Texts.captionTerminal,
	inventory = Texts.captionInventory,
	collections = Texts.captionCollections,
	loot = Texts.captionLoot,
	perks = Texts.captionPerks,
	daily = Texts.captionDaily,
	dial = Texts.captionDial,
	settings = Texts.captionSettings,
}
local ACCENTS: { [string]: Color3 } = {
	terminal = Style.Signal,
	inventory = Style.Cyan,
	collections = Style.Violet,
	loot = Style.Amber,
	perks = Style.Amber,
	daily = Style.Amber,
	dial = Style.Cyan,
	settings = Style.Cyan,
}
local ICONS: { [string]: Icons.IconName } = {
	terminal = "screen",
	inventory = "box",
	collections = "grid",
	loot = "box",
	perks = "star",
	daily = "gift",
	dial = "lock",
	settings = "gear",
}

Menus.TITLES = TITLES
Menus.CAPTIONS = CAPTIONS
Menus.ACCENTS = ACCENTS
Menus.ICONS = ICONS

return Menus
