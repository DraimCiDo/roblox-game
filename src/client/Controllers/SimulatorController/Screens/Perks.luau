--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Components)
local Icons = require(script.Parent.Parent.Icons)
local Style = require(script.Parent.Parent.Style)

local BOARD = Color3.fromRGB(18, 20, 45)
local PANEL = Color3.fromRGB(31, 33, 65)
local RAIL = Color3.fromRGB(62, 67, 105)
local BRANCH_COLORS: { [string]: Color3 } = {
	logistics = Style.Violet,
	storage = Style.Cyan,
	trade = Style.Signal,
	luck = Style.Amber,
}
local WIDE_SIZE = Vector2.new(680, 485)
local COMPACT_SIZE = Vector2.new(350, 548)
local PANEL_WIDTH = 276
local MOBILE_DOCK = 194

type Layout = { Label: string, Icon: Icons.IconName, Wide: Vector2, Compact: Vector2 }
local LAYOUT: { [string]: Layout } = {
	orders = { Label = "Очередь", Icon = "box", Wide = Vector2.new(253, 173), Compact = Vector2.new(104, 178) },
	delivery = {
		Label = "Доставка",
		Icon = "screen",
		Wide = Vector2.new(165, 108),
		Compact = Vector2.new(49, 108),
	},
	discount = { Label = "Скидка", Icon = "coin", Wide = Vector2.new(77, 56), Compact = Vector2.new(44, 40) },
	daily = { Label = "Награда", Icon = "gift", Wide = Vector2.new(257, 61), Compact = Vector2.new(151, 61) },
	storage = { Label = "Склад", Icon = "grid", Wide = Vector2.new(223, 322), Compact = Vector2.new(256, 173) },
	quickCollect = {
		Label = "Быстрый сбор",
		Icon = "box",
		Wide = Vector2.new(94, 401),
		Compact = Vector2.new(295, 101),
	},
	sale = {
		Label = "Бонус продажи",
		Icon = "coin",
		Wide = Vector2.new(458, 163),
		Compact = Vector2.new(101, 317),
	},
	quickSell = {
		Label = "Быстрая продажа",
		Icon = "coin",
		Wide = Vector2.new(560, 84),
		Compact = Vector2.new(51, 384),
	},
	collection = {
		Label = "Коллекции",
		Icon = "grid",
		Wide = Vector2.new(612, 177),
		Compact = Vector2.new(113, 457),
	},
	odds = { Label = "Редкость", Icon = "box", Wide = Vector2.new(447, 317), Compact = Vector2.new(254, 303) },
	quality = {
		Label = "Качество",
		Icon = "star",
		Wide = Vector2.new(518, 374),
		Compact = Vector2.new(300, 366),
	},
	bonusLoot = {
		Label = "Двойная находка",
		Icon = "gift",
		Wide = Vector2.new(599, 411),
		Compact = Vector2.new(280, 446),
	},
	variant = {
		Label = "Вариации",
		Icon = "star",
		Wide = Vector2.new(621, 305),
		Compact = Vector2.new(190, 489),
	},
}

type NodeState = {
	Perk: Catalog.Perk,
	Level: number,
	Cost: number?,
	Locked: boolean,
	Reason: string?,
	Color: Color3,
}
type NodeWidget = { Button: TextButton, Border: UIStroke, State: NodeState }

local Perks = {}
local selectedKey: string? = nil

