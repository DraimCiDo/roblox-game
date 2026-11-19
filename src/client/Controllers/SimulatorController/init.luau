--!strict
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Data = require(script.Parent.DataController)
local Style = require(script.Style)
local Preview = require(script.ContainerPreview)

local TITLES: { [string]: string } = {
	terminal = "Терминал заказов",
	inventory = "Склад",
	collections = "Коллекции",
	loot = "Управление добычей",
	perks = "Древо перков",
	daily = "Ежедневная награда",
	dial = "Ручка сейфа",
}
local CAPTIONS: { [string]: string } = {
	terminal = "Случайные контейнеры и очередь доставки",
	inventory = "Находки и их стоимость",
	collections = "Пополняйте экспозиции находками со склада",
	loot = "Операции с открытым контейнером",
	perks = "Возможности вашего сектора",
	daily = "Награда за время в лаборатории",
	dial = "Остановите указатель в выделенном секторе",
}
local DISPLAY_TYPES: { [string]: string } =
	{ small = "Малые предметы", large = "Крупные предметы", car = "Автомобили" }
local SEALED_HELP: { [string]: string } = {
	box = "Подойдите к коробке и снимите скотч.",
	crate = "Сломайте четыре крепления на ящике.",
	safe = "Активируйте ручку и остановите её в секторе.",
	cargo = "Разблокируйте оба фиксатора и откройте створки.",
	secret = "Активируйте контейнер, пока он не откроется.",
}
local PERK_EFFECTS: { [string]: string } = {
	storage = "Вместимость склада",
	orders = "Вместимость очереди",
	odds = "Вероятность более редкой доставки",
	sale = "Доплата при продаже находок",
	quickCollect = "Сбор всей добычи одним действием",
	quickSell = "Продажа всей добычи одним действием",
}
local PERK_PARENTS: { [string]: string } = { storage = "Склад", sale = "Бонус продажи" }

type Dial = { Id: string, Start: number, Target: number, Period: number, Tolerance: number }
type Sort = "recent" | "price" | "quality"
type DailyWidgets = { Time: TextLabel, Caption: TextLabel, Fill: Frame, Button: TextButton }
type DialWidgets = { Needle: Frame, Time: TextLabel }
type OrderTelemetry = { OrderProgress: number?, OrderGoal: number?, OrderDeadline: number? }

local SimulatorController = {}
local state: Types.View?
local menu: string?
local dial: Dial?
local sort: Sort = "recent"

local action: RemoteEvent
local title: TextLabel
local subtitle: TextLabel
local balance: TextLabel
local statusHeading: TextLabel
local statusHint: TextLabel
local statusSignal: Frame
local rewardButton: TextButton
local notice: Frame
local noticeText: TextLabel
local panel: Frame
local backdrop: TextButton
local close: TextButton
local content: ScrollingFrame
local dailyWidgets: DailyWidgets?
local dialWidgets: DialWidgets?
local deliveryLabel: TextLabel?
local preferredFocus: GuiObject?
local noticeSerial = 0
local contentOrder = 0
local selectMenu: (string?) -> ()

local function append(gui: GuiObject): ()
	contentOrder += 1
	gui.LayoutOrder = contentOrder
	gui.Parent = content
end

local function label(parent: Instance, value: string, size: number, color: Color3?, bold: boolean?): TextLabel
	return Style.label(parent, value, size, color, if bold then Enum.Font.GothamBold else nil)
end

local function place(gui: GuiObject, x: number, y: number, width: UDim, height: number): ()
	gui.Position = UDim2.fromOffset(x, y)
	gui.Size = UDim2.new(width, UDim.new(0, height))
end

local function heading(value: string): ()
	local field = label(content, value, 15, Style.Text, true)
	field.Size = UDim2.new(1, -9, 0, 28)
	append(field)
end

local function paragraph(value: string, height: number, color: Color3?): ()
	local field = label(content, value, 14, color or Style.Muted)
	field.Size = UDim2.new(1, -9, 0, height)
	append(field)
