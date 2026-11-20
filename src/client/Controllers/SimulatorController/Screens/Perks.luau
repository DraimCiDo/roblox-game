--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Components)
local Icons = require(script.Parent.Parent.Icons)
local Sfx = require(script.Parent.Parent.Sfx)
local Style = require(script.Parent.Parent.Style)

-- Карта навыков — «экран прибора»: почти чёрный графит, стальные рельсы связей.
local BOARD = Color3.fromRGB(8, 12, 18)
local PANEL = Color3.fromRGB(20, 28, 38)
local RAIL = Color3.fromRGB(58, 74, 90)
local BRANCH_COLORS: { [string]: Color3 } = {
	logistics = Style.Violet,
	storage = Style.Cyan,
	trade = Style.Signal,
	luck = Style.Amber,
	mastery = Style.Warning,
	collections = Color3.fromRGB(244, 140, 224),
	lockpick = Color3.fromRGB(120, 214, 255),
}
-- Ветки веером от общего ствола: соседние по смыслу и по зависимостям стоят рядом (угол от вертикали, градусы).
local BRANCH_ANGLES: { [string]: number } = {
	logistics = -86,
	storage = -58,
	collections = -29,
	trade = 0,
	luck = 29,
	mastery = 58,
	lockpick = 86,
}
local PERK_ICONS: { [string]: Icons.IconName } = {
	orders = "box",
	delivery = "arrow",
	express = "bolt",
	discount = "tag",
	cashback = "coin",
	daily = "gift",
	grant = "gem",
	storage = "grid",
	quickCollect = "magnet",
	recycler = "cycle",
	gallery = "frame",
	sale = "coin",
	quickSell = "bolt",
	bulk = "stack",
	haggle = "scale",
	jackpot = "dice",
	junk = "tag",
	odds = "star",
	quality = "eye",
	floor = "stack",
	perfect = "gem",
	rarity = "sparkle",
	bonusLoot = "plus",
	variant = "ticket",
	variantLoot = "plus",
	crateLuck = "target",
	safeLuck = "target",
	cargoLuck = "target",
	secretLuck = "target",
	boxMaster = "medal",
	crateMaster = "medal",
	safeMaster = "medal",
	cargoMaster = "medal",
	secretMaster = "medal",
	collection = "grid",
	collElectronics = "screen",
	collJewel = "gem",
	collCars = "frame",
	collLab = "sparkle",
	museum = "frame",
	steady = "lock",
	slow = "clock",
}
local VIEW_HEIGHT = 440
local MOBILE_DOCK = 194
-- Раскладка: расстояние от ствола задаёт глубина навыка, а соседние листья расходятся в стороны.
local FIRST_RADIUS = 290
local RADIUS_STEP = 140
local LEAF_SPACING = 104
local CANVAS_MARGIN = 140
-- Минимальный «габарит» узла с подписью: по горизонтали и вертикали; ближе узлы не располагаются.
local CLEARANCE_X = 128
local CLEARANCE_Y = 118
local CORE_CLEARANCE = 210
local ROOT_DIAMETER = 62
local NODE_DIAMETER = 52
local MIN_ZOOM = 0.45
local MAX_ZOOM = 1.5

type NodeState = {
	Perk: Catalog.Perk,
	Level: number,
	Cost: number?,
	Locked: boolean,
	Reason: string?,
	-- Можно улучшить прямо сейчас: навык открыт, хватает монет и остаётся запас на заказ.
	Ready: boolean,
	Color: Color3,
}
type NodeWidget = { Button: TextButton, Apply: (boolean) -> (), State: NodeState }

local Perks = {}
local selectedKey: string? = nil
local zoom = 0.8
local scroll: Vector2? = nil
local connections: { RBXScriptConnection } = {}
local cachedLayout: Layout? = nil

local function disconnect(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

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
		Ready = cost ~= nil and reason == nil,
		Color = BRANCH_COLORS[perk.Branch] or Style.Cyan,
	}
end

