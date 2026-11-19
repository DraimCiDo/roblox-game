--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Preview = require(script.Parent.Parent.ContainerPreview)
local Components = require(script.Parent.Parent.Components)
local Style = require(script.Parent.Parent.Style)

local Terminal = {}

function Terminal.render(data: Types.View): ()
	local maximum = 1 + (data.Perks.orders or 0)
	local available = data.Orders < maximum
	local canPay = data.Coins >= Config.OrderPrice
	local name, hint, tint = Components.status(data)

	local hero = Components.card(152)
	local preview = Preview.draw(hero, data.OrderKind or "cargo")
	preview.AnchorPoint = Vector2.new(1, 0)
	preview.Position = UDim2.new(1, -6, 0, 4)
	preview.Size = UDim2.new(0.36, 0, 0, 104)
	local progress = Components.progressText(data)
	local queueText = progress or `Заказы  {data.Orders} / {maximum}`
	local queue = Components.text(hero, queueText, 13, tint, true)
	Components.place(queue, 14, 10, UDim.new(0.64, -14), 18)
	local title = Components.text(hero, name, 22, Style.Text, true)
	Components.place(title, 14, 30, UDim.new(0.64, -14), 54)
	local tip = Components.text(hero, hint, 13, Style.Muted)
	Components.place(tip, 14, 88, UDim.new(1, -28), 32)
	if data.OrderStage == "delivery" then
		Components.Live.Delivery = tip
	end
	local slots = Style.frame(hero)
	Components.place(slots, 14, 128, UDim.new(1, -28), 10)
	for index = 1, maximum do
		local marker = Style.frame(slots, if index <= data.Orders then tint else Style.Track, 4)
		marker.Position = UDim2.fromScale((index - 1) / maximum, 0)
		marker.Size = UDim2.new(1 / maximum, -4, 1, 0)
		Style.outline(marker, Style.Edge, 1)
	end

	local caption = if not available
		then "Очередь заполнена"
		elseif not canPay then `Не хватает {Components.coin(Config.OrderPrice - data.Coins)} монет`
		else `Заказать  ·  {Components.coin(Config.OrderPrice)} монет`
	Components.command(caption, function()
		Components.send("buy")
	end, available and canPay, "primary")

	Components.heading("Шансы доставки")
	Components.odds(data.Perks.odds or 0)
end

-- Обновляет обратный отсчёт доставки без перерисовки экрана.
function Terminal.tick(data: Types.View, now: number): ()
	local label = Components.Live.Delivery
	local arrival = data.OrderDeadline
	if label and arrival and data.OrderStage == "delivery" then
		local seconds = math.max(0, math.ceil(arrival - now))
		label.Text = if seconds > 0
			then `Прибытие через {Components.clock(seconds)}`
			else "Контейнер у шлюза."
	end
end

return Terminal
