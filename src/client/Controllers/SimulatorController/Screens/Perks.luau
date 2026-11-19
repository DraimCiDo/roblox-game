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
	mastery = Style.Warning,
	collections = Color3.fromRGB(244, 140, 224),
	lockpick = Color3.fromRGB(120, 214, 255),
}
local BRANCH_ICONS: { [string]: Icons.IconName } = {
	logistics = "box",
	storage = "grid",
	trade = "coin",
	luck = "star",
	mastery = "star",
	collections = "gift",
	lockpick = "lock",
}
local MOBILE_DOCK = 194
-- Раскладка: каждая ветка — горизонтальное дерево; глубина задаёт колонку, листья — строки.
local COLUMN = 122
local ROW = 104
local MARGIN_X = 76
local BAND_HEADER = 34
local BAND_GAP = 16
local LABEL_WIDTH = 108

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

local function stateFor(perk: Catalog.Perk, data: Types.View): NodeState
	local level = math.min(data.Perks[perk.Key] or 0, #perk.Costs)
	local cost = Catalog.perkCost(perk, level, data.Perks)
	local lock = if cost then Catalog.perkLock(perk, level, data.Perks, data.Opened) else nil
	local reason: string? = lock
	if cost and not lock then
		if data.Coins < cost then
			reason = `Не хватает {Components.coin(cost - data.Coins)} монет`
		elseif data.Coins - cost < data.OrderPrice then
			reason = `Оставьте {Components.coin(data.OrderPrice)} монет на заказ`
		end
	end
	return {
		Perk = perk,
		Level = level,
		Cost = cost,
		Locked = lock ~= nil,
		Reason = reason,
		Color = BRANCH_COLORS[perk.Branch] or Style.Cyan,
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

local function drawNode(parent: Frame, perk: NodeState, position: Vector2): NodeWidget
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
	local icon = Icons.draw(btn, BRANCH_ICONS[perk.Perk.Branch] or "star", accent, Style.Text)
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

	local label = centerText(parent, perk.Perk.Name, 11, if perk.Locked then Style.Muted else Style.Text, true)
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromOffset(position.X, position.Y + diameter / 2 + 10)
	label.Size = UDim2.fromOffset(LABEL_WIDTH, 28)
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.ZIndex = 5
	return { Button = btn, Border = border, State = perk }
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
	local columns = if wide then 4 else 2
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

type Band = { Branch: string, Top: number, Height: number }

-- Расставляет навыки по веткам: колонка = глубина в дереве ветки, строка = порядок листьев.
local function layout(): ({ [string]: Vector2 }, { Band }, Vector2)
	local points: { [string]: Vector2 } = {}
	local bands: { Band } = {}
	local top = 0
	local deepest = 0
	local own: { [string]: string } = {}
	for _, perk in Catalog.Perks do
		own[perk.Key] = perk.Branch
	end
	for _, branch in Catalog.Branches do
		local members: { Catalog.Perk } = {}
		local children: { [string]: { Catalog.Perk } } = {}
		local roots: { Catalog.Perk } = {}
		for _, perk in Catalog.Perks do
			if perk.Branch == branch.Key then
				table.insert(members, perk)
				if perk.Parent and own[perk.Parent] == branch.Key then
					children[perk.Parent] = children[perk.Parent] or {}
					table.insert(children[perk.Parent], perk)
				else
					table.insert(roots, perk)
				end
			end
		end
		local nextRow = 0
		local rows: { [string]: number } = {}
		local depths: { [string]: number } = {}
		local function place(perk: Catalog.Perk, depth: number): ()
			depths[perk.Key] = depth
			deepest = math.max(deepest, depth)
			local list = children[perk.Key]
			if not list then
				rows[perk.Key] = nextRow
				nextRow += 1
				return
			end
			for _, child in list do
				place(child, depth + 1)
			end
			rows[perk.Key] = (rows[list[1].Key] + rows[list[#list].Key]) / 2
		end
		for _, root in roots do
			place(root, 0)
		end
		local height = BAND_HEADER + math.max(nextRow, 1) * ROW
		for _, perk in members do
			points[perk.Key] = Vector2.new(
				MARGIN_X + depths[perk.Key] * COLUMN,
				top + BAND_HEADER + rows[perk.Key] * ROW + ROW / 2 - 8
			)
		end
		table.insert(bands, { Branch = branch.Key, Top = top, Height = height })
		top += height + BAND_GAP
	end
	return points, bands, Vector2.new(MARGIN_X * 2 + deepest * COLUMN, top)
end

function Perks.render(data: Types.View, wide: boolean): ()
	local states: { [string]: NodeState } = {}
	local branches: { [string]: string } = {}
	for _, branch in Catalog.Branches do
		branches[branch.Key] = branch.Name
	end
	for _, perk in Catalog.Perks do
		states[perk.Key] = stateFor(perk, data)
	end

	local points, bands, chartSize = layout()
	local columns = if wide then 4 else 2
	local legendHeight = math.ceil(#Catalog.Branches / columns) * 24 + 12
	local shell = Components.strip(legendHeight + chartSize.Y)
	local graph = Style.frame(shell, BOARD, 14)
	graph.Size = UDim2.fromScale(1, 1)
	Style.outline(graph, Style.Edge, 1)
	local key = Style.frame(graph, nil)
	key.Position = UDim2.fromOffset(8, 7)
	key.Size = UDim2.new(1, -16, 0, legendHeight - 6)
	legend(key, states, wide)

	-- Дерево шире экрана: прокручивается по горизонтали, по вертикали его листает само меню.
	local host = Instance.new("ScrollingFrame")
	host.Name = "Дерево"
	host.BackgroundTransparency = 1
	host.BorderSizePixel = 0
	host.Position = UDim2.fromOffset(0, legendHeight)
	host.Size = UDim2.new(1, 0, 1, -legendHeight)
	host.CanvasSize = UDim2.fromOffset(chartSize.X, 0)
	host.ScrollingDirection = Enum.ScrollingDirection.X
	host.ScrollBarThickness = 5
	host.ScrollBarImageColor3 = Style.Amber
	host.Selectable = false
	host.Parent = graph
	local chart = Style.frame(host, nil)
	chart.Size = UDim2.fromOffset(chartSize.X, chartSize.Y)

	for _, band in bands do
		local color = BRANCH_COLORS[band.Branch] or Style.Cyan
		local strip = Style.frame(chart, PANEL, 12)
		strip.Position = UDim2.fromOffset(6, band.Top)
		strip.Size = UDim2.fromOffset(chartSize.X - 12, band.Height)
		strip.BackgroundTransparency = 0.45
		local mark = Style.frame(strip, color, 3)
		mark.Position = UDim2.fromOffset(10, 9)
		mark.Size = UDim2.fromOffset(5, 18)
		local title = Components.text(strip, branches[band.Branch], 15, color, true)
		Components.place(title, 22, 7, UDim.new(0, 220), 22)
		title.TextWrapped = false
	end

	local detailPanel = Components.dock(MOBILE_DOCK)

	for _, perk in Catalog.Perks do
		local state = states[perk.Key]
		local at = points[perk.Key]
		if perk.Parent then
			local accent = if state.Level > 0
				then state.Color
				elseif state.Locked then RAIL
				else RAIL:Lerp(state.Color, 0.62)
			link(chart, points[perk.Parent], at, accent, state.Level > 0)
		end
		-- Дополнительные условия: тонкая линия от нужного навыка.
		if perk.Needs then
			for _, need in perk.Needs do
				local met = (data.Perks[need.Key] or 0) >= need.Level
				link(chart, points[need.Key], at, if met then state.Color else RAIL, false)
			end
		end
	end

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
		details(detailPanel, states[perkKey], branches, false)
	end

	for _, perk in Catalog.Perks do
		local widget = drawNode(chart, states[perk.Key], points[perk.Key])
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