-- Отрезок линии: скруглённая полоса нужной толщины между двумя точками.
local function segment(parent: Frame, a: Vector2, b: Vector2, color: Color3, thickness: number): ()
	local delta = b - a
	local piece = Style.frame(parent, color, thickness / 2)
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	local center = (a + b) / 2
	piece.Position = UDim2.fromOffset(center.X, center.Y)
	piece.Size = UDim2.fromOffset(delta.Magnitude + thickness * 0.6, thickness)
	piece.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

-- Плавная кривая, вытекающая по направлению роста ветки: так линии выглядят как «ветви» дерева.
local function curve(
	parent: Frame,
	a: Vector2,
	b: Vector2,
	headA: Vector2,
	headB: Vector2,
	color: Color3,
	thickness: number
): ()
	local reach = (b - a).Magnitude * 0.42
	local first = a + headA * reach
	local second = b - headB * reach
	local steps = math.clamp(math.floor((b - a).Magnitude / 14), 8, 30)
	local previous = a
	for index = 1, steps do
		local t = index / steps
		local u = 1 - t
		local at = a * (u ^ 3) + first * (3 * u * u * t) + second * (3 * u * t * t) + b * (t ^ 3)
		segment(parent, previous, at, color, thickness)
		previous = at
	end
end

local function centerText(parent: Instance, value: string, size: number, color: Color3, bold: boolean?): TextLabel
	local label = Style.label(parent, value, size, color, if bold then Style.Bold else Style.Body)
	label.TextXAlignment = Enum.TextXAlignment.Center
	return label
end

