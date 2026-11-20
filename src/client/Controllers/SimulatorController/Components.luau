--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Preview = require(script.Parent.ContainerPreview)
local Sfx = require(script.Parent.Sfx)
local ItemPreview = require(script.Parent.ItemPreview)
local Style = require(script.Parent.Style)

export type DailyWidgets = { Time: TextLabel, Caption: TextLabel, Fill: Frame, Button: TextButton }
export type DialWidgets = { Needle: Frame, Time: TextLabel, Glow: UIStroke }
export type LiveWidgets = { Delivery: TextLabel?, Daily: DailyWidgets?, Dial: DialWidgets? }
export type TileOptions = {
	Caption: string?,
	CaptionColor: Color3?,
	Badge: string?,
	Selected: boolean?,
	Ghost: boolean?,
	Callback: (() -> ())?,
	FocusKey: string?,
}
export type RowOptions = {
	Name: string,
	Details: string,
	Tint: Color3,
	Kind: string?,
	Caption: string?,
	Callback: (() -> ())?,
	Enabled: boolean?,
	FocusKey: string?,
	Tone: Style.ButtonTone?,
}

local SEALED_HELP: { [string]: string } = {
	box = "Подойдите к коробке и снимите скотч.",
	crate = "Сломайте четыре крепления на ящике.",
	safe = "Активируйте ручку и остановите её в секторе.",
	cargo = "Разблокируйте оба фиксатора и откройте створки.",
	secret = "Активируйте контейнер, пока он не откроется.",
}
local CONDITION_COLORS: { [string]: Color3 } = {
	["Плохое"] = Color3.fromRGB(160, 165, 196),
	["Изношенное"] = Color3.fromRGB(110, 214, 134),
	["Нормальное"] = Color3.fromRGB(80, 194, 255),
	["Хорошее"] = Color3.fromRGB(190, 124, 255),
	["Идеальное"] = Color3.fromRGB(255, 200, 60),
}
local CONTENT_INSET = 108
-- Ниже этой высоты панели (ландшафтный телефон) нижняя панель уходит вбок, иначе на содержимое не остаётся места.
local COMPACT_BELOW = 420
local SIDE_DOCK_WIDTH = 220
local SIDE_DOCK_TOP = 96

local Components = {}
Components.Live = {} :: LiveWidgets

local content: ScrollingFrame
local dockFrame: Frame
local sendAction: (string, string?, string?) -> ()
local redraw: () -> ()
local order = 0
local focus: GuiObject?

function Components.setup(
	scroller: ScrollingFrame,
	dock: Frame,
	send: (string, string?, string?) -> (),
	request: () -> ()
): ()
	content, dockFrame, sendAction, redraw = scroller, dock, send, request
end

function Components.send(name: string, argument: string?, extra: string?): ()
	sendAction(name, argument, extra)
end

function Components.redraw(): ()
	redraw()
end

-- Очищает область содержимого перед отрисовкой нового экрана.
function Components.begin(): ()
	order = 0
	focus = nil
	table.clear(Components.Live)
	dockFrame.Visible = false
	content.Size = UDim2.new(1, -26, 1, -CONTENT_INSET)
	for _, object in content:GetChildren() do
		if object:IsA("GuiObject") then
			object:Destroy()
		end
	end
end

-- Высота окна меню в пикселях: так же считается его размер (экран минус системные отступы и поля 22).
function Components.panelHeight(): number
	local camera = Workspace.CurrentCamera
	local top, bottom = GuiService:GetGuiInset()
	local viewport = if camera then camera.ViewportSize.Y else 1080
	return viewport - top.Y - bottom.Y - 22
end

-- Низкое окно меню (ландшафтный телефон).
function Components.compact(): boolean
	return Components.panelHeight() < COMPACT_BELOW
end

-- Высота полосы для карты: на низком окне не выше видимой области содержимого.
function Components.viewHeight(preferred: number): number
	if not Components.compact() then
		return preferred
	end
	return math.clamp(Components.panelHeight() - CONTENT_INSET - 12, 120, preferred)
end

