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
	-- Mopping job in the hall. Rewards are in GameConfig (Mop*).
	Mop = {
		StationOffset = Vector3.new(0, 0, 26),
		SpotMinRadius = 7,
		SpotMaxRadius = 20,
		MaxDistance = 70,
		-- Stepping this close to the middle of a spot starts the cleaning.
		MarkerRadius = 4,
		-- A spot has this many pieces of mud; each needs ChunkWork studs of mop head movement within ScrubRadius.
		ChunkCount = 10,
		ChunkWork = 5,
		ScrubRadius = 1.8,
		-- Most movement counted in one server tick (0.1 s), and the shortest possible cleaning of a spot.
		MaxStep = 2.5,
		MinCleanTime = 3,
	},
}
