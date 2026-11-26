--!strict
-- Buying perk levels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.Notices)
local Audio = require(script.Parent.Parent.Network.Audio)
local Economy = require(script.Parent.Parent.Economy.Economy)
local State = require(script.Parent.State)

local Perks = {}

-- The client sends a tree node key ("perk#step"); only the next step can be bought.
function Perks.buy(player: Player, data: Types.PlayerData, key: string): boolean
	local updated = false
	-- Клиент присылает ключ узла дерева («навык#ступень»): купить можно только следующую ступень по порядку.
	local node = Catalog.perk(key)
	local base = if node then node.Base else nil
	local step = if node then node.Step else nil
	if not node or not base or not step then
		return false
	end
	local level = data.Perks[base] or 0
	if level ~= step - 1 then
		return false
	end
	local levels = Catalog.nodeLevels(data.Perks)
	local cost = Catalog.perkCost(node, 0, levels)
	if not cost then
		return false
	end
	local lock = Catalog.perkLock(node, 0, levels, data.Opened)
	if lock then
		State.tell(player, lock)
	elseif data.Coins < cost then
		State.warn(player, Texts.notEnoughCoins)
	elseif data.Coins - cost < Economy.orderPrice(data) then
		-- Защита от тупика: после покупки должно хватать на следующий заказ.
		State.tell(player, Texts.keepCoinsForOrder)
	else
		data.Coins -= cost
		data.Perks[base] = step
		Audio.to(player, "perk")
		updated = true
	end
	return updated
end

return Perks
