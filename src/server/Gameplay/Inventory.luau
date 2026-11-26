--!strict
-- Stored finds: selling, collections and display stands.
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
local Plots = require(script.Parent.Plots)

local Inventory = {}

function Inventory.act(
	player: Player,
	plot: World.Plot,
	data: Types.PlayerData,
	action: string,
	itemId: string?,
	slotKey: string?
): boolean
	if action == "removeDisplay" then
		local stand = Plots.standPart(plot, slotKey)
		local displayed = slotKey and data.Displays[slotKey]
		if not stand or not slotKey or not displayed then
			return false
		end
		if not World.Near(player, stand, Rules.Range.Stand) then
			State.tell(player, Texts.goToOwnStand)
			return false
		end
		if #data.Inventory >= Economy.capacity(data) then
			State.warn(player, Texts.storageFull)
			return false
		end
		table.insert(data.Inventory, displayed)
		data.Displays[slotKey] = nil
		return true
	end
	local itemIndex: number?
	for index, item in data.Inventory do
		if item.Id == itemId then
			itemIndex = index
			break
		end
	end
	if not itemIndex then
		State.tell(player, Texts.itemGone)
		return false
	end
	local item = data.Inventory[itemIndex]
	if action == "sell" then
		if not World.Near(player, plot.Stations.inventory, Rules.Range.Station) then
			State.tell(player, Texts.goToStorageToSell)
			return false
		end
		local total = Economy.payout(data, item)
		Economy.credit(data, total)
		State.tell(player, Format(Texts.sold, { total = total }))
		Audio.to(player, "sell")
	elseif action == "collection" then
		if not Economy.collectible(item.Kind) then
			return false
		end
		if not World.Near(player, plot.Stations.collections, Rules.Range.Station) then
			State.tell(player, Texts.goToCollections)
			return false
		end
		local replaced = data.Collections[item.Kind] ~= nil
		data.Collections[item.Kind] = item
		State.tell(player, if replaced then Texts.collectionReplaced else Texts.collectionAdded)
		Audio.to(player, "deposit")
	elseif action == "display" and slotKey then
		local stand = Plots.standPart(plot, slotKey)
		local index = Plots.member(slotKey, #Catalog.DisplaySizes)
		if not stand or not index or data.Displays[slotKey] then
			return false
		end
		if Catalog.Items[item.Kind].Size ~= Catalog.DisplaySizes[index] then
			return false
		end
		if not World.Near(player, stand, Rules.Range.Stand) then
			State.tell(player, Texts.goToOwnStand)
			return false
		end
		data.Displays[slotKey] = item
		State.tell(player, Texts.itemDisplayed)
		Audio.to(player, "place")
	else
		return false
	end
	table.remove(data.Inventory, itemIndex)
	return true
end

return Inventory
