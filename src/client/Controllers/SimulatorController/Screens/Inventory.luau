--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Components)
local ItemPreview = require(script.Parent.Parent.ItemPreview)
local Style = require(script.Parent.Parent.Style)

export type Sort = "recent" | "price" | "quality"

local COLUMNS = 4
local GAP = 8
local SORTS: { { Key: Sort, Caption: string } } = {
	{ Key = "recent", Caption = "Новые" },
	{ Key = "price", Caption = "По цене" },
	{ Key = "quality", Caption = "По качеству" },
}

local Inventory = {}
local sort: Sort = "recent"
local selected: string?

local function collectionOf(kind: string): string?
	for _, collection in Catalog.Collections do
		if table.find(collection.Items, kind) then
			return collection.Name
		end
	end
	return nil
end

local function sorted(data: Types.View): { Types.Item }
	local results = table.clone(data.Inventory)
	if sort == "recent" then
		table.clear(results)
		for index = #data.Inventory, 1, -1 do
			table.insert(results, data.Inventory[index])
		end
	else
		table.sort(results, function(a, b)
			local left = if sort == "price" then data.Prices[a.Id] or 0 else a.Quality
			local right = if sort == "price" then data.Prices[b.Id] or 0 else b.Quality
			return if left == right then a.Id < b.Id else left > right
		end)
	end
	return results
end

local function detail(item: Types.Item, price: number?): ()
	local definition = Catalog.Items[item.Kind]
	local tint = Components.qualityColor(item.Quality)
	local dock = Components.dock(140, true)
	local frame = Style.frame(dock, Style.Card, 14)
	frame.Size = UDim2.fromScale(1, 1)
	Style.outline(frame, tint, 3)
	-- Низкое окно (телефон): панель узкая и стоит сбоку, поэтому значок меньше, а подписи идут столбцом.
	local compact = Components.compact()
	local side = if compact then 10 else 132

	local badge = Style.frame(frame, Style.Track, 12)
	Components.place(badge, 10, 10, UDim.new(0, if compact then 60 else 110), if compact then 60 else 110)
	Style.outline(badge, tint, 2)
	local icon = ItemPreview.draw(badge, item.Kind)
	icon.Size = UDim2.fromScale(1, 1)

	local name = Components.text(frame, definition.Name, if compact then 16 else 19, Style.Text, true)
	Components.place(name, if compact then 78 else 132, 8, UDim.new(1, if compact then -88 else -142), 26)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local note = collectionOf(item.Kind)
	local extra = Components.text(
		frame,
		if note then `Коллекция «{note}»` else "Не входит в коллекции",
		12,
		Style.Muted
	)
	if compact then
		Components.place(extra, 78, 36, UDim.new(1, -88), 32)
		extra.TextWrapped = true
		extra.TextYAlignment = Enum.TextYAlignment.Top
	else
		Components.place(extra, 132, 70, UDim.new(1, -142), 18)
	end
	extra.TextTruncate = Enum.TextTruncate.AtEnd
	local state = Components.text(frame, Components.itemDetails(item), 13, tint, true)
	Components.place(state, side, if compact then 78 else 35, UDim.new(1, if compact then -20 else -142), 18)
	state.TextTruncate = Enum.TextTruncate.AtEnd
	local track = Style.meter(frame, item.Quality / 100, tint)
	Components.place(track, side, if compact then 102 else 57, UDim.new(1, if compact then -22 else -144), 8)

	local caption = if price then `Продать · {Components.coin(price)}` else "Продать"
	local sell = Style.button(frame, caption, function()
		Components.send("sell", item.Id)
		selected = nil
	end, price ~= nil, "reward")
	sell.Name = item.Id
	sell.TextSize = 17
	sell.AnchorPoint = Vector2.new(1, 1)
	sell.Position = UDim2.new(1, -10, 1, -10)
	sell.Size = UDim2.new(1, if compact then -20 else -142, 0, 44)
	Components.prefer(sell)
end

function Inventory.reset(): ()
	selected = nil
end

function Inventory.render(data: Types.View): ()
	local capacity = 15 + 5 * (data.Perks.storage or 0)
	local full = #data.Inventory >= capacity

	local header = Components.card(76)
	local count =
		Components.text(header, `{#data.Inventory} / {capacity}`, 26, if full then Style.Amber else Style.Text, true)
	Components.place(count, 14, 6, UDim.new(0.5, 0), 34)
	local hint = Components.text(
		header,
		if full then "Склад заполнен" else "занятых мест",
		13,
		Style.Muted
	)
	hint.TextXAlignment = Enum.TextXAlignment.Right
	Components.place(hint, 0, 16, UDim.new(1, -14), 20)
	local track = Style.meter(header, #data.Inventory / capacity, if full then Style.Amber else Style.Signal)
	Components.place(track, 14, 48, UDim.new(1, -28), 14)

	local bar = Components.strip(44)
	for index, option in SORTS do
		local choice = Style.button(bar, option.Caption, function()
			sort = option.Key
			Components.redraw()
		end, true, if sort == option.Key then "primary" else "neutral")
		choice.TextSize = 14
		choice.Position = UDim2.fromScale((index - 1) / 3, 0)
		choice.Size = UDim2.new(1 / 3, if index == 3 then 0 else -6, 1, 0)
	end

	if #data.Inventory == 0 then
		Components.paragraph(
			"Склад пуст. Подберите добычу на площадке и вернитесь сюда."
		)
	end

	local results = sorted(data)
	local picked: Types.Item?
	local grid = Components.grid(COLUMNS, GAP)
	for _, item in results do
		local isPicked = item.Id == selected
		if isPicked then
			picked = item
		end
		Components.tile(grid, item.Kind, item, {
			Caption = Components.coin(data.Prices[item.Id] or 0),
			Badge = if collectionOf(item.Kind) then "★" else nil,
			Selected = isPicked,
			FocusKey = item.Id,
			Callback = function()
				selected = if selected == item.Id then nil else item.Id
				Components.redraw()
			end,
		})
	end
	for _ = #results + 1, capacity do
		Components.emptySlot(grid)
	end

	if picked then
		detail(picked, data.Prices[picked.Id])
	else
		selected = nil
	end
end

return Inventory