end

local function card(height: number, color: Color3?): Frame
	local result = Style.frame(content, color or Style.Card, 9)
	result.Size = UDim2.new(1, -9, 0, height)
	Style.outline(result)
	append(result)
	return result
end

local function prefer(button: TextButton): ()
	if not preferredFocus and button.Selectable then
		preferredFocus = button
	end
end

local function command(value: string, callback: () -> (), enabled: boolean?, tone: Style.ButtonTone?): TextButton
	local control = Style.button(content, value, callback, enabled, tone)
	control.Size = UDim2.new(1, -9, 0, 44)
	append(control)
	prefer(control)
	return control
end

local function row(
	name: string,
	details: string,
	tint: Color3,
	caption: string?,
	callback: (() -> ())?,
	enabled: boolean?,
	focusKey: string?
): ()
	local entry = card(68)
	local stripe = Style.frame(entry, tint, 2)
	place(stripe, 10, 14, UDim.new(0, 3), 40)
	local headline = label(entry, name, 15, Style.Text, true)
	place(headline, 22, 4, UDim.new(1, if caption then -134 else -34), 33)
	local sub = label(entry, details, 12, Style.Muted)
	place(sub, 22, 37, UDim.new(1, if caption then -134 else -34), 26)
	sub.TextYAlignment = Enum.TextYAlignment.Top

	if caption and callback then
		local control = Style.button(entry, caption, callback, enabled)
		control.Name = focusKey or name
		control.AnchorPoint = Vector2.new(1, 0.5)
		control.Position = UDim2.new(1, -10, 0.5, 0)
		control.Size = UDim2.fromOffset(94, 44)
		prefer(control)
	end
end

local function send(name: string, argument: string?, extra: string?): ()
	action:FireServer(name, argument, extra)
end

local function coin(value: number): string
	local reversed = string.reverse(tostring(value))
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1 ")
	return (string.gsub(string.reverse(grouped), "^ ", ""))
end

local function clockText(seconds: number): string
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local function itemDetails(item: Types.Item): string
	return `{Catalog.condition(item.Quality)} · {item.Quality}/100`
end

local function qualityColor(quality: number): Color3
	if quality >= 90 then
		return Style.Amber
	elseif quality >= 70 then
		return Style.Signal
	end
	return Style.Muted
end

local function containerName(data: Types.View): string
	local kind = data.OrderKind
	if kind then
		return (if data.OrderVariant then Catalog.Variants else Catalog.Containers)[kind]
	end
	return "Случайный контейнер"
end

local function displayProgress(data: Types.View): string?
	local progress = (data :: Types.View & OrderTelemetry).OrderProgress
	local goal = (data :: Types.View & OrderTelemetry).OrderGoal
	if progress and goal then
		return `Шаг {progress} / {goal}`
	end
	return nil
end

local function statusText(data: Types.View): (string, string, Color3)
	local stage = data.OrderStage
	if stage == "queued" or stage == "delivery" then
		return "Контейнер в пути",
			"Дождитесь доставки у верхнего шлюза.",
			Style.Amber
	elseif stage == "sealed" then
		return containerName(data),
			SEALED_HELP[data.OrderKind or "box"] or "Откройте контейнер.",
			Style.Signal
	elseif stage == "open" then
		local hint = if data.OrderKind == "cargo"
			then "Войдите в контейнер за добычей."
			else "Подберите предметы на площадке."
		return `Добыча на площадке · {data.RemainingLoot}`, hint, Style.Signal
	elseif stage == "clear" then
		return "Площадка готова к очистке",
			"Выйдите из зоны шлюза.",
			Style.Amber
	elseif #data.Inventory > 0 then
		return "Сектор готов к приёму",
			"Продайте находки на складе или оформите заказ.",
			Style.Signal
	end
	return "Сектор готов к приёму",
		"Оформите заказ через терминал.",
		Style.Signal
