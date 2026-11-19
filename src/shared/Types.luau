--!strict
export type Item = { Id: string, Kind: string, Quality: number }
export type Loot = { Item: Item, X: number, Z: number }
export type Stage = "queued" | "delivery" | "sealed" | "open" | "clear"
export type Order = {
	Id: string,
	Kind: string,
	Variant: boolean,
	Stage: Stage,
	Deadline: number,
	Progress: number,
	Target: number,
	DialStarted: number,
	Loot: { Loot },
}

export type PlayerData = {
	Version: number,
	Coins: number,
	Earned: number,
	Opened: number,
	TutorialDone: boolean,
	StarterGranted: boolean,
	Inventory: { Item },
	Collections: { [string]: Item },
	Displays: { [string]: Item },
	Perks: { [string]: number },
	Orders: { Order },
	DailyClaim: number,
}

export type View = {
	Coins: number,
	Earned: number,
	Opened: number,
	OrderPrice: number,
	DailyReward: number,
	Inventory: { Item },
	Collections: { [string]: Item },
	Displays: { [string]: Item },
	Perks: { [string]: number },
	Orders: number,
	OrderStage: Stage?,
	OrderKind: string?,
	OrderVariant: boolean?,
	OrderProgress: number?,
	OrderGoal: number?,
	OrderDeadline: number?,
	RemainingLoot: number,
	Prices: { [string]: number },
	DailyReadyAt: number,
	DailyClaim: number,
}

return {}