local function stateFor(perk: Catalog.Perk, data: Types.View, names: { [string]: string }): NodeState
	local level = math.min(data.Perks[perk.Key] or 0, #perk.Costs)
	local cost = perk.Costs[level + 1]
	local need = perk.Opened[level + 1] or 0
	local locked = false
	local reason: string? = nil
	if cost then
		if perk.Parent and (data.Perks[perk.Parent] or 0) < (perk.Required or 1) then
			locked = true
			reason = `Нужен «{names[perk.Parent]}» · ур. {perk.Required or 1}`
		elseif data.Opened < need then
			locked = true
			reason = `Откройте {need} контейнеров · сейчас {data.Opened}`
		elseif data.Coins < cost then
			reason = `Не хватает {Components.coin(cost - data.Coins)} монет`
		elseif data.Coins - cost < data.OrderPrice then
			reason = `Оставьте {Components.coin(data.OrderPrice)} монет на заказ`
		end
	end
	return {
		Perk = perk,
		Level = level,
		Cost = cost,
		Locked = locked,
		Reason = reason,
		Color = BRANCH_COLORS[perk.Branch],
	}
end

local function line(parent: Frame, a: Vector2, b: Vector2, color: Color3, thickness: number): ()
	local delta = b - a
	local stroke = Style.frame(parent, color, 2)
	stroke.AnchorPoint = Vector2.new(0.5, 0.5)
	local center = (a + b) / 2
	stroke.Position = UDim2.fromOffset(center.X, center.Y)
	stroke.Size = UDim2.fromOffset(delta.Magnitude + thickness, thickness)
	stroke.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

local function link(parent: Frame, a: Vector2, b: Vector2, color: Color3, strong: boolean): ()
	local delta = b - a
	local first = a + Vector2.new(delta.X * 0.15, delta.Y * 0.68)
	local second = b - Vector2.new(delta.X * 0.58, delta.Y * 0.11)
	local previous = a
	for i = 1, 14 do
		local t = i / 14
		local u = 1 - t
		local at = a * (u ^ 3) + first * (3 * u * u * t) + second * (3 * u * t * t) + b * (t ^ 3)
		line(parent, previous, at, color, if strong then 4 else 2)
		previous = at
	end
end

local function centerText(parent: Instance, value: string, size: number, color: Color3, bold: boolean?): TextLabel
	local label = Style.label(parent, value, size, color, if bold then Style.Bold else Style.Body)
	label.TextXAlignment = Enum.TextXAlignment.Center
	return label
end

local function drawNode(parent: Frame, perk: NodeState, spec: Layout, position: Vector2): NodeWidget
	local key = perk.Perk.Key
	local diameter = if perk.Perk.Parent then 48 else 56
	local accent = if perk.Locked then perk.Color:Lerp(Style.Muted, 0.58) else perk.Color
	local btn = Instance.new("TextButton")
	btn.Name = `Перк:{key}`
	btn.Size = UDim2.fromOffset(diameter, diameter)
	btn.Position = UDim2.fromOffset(position.X, position.Y)
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.BackgroundColor3 = if perk.Level > 0 then BOARD:Lerp(perk.Color, 0.32) else PANEL
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Selectable = true
	btn.Text = ""
	btn.ZIndex = 4
	btn.Parent = parent
	Style.round(btn, 50)
	local border = Style.outline(btn, accent, 2)
	local icon = Icons.draw(btn, spec.Icon, accent, Style.Text)
	icon.Position = UDim2.fromScale(0.50, 0.44)
	icon.Size = UDim2.fromScale(0.60, 0.60)
	if perk.Locked then
		local lock = Icons.draw(btn, "lock", Style.Muted)
		lock.Position = UDim2.fromScale(0.91, 0.13)
		lock.Size = UDim2.fromOffset(17, 17)
		lock.ZIndex = 6
	end

	local pill = Style.frame(btn, BOARD, 8)
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.98)
	pill.Size = UDim2.fromOffset(37, 16)
	pill.ZIndex = 6
	Style.outline(pill, accent, 1)
	local counter = centerText(pill, `{perk.Level}/{#perk.Perk.Costs}`, 11, Style.Text, true)
	counter.Size = UDim2.fromScale(1, 1)
	counter.ZIndex = 7

	local label = centerText(parent, spec.Label, 12, if perk.Locked then Style.Muted else Style.Text, true)
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromOffset(position.X, position.Y + diameter / 2 + 10)
	label.Size = UDim2.fromOffset(96, 18)
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = 5
	return { Button = btn, Border = border, State = perk }
end

local function drawHub(board: Frame, center: Vector2, data: Types.View): ()
	local hub = Style.frame(board, PANEL, 17)
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromOffset(center.X, center.Y)
	hub.Size = UDim2.fromOffset(106, 76)
	hub.ZIndex = 3
	Style.outline(hub, Style.Neutral, 2)
	local title = centerText(hub, "Лаборатория", 12, Style.Muted, true)
	title.Position = UDim2.fromOffset(0, 8)
	title.Size = UDim2.new(1, 0, 0, 16)
	title.ZIndex = 4
	title.TextWrapped = false
	local level = centerText(hub, `Ур. {Catalog.level(data.Opened)}`, 22, Style.Text, true)
	level.Position = UDim2.fromOffset(0, 24)
	level.Size = UDim2.new(1, 0, 0, 27)
	level.ZIndex = 4
	local opened = centerText(hub, `{data.Opened} открыто`, 11, Style.Muted)
	opened.Position = UDim2.fromOffset(0, 53)
	opened.Size = UDim2.new(1, 0, 0, 15)
	opened.ZIndex = 4