end

local function odds(level: number, nextLevel: number?): ()
	local values = Catalog.Odds[level + 1]
	local following = if nextLevel then Catalog.Odds[nextLevel + 1] else nil
	local summary = card(#values * 33 + 16, Style.Track)
	for index, chance in values do
		local kind = Catalog.Kinds[index]
		local top = 8 + (index - 1) * 33
		local name = label(summary, Catalog.Containers[kind], 12, Style.Text)
		place(name, 12, top, UDim.new(1, -101), 19)
		local chanceText = if following then `{chance}% → {following[index]}%` else `{chance}%`
		local number = label(summary, chanceText, 12, Style.Muted, true)
		number.TextXAlignment = Enum.TextXAlignment.Right
		number.AnchorPoint = Vector2.new(1, 0)
		number.Position = UDim2.new(1, -12, 0, top)
		number.Size = UDim2.fromOffset(80, 19)
		local track =
			Style.meter(summary, if following then following[index] / 100 else chance / 100, Preview.color(kind))
		track.BackgroundColor3 = Style.Card
		place(track, 12, top + 21, UDim.new(1, -24), 4)
	end
end

local function terminal(data: Types.View): ()
	local maximum = 1 + (data.Perks.orders or 0)
	local available = data.Orders < maximum
	local canPay = data.Coins >= Config.OrderPrice
	local name, hint, tint = statusText(data)
	local hero = card(139)
	local preview = Preview.draw(hero, data.OrderKind or "cargo")
	preview.AnchorPoint = Vector2.new(1, 0)
	preview.Position = UDim2.new(1, -6, 0, 0)
	preview.Size = UDim2.new(0.35, 0, 0, 99)
	local progress = displayProgress(data)
	local queueText = if progress then progress else `АКТИВНЫЕ ЗАКАЗЫ    {data.Orders} / {maximum}`
	local queue = label(hero, queueText, 11, tint, true)
	place(queue, 13, 9, UDim.new(0.68, -14), 17)
	local heroTitle = label(hero, name, 20, Style.Text, true)
	place(heroTitle, 13, 27, UDim.new(0.68, -14), 51)
	local heroHint = label(hero, hint, 12, Style.Muted)
	place(heroHint, 13, 79, UDim.new(1, -26), 29)
	if data.OrderStage == "delivery" then
		deliveryLabel = heroHint
	end
	local slots = Style.frame(hero)
	place(slots, 13, 114, UDim.new(1, -26), 8)
	for index = 1, maximum do
		local marker = Style.frame(slots, if index <= data.Orders then tint else Style.Track, 3)
		marker.Position = UDim2.fromScale((index - 1) / maximum, 0)
		marker.Size = UDim2.new(1 / maximum, -4, 1, 0)
	end
	local caption = if not available
		then "Очередь заполнена"
		elseif not canPay then `Нужно ещё {coin(Config.OrderPrice - data.Coins)} монет`
		else `Оформить заказ   ·   {coin(Config.OrderPrice)} монет`
	command(caption, function()
		send("buy")
	end, available and canPay)

	heading("Шансы доставки")
	odds(data.Perks.odds or 0)
end

local function inventory(data: Types.View): ()
	local capacity = 15 + 5 * (data.Perks.storage or 0)
	local storage = card(71)
	local count = label(storage, `Занято {#data.Inventory} / {capacity} мест`, 18, Style.Text, true)
	place(count, 13, 8, UDim.new(1, -26), 34)
	local track = Style.meter(
		storage,
		#data.Inventory / capacity,
		if #data.Inventory >= capacity then Style.Amber else Style.Signal
	)
	place(track, 13, 50, UDim.new(1, -26), 7)

	if #data.Inventory == 0 then
		paragraph(
			"Склад пуст. Подберите добычу на площадке и вернитесь сюда.",
			53
		)
		return
	end
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
	for _, item in results do
		row(
			Catalog.Items[item.Kind].Name,
			`{itemDetails(item)} · {coin(data.Prices[item.Id] or 0)} монет`,
			qualityColor(item.Quality),
			"Продать",
			function()
				send("sell", item.Id)
			end,
			data.Prices[item.Id] ~= nil,
			item.Id
		)
	end
end

local function collections(data: Types.View): ()
	local matches: { [string]: { Types.Item } } = {}
	for _, item in data.Inventory do
		local group = matches[item.Kind]
		if not group then
			group = {}
			matches[item.Kind] = group
		end
		table.insert(group, item)
	end
	for _, collection in Catalog.Collections do
		local quality, count = 0, 0
		for _, kind in collection.Items do
			local saved = data.Collections[kind]
			if saved then
				count += 1
				quality += saved.Quality
			end
		end
		local complete = count == #collection.Items
		local group = card(82)
		local groupTitle = label(group, collection.Name, 18, Style.Text, true)
		place(groupTitle, 13, 6, UDim.new(1, -26), 36)
		local progress = if complete
			then string.format("+%.1f%% при продаже", quality / count / 10)
			else `Экспонаты   {count} / {#collection.Items}`
		local groupCount = label(group, progress, 13, if complete then Style.Signal else Style.Muted, true)
		place(groupCount, 13, 41, UDim.new(1, -26), 21)
		local track = Style.meter(group, count / #collection.Items, Style.Signal)
		place(track, 13, 69, UDim.new(1, -26), 4)
		for _, kind in collection.Items do
			local saved = data.Collections[kind]
			local definition = Catalog.Items[kind]
			row(
				definition.Name,
				if saved then itemDetails(saved) else "Нет в коллекции",
				definition.Color,
				nil
			)
			local matching: { Types.Item } = matches[kind] or {}
			for _, item in matching do
				row(
					definition.Name,
					`Со склада · {itemDetails(item)}`,
					qualityColor(item.Quality),
					if saved then "Заменить" else "Внести",
					function()
						send("collection", item.Id)
					end,
					nil,
					item.Id
				)
			end
		end
	end
end

local function showcases(data: Types.View, key: string): ()
	local size = Catalog.DisplaySizes[tonumber(key) or 0]
	if not size then
		return
	end
	heading(DISPLAY_TYPES[size])
	local item = data.Displays[key]
	if item then
		local definition = Catalog.Items[item.Kind]
		row(definition.Name, itemDetails(item), definition.Color, "На склад", function()
			send("removeDisplay", nil, key)
		end)
		return
	end
	local found = false
	for _, candidate in data.Inventory do
		local definition = Catalog.Items[candidate.Kind]
		if definition.Size == size then
			found = true
			row(definition.Name, itemDetails(candidate), definition.Color, "Выставить", function()
				send("display", candidate.Id, key)
			end, nil, candidate.Id)
		end
	end
	if not found then
		paragraph("На складе пока нет предметов подходящего размера.", 52)
	end
end

local function perkTree(data: Types.View): ()
	for _, perk in Catalog.Perks do
		local level = data.Perks[perk.Key] or 0
		local cost = perk.Costs[level + 1]
		local parentLevel = perk.Required or 1
		local unlocked = not perk.Parent or (data.Perks[perk.Parent] or 0) >= parentLevel
		local benefit = PERK_EFFECTS[perk.Key]
		if perk.Key == "storage" then
			benefit = `{15 + level * 5} мест на складе`
		elseif perk.Key == "orders" then
			benefit = `Мест в очереди · {1 + level}`
		elseif perk.Key == "sale" then
			benefit = `+{level * 10}% при продаже`
		end
		local detail = if not unlocked and perk.Parent
			then `«{PERK_PARENTS[perk.Parent]}» · уровень {parentLevel}`
			else `{benefit} · {level}/{#perk.Costs}`
		row(
			perk.Name,
			detail,
			if unlocked then Style.Signal else Style.Amber,
			if cost then `{coin(cost)} монет` else "Максимум",
			function()
				send("perk", perk.Key)
			end,
			cost ~= nil and unlocked and data.Coins >= (cost or 0)
		)
		if perk.Key == "odds" then
			heading(
				if cost
					then "Шансы сейчас → после улучшения"
					else "Шансы доставки"
			)
			odds(level, if cost then level + 1 else nil)
		end
	end
end

local function loot(data: Types.View): ()
	local open = data.OrderStage == "open" and data.RemainingLoot > 0
	local name, hint, tint = statusText(data)
	local summary = card(96)
	local current = label(summary, name, 19, tint, true)
	place(current, 13, 8, UDim.new(1, -26), 47)
	local caption = label(summary, hint, 13, Style.Muted)
	place(caption, 13, 55, UDim.new(1, -26), 30)
	row(
		"Быстрый сбор",
		if (data.Perks.quickCollect or 0) > 0
			then "Переместить добычу на склад"
			else "Откройте перк «Быстрый сбор»",
		Style.Signal,
		"Собрать",
		function()
			send("quickCollect")
		end,
		open and (data.Perks.quickCollect or 0) > 0
	)
	row(
		"Быстрая продажа",
		if (data.Perks.quickSell or 0) > 0
			then "Продать добычу на площадке"
			else "Откройте перк «Быстрая продажа»",
		Style.Amber,
		"Продать",
		function()
			send("quickSell")
		end,
		open and (data.Perks.quickSell or 0) > 0
	)
end

local function daily(): ()
	local summary = card(158, Style.Track)
	local remaining = Style.label(summary, "", 43, Style.Amber, Enum.Font.RobotoMono)
	place(remaining, 13, 14, UDim.new(1, -26), 73)
	remaining.TextXAlignment = Enum.TextXAlignment.Center
	local caption = label(summary, "", 14, Style.Muted)
	place(caption, 13, 87, UDim.new(1, -26), 32)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	local track, fill = Style.meter(summary, 0, Style.Amber)
	track.BackgroundColor3 = Style.Card
	place(track, 23, 130, UDim.new(1, -46), 7)
	local control = command("Забрать награду", function()
		send("daily")
	end, false, "reward")
	dailyWidgets = { Time = remaining, Caption = caption, Fill = fill, Button = control }
end

local function safeDial(roundData: Dial, stop: () -> ()): ()
	local summary = card(138, Style.Track)
	local left = label(summary, "0", 12, Style.Muted, true)
	place(left, 16, 11, UDim.new(0, 28), 24)
	local time = Style.label(summary, "", 15, Style.Amber, Enum.Font.RobotoMono)
	time.TextXAlignment = Enum.TextXAlignment.Right
	time.AnchorPoint = Vector2.new(1, 0)
	time.Position = UDim2.new(1, -16, 0, 11)
	time.Size = UDim2.fromOffset(130, 24)

	local track = Style.frame(summary, Style.Card, 6)
	place(track, 16, 42, UDim.new(1, -32), 49)
	Style.outline(track)
	local sector = Style.frame(track, Style.Signal, 3)
	sector.AnchorPoint = Vector2.new(0.5, 0)
	sector.Position = UDim2.new(roundData.Target, 0, 0, 4)
	sector.Size = UDim2.new(roundData.Tolerance * 2, 0, 1, -8)
	local target = label(sector, "ЦЕЛЬ", 12, Style.Ink, true)
	target.TextXAlignment = Enum.TextXAlignment.Center
	target.Size = UDim2.fromScale(1, 1)
	for tick = 0, 10 do
		local mark = Style.frame(summary, Style.Muted)
		mark.AnchorPoint = Vector2.new(0.5, 0)
		mark.Position = UDim2.new(tick / 10, 16 - (tick / 10) * 32, 0, 98)
		mark.Size = UDim2.fromOffset(1, if tick % 5 == 0 then 10 else 5)
	end
	local needle = Style.frame(track, Style.Amber, 3)
	needle.AnchorPoint = Vector2.new(0.5, 0)
	needle.Size = UDim2.new(0, 6, 1, 8)
	needle.Position = UDim2.fromOffset(0, -4)
	Style.outline(needle, Style.Ink)
	dialWidgets = { Needle = needle, Time = time }
	command("Остановить ручку", stop)
end

local function displayNotice(message: string): ()
	noticeSerial += 1
	local serial = noticeSerial
	noticeText.Text = message
	notice.Visible = true
	task.delay(3.6, function()
		if noticeSerial == serial then
			notice.Visible = false
		end
	end)
end

local function updateClocks(): ()
	local data = state
	if not data then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local claimed = data.DailyClaim >= math.floor(now / 86400)
	local remaining = math.max(0, math.ceil(data.DailyReadyAt - now))
	local canClaim = not claimed and remaining == 0
	local rewardText = if canClaim then "Забрать награду" else "Награда"
	rewardButton.Text = rewardText
	Style.setButton(rewardButton, true, if canClaim then "reward" else "neutral")
	local arrival = (data :: Types.View & OrderTelemetry).OrderDeadline
	if menu == "terminal" and deliveryLabel and arrival and data.OrderStage == "delivery" then
		local seconds = math.max(0, math.ceil(arrival - now))
		deliveryLabel.Text = if seconds > 0
			then `Прибытие через {clockText(seconds)}`
			else "Контейнер у шлюза."
	end
	local widgets = dailyWidgets
	if menu == "daily" and widgets then
		widgets.Time.Text = if claimed
			then "ПОЛУЧЕНО"
			elseif canClaim then "ГОТОВО"
			else clockText(remaining)
		widgets.Caption.Text = if claimed
			then "Награда сегодня получена"
			elseif canClaim then "Награда доступна"
			else "До получения награды"
		widgets.Fill.Size =
			UDim2.fromScale(if claimed then 1 else math.clamp(1 - remaining / Config.DailySeconds, 0, 1), 1)
		Style.setButton(widgets.Button, canClaim, "reward")
		prefer(widgets.Button)
	end
end

local function gamepadActive(): boolean
	local input = UserInputService:GetLastInputType()
	return input.Name:sub(1, 7) == "Gamepad"
end

local function refresh(preserveScroll: boolean?): ()
	local key, data = menu, state
	panel.Visible, backdrop.Visible = key ~= nil, key ~= nil
	if not key then
		dialWidgets, dailyWidgets, preferredFocus, deliveryLabel = nil, nil, nil, nil
		return
	end
	local canvas = content.CanvasPosition
	local oldSelection = GuiService.SelectedObject
	local selectedName = oldSelection and oldSelection:IsDescendantOf(content) and oldSelection.Name
	contentOrder = 0
	for _, object in content:GetChildren() do
		if object:IsA("GuiObject") then
			object:Destroy()
		end
	end
	dialWidgets, dailyWidgets, preferredFocus, deliveryLabel = nil, nil, nil, nil
	title.Text = TITLES[key] or `Витрина {key}`
	subtitle.Text = CAPTIONS[key] or "Экспозиция вашего сектора"

	if not data then
		paragraph("Синхронизация данных сектора…", 55)
	elseif key == "terminal" then
		terminal(data)
	elseif key == "inventory" then
		local sortBar = Style.frame(content)
		sortBar.Size = UDim2.new(1, -9, 0, 44)
		append(sortBar)
		local options: { { Key: Sort, Caption: string } } = {
			{ Key = "recent", Caption = "Последние" },
			{ Key = "price", Caption = "По цене" },
			{ Key = "quality", Caption = "По качеству" },
		}
		for index, option in options do
			local choice = Style.button(sortBar, option.Caption, function()
				sort = option.Key
				refresh(false)
			end, true, if sort == option.Key then "primary" else "neutral")
			choice.Position = UDim2.fromScale((index - 1) / 3, 0)
			choice.Size = UDim2.new(1 / 3, if index == 3 then 0 else -5, 1, 0)
		end
		inventory(data)
	elseif key == "collections" then
		collections(data)
	elseif key == "perks" then
		perkTree(data)
	elseif key == "loot" then
		loot(data)
	elseif key == "daily" then
		daily()
	elseif key == "dial" then
		local roundData = dial
		if roundData then
			safeDial(roundData, function()
				send("open", roundData.Id)
				selectMenu(nil)
			end)
		end
	else
		showcases(data, key)
	end

	updateClocks()
	if preserveScroll then
		task.defer(function()
			if menu == key then
				content.CanvasPosition = canvas
			end
		end)
	else
		content.CanvasPosition = Vector2.zero
	end
	if gamepadActive() and oldSelection ~= close then
		local nextFocus = preferredFocus or close
		if selectedName then
			for _, descendant in content:GetDescendants() do
				if descendant:IsA("GuiButton") and descendant.Name == selectedName and descendant.Selectable then
					nextFocus = descendant
					break
				end
			end
		end
		GuiService.SelectedObject = nextFocus
	end
end

selectMenu = function(key: string?): ()
	local previous = menu
	menu = key
	if key ~= "dial" then
		dial = nil
	end
	refresh(previous == key)
	if not key and previous and gamepadActive() then
		GuiService.SelectedObject = nil
	end
end

local function build(): ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CORPA"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local hud = Style.frame(gui, Style.Ink, 10)
	hud.Name = "Сектор"
	hud.AnchorPoint = Vector2.new(0.5, 0)
	hud.Position = UDim2.new(0.5, 0, 0, 8)
	hud.Size = UDim2.new(1, -20, 0, 110)
	Style.outline(hud)
	local maxHud = Instance.new("UISizeConstraint")
	maxHud.MaxSize = Vector2.new(378, 110)
	maxHud.Parent = hud

	statusSignal = Style.frame(hud, Style.Amber, 2)
	place(statusSignal, 11, 14, UDim.new(0, 4), 19)
	statusHeading = label(hud, "Синхронизация сектора…", 14, Style.Text, true)
	place(statusHeading, 22, 6, UDim.new(0.64, -22), 34)
	balance = label(hud, "", 14, Style.Amber, true)
	balance.AnchorPoint = Vector2.new(1, 0)
	balance.Position = UDim2.new(1, -10, 0, 6)
	balance.Size = UDim2.new(0.36, -4, 0, 34)
	balance.TextXAlignment = Enum.TextXAlignment.Right
	statusHint = label(hud, "", 12, Style.Muted)
	place(statusHint, 11, 41, UDim.new(1, -22), 22)
	local perkButton = Style.button(hud, "Древо перков", function()
		selectMenu("perks")
	end, true, "neutral")
	perkButton.Position = UDim2.new(0, 10, 0, 68)
	perkButton.Size = UDim2.new(0.5, -14, 0, 34)
	rewardButton = Style.button(hud, "Награда", function()
		selectMenu("daily")
	end, true, "neutral")
	rewardButton.Position = UDim2.new(0.5, 4, 0, 68)
	rewardButton.Size = UDim2.new(0.5, -14, 0, 34)

	backdrop = Instance.new("TextButton")
	backdrop.Name = "Затемнение"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Style.Ink
	backdrop.BackgroundTransparency = 0.39
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Selectable = false
	backdrop.Visible = false
	backdrop.ZIndex = 2
	backdrop.Parent = gui
	backdrop.Activated:Connect(function()
		selectMenu(nil)
	end)

	panel = Style.frame(gui, Style.Panel, 13)
	panel.Name = "Меню сектора"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -20, 1, -22)
	panel.Visible = false
	panel.Active = true
	panel.SelectionGroup = true
	panel.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	panel.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	panel.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	panel.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	panel.ZIndex = 3
	Style.outline(panel)
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(572, 620)
	bounds.Parent = panel

	local tag = Style.frame(panel, Style.Amber, 2)
	place(tag, 16, 15, UDim.new(0, 29), 3)
	title = label(panel, "", 23, Style.Text, true)
	place(title, 16, 22, UDim.new(1, -74), 38)
	subtitle = label(panel, "", 12, Style.Muted)
	place(subtitle, 16, 59, UDim.new(1, -32), 26)
	close = Style.button(panel, "×", function()
		selectMenu(nil)
	end, true, "neutral")
	close.TextSize = 22
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -13, 0, 18)
	close.Size = UDim2.fromOffset(44, 44)
	local divider = Style.frame(panel, Style.Edge)
	place(divider, 16, 91, UDim.new(1, -32), 1)

	content = Instance.new("ScrollingFrame")
	content.Name = "Содержимое"
	content.Position = UDim2.fromOffset(16, 103)
	content.Size = UDim2.new(1, -26, 1, -114)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.ScrollBarImageColor3 = Style.Signal
	content.CanvasSize = UDim2.new()
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.Selectable = false
	content.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 9)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content
	local margin = Instance.new("UIPadding")
	margin.PaddingLeft = UDim.new(0, 1)
	margin.PaddingTop = UDim.new(0, 1)
	margin.PaddingBottom = UDim.new(0, 4)
	margin.Parent = content

	notice = Style.frame(gui, Style.Ink, 8)
	notice.Name = "Уведомление"
	notice.AnchorPoint = Vector2.new(0.5, 1)
	notice.Position = UDim2.new(0.5, 0, 1, -18)
	notice.Size = UDim2.new(1, -38, 0, 48)
	notice.Visible = false
	notice.ZIndex = 4
	Style.outline(notice, Style.Amber)
	noticeText = label(notice, "", 14, Style.Amber, true)
	place(noticeText, 12, 0, UDim.new(1, -24), 48)
	noticeText.TextXAlignment = Enum.TextXAlignment.Center
	local noticeBounds = Instance.new("UISizeConstraint")
	noticeBounds.MaxSize = Vector2.new(430, 48)
	noticeBounds.Parent = notice
