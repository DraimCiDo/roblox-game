--!strict
-- Loot of every container type (server only).
-- Min/Max: items per container; Deliver: delivery seconds; OpenSteps: actions needed to open.
-- drop(item key, base price, weight): a higher weight drops more often. Extra joins the pool of variants only.
export type Drop = { Kind: string, Price: number, Weight: number }
export type Container = { Min: number, Max: number, Deliver: number, OpenSteps: number, Drops: { Drop }, Extra: Drop }

local function drop(kind: string, price: number, weight: number): Drop
	return { Kind = kind, Price = price, Weight = weight }
end

local Containers: { [string]: Container } = {
	box = {
		Min = 1,
		Max = 2,
		Deliver = 2,
		OpenSteps = 4,
		Drops = {
			drop("ball", 2600, 13),
			drop("trash", 2300, 16),
			drop("bell", 3100, 10),
			drop("bowl", 2500, 13),
			drop("painting", 4200, 5),
			drop("fish", 3200, 8),
			drop("dumbbell", 2900, 11),
			drop("brush", 2400, 14),
			drop("parcel", 2500, 15),
			drop("elfhat", 4800, 4),
		},
		Extra = drop("prism", 6000, 8),
	},
	crate = {
		Min = 2,
		Max = 4,
		Deliver = 2.5,
		OpenSteps = 4,
		Drops = {
			drop("flower", 4000, 15),
			drop("meteor", 10000, 4),
			drop("bin", 3900, 15),
			drop("computer", 6500, 9),
			drop("tv", 7100, 8),
			drop("fan", 4500, 13),
			drop("trophy", 8300, 6),
			drop("rockart", 6000, 10),
			drop("radio", 5000, 12),
			drop("camera", 6200, 10),
		},
		Extra = drop("crateGem", 10000, 8),
	},
	safe = {
		Min = 3,
		Max = 4,
		Deliver = 3,
		OpenSteps = 1,
		Drops = {
			drop("gold", 21000, 10),
			drop("dollars", 15000, 15),
			drop("gpu", 23000, 7),
			drop("glasses", 20000, 10),
			drop("boombox", 31000, 4),
			drop("button", 22000, 9),
			drop("console", 17000, 13),
			drop("phone", 17000, 14),
			drop("davinci", 32000, 4),
			drop("bomb", 14000, 15),
		},
		Extra = drop("diamond", 55000, 8),
	},
	cargo = {
		Min = 2,
		Max = 3,
		Deliver = 4,
		OpenSteps = 3,
		Drops = {
			drop("rover", 150000, 12),
			drop("coupe", 230000, 6),
			drop("robot", 110000, 14),
			drop("crateGem", 10000, 14),
		},
		Extra = drop("concept", 550000, 8),
	},
	secret = {
		Min = 3,
		Max = 4,
		Deliver = 3.5,
		OpenSteps = 5,
		Drops = {
			drop("diamond", 55000, 10),
			drop("core", 390000, 10),
			drop("concept", 550000, 6),
			drop("anomaly", 300000, 14),
		},
		Extra = drop("prism", 6000, 8),
	},
}

return Containers
