--!strict
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

local INK = Color3.fromRGB(10, 20, 29)
local PANEL = Color3.fromRGB(17, 31, 43)
local ROW = Color3.fromRGB(27, 45, 58)
local ICE = Color3.fromRGB(110, 242, 224)
local TEXT = Color3.fromRGB(231, 241, 245)
local MUTED = Color3.fromRGB(161, 185, 199)
local AMBER = Color3.fromRGB(255, 190, 105)

local TITLES: { [string]: string } = {
	terminal = "Терминал заказов",
	inventory = "Склад",
	collections = "Коллекции",
	loot = "Управление добычей",
	perks = "Древо перков",
	daily = "Ежедневная награда",
	dial = "Ручка сейфа",
}
local SIZE_NAMES: { [string]: string } =
	{ small = "Маленький", large = "Большой", car = "Автомобиль" }
local SEALED_HELP: { [string]: string } = {
	box = "Отклейте скотч с коробки.",
	crate = "Сломайте четыре крепления ящика.",
	safe = "Поверните ручку сейфа и остановите её в выделенном секторе.",
	cargo = "Разблокируйте оба фиксатора и откройте створки.",
	secret = "Усильте свечение контейнера до открытия.",
}

type Dial = { Id: string, Start: number, Target: number, Period: number, Tolerance: number }
local state: Types.View?
local menu: string?
local dial: Dial?
local title: TextLabel
local balance: TextLabel
local status: TextLabel
local notice: TextLabel
local panel: Frame
local backdrop: TextButton
local content: ScrollingFrame
local dialNeedle: Frame?
local dailyClock: TextLabel?
local dailyButton: TextButton?
local noticeSerial = 0
local contentOrder = 0
local action: RemoteEvent

local SimulatorController = {}

local function round(parent: GuiObject, radius: number): ()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function text(parent: Instance, value: string, size: number, color: Color3?, bold: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextColor3 = color or TEXT
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	label.TextSize = size
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function button(parent: Instance, label: string, callback: () -> (), enabled: boolean?): TextButton
	local control = Instance.new("TextButton")
	control.BackgroundColor3 = if enabled == false then ROW else ICE
	control.TextColor3 = if enabled == false then MUTED else INK
	control.Font = Enum.Font.GothamBold
	control.TextSize = 14
	control.TextWrapped = true
	control.AutoButtonColor = enabled ~= false
	control.Interactable = enabled ~= false
	control.Text = label
	control.Parent = parent
	round(control, 8)
	control.Activated:Connect(function()
		if control.Interactable then
			callback()
		end
	end)
	return control
end

local function append(gui: GuiObject): ()
	contentOrder += 1
	gui.LayoutOrder = contentOrder
	gui.Parent = content
end

local function block(value: string, height: number, color: Color3?, bold: boolean?): TextLabel
	local label = text(content, value, if bold then 17 else 15, color, bold)
	label.Size = UDim2.new(1, -8, 0, height)
	append(label)
	return label
end

local function command(label: string, callback: () -> (), enabled: boolean?): TextButton
	local control = button(content, label, callback, enabled)
	control.Size = UDim2.new(1, -8, 0, 46)
	append(control)
	return control
end

local function row(name: string, details: string, label: string?, callback: (() -> ())?, enabled: boolean?): ()
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, 68)
	card.BackgroundColor3 = ROW
	append(card)
	round(card, 9)
	local headline = text(card, name, 15, TEXT, true)
	headline.Position = UDim2.fromOffset(12, 5)
	headline.Size = UDim2.new(1, if label then -127 else -24, 0, 24)
	local subtitle = text(card, details, 12, MUTED)
	subtitle.Position = UDim2.fromOffset(12, 29)
	subtitle.Size = UDim2.new(1, if label then -127 else -24, 0, 32)
	subtitle.TextYAlignment = Enum.TextYAlignment.Top
	if label and callback then
		local control = button(card, label, callback, enabled)
		control.AnchorPoint = Vector2.new(1, 0.5)
		control.Position = UDim2.new(1, -9, 0.5, 0)
		control.Size = UDim2.fromOffset(101, 43)
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

local function itemDetails(item: Types.Item): string
	return `{Catalog.condition(item.Quality)} · {item.Quality}/100`
end

