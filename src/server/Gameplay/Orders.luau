--!strict
-- Ordering containers and the delivery queue: queued -> delivery -> sealed ... clear.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.Notices)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Data = require(script.Parent.Parent.Services.PlayerDataService)
local Audio = require(script.Parent.Parent.Network.Audio)
local Economy = require(script.Parent.Parent.Economy.Economy)
local World = require(script.Parent.Parent.World.World)
local Rules = require(script.Parent.Parent.Config.Rules)
local State = require(script.Parent.State)
local View = require(script.Parent.View)
local Opening = require(script.Parent.Opening)

local Orders = {}

-- Buys the next random container. Returns whether the data changed.
function Orders.buy(player: Player, plot: World.Plot, data: Types.PlayerData): boolean
	local updated = false
	if not World.Near(player, plot.Stations.terminal, Rules.Range.Station) then
		State.tell(player, Texts.goToTerminal)
	elseif #data.Orders >= 1 + (data.Perks.orders or 0) then
		State.tell(player, Texts.allSlotsBusy)
	elseif data.Coins < Economy.orderPrice(data) then
		State.tell(player, Texts.notEnoughCoins)
	else
		local price = Economy.orderPrice(data)
		local refund = Economy.cashback(data, price)
		data.Coins += refund - price
		table.insert(data.Orders, Economy.newOrder(data, false))
		updated = true
		local text = if #data.Orders == 1
			then Texts.orderAccepted
			else Format(Texts.orderQueued, { position = #data.Orders })
		State.tell(player, if refund > 0 then Format(Texts.cashback, { text = text, refund = refund }) else text)
		Audio.to(player, "order")
	end
	return updated
end

function Orders.tick(player: Player, session: State.Session, now: number): ()
	if not session.Initialized then
		return
	end
	local data = Data:Get(player)
	local order = data and data.Orders[1]
	if not data or not order then
		return
	end
	if order.Stage == "queued" then
		Data:Update(player, function()
			order.Stage = "delivery"
			order.Deadline = now + Economy.deliveryTime(order, data)
		end)
		Audio.at(session.Plot.Clear, "whoosh")
		View.sync(player, session)
	elseif order.Stage == "delivery" and now >= order.Deadline then
		Data:Update(player, function()
			order.Stage = "sealed"
			order.Deadline = 0
		end)
		Audio.at(session.Plot.Clear, "thud")
		View.sync(player, session)
	elseif order.Stage == "sealed" and order.DialStarted > 0 then
		Opening.tickDial(player, session, order, data, now)
	elseif order.Stage == "clear" then
		local releaseAt = session.ReleaseAt
		if releaseAt then
			if now >= releaseAt then
				World.Clear(session.Plot)
				Data:Update(player, function(current)
					table.remove(current.Orders, 1)
				end)
				session.ReleaseAt = nil
				View.sync(player, session)
			end
		elseif World.Position(player) and not World.InPad(session.Plot, player) then
			session.ReleaseAt = now + World.Release(session.Plot)
		end
	end
end

return Orders