end

local function legend(parent: Frame, states: { [string]: NodeState }, wide: boolean): ()
	local progress: { [string]: { number } } = {}
	for _, branch in Catalog.Branches do
		progress[branch.Key] = { 0, 0 }
	end
	for _, state in states do
		local total = progress[state.Perk.Branch]
		total[1] += state.Level
		total[2] += #state.Perk.Costs
	end
	local columns = if wide then #Catalog.Branches else 2
	for i, branch in Catalog.Branches do
		local index = i - 1
		local color = BRANCH_COLORS[branch.Key]
		local row = Style.frame(parent, PANEL, 7)
		row.Position = UDim2.new(index % columns / columns, 3, 0, index // columns * 24)
		row.Size = UDim2.new(1 / columns, -6, 0, 20)
		local mark = Style.frame(row, color, 4)
		mark.Position = UDim2.fromOffset(7, 6)
		mark.Size = UDim2.fromOffset(8, 8)
		local pair = progress[branch.Key]
		local words = `{branch.Name} · {pair[1]}/{pair[2]}`
		local field = Components.text(row, words, 11, Style.Text)
		Components.place(field, 21, 0, UDim.new(1, -25), 20)
		field.TextWrapped = false
		field.TextTruncate = Enum.TextTruncate.AtEnd
	end
end

local function details(panel: Frame, state: NodeState, branches: { [string]: string }, wide: boolean): ()
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local perk = state.Perk
	local inset = if wide then 16 else 12
	local width = UDim.new(1, -2 * inset)
	local branch = Components.text(panel, branches[perk.Branch], 12, state.Color)
	Components.place(branch, inset, 9, width, 16)
	local title = Components.text(panel, perk.Name, if wide then 23 else 18, Style.Text, true)
	Components.place(title, inset, 29, width, if wide then 52 else 28)
	title.TextWrapped = wide
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local count = Components.text(panel, `Уровень {state.Level} / {#perk.Costs}`, 13, Style.Muted)
	Components.place(count, inset, if wide then 82 else 25, width, 16)
	if not wide then
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.Position = UDim2.fromOffset(inset, 9)
	end

	if wide then
		local pips = Components.pips(panel, #perk.Costs, state.Level, state.Color)
		pips.Position = UDim2.fromOffset(inset, 106)
		pips.Size = UDim2.new(width, UDim.new(0, 7))
	end

	local currentText = if state.Level > 0 then perk.Describe(state.Level) else "Не изучено"
	local current = Components.text(panel, `Сейчас · {currentText}`, if wide then 14 else 12, Style.Muted)
	Components.place(current, inset, if wide then 126 else 57, width, if wide then 40 else 26)
	local nextText = if state.Cost
		then `Далее · {perk.Describe(state.Level + 1)}`
		else "Максимальный уровень"
	local nextEffect = Components.text(panel, nextText, if wide then 16 else 13, Style.Text)
	Components.place(nextEffect, inset, if wide then 170 else 83, width, if wide then 60 else 35)

	local note = state.Reason
	if note then
		local reason = Components.text(panel, note, if wide then 13 else 11, Style.Warning)
		Components.place(reason, inset, if wide then 237 else 117, width, if wide then 44 else 28)
	end
	local affordable = state.Cost ~= nil and state.Reason == nil
	local caption = if state.Cost then `Улучшить · {Components.coin(state.Cost)}` else "Максимум"
	local buy = Style.button(panel, caption, function()
		Components.send("perk", perk.Key)
	end, affordable, if affordable then "primary" else "neutral")
	buy.Name = "Покупка перка"
	buy.TextSize = 16
	buy.AnchorPoint = Vector2.new(0, 1)
	buy.Position = UDim2.new(0, inset, 1, -9)
	buy.Size = UDim2.new(width, UDim.new(0, if wide then 48 else 39))
end

function Perks.reset(): ()
	selectedKey = nil
end

function Perks.render(data: Types.View, wide: boolean): ()
	local states: { [string]: NodeState } = {}
	local names: { [string]: string } = {}
	local branches: { [string]: string } = {}
	for _, branch in Catalog.Branches do
		branches[branch.Key] = branch.Name
	end
	for _, perk in Catalog.Perks do
		names[perk.Key] = perk.Name
	end
	for _, perk in Catalog.Perks do
		states[perk.Key] = stateFor(perk, data, names)
	end

	local chartSize = if wide then WIDE_SIZE else COMPACT_SIZE
	local center = if wide then Vector2.new(340, 247) else Vector2.new(175, 246)
	local legendHeight = if wide then 28 else 52
	local shell = Components.strip(legendHeight + chartSize.Y)
	local graph = Style.frame(shell, BOARD, 14)
	graph.Size = UDim2.new(1, if wide then -(PANEL_WIDTH + 12) else 0, 1, 0)
	Style.outline(graph, Style.Edge, 1)
	local key = Style.frame(graph, nil)
	key.Position = UDim2.fromOffset(8, 7)
	key.Size = UDim2.new(1, -16, 0, legendHeight)
	legend(key, states, wide)
	local host = Style.frame(graph, nil)
	host.Position = UDim2.fromOffset(0, legendHeight)
	host.Size = UDim2.new(1, 0, 1, -legendHeight)
	local chart = Style.frame(host, nil)
	chart.AnchorPoint = Vector2.new(0.5, 0)
	chart.Position = UDim2.fromScale(0.5, 0)
	chart.Size = UDim2.fromOffset(chartSize.X, chartSize.Y)
	local scale = Instance.new("UIScale")
	scale.Parent = chart
	local function fit(): ()
		local width = graph.AbsoluteSize.X
		if width <= 0 then
			return
		end
		scale.Scale = math.min(1, width / chartSize.X)
		local height = legendHeight + math.ceil(scale.Scale * chartSize.Y)
		shell.Size = UDim2.new(shell.Size.X, UDim.new(0, height))
	end
	graph:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)

	local detailPanel
	if wide then
		detailPanel = Style.frame(shell, PANEL, 14)
		detailPanel.AnchorPoint = Vector2.new(1, 0)
		detailPanel.Position = UDim2.fromScale(1, 0)
		detailPanel.Size = UDim2.fromOffset(PANEL_WIDTH, 348)
		Style.outline(detailPanel, Style.Edge, 1)
	else
		detailPanel = Components.dock(MOBILE_DOCK)
	end

	local points: { [string]: Vector2 } = {}
	for perkKey, cell in LAYOUT do
		points[perkKey] = if wide then cell.Wide else cell.Compact
	end
	for _, perk in Catalog.Perks do
		local state = states[perk.Key]
		local at = points[perk.Key]
		local from = if perk.Parent then points[perk.Parent] else center
		local accent = if state.Level > 0
			then state.Color
			elseif state.Locked then RAIL
			else RAIL:Lerp(state.Color, 0.62)
		link(chart, from, at, accent, state.Level > 0)
	end
	drawHub(chart, center, data)

	local widgets: { [string]: NodeWidget } = {}
	local function selectPerk(perkKey: string): ()
		selectedKey = perkKey
		for nodeKey, widget in widgets do
			local active = nodeKey == perkKey
			local state = widget.State
			widget.Border.Color = if active
				then Style.Text
				elseif state.Locked then state.Color:Lerp(Style.Muted, 0.58)
				else state.Color
			widget.Border.Thickness = if active then 3 else 2
			widget.Button.BackgroundColor3 = if active
				then PANEL:Lerp(state.Color, 0.36)
				elseif state.Level > 0 then BOARD:Lerp(state.Color, 0.32)
				else PANEL
		end
		details(detailPanel, states[perkKey], branches, wide)
	end

	for _, perk in Catalog.Perks do
		local widget = drawNode(chart, states[perk.Key], LAYOUT[perk.Key], points[perk.Key])
		widgets[perk.Key] = widget
		widget.Button.Activated:Connect(function()
			selectPerk(perk.Key)
		end)
	end

	local first = selectedKey or Catalog.Perks[1].Key
	selectPerk(first)
	Components.prefer(widgets[first].Button)
end

return Perks
