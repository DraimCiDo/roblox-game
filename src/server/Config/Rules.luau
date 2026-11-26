--!strict
-- Server rules that are not prices or chances (those are in Balance.luau and Loot.luau). Distances in studs, time in seconds.
return {
	TickInterval = 0.1,
	-- Minimum pause between two actions of one player.
	ActionInterval = 0.14,
	GalleryInterval = 10,
	Range = {
		-- Terminal, storage, collections, loot panel and most containers.
		Station = 11,
		Stand = 9,
		-- Opening a crate clamp or cargo lock.
		CloseOpening = 8,
		Pickup = 8.9,
		CargoPickup = 5.8,
	},
	-- Half size of the cargo container floor that counts as being inside.
	CargoInside = Vector2.new(6.6, 7.8),
	Rankings = { GlobalRefresh = 90, LobbyRefresh = 3 },
	-- Mopping job in the hall. The reward per spot is GameConfig.MopReward.
	Mop = {
		StationOffset = Vector3.new(0, 0, 26),
		SpotMinRadius = 7,
		SpotMaxRadius = 20,
		SpotReach = 14,
		MaxDistance = 70,
		MinInterval = 0.6,
		CleanTime = 0.9,
	},
}
