--!strict
-- Loot lying on the pad of an opened container: pickup, quick sell and quick collect.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.Notices)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Audio = require(script.Parent.Parent.Network.Audio)
local Economy = require(script.Parent.Parent.Economy.Economy)
local World = require(script.Parent.Parent.World.World)
local Rules = require(script.Parent.Parent.Config.Rules)
local State = require(script.Parent.State)

local Loot = {}

local function finishLoot(order: Types.Order): ()
	if #order.Loot == 0 then
		order.Stage = "clear"
	end
end

function Loot.act(
	player: Player,
	plot: World.Plot,
	data: Types.PlayerData,
	order: Types.Order,
	action: string,
	itemId: string?,
	physical: boolean
): boolean
	if order.Stage ~= "open" then
		return false
	end
	if action == "pickup" and physical and itemId then
		local position, target = World.Position(player), plot.LootPositions[itemId]
		if
			not position
			or not target
			or (position - target).Magnitude
				> (if order.Kind == "cargo" then Rules.Range.CargoPickup else Rules.Range.Pickup)
		then
			return false
		end
		if order.Kind == "cargo" then
			local inside = plot.Pad:PointToObjectSpace(position)
			if math.abs(inside.X) > Rules.CargoInside.X or math.abs(inside.Z) > Rules.CargoInside.Y then
				return false
			end
		end
		for index, loot in order.Loot do
			if loot.Item.Id == itemId then
				if loot.Item.Quality <= Economy.recycleLimit(data) then
					-- «Утилизатор»: дешёвая находка продаётся сразу и не занимает место на складе.
					local value = Economy.payout(data, loot.Item)
					Economy.credit(data, value)
					table.remove(order.Loot, index)
					finishLoot(order)
					State.tell(
						player,
						Format(Texts.recycled, { name = Catalog.Items[loot.Item.Kind].Name, value = value })
					)
					Audio.to(player, "coin")
					return true
				end
				if #data.Inventory >= Economy.capacity(data) then
					State.warn(player, Texts.storageFull)
					return false
				end
				table.insert(data.Inventory, loot.Item)
				table.remove(order.Loot, index)
				finishLoot(order)
				State.tell(player, Format(Texts.stored, { name = Catalog.Items[loot.Item.Kind].Name }))
				Audio.to(player, "pickup")
				return true
			end
		end
	elseif (action == "quickSell" or action == "quickCollect") and (data.Perks[action] or 0) > 0 then
		if not World.Near(player, plot.Button, Rules.Range.Station) then
			State.tell(player, Texts.goToLootPanel)
			return false
		end
		if action == "quickSell" then
			local total = 0
			local bonus = Economy.bulkBonus(data)
			for _, loot in order.Loot do
				total += Economy.payout(data, loot.Item, bonus)
			end
			table.clear(order.Loot)
			Economy.credit(data, total)
			State.tell(player, Format(Texts.quickSold, { total = total }))
			Audio.to(player, "sell")
		else
			local limit = Economy.recycleLimit(data)
			local stored, sold, earned = 0, 0, 0
			local index = 1
			while index <= #order.Loot do
				local loot = order.Loot[index]
				if loot.Item.Quality <= limit then
					earned += Economy.payout(data, loot.Item)
					table.remove(order.Loot, index)
					sold += 1
				elseif #data.Inventory < Economy.capacity(data) then
					table.insert(data.Inventory, loot.Item)
					table.remove(order.Loot, index)
					stored += 1
				else
					index += 1
				end
			end
			if stored + sold == 0 then
				State.warn(player, Texts.storageFull)
				return false
			end
			if earned > 0 then
				Economy.credit(data, earned)
			end
			local note = if sold > 0 then Format(Texts.recycledNote, { sold = sold, earned = earned }) else ""
			if #order.Loot > 0 then
				State.warn(player, Format(Texts.storageFullLeft, { left = #order.Loot, note = note }))
			else
				State.tell(player, Format(Texts.collected, { stored = stored, note = note }))
				Audio.to(player, "pickup")
			end
		end
		finishLoot(order)
		return true
	end
	return false
end

return Loot
