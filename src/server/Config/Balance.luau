--!strict
-- Economy numbers (server only). Perk strength and perk prices are in shared/Config/Perks.luau.
return {
	-- Order price is this share of the expected revenue of a container at the current laboratory level.
	PriceShare = 0.6,
	PriceStep = 50,
	-- Average quality multiplier used for that expectation.
	QualityMean = 0.9626,

	-- Items with a drop weight not above this count as rare.
	RareWeight = 9,
	-- Rare items of a variant container are this many times more frequent.
	VariantRareEmphasis = 2,

	-- Quality roll: Chance in percent (must sum to 100) of a value between Min and Max.
	Quality = {
		{ Chance = 20, Min = 1, Max = 20 },
		{ Chance = 40, Min = 21, Max = 49 },
		{ Chance = 30, Min = 50, Max = 70 },
		{ Chance = 8, Min = 71, Max = 99 },
		{ Chance = 2, Min = 100, Max = 100 },
	},
	-- Price multiplier by quality: Base + quality * PerPoint up to Middle,
	-- then UpperBase + (quality - Middle) * UpperPerPoint.
	Price = { Base = 0.5, PerPoint = 0.01, Middle = 50, UpperBase = 1, UpperPerPoint = 0.015 },
	-- Quality from which "haggle" applies, and up to which "junk" applies.
	HaggleFrom = 71,
	JunkUpTo = 49,
	-- Full collection bonus is average quality / this number (1000 = 10% at quality 100).
	CollectionDivisor = 1000,

	-- "... expert" perks: bonus for loot of one container type, in container type order.
	MasteryPerks = { "boxMaster", "crateMaster", "safeMaster", "cargoMaster", "secretMaster" },

	-- Order price floor after discounts.
	MinOrderPrice = 10,
	-- Daily reward in current order prices.
	DailyRewardOrders = 2,
	-- Delivery seconds when "express" fires.
	ExpressDelivery = 0.6,

	-- Safe mini-game: one entry per stage. Period: seconds per pointer turn; Tolerance: half width of the hit zone.
	Dial = {
		TimeLimit = 20,
		MaxTolerance = 0.3,
		Periods = { 3, 2.4, 1.9 },
		Tolerances = { 0.12, 0.1, 0.08 },
	},
}
