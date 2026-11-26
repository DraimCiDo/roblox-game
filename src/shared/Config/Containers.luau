--!strict
-- Container types and laboratory progression. Lists are ordered from the most common type to the rarest.
-- Loot, prices and delivery times are in server/Config/Loot.luau.
local Containers = {}

Containers.Kinds = { "box", "crate", "safe", "cargo", "secret" }
Containers.Names = {
	box = "Картонная коробка",
	crate = "Деревянный ящик",
	safe = "Сейф",
	cargo = "Грузовой контейнер",
	secret = "Секретный контейнер",
} :: { [string]: string }
Containers.Variants = {
	box = "Хрупкая коробка",
	crate = "Экспедиционный ящик",
	safe = "Резервный сейф",
	cargo = "Груз повышенной ценности",
	secret = "Аномальный контейнер",
} :: { [string]: string }

-- Opened containers needed for each laboratory level.
Containers.Levels = { 0, 12, 30, 70, 130, 220, 360, 560, 840, 1250, 1800, 2600, 3600, 5000, 7000 }
-- Laboratory level that unlocks each type, and its base chance weight.
Containers.TierUnlock = { 1, 2, 4, 8, 12 }
Containers.TierWeights = { 100, 38, 14, 4.5, 1.4 }
-- Perk that raises the chance of each type and every rarer one.
Containers.TierLuckPerks = { "", "crateLuck", "safeLuck", "cargoLuck", "secretLuck" }

-- Display stands of a sector, by size.
Containers.DisplaySizes = { "small", "small", "small", "small", "small", "small", "large", "car" }

return Containers
