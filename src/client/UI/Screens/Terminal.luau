--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Preview = require(script.Parent.Parent.Parent.Visuals.ContainerPreview)
local Components = require(script.Parent.Parent.Components)
local Style = require(script.Parent.Parent.Style)

local Terminal = {}

function Terminal.render(data: Types.View): ()
	local maximum = 1 + (data.Perks.orders or 0)
	local available = data.Orders < maximum
	local canPay = data.Coins >= data.OrderPrice
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
		elseif not canPay then `Не хватает {Components.coin(data.OrderPrice - data.Coins)} монет`
		else `Заказать  ·  {Components.coin(data.OrderPrice)} монет`
	Components.command(caption, function()
		Components.send("buy")
	end, available and canPay, "primary")

	-- Уровень лаборатории: растёт с числом открытых контейнеров, повышает цену заказа и открывает редкие типы.
	local level, floor, ceiling = Catalog.levelRange(data.Opened)
	local lab = Components.card(96)
	local labTitle = Components.text(lab, `Уровень лаборатории {level}`, 20, Style.Text, true)
	Components.place(labTitle, 14, 8, UDim.new(1, -28), 26)
	local detail
	if ceiling then
		detail = `Открыто {data.Opened} · до уровня {level + 1} ещё {ceiling - data.Opened}`
	else
		detail = `Открыто {data.Opened} · максимальный уровень`
	end
	for tier, need in Catalog.TierUnlock do
		if need > level then
			detail ..= `\nНа уровне {need} появится: {Catalog.Containers[Catalog.Kinds[tier]]}`
			break
		end
	end
	local info = Components.text(lab, detail, 13, Style.Muted)
	Components.place(info, 14, 34, UDim.new(1, -28), 36)
	local ratio = if ceiling then (data.Opened - floor) / (ceiling - floor) else 1
	local bar = Style.meter(lab, ratio, Style.Violet)
	Components.place(bar, 14, 76, UDim.new(1, -28), 10)

	Components.heading("Шансы доставки")
	Components.odds(Catalog.odds(data.Opened, data.Perks), nil, level)
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
