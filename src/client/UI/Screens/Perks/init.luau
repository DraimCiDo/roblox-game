--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Components)
local Icons = require(script.Parent.Parent.Icons)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local Style = require(script.Parent.Parent.Style)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.UI)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local LayoutOf = require(script.Layout)
local Look = require(script.Look)
local Node = require(script.Node)
local BOARD = Look.BOARD
local PANEL = Look.PANEL
local RAIL = Look.RAIL
local BRANCH_COLORS = Look.BRANCH_COLORS
local ROOT_DIAMETER = LayoutOf.ROOT_DIAMETER
local NODE_DIAMETER = LayoutOf.NODE_DIAMETER
type Layout = LayoutOf.Layout
local layout = LayoutOf.layout
type NodeState = Node.NodeState
type NodeWidget = Node.NodeWidget
local stateFor = Node.stateFor
local curve = Node.curve
local centerText = Node.centerText
local drawNode = Node.drawNode
local details = Node.details

local Perks = {}

local MOBILE_DOCK = 194
-- Минимум позволяет уместить всё дерево в окне на любом экране.
local MIN_ZOOM = 0.2
local SIDE_PANEL = 320
local MAX_ZOOM = 1.5
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

function Perks.reset(): ()
	selectedKey = nil
	scroll = nil
	-- На низком окне (телефон) карта стартует мельче, чтобы ветки были видны сразу.
	zoom = if Components.compact() then 0.55 else 0.8
	disconnect()
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

	-- Окно перков растянуто на весь экран: карта занимает всю высоту, описание узла — колонка справа.
	local shell = Components.strip(Components.fillHeight())
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
	-- Смещение считается по положению курсора, а не по input.Delta: Delta бывает нулевой, и карта не двигалась.
	local lastMouse = Vector2.zero
	local function beginDrag(input: InputObject): ()
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			travelled = 0
			lastMouse = UserInputService:GetMouseLocation()
		end
	end
	-- Зажатие по любому месту карты (пустая область, линии, подписи) начинает перетаскивание; узлы ловят его сами.
	table.insert(connections, surface.InputBegan:Connect(beginDrag))
	table.insert(connections, view.InputBegan:Connect(beginDrag))
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
	-- Масштаб «всё дерево целиком»: карта вписывается в окно с небольшим полем и встаёт по центру.
	-- Границы считаются по самим узлам (с полем под подписи), а не по холсту: у холста есть пустые поля.
	local low, high = map.Hub, map.Hub
	for _, point in map.Points do
		low = low:Min(point)
		high = high:Max(point)
	end
	low -= Vector2.new(70, 60)
	high += Vector2.new(70, 80)
	local function fitWhole(): ()
		local size = host.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			return
		end
		local bounds = high - low
		zoom = math.clamp(math.min(size.X / bounds.X, size.Y / bounds.Y), MIN_ZOOM, MAX_ZOOM)
		scale.Scale = zoom
		host.CanvasSize = UDim2.fromOffset(map.Size.X * zoom, map.Size.Y * zoom)
		local middle = (low + high) / 2 * zoom
		host.CanvasPosition = Vector2.new(math.max(0, middle.X - size.X / 2), math.max(0, middle.Y - size.Y / 2))
	end
	-- Размер окна карты известен только после первой раскладки интерфейса.
	task.delay(0.05, function()
		if not host.Parent then
			return
		end
		if scroll then
			host.CanvasPosition = scroll
		else
			fitWhole()
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
	local coreLevel =
		centerText(core, Format(Texts.perkLabLevel, { level = Catalog.level(data.Opened) }), 24, Style.Text, true)
	coreLevel.Position = UDim2.fromOffset(0, 24)
	coreLevel.Size = UDim2.new(1, 0, 0, 30)
	coreLevel.ZIndex = 5
	Style.textStroke(coreLevel, 2)
	local coreNote = centerText(core, Format(Texts.perkOpened, { opened = data.Opened }), 12, Style.Muted)
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

	local detailPanel = Components.dock(MOBILE_DOCK, true, SIDE_PANEL)
	-- В широкой колонке справа — развёрнутое описание (шкала уровней, крупная кнопка).
	local wideDetails = not Components.compact()
	local widgets: { [string]: NodeWidget } = {}
	local function selectPerk(perkKey: string): ()
		selectedKey = perkKey
		for nodeKey, widget in widgets do
			widget.Apply(nodeKey == perkKey)
		end
		details(detailPanel, states[perkKey], branches, wideDetails)
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
				fitWhole()
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
			then Format(Texts.perkTotalReady, { owned = owned, total = total, ready = ready })
			else Format(Texts.perkTotal, { owned = owned, total = total }),
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
				local current = UserInputService:GetMouseLocation()
				local delta = current - lastMouse
				lastMouse = current
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