-- Нижняя панель вне прокрутки: остаётся на виду при выборе предмета в длинном списке.
-- side = true: на низком окне панель встаёт справа от содержимого, а не под ним.
function Components.dock(height: number, side: boolean?): Frame
	for _, object in dockFrame:GetChildren() do
		if object:IsA("GuiObject") then
			object:Destroy()
		end
	end
	dockFrame.Visible = true
	if side and Components.compact() then
		dockFrame.AnchorPoint = Vector2.new(1, 0)
		dockFrame.Position = UDim2.new(1, -12, 0, SIDE_DOCK_TOP)
		dockFrame.Size = UDim2.fromOffset(SIDE_DOCK_WIDTH, math.max(150, Components.panelHeight() - SIDE_DOCK_TOP - 8))
		content.Size = UDim2.new(1, -(26 + SIDE_DOCK_WIDTH + 8), 1, -CONTENT_INSET)
	else
		dockFrame.AnchorPoint = Vector2.new(0.5, 1)
		dockFrame.Position = UDim2.new(0.5, 0, 1, -12)
		dockFrame.Size = UDim2.new(1, -32, 0, height)
		content.Size = UDim2.new(1, -26, 1, -(CONTENT_INSET + height + 10))
	end
	return dockFrame
end

function Components.preferred(): GuiObject?
	return focus
end

function Components.prefer(button: TextButton): ()
	if not focus and button.Selectable then
		focus = button
	end
end

function Components.append(gui: GuiObject): ()
	order += 1
	gui.LayoutOrder = order
	gui.Parent = content
end

function Components.coin(value: number): string
	local reversed = string.reverse(tostring(value))
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1 ")
	return (string.gsub(string.reverse(grouped), "^ ", ""))
end

function Components.clock(seconds: number): string
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

function Components.qualityColor(quality: number): Color3
	return CONDITION_COLORS[Catalog.condition(quality)]
end

function Components.itemDetails(item: Types.Item): string
	return `{Catalog.condition(item.Quality)} · {item.Quality}/100`
end

function Components.dailyState(data: Types.View, now: number): (boolean, number, boolean)
	local claimed = data.DailyClaim >= math.floor(now / 86400)
	local remaining = math.max(0, math.ceil(data.DailyReadyAt - now))
	return claimed, remaining, not claimed and remaining == 0
end

function Components.containerName(data: Types.View): string
	local kind = data.OrderKind
	if kind then
		return (if data.OrderVariant then Catalog.Variants else Catalog.Containers)[kind]
	end
	return "Случайный контейнер"
end

function Components.progressText(data: Types.View): string?
	if data.OrderProgress and data.OrderGoal then
		return `Шаг {data.OrderProgress} / {data.OrderGoal}`
	end
	return nil
end

function Components.status(data: Types.View): (string, string, Color3)
	local stage = data.OrderStage
	if stage == "queued" or stage == "delivery" then
		return "Контейнер в пути",
			"Дождитесь доставки у верхнего шлюза.",
			Style.Amber
	elseif stage == "sealed" then
		return Components.containerName(data),
			SEALED_HELP[data.OrderKind or "box"] or "Откройте контейнер.",
			Style.Cyan
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

function Components.place(gui: GuiObject, x: number, y: number, width: UDim, height: number): ()
	gui.Position = UDim2.fromOffset(x, y)
	gui.Size = UDim2.new(width, UDim.new(0, height))
end

-- display = заголовочный шрифт. Мелкие подписи (меньше 15 px) Jura рисует с разреженными буквами,
-- поэтому для них берётся плотный жирный Roboto Condensed.
function Components.text(parent: Instance, value: string, size: number, color: Color3?, display: boolean?): TextLabel
	local font = if not display then nil elseif size < 15 then Style.Bold else Style.Display
	return Style.label(parent, value, size, color, font)
end

function Components.heading(value: string): ()
	local field = Components.text(content, value, 21, Style.Text, true)
	field.Size = UDim2.new(1, -9, 0, 32)
	Components.append(field)
end

function Components.paragraph(value: string, color: Color3?): ()
	local field = Components.text(content, value, 15, color or Style.Muted)
	field.AutomaticSize = Enum.AutomaticSize.Y
	field.Size = UDim2.new(1, -9, 0, 0)
	Components.append(field)
end

function Components.card(height: number, color: Color3?): Frame
	local result = Style.frame(content, color or Style.Card, 14)
	result.Size = UDim2.new(1, -9, 0, height)
	Style.outline(result)
	Style.soft(result)
	Components.append(result)
	return result