end

local function animate(): ()
	local widgets, roundData = dialWidgets, dial
	if menu ~= "dial" or not widgets or not roundData then
		return
	end
	local elapsed = math.max(0, Workspace:GetServerTimeNow() - roundData.Start)
	if elapsed > 20 then
		selectMenu(nil)
		displayNotice("Время вышло. Поверните ручку снова.")
		return
	end
	widgets.Needle.Position = UDim2.new((elapsed % roundData.Period) / roundData.Period, 0, 0, -4)
	widgets.Time.Text = `Осталось {math.ceil(20 - elapsed)} с`
end

function SimulatorController:Start(): ()
	action = Remotes.event(Remotes.Events.Action)
	build()
	Remotes.event(Remotes.Events.Interface).OnClientEvent:Connect(function(mode, value, ...)
		if mode == "menu" then
			selectMenu(value)
		elseif mode == "notice" then
			displayNotice(value)
		elseif mode == "dial" then
			local start, target, period, tolerance = ...
			dial = { Id = value, Start = start, Target = target, Period = period, Tolerance = tolerance }
			selectMenu("dial")
		end
	end)
	Data:OnChanged(function(data)
		state = data
		balance.Text = `{coin(data.Coins)} монет`
		local headingText, hint, tint = statusText(data)
		local progress = displayProgress(data)
		if progress then
			headingText = `{headingText} · {progress}`
		end
		statusHeading.Text, statusHint.Text, statusSignal.BackgroundColor3 = headingText, hint, tint
		if menu ~= "dial" then
			refresh(true)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, consumed)
		if not consumed and input.KeyCode == Enum.KeyCode.ButtonB and menu then
			selectMenu(nil)
		end
	end)
	RunService.RenderStepped:Connect(animate)
	while true do
		task.wait(0.25)
		updateClocks()
	end
end

return SimulatorController