local function statusText(data: Types.View): string
	local stage = data.OrderStage
	if stage == "queued" or stage == "delivery" then
		return "Контейнер прибывает через верхний шлюз."
	elseif stage == "sealed" then
		return SEALED_HELP[data.OrderKind or "box"] or "Откройте контейнер."
	elseif stage == "open" then
		local hint = if data.OrderKind == "cargo"
			then "Войдите в контейнер."
			else "Подберите предметы на площадке."
		return `Добыча: {data.RemainingLoot}. {hint}`
	elseif stage == "clear" then
		return "Выйдите из зоны шлюза, чтобы освободить площадку."
	end
	return "Закажите контейнер на терминале своего сектора."
end

local function odds(level: number): string
	local values = Catalog.Odds[level + 1]
	local lines = {}
	for index, chance in values do
		table.insert(lines, `{Catalog.Containers[Catalog.Kinds[index]]} · {chance}%`)
	end
	return table.concat(lines, "\n")
end

local function terminal(data: Types.View): ()
	local maximum = 1 + (data.Perks.orders or 0)
	block(`Активные заказы · {data.Orders}/{maximum}`, 29, ICE, true)
	local kind = data.OrderKind
	if kind then
		block((if data.OrderVariant then Catalog.Variants else Catalog.Containers)[kind], 29, TEXT, true)
	end
	block(statusText(data), 43, TEXT)
	block("Вероятности заказа", 30, ICE, true)
	block(odds(data.Perks.odds or 0), 114, TEXT)
	command(`Заказать за {coin(Config.OrderPrice)} монет`, function()
		send("buy")
	end, data.Coins >= Config.OrderPrice and data.Orders < maximum)
end

local function inventory(data: Types.View): ()
	block(`Занято {#data.Inventory} из {15 + 5 * (data.Perks.storage or 0)} слотов`, 32, ICE, true)
	if #data.Inventory == 0 then
		block(
			"На складе пока пусто. Подберите добычу у контейнера.",
			58,
			MUTED
		)
	end
	for _, item in data.Inventory do
		row(
			Catalog.Items[item.Kind].Name,
			`{itemDetails(item)} · {coin(data.Prices[item.Id])} монет`,
			"Продать",
			function()
				send("sell", item.Id)
			end
		)
	end
end

local function collections(data: Types.View): ()
	for _, collection in Catalog.Collections do
		local sum, count = 0, 0
		for _, kind in collection.Items do
			local saved = data.Collections[kind]
			if saved then
				count += 1
				sum += saved.Quality
			end
		end
		local progress = if count == #collection.Items
			then string.format("+%.1f%%", sum / count / 10)
			else `{count}/{#collection.Items}`
		block(`{collection.Name} · {progress}`, 33, ICE, true)
		for _, kind in collection.Items do
			local saved = data.Collections[kind]
			local definition = Catalog.Items[kind]
			row(definition.Name, if saved then itemDetails(saved) else "Слот свободен", nil)
			for _, item in data.Inventory do
				if item.Kind == kind then
					row(
						"На складе",
						itemDetails(item),
						if saved then "Заменить" else "Внести",
						function()
							send("collection", item.Id)
						end
					)
				end
			end
		end
	end
end

local function showcases(data: Types.View, key: string): ()
	local size = Catalog.DisplaySizes[tonumber(key) or 0]
	if not size then
		return
	end
	block(SIZE_NAMES[size], 30, ICE, true)
	local item = data.Displays[key]
	if item then
		row(Catalog.Items[item.Kind].Name, itemDetails(item), "На склад", function()
			send("removeDisplay", nil, key)
		end)
		return
	end
	local found = false
	for _, candidate in data.Inventory do
		if Catalog.Items[candidate.Kind].Size == size then
			found = true
			row(Catalog.Items[candidate.Kind].Name, itemDetails(candidate), "Выставить", function()
				send("display", candidate.Id, key)
			end)
		end
	end
	if not found then
		block("На складе пока нет предметов подходящего размера.", 52, MUTED)
	end
end