end

-- Карточка с автовысотой: внутрь кладут заголовок и сетку слотов.
function Components.group(): Frame
	local result = Style.frame(content, Style.Card, 14)
	result.AutomaticSize = Enum.AutomaticSize.Y
	result.Size = UDim2.new(1, -9, 0, 0)
	Style.outline(result)
	Style.soft(result)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = result
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = result
	Components.append(result)
	return result
end

-- Строка текста внутри group: высота подбирается по содержимому.
function Components.line(parent: Instance, value: string, size: number, color: Color3?, display: boolean?): TextLabel
	local field = Components.text(parent, value, size, color, display)
	field.AutomaticSize = Enum.AutomaticSize.Y
	field.Size = UDim2.new(1, 0, 0, 0)
	field.LayoutOrder = #parent:GetChildren()
	return field
end

function Components.command(value: string, callback: () -> (), enabled: boolean?, tone: Style.ButtonTone?): TextButton
	local control = Style.button(content, value, callback, enabled, tone)
	control.TextSize = 20
	control.Size = UDim2.new(1, -9, 0, 58)
	Components.append(control)
	Components.prefer(control)
	return control
end

-- Сетка квадратных ячеек: размер ячейки пересчитывается по ширине списка.
function Components.grid(columns: number, gap: number, parent: Instance?): Frame
	local holder = Style.frame(parent or content)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Size = UDim2.new(1, if parent then 0 else -9, 0, 0)
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(gap, gap)
	layout.Parent = holder
	local function fit()
		local width = holder.AbsoluteSize.X
		if width > 0 then
			local cell = math.floor((width - gap * (columns - 1)) / columns)
			layout.CellSize = UDim2.fromOffset(cell, cell)
		end
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	if parent then
		holder.LayoutOrder = #parent:GetChildren()
	else
		Components.append(holder)
	end
	fit()
	return holder
end

function Components.emptySlot(parent: Instance): Frame
	local slot = Style.frame(parent, Style.Track, 10)
	Style.outline(slot, Style.Edge, 1)
	slot.LayoutOrder = #parent:GetChildren()
	return slot
end

-- Слот предмета: 3D-иконка, рамка цвета состояния, подпись и бейдж.
function Components.tile(parent: Instance, kind: string, item: Types.Item?, options: TileOptions): TextButton
	local tint = if item then Components.qualityColor(item.Quality) else Style.Edge
	local tile = Instance.new("TextButton")
	tile.Name = options.FocusKey or kind
	tile.Text = ""
	tile.AutoButtonColor = false
	tile.BorderSizePixel = 0
	tile.BackgroundColor3 = if options.Ghost then Style.Track else Style.Card
	tile.LayoutOrder = #parent:GetChildren()
	Style.round(tile, 10)
	Style.outline(tile, if options.Selected then Style.Text else tint, if options.Selected then 3 else 2)

	local icon = ItemPreview.draw(tile, kind, options.Ghost)
	icon.Position = UDim2.fromScale(0.08, 0.05)
	icon.Size = UDim2.fromScale(0.84, 0.64)
	if item then
		local quality = Components.text(tile, tostring(item.Quality), 12, tint, true)
		Components.place(quality, 6, 3, UDim.new(0.5, 0), 16)
	end
	if options.Badge then
		local badge = Components.text(tile, options.Badge, 12, Style.Amber, true)
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -6, 0, 3)
		badge.Size = UDim2.fromOffset(40, 16)
		badge.TextXAlignment = Enum.TextXAlignment.Right
	end
	if options.Caption then
		local caption = Components.text(tile, options.Caption, 12, options.CaptionColor or Style.Amber, true)
		caption.AnchorPoint = Vector2.new(0, 1)
		caption.Position = UDim2.new(0, 0, 1, -3)
		caption.Size = UDim2.new(1, 0, 0, 16)
		caption.TextXAlignment = Enum.TextXAlignment.Center
		caption.TextTruncate = Enum.TextTruncate.AtEnd
	end

	local callback = options.Callback
	tile.Selectable = callback ~= nil
	if callback then
		tile.Activated:Connect(function()
			Sfx.play("click")
			callback()
		end)
		Components.prefer(tile)
	end
	tile.Parent = parent
	return tile
end