-- Круглый узел: изучен — залит цветом ветки, доступен — тёмный с цветным кольцом, закрыт — серый с замком.
local function drawNode(parent: Frame, state: NodeState, position: Vector2, diameter: number): NodeWidget
	local perk = state.Perk
	local color = state.Color
	-- Узел, который можно улучшить сейчас, окружён пульсирующим кольцом.
	if state.Ready then
		local ring = Style.frame(parent, nil, diameter + 16)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromOffset(position.X, position.Y)
		ring.Size = UDim2.fromOffset(diameter + 16, diameter + 16)
		ring.ZIndex = 3
		local glow = Style.outline(ring, color, 5)
		TweenService:Create(glow, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Transparency = 0.85,
		}):Play()
	end
	local button = Instance.new("TextButton")
	button.Name = `Перк:{perk.Key}`
	button.Size = UDim2.fromOffset(diameter, diameter)
	button.Position = UDim2.fromOffset(position.X, position.Y)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Selectable = true
	button.Text = ""
	button.ZIndex = 4
	button.Parent = parent
	Style.round(button, diameter)
	local border = Style.outline(button, color, 3)

	local iconColor = if state.Level > 0 then Style.Ink elseif state.Locked then RAIL:Lerp(Style.Muted, 0.35) else color
	local icon = Icons.draw(
		button,
		PERK_ICONS[perk.Base or perk.Key] or "star",
		iconColor,
		if state.Level > 0 then Style.Text else Style.Muted
	)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.58, 0.58)
	icon.ZIndex = 5
	if state.Locked then
		local lock = Icons.draw(button, "lock", Style.Muted)
		lock.Position = UDim2.fromScale(0.86, 0.14)
		lock.Size = UDim2.fromOffset(18, 18)
		lock.ZIndex = 7
	end

	if state.Ready then
		local badge = Style.frame(button, Style.Signal, 12)
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.fromScale(1.02, -0.02)
		badge.Size = UDim2.fromOffset(24, 24)
		badge.ZIndex = 8
		Style.outline(badge, Style.Edge, 2)
		local plus = Icons.draw(badge, "plus", Style.Ink)
		plus.Size = UDim2.fromScale(0.72, 0.72)
		plus.ZIndex = 9
	end

	local pill = Style.frame(parent, BOARD, 9)
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromOffset(position.X, position.Y + diameter / 2 + 4)
	pill.Size = UDim2.fromOffset(40, 17)
	pill.ZIndex = 6
	Style.outline(pill, if state.Locked then RAIL else color, 2)
	local counter = centerText(pill, `{perk.Step or state.Level}/{perk.Steps or #perk.Costs}`, 11, Style.Text, true)
	counter.Size = UDim2.fromScale(1, 1)
	counter.ZIndex = 7

	local name = centerText(parent, perk.Name, 12, if state.Locked then RAIL:Lerp(Style.Muted, 0.5) else Style.Text)
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.fromOffset(position.X, position.Y + diameter / 2 + 15)
	name.Size = UDim2.fromOffset(116, 30)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.ZIndex = 5

	local function apply(selected: boolean): ()
		border.Color = if selected then Style.Text elseif state.Locked then RAIL else color
		border.Thickness = if selected then 4 else 3
		button.BackgroundColor3 = if state.Level > 0
			then color
			elseif selected then PANEL:Lerp(color, 0.3)
			elseif state.Ready then BOARD:Lerp(color, 0.25)
			else BOARD
	end
	apply(false)
	return { Button = button, Apply = apply, State = state }
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
	local progress = if perk.Step
		then `Ступень {perk.Step} из {perk.Steps} · {if state.Level > 0
			then "изучена"
			else "не изучена"}`
		else `Уровень {state.Level} / {#perk.Costs}`
	local count = Components.text(panel, progress, 13, Style.Muted)
	Components.place(count, inset, if wide then 82 else 25, width, 16)
	if not wide then
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.Position = UDim2.fromOffset(inset, 9)
	end

	if wide and not perk.Step then
		local pips = Components.pips(panel, #perk.Costs, state.Level, state.Color)
		pips.Position = UDim2.fromOffset(inset, 106)
		pips.Size = UDim2.new(width, UDim.new(0, 7))
	end

	local currentText = if state.Level > 0 then perk.Describe(state.Level) else "Не изучено"
	local current = Components.text(panel, `Сейчас · {currentText}`, if wide then 14 else 12, Style.Muted)
	Components.place(current, inset, if wide then 126 else 57, width, if wide then 40 else 26)
	local nextText = if state.Cost
		then `Далее · {perk.Describe(state.Level + 1)}`
		else "Эта ступень уже изучена"
	local nextEffect = Components.text(panel, nextText, if wide then 16 else 13, Style.Text)
	Components.place(nextEffect, inset, if wide then 170 else 83, width, if wide then 60 else 35)

	local note = state.Reason
	if note then
		local reason = Components.text(panel, note, if wide then 13 else 11, Style.Warning)
		Components.place(reason, inset, if wide then 237 else 117, width, if wide then 44 else 28)
	end
	local affordable = state.Cost ~= nil and state.Reason == nil
	local caption = if state.Cost then `Изучить · {Components.coin(state.Cost)}` else "Изучено"
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
	scroll = nil
	-- На низком окне (телефон) карта стартует мельче, чтобы ветки были видны сразу.
	zoom = if Components.compact() then 0.55 else 0.8
	disconnect()
end

type Layout = {
	Points: { [string]: Vector2 },
	Heading: { [string]: Vector2 },
	Roots: { [string]: { Catalog.Perk } },
	Titles: { { Branch: string, At: Vector2 } },
	Hub: Vector2,
	Size: Vector2,
}

-- Радиальная раскладка: ветка растёт от ствола под своим углом, глубина — вдоль ветки, листья — поперёк.
local function layout(): Layout
	local points: { [string]: Vector2 } = {}
	local heading: { [string]: Vector2 } = {}
	local roots: { [string]: { Catalog.Perk } } = {}
	local titles: { { Branch: string, At: Vector2 } } = {}
	local own: { [string]: string } = {}
	for _, perk in Catalog.PerkNodes do
		own[perk.Key] = perk.Branch
	end
	local low, high = Vector2.zero, Vector2.zero
	local function track(at: Vector2): ()
		low = Vector2.new(math.min(low.X, at.X), math.min(low.Y, at.Y))
		high = Vector2.new(math.max(high.X, at.X), math.max(high.Y, at.Y))
	end
	for _, branch in Catalog.Branches do
		local angle = math.rad(BRANCH_ANGLES[branch.Key] or 0)
		local direction = Vector2.new(math.sin(angle), -math.cos(angle))
		local across = Vector2.new(math.cos(angle), math.sin(angle))
		local children: { [string]: { Catalog.Perk } } = {}
		local branchRoots: { Catalog.Perk } = {}
		for _, perk in Catalog.PerkNodes do
			if perk.Branch == branch.Key then
				if perk.Parent and own[perk.Parent] == branch.Key then
					children[perk.Parent] = children[perk.Parent] or {}
					table.insert(children[perk.Parent], perk)
				else
					table.insert(branchRoots, perk)
				end
			end
		end
		roots[branch.Key] = branchRoots
		local nextLeaf = 0
		local rows: { [string]: number } = {}
		local depths: { [string]: number } = {}
		local function place(perk: Catalog.Perk, depth: number): ()
			depths[perk.Key] = depth
			local list = children[perk.Key]
			if not list then
				rows[perk.Key] = nextLeaf
				nextLeaf += 1
				return
			end
			for _, child in list do
				place(child, depth + 1)
			end
			rows[perk.Key] = (rows[list[1].Key] + rows[list[#list].Key]) / 2
		end
		for _, root in branchRoots do
			place(root, 0)
		end
		local middle = (math.max(nextLeaf, 1) - 1) / 2
		for key, depth in depths do
			local at = direction * (FIRST_RADIUS + depth * RADIUS_STEP) + across * ((rows[key] - middle) * LEAF_SPACING)
			points[key] = at
			heading[key] = direction
			track(at)
		end
		local side = if angle < 0 then -1 else 1
		table.insert(titles, { Branch = branch.Key, At = direction * (FIRST_RADIUS * 0.45) + across * (side * 78) })
	end
	-- Разводим пересекающиеся узлы соседних веток: попарно отталкиваем их, пока габариты не перестанут пересекаться.
	local keys: { string } = {}
	for key in points do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _ = 1, 140 do
		local moved = false
		for i = 1, #keys do
			local a = points[keys[i]]
			local away = a.Magnitude
			if away < CORE_CLEARANCE and away > 0 then
				points[keys[i]] = a + a.Unit * (CORE_CLEARANCE - away)
				moved = true
			end
			for j = i + 1, #keys do
				local first, second = points[keys[i]], points[keys[j]]
				local scaled = Vector2.new((first.X - second.X) / CLEARANCE_X, (first.Y - second.Y) / CLEARANCE_Y)
				local gap = scaled.Magnitude
				if gap < 1 then
					local direction = if gap > 0.001 then scaled / gap else Vector2.new(1, 0)
					local push = direction * ((1 - gap) * 0.5)
					local shift = Vector2.new(push.X * CLEARANCE_X, push.Y * CLEARANCE_Y)
					points[keys[i]] = first + shift
					points[keys[j]] = second - shift
					moved = true
				end
			end
		end
		if not moved then
			break
		end
	end
	low, high = Vector2.zero, Vector2.zero
	for _, at in points do
		track(at)
	end
	local hub = Vector2.new(CANVAS_MARGIN - low.X, CANVAS_MARGIN - low.Y)
	local shifted: { [string]: Vector2 } = {}
	for key, at in points do
		shifted[key] = at + hub
	end
	for _, title in titles do
		title.At += hub
	end
	return {
		Points = shifted,
		Heading = heading,
		Roots = roots,
		Titles = titles,
		Hub = hub,
		Size = Vector2.new(high.X - low.X + CANVAS_MARGIN * 2, high.Y - low.Y + CANVAS_MARGIN * 2),
	}
end

function Perks.render(source: Types.View, _wide: boolean): ()
	disconnect()
	-- Дерево рисуется узлами с одним уровнем: уровни навыков раскладываются на ступени (Catalog.PerkNodes).
	local data = table.clone(source)
	data.Perks = Catalog.nodeLevels(source.Perks)
	local states: { [string]: NodeState } = {}
	local branches: { [string]: string } = {}
	local spent: { [string]: number } = {}
	local owned, total, ready = 0, 0, 0
	for _, branch in Catalog.Branches do
		branches[branch.Key] = branch.Name
		spent[branch.Key] = 0
	end
	for _, perk in Catalog.PerkNodes do
		local state = stateFor(perk, data)
		states[perk.Key] = state
		spent[perk.Branch] += state.Level
		owned += state.Level
		total += #perk.Costs
		if state.Ready then
			ready += 1
		end
	end
	local map: Layout = cachedLayout or layout()
	cachedLayout = map

	local shell = Components.strip(Components.viewHeight(VIEW_HEIGHT))
	local view = Style.frame(shell, BOARD, 14)
	view.Size = UDim2.fromScale(1, 1)
	view.ClipsDescendants = true
	Style.outline(view, Style.Edge, 2)
	Style.gloss(view)

	local host = Instance.new("ScrollingFrame")
	host.Name = "Дерево"
	host.BackgroundTransparency = 1
	host.BorderSizePixel = 0
	host.Size = UDim2.fromScale(1, 1)
	host.ScrollingDirection = Enum.ScrollingDirection.XY
	-- Касание и трекпад двигают карту встроенной прокруткой; мышь перетаскивает карту вручную (ниже).
	-- Встроенная прокрутка нужна только для касаний; с мышью она бы перехватывала колесо, а карту двигает перетаскивание.
	host.ScrollingEnabled = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	host.Active = true
	host.ScrollBarThickness = 0
	host.Selectable = false
	host.Parent = view
	local chart = Style.frame(host, nil)
	chart.Size = UDim2.fromOffset(map.Size.X, map.Size.Y)
	-- Прозрачная кнопка на всю карту под узлами: гарантированно получает нажатия мыши на пустом месте.
	local surface = Instance.new("TextButton")
	surface.Name = "Поверхность"
	surface.BackgroundTransparency = 1
	surface.Text = ""
	surface.AutoButtonColor = false
	surface.Selectable = false
	surface.Size = UDim2.fromScale(1, 1)
	surface.ZIndex = 1
	surface.Parent = chart
	local dragging = false
	-- Сколько пикселей прошла мышь за нажатие: сдвиг больше порога не считается кликом по узлу.
	local travelled = 0
	local function beginDrag(input: InputObject): ()
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			travelled = 0
		end
	end
	table.insert(connections, surface.InputBegan:Connect(beginDrag))
	local scale = Instance.new("UIScale")
	scale.Parent = chart

	local function setZoom(value: number, anchor: Vector2?): ()
		local previous = scale.Scale
		zoom = math.clamp(value, MIN_ZOOM, MAX_ZOOM)
		scale.Scale = zoom
		host.CanvasSize = UDim2.fromOffset(map.Size.X * zoom, map.Size.Y * zoom)
		-- Масштаб относительно точки обзора, чтобы карта не «уезжала».
		local focus = anchor or host.AbsoluteSize / 2
		host.CanvasPosition = (host.CanvasPosition + focus) * (zoom / previous) - focus
	end
	scale.Scale = zoom
	host.CanvasSize = UDim2.fromOffset(map.Size.X * zoom, map.Size.Y * zoom)
	local function centerOnHub(): ()
		local size = host.AbsoluteSize
		host.CanvasPosition =
			Vector2.new(math.max(0, map.Hub.X * zoom - size.X / 2), math.max(0, map.Hub.Y * zoom - size.Y * 0.82))
	end
	-- Размер окна карты известен только после первой раскладки интерфейса.
	task.delay(0.05, function()
		if not host.Parent then
			return
		end
		if scroll then
			host.CanvasPosition = scroll
		else
			centerOnHub()
		end
	end)
	table.insert(
		connections,
		host:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			scroll = host.CanvasPosition
		end)
	)

	-- Линии: ствол к корням веток, затем связи родитель → потомок и дополнительные условия.
	for _, branch in Catalog.Branches do
		local color = BRANCH_COLORS[branch.Key] or Style.Cyan
		for _, root in map.Roots[branch.Key] do
			local head = map.Heading[root.Key]
			if not root.Parent then
				local lit = states[root.Key].Level > 0
				local tone = if lit then color elseif states[root.Key].Locked then RAIL else color:Lerp(RAIL, 0.55)
				curve(chart, map.Hub, map.Points[root.Key], head, head, tone, if lit then 9 else 4)
			end
		end
	end
	for _, perk in Catalog.PerkNodes do
		local state = states[perk.Key]
		local head = map.Heading[perk.Key]
		local tone = if state.Level > 0 then state.Color elseif state.Locked then RAIL else state.Color:Lerp(RAIL, 0.55)
		local thickness = if state.Level > 0 then 9 elseif state.Locked then 2 else 4
		if perk.Parent then
			curve(chart, map.Points[perk.Parent], map.Points[perk.Key], map.Heading[perk.Parent], head, tone, thickness)
		end
		if perk.Needs then
			for _, need in perk.Needs do
				local met = (data.Perks[need.Key] or 0) >= need.Level
				curve(
					chart,
					map.Points[need.Key],
					map.Points[perk.Key],
					map.Heading[need.Key],
					head,
					if met then state.Color else RAIL,
					2
				)
			end
		end
	end

	-- Ствол: ядро лаборатории и названия веток с суммой изученных уровней.
	local core = Style.frame(chart, PANEL, 60)
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromOffset(map.Hub.X, map.Hub.Y)
	core.Size = UDim2.fromOffset(104, 104)
	core.ZIndex = 4
	Style.outline(core, Style.Text, 4)
	local coreLevel = centerText(core, `Ур. {Catalog.level(data.Opened)}`, 24, Style.Text, true)
	coreLevel.Position = UDim2.fromOffset(0, 24)
	coreLevel.Size = UDim2.new(1, 0, 0, 30)
	coreLevel.ZIndex = 5
	Style.textStroke(coreLevel, 2)
	local coreNote = centerText(core, `{data.Opened} откр.`, 12, Style.Muted)
	coreNote.Position = UDim2.fromOffset(0, 58)
	coreNote.Size = UDim2.new(1, 0, 0, 18)
	coreNote.ZIndex = 5
	for _, title in map.Titles do
		local color = BRANCH_COLORS[title.Branch] or Style.Cyan
		local name = centerText(chart, branches[title.Branch], 17, color, true)
		name.AnchorPoint = Vector2.new(0.5, 0.5)
		name.Position = UDim2.fromOffset(title.At.X, title.At.Y - 16)
		name.Size = UDim2.fromOffset(170, 22)
		name.TextWrapped = false
		name.ZIndex = 3
		Style.textStroke(name, 2)
		local count = centerText(chart, tostring(spent[title.Branch]), 30, Style.Text, true)
		count.AnchorPoint = Vector2.new(0.5, 0.5)
		count.Position = UDim2.fromOffset(title.At.X, title.At.Y + 12)
		count.Size = UDim2.fromOffset(120, 34)
		count.ZIndex = 3
		Style.textStroke(count, 3)
	end

	local detailPanel = Components.dock(MOBILE_DOCK, true)
	local widgets: { [string]: NodeWidget } = {}
	local function selectPerk(perkKey: string): ()
		selectedKey = perkKey
		for nodeKey, widget in widgets do
			widget.Apply(nodeKey == perkKey)
		end
		details(detailPanel, states[perkKey], branches, false)
	end
	for _, perk in Catalog.PerkNodes do
		local diameter = if perk.Parent then NODE_DIAMETER else ROOT_DIAMETER
		local widget = drawNode(chart, states[perk.Key], map.Points[perk.Key], diameter)
		widgets[perk.Key] = widget
		table.insert(connections, widget.Button.InputBegan:Connect(beginDrag))
		widget.Button.Activated:Connect(function()
			if travelled > 6 then
				return
			end
			Sfx.play("click")
			selectPerk(perk.Key)
		end)
	end

	-- Управление картой: кнопки масштаба и центра, колесо мыши и перетаскивание.
	local toolbar = Style.frame(view, nil)
	toolbar.AnchorPoint = Vector2.new(1, 0)
	toolbar.Position = UDim2.new(1, -8, 0, 8)
	toolbar.Size = UDim2.fromOffset(46, 150)
	toolbar.ZIndex = 10
	local layoutList = Instance.new("UIListLayout")
	layoutList.Padding = UDim.new(0, 6)
	layoutList.SortOrder = Enum.SortOrder.LayoutOrder
	layoutList.Parent = toolbar
	-- «Центр» рисуется иконкой: глифа прицела нет в шрифтах с кириллицей.
	local toolList: { { Caption: string, Factor: number } } = {
		{ Caption = "+", Factor = 1.2 },
		{ Caption = "−", Factor = 1 / 1.2 },
		{ Caption = "", Factor = 0 },
	}
	for index, tool in toolList do
		local control = Style.button(toolbar, tool.Caption, function()
			if tool.Factor == 0 then
				setZoom(if Components.compact() then 0.55 else 0.8)
				centerOnHub()
			else
				setZoom(zoom * tool.Factor)
			end
		end, true, "neutral")
		control.Name = if tool.Factor == 0 then "Центр" else tool.Caption
		control.LayoutOrder = index
		control.Size = UDim2.fromOffset(46, 42)
		control.TextSize = 24
		control.ZIndex = 10
		if tool.Factor == 0 then
			local mark = Icons.draw(control, "target", Style.Cyan)
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.fromScale(0.5, 0.5)
			mark.Size = UDim2.fromOffset(24, 24)
			mark.ZIndex = 11
		end
	end
	local summary = Components.text(
		view,
		if ready > 0
			then `Изучено {owned} из {total} · можно улучшить: {ready}`
			else `Изучено {owned} из {total}`,
		13,
		Style.Muted,
		true
	)
	-- Плашка поверх карты, чтобы надпись не смешивалась с узлами под ней.
	summary.AutomaticSize = Enum.AutomaticSize.X
	summary.Position = UDim2.fromOffset(8, 8)
	summary.Size = UDim2.fromOffset(0, 24)
	summary.TextWrapped = false
	summary.ZIndex = 10
	summary.BackgroundColor3 = Style.Panel
	summary.BackgroundTransparency = 0.1
	local summaryPad = Instance.new("UIPadding")
	summaryPad.PaddingLeft = UDim.new(0, 8)
	summaryPad.PaddingRight = UDim.new(0, 8)
	summaryPad.Parent = summary
	Style.round(summary, 4)
	Style.outline(summary, Style.Edge, 1)

	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
				-- Activated срабатывает сразу после отпускания, поэтому сдвиг сбрасываем с небольшой задержкой.
				task.delay(0.1, function()
					travelled = 0
				end)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = Vector2.new(input.Delta.X, input.Delta.Y)
				travelled += delta.Magnitude
				host.CanvasPosition -= delta
			end
		end)
	)
	-- Колесо над картой меняет масштаб. Над прокручиваемым кадром колесо получает сам интерфейс,
	-- поэтому слушаем событие карты, а не ContextActionService (туда колесо над GUI не доходит).
	table.insert(
		connections,
		host.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				local anchor = Vector2.new(input.Position.X, input.Position.Y) - host.AbsolutePosition
				setZoom(zoom * (if input.Position.Z > 0 then 1.1 else 1 / 1.1), anchor)
			end
		end)
	)
	-- Щипок двумя пальцами над картой — масштаб на сенсорных экранах.
	local pinchStart = zoom
	table.insert(
		connections,
		UserInputService.TouchPinch:Connect(function(touches, scaleFactor, _, state)
			local first = touches[1]
			if not first then
				return
			end
			local at, size = host.AbsolutePosition, host.AbsoluteSize
			local point = Vector2.new(first.X, first.Y) - GuiService:GetGuiInset()
			if point.X < at.X or point.Y < at.Y or point.X > at.X + size.X or point.Y > at.Y + size.Y then
				return
			end
			if state == Enum.UserInputState.Begin then
				pinchStart = zoom
			end
			setZoom(pinchStart * scaleFactor)
		end)
	)

	local first = selectedKey or Catalog.PerkNodes[1].Key
	selectPerk(first)
	Components.prefer(widgets[first].Button)
end

return Perks