local function perkTree(data: Types.View): ()
	local levels = data.Perks
	for _, perk in Catalog.Perks do
		local level = levels[perk.Key] or 0
		local cost = perk.Costs[level + 1]
		local parentLevel = perk.Required or 1
		local unlocked = not perk.Parent or (levels[perk.Parent] or 0) >= parentLevel
		local description = `Уровень {level}/{#perk.Costs}`
		if perk.Key == "storage" then
			description ..= ` · {15 + level * 5} слотов`
		elseif perk.Key == "orders" then
			description ..= ` · {1 + level} заказов`
		elseif perk.Key == "sale" then
			description ..= ` · +{level * 10}%`
		elseif not unlocked then
			local parentName = if perk.Parent == "storage" then "Склад" else "Бонус продажи"
			description = `Требуется «{parentName}» · уровень {parentLevel}`
		end
		row(perk.Name, description, if cost then coin(cost) else "Макс.", function()
			send("perk", perk.Key)
		end, cost ~= nil and unlocked and data.Coins >= (cost or 0))
		if perk.Key == "odds" then
			block("Текущие шансы", 28, MUTED, true)
			block(odds(level), 108)
			if cost then
				block("Шансы после улучшения", 29, ICE, true)
				block(odds(level + 1), 109)
			end
		end
	end
end

local function loot(data: Types.View): ()
	block(statusText(data), 62, TEXT)
	local canUse = data.OrderStage == "open" and data.RemainingLoot > 0
	for _, option in
		{
			{ "quickCollect", "Собрать на склад" },
			{ "quickSell", "Продать оставшуюся добычу" },
		}
	do
		local name, caption = option[1], option[2]
		local unlocked = (data.Perks[name] or 0) > 0
		command(if unlocked then caption else `{caption} · требуется перк`, function()
			send(name)
		end, canUse and unlocked)
	end
end

local function daily(data: Types.View): ()
	block("Проведите в игре 15 минут, затем заберите награду.", 56, TEXT)
	dailyClock = block("", 47, ICE, true)
	dailyButton = command("Забрать награду", function()
		send("daily")
	end, data.DailyReadyAt <= Workspace:GetServerTimeNow())
end

local function safeDial(): ()
	local roundData = dial
	if not roundData then
		block("Подойдите к сейфу и снова поверните ручку.", 62, TEXT)
		return
	end
	block("Остановите бегунок в зелёном секторе.", 54, TEXT)
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -8, 0, 45)
	track.BackgroundColor3 = ROW
	append(track)
	round(track, 8)
	local sector = Instance.new("Frame")
	sector.AnchorPoint = Vector2.new(0.5, 0)
	sector.Position = UDim2.fromScale(roundData.Target, 0)
	sector.Size = UDim2.fromScale(roundData.Tolerance * 2, 1)
	sector.BackgroundColor3 = ICE
	sector.Parent = track
	round(sector, 5)
	local needle = Instance.new("Frame")
	needle.AnchorPoint = Vector2.new(0.5, 0)
	needle.Size = UDim2.new(0, 6, 1, 0)
	needle.BackgroundColor3 = AMBER
	needle.BorderSizePixel = 0
	needle.Parent = track
	dialNeedle = needle
	command("Остановить ручку", function()
		send("open", roundData.Id)
		dial = nil
		dialNeedle = nil
		panel.Visible, backdrop.Visible = false, false
		menu = nil
	end)
end

local function refresh(preserveScroll: boolean?): ()
	local key, data = menu, state
	panel.Visible, backdrop.Visible = key ~= nil, key ~= nil
	if not key then
		return
	end
	local canvas = content.CanvasPosition
	contentOrder = 0
	for _, object in content:GetChildren() do
		if object:IsA("GuiObject") then
			object:Destroy()
		end
	end
	dialNeedle, dailyClock, dailyButton = nil, nil, nil
	title.Text = TITLES[key] or `Витрина {key}`
	if not data then
		block("Загружаем данные игрока…", 55, MUTED)
	elseif key == "terminal" then
		terminal(data)
	elseif key == "inventory" then
		inventory(data)
	elseif key == "collections" then
		collections(data)
	elseif key == "perks" then
		perkTree(data)
	elseif key == "loot" then
		loot(data)
	elseif key == "daily" then
		daily(data)
	elseif key == "dial" then
		safeDial()
	else
		showcases(data, key)
	end
	if preserveScroll then
		task.defer(function()
			if menu == key then
				content.CanvasPosition = canvas
			end
		end)
	else
		content.CanvasPosition = Vector2.zero
	end
end

local function selectMenu(key: string?): ()
	menu = key
	if key ~= "dial" then
		dial = nil
	end
	refresh(false)
end

local function displayNotice(message: string): ()
	noticeSerial += 1
	local serial = noticeSerial
	notice.Text = message
	notice.Visible = true
	task.delay(3.5, function()
		if noticeSerial == serial then
			notice.Visible = false
		end
	end)
end