-- Строка списка: иконка слева, название и подробности, кнопка справа.
function Components.row(options: RowOptions): ()
	local entry = Components.card(84)
	local badge = Style.frame(entry, Style.Track, 12)
	Components.place(badge, 8, 8, UDim.new(0, 68), 68)
	if options.Kind then
		local icon = ItemPreview.draw(badge, options.Kind)
		icon.Size = UDim2.fromScale(1, 1)
	else
		local dot = Style.frame(badge, options.Tint, 8)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromOffset(20, 20)
	end
	Style.outline(badge, options.Tint, 2)

	local reserved = if options.Caption then -192 else -92
	local headline = Components.text(entry, options.Name, 18, Style.Text, true)
	Components.place(headline, 88, 9, UDim.new(1, reserved), 26)
	headline.TextTruncate = Enum.TextTruncate.AtEnd
	local sub = Components.text(entry, options.Details, 13, Style.Muted)
	Components.place(sub, 88, 38, UDim.new(1, reserved), 40)
	sub.TextYAlignment = Enum.TextYAlignment.Top

	local callback = options.Callback
	if options.Caption and callback then
		local control = Style.button(entry, options.Caption, callback, options.Enabled, options.Tone)
		control.Name = options.FocusKey or options.Name
		control.AnchorPoint = Vector2.new(1, 0.5)
		control.Position = UDim2.new(1, -10, 0.5, 0)
		control.Size = UDim2.fromOffset(110, 52)
		Components.prefer(control)
	end
end

-- Индикатор уровней: заполненные и свободные деления.
function Components.pips(parent: Instance, total: number, filled: number, color: Color3): Frame
	local holder = Style.frame(parent)
	for index = 1, total do
		local pip = Style.frame(holder, if index <= filled then color else Style.Track, 3)
		pip.Position = UDim2.fromScale((index - 1) / total, 0)
		pip.Size = UDim2.new(1 / total, -3, 1, 0)
	end
	return holder
end

-- Крупные числа для узких мест (плашка баланса, кнопки): 12 345, 480 К, 1,9 М, 2,4 Б.
function Components.short(value: number): string
	local function trim(number: number): string
		local text = string.format("%.2f", number)
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
		return (string.gsub(text, "%.", ","))
	end
	if value >= 1e9 then
		return `{trim(value / 1e9)} Б`
	elseif value >= 1e6 then
		return `{trim(value / 1e6)} М`
	elseif value >= 1e5 then
		return `{math.floor(value / 1e3)} К`
	end
	return Components.coin(value)
end

local function percent(value: number): string
	return string.format(if value >= 10 then "%.0f%%" else "%.1f%%", value)
end

-- Таблица шансов типов контейнеров; закрытые уровнем типы затемнены и подписаны.
function Components.odds(values: { number }, following: { number }?, level: number): ()
	local summary = Components.card(#values * 34 + 16, Style.Track)
	for index, chance in values do
		local kind = Catalog.Kinds[index]
		local top = 8 + (index - 1) * 34
		local locked = level < Catalog.TierUnlock[index]
		local name =
			Components.text(summary, Catalog.Containers[kind], 13, if locked then Style.Muted else Style.Text, true)
		Components.place(name, 12, top, UDim.new(1, -132), 19)
		local chanceText = if locked
			then `уровень {Catalog.TierUnlock[index]}`
			elseif following then `{percent(chance)} → {percent(following[index])}`
			else percent(chance)
		local number = Components.text(summary, chanceText, 13, if locked then Style.Warning else Style.Muted, true)
		number.TextXAlignment = Enum.TextXAlignment.Right
		number.AnchorPoint = Vector2.new(1, 0)
		number.Position = UDim2.new(1, -12, 0, top)
		number.Size = UDim2.fromOffset(116, 19)
		local share = (if following then following[index] else chance) / 100
		local track = Style.meter(summary, share, if locked then Style.Edge else Preview.color(kind))
		Components.place(track, 12, top + 21, UDim.new(1, -24), 6)
	end
end

-- Прозрачная полоса фиксированной высоты для рядов кнопок и ветвей дерева.
function Components.strip(height: number): Frame
	local strip = Style.frame(content)
	strip.Size = UDim2.new(1, -9, 0, height)
	Components.append(strip)
	return strip
end

return Components