local function build(): ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CORPA"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local hud = Instance.new("Frame")
	hud.AnchorPoint = Vector2.new(0.5, 0)
	hud.Position = UDim2.new(0.5, 0, 0, 10)
	hud.Size = UDim2.new(1, -24, 0, 113)
	hud.BackgroundColor3 = INK
	hud.BackgroundTransparency = 0.12
	hud.Parent = gui
	round(hud, 12)
	local maxHud = Instance.new("UISizeConstraint")
	maxHud.MaxSize = Vector2.new(448, 113)
	maxHud.Parent = hud

	balance = text(hud, "Загружаем прогресс…", 18, ICE, true)
	balance.Position = UDim2.fromOffset(12, 4)
	balance.Size = UDim2.new(1, -24, 0, 28)
	status = text(hud, "", 13, TEXT)
	status.Position = UDim2.fromOffset(12, 32)
	status.Size = UDim2.new(1, -24, 0, 29)
	local perkButton = button(hud, "Древо перков", function()
		selectMenu("perks")
	end)
	perkButton.Position = UDim2.fromOffset(12, 69)
	perkButton.Size = UDim2.new(0.45, -10, 0, 32)
	local reward = button(hud, "Ежедневная награда", function()
		selectMenu("daily")
	end)
	reward.Position = UDim2.new(0.45, 8, 0, 69)
	reward.Size = UDim2.new(0.55, -20, 0, 32)

	backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = INK
	backdrop.BackgroundTransparency = 0.32
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Visible = false
	backdrop.Parent = gui
	backdrop.Activated:Connect(function()
		selectMenu(nil)
	end)
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -24, 1, -35)
	panel.BackgroundColor3 = PANEL
	panel.Visible = false
	panel.Active = true
	panel.Parent = gui
	round(panel, 14)
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(560, 650)
	bounds.Parent = panel
	local accent = Instance.new("UIStroke")
	accent.Color = ROW
	accent.Thickness = 2
	accent.Parent = panel

	title = text(panel, "", 23, ICE, true)
	title.Position = UDim2.fromOffset(17, 8)
	title.Size = UDim2.new(1, -75, 0, 47)
	local close = button(panel, "×", function()
		selectMenu(nil)
	end)
	close.TextSize = 22
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 13)
	close.Size = UDim2.fromOffset(38, 36)

	content = Instance.new("ScrollingFrame")
	content.Position = UDim2.fromOffset(17, 64)
	content.Size = UDim2.new(1, -30, 1, -80)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.ScrollBarImageColor3 = ICE
	content.CanvasSize = UDim2.new()
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	notice = text(gui, "", 16, INK, true)
	notice.AnchorPoint = Vector2.new(0.5, 1)
	notice.Position = UDim2.new(0.5, 0, 1, -26)
	notice.Size = UDim2.new(0.87, 0, 0, 48)
	notice.BackgroundColor3 = AMBER
	notice.BackgroundTransparency = 0.02
	notice.TextXAlignment = Enum.TextXAlignment.Center
	notice.Visible = false
	notice.ZIndex = 3
	notice.Parent = gui
	round(notice, 10)
	local noticeBounds = Instance.new("UISizeConstraint")
	noticeBounds.MaxSize = Vector2.new(480, 48)
	noticeBounds.Parent = notice
end

local function animate(): ()
	local now = Workspace:GetServerTimeNow()
	local clock, control, data = dailyClock, dailyButton, state
	if menu == "daily" and clock and control and data then
		local remaining = math.max(0, math.ceil(data.DailyReadyAt - now))
		local claimed = data.DailyClaim >= math.floor(now / 86400)
		local active = not claimed and remaining == 0
		if claimed then
			clock.Text = "Сегодня награда уже получена."
		elseif active then
			clock.Text = "Награда доступна."
		else
			clock.Text = string.format("До награды · %02d:%02d", remaining // 60, remaining % 60)
		end
		control.Interactable = active
		control.AutoButtonColor = active
		control.BackgroundColor3 = if active then ICE else ROW
		control.TextColor3 = if active then INK else MUTED
	end
	local needle, roundData = dialNeedle, dial
	if menu == "dial" and needle and roundData then
		if now - roundData.Start > 20 then
			selectMenu(nil)
			displayNotice("Время вышло. Поверните ручку снова.")
		else
			needle.Position = UDim2.fromScale(((now - roundData.Start) % roundData.Period) / roundData.Period, 0)
		end
	end
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
		status.Text = statusText(data)
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
end

return SimulatorController
