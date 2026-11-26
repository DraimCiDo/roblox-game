--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Components)
local Icons = require(script.Parent.Icons)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local Style = require(script.Parent.Style)

export type Callbacks = { Perks: () -> (), Reward: () -> (), Settings: () -> () }

local MAX_TOASTS = 3
local TOAST_SECONDS = 3.4
-- Фрагменты без первой буквы, чтобы не зависеть от регистра.
local WARNING_HINTS = {
	"аполнен",
	"едостаточ",
	"ельзя",
	"ремя вышло",
	"е хватает",
	"лишком",
	"орвался",
}
local BUTTON_SIZE = 84

local Hud = {}

local balance: TextLabel
local popScale: UIScale
local levelLabel: TextLabel
local levelFill: Frame
local levelCount: TextLabel
local queueLabel: TextLabel
local rewardButton: TextButton
local perksButton: TextButton
local pulseRing: Frame?
local rewardBadge: Frame
local perksBadge: Frame
local toasts: Frame
local toastSerial = 0
local lastCoins: number?
local lastLevel: number?
local cursorHint: TextLabel

-- Отступы справа снизу зависят от платформы: на телефоне выше кнопки прыжка, на консоли — за безопасной зоной.
local function sideOffset(): Vector2
	if GuiService:IsTenFootInterface() then
		return Vector2.new(48, 48)
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return Vector2.new(16, 200)
	end
	return Vector2.new(16, 16)
end

-- Высота колонки «Перки + Награда»: две кнопки и промежуток между ними.
local SIDE_HEIGHT = BUTTON_SIZE * 2 + 12

-- Масштаб слоя HUD (задаёт контроллер): высоту экрана переводим в единицы слоя.
local hudScale = 1
local sideColumn: Frame? = nil

-- Отступ колонки от низа: на низком экране (ландшафтный телефон) уменьшается, чтобы колонка не выходила за верхний край.
local function sideBottom(): number
	local wanted = sideOffset().Y
	local camera = Workspace.CurrentCamera
	if not camera then
		return wanted
	end
	local top, bottom = GuiService:GetGuiInset()
	local free = (camera.ViewportSize.Y - top.Y - bottom.Y) / hudScale - SIDE_HEIGHT - 8
	return math.max(8, math.min(wanted, free))
end

-- Объёмная плашка: толстая тёмная обводка, цветной градиент и мягкий блик, как у кнопок в симуляторах.
local function plate(parent: Instance, color: Color3, radius: number): Frame
	local frame = Style.frame(parent, color, radius)
	Style.outline(frame, Style.Edge, 4)
	Style.gloss(frame)
	return frame
end

local function label(parent: Instance, text: string, size: number, color: Color3?): TextLabel
	local result = Components.text(parent, text, size, color or Style.Text, true)
	result.TextWrapped = false
	Style.textStroke(result, 2)
	return result
end

-- Клавиша-подсказка в углу кнопки (только при клавиатуре).
local function keycap(parent: GuiObject, key: string): ()
	if not UserInputService.KeyboardEnabled then
		return
	end
	local cap = Style.frame(parent, Style.Track, 4)
	cap.Name = "Клавиша"
	cap.Position = UDim2.fromOffset(4, 4)
	cap.Size = UDim2.fromOffset(18, 18)
	cap.ZIndex = parent.ZIndex + 2
	Style.outline(cap, Style.Edge, 1)
	local text = Components.text(cap, key, 12, Style.Cyan, true)
	text.Size = UDim2.fromScale(1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextWrapped = false
	text.ZIndex = cap.ZIndex + 1
end

-- Квадратная кнопка с иконкой и подписью под ней.
local function iconButton(
	parent: Instance,
	icon: Icons.IconName,
	caption: string,
	hotkey: string?,
	callback: () -> ()
): TextButton
	local control = Style.button(parent, "", callback, true, "neutral")
	control.Name = caption
	control.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	Style.round(control, 20)
	local holder = Style.frame(control)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 8)
	holder.Size = UDim2.fromOffset(46, 46)
	Icons.draw(holder, icon, Style.Amber, Style.Text)
	local text = label(control, caption, 14)
	text.AnchorPoint = Vector2.new(0.5, 1)
	text.Position = UDim2.new(0.5, 0, 1, -5)
	text.Size = UDim2.new(1, -8, 0, 18)
	text.TextXAlignment = Enum.TextXAlignment.Center
	if hotkey then
		keycap(control, hotkey)
	end
	return control
end

function Hud.build(gui: GuiBase2d, callbacks: Callbacks): ()
	-- Монеты: крупная плашка сверху по центру.
	local pill = plate(gui, Style.Ink, 32)
	pill.Name = "Баланс"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 8)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 64)
	local outline = pill:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Color = Style.Amber
	end
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(200, 64)
	minimum.Parent = pill
	popScale = Instance.new("UIScale")
	popScale.Parent = pill
	local pillLayout = Instance.new("UIListLayout")
	pillLayout.FillDirection = Enum.FillDirection.Horizontal
	pillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pillLayout.Padding = UDim.new(0, 10)
	pillLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pillLayout.Parent = pill
	local pillPadding = Instance.new("UIPadding")
	pillPadding.PaddingLeft = UDim.new(0, 14)
	pillPadding.PaddingRight = UDim.new(0, 22)
	pillPadding.Parent = pill
	local coin = Style.frame(pill)
	coin.LayoutOrder = 1
	coin.Size = UDim2.fromOffset(44, 44)
	Icons.draw(coin, "coin", Style.Amber)
	balance = label(pill, "", 34, Style.Amber)
	balance.LayoutOrder = 2
	balance.AutomaticSize = Enum.AutomaticSize.X
	balance.Size = UDim2.fromOffset(0, 64)

	-- Уровень и заказы: слева по центру экрана.
	local card = plate(gui, Style.Ink, 18)
	card.Name = "Уровень"
	card.AnchorPoint = Vector2.new(0, 0.5)
	card.Position = UDim2.new(0, 12, 0.5, 0)
	card.Size = UDim2.fromOffset(176, 96)
	Style.accent(card, Style.Cyan)
	local caption = label(card, "ЛАБОРАТОРИЯ", 11, Style.Muted)
	Components.place(caption, 14, 6, UDim.new(1, -24), 14)
	levelLabel = label(card, "УР. 1", 24, Style.Cyan)
	Components.place(levelLabel, 14, 18, UDim.new(1, -24), 26)
	local track, fill = Style.meter(card, 0, Style.Cyan)
	Components.place(track, 14, 46, UDim.new(1, -26), 14)
	levelFill = fill
	levelCount = label(track, "", 12, Style.Text)
	levelCount.AnchorPoint = Vector2.new(0.5, 0.5)
	levelCount.Position = UDim2.fromScale(0.5, 0.5)
	levelCount.Size = UDim2.fromScale(1, 1)
	levelCount.TextXAlignment = Enum.TextXAlignment.Center
	levelCount.ZIndex = 2
	queueLabel = label(card, "", 14, Style.Text)
	Components.place(queueLabel, 14, 66, UDim.new(1, -26), 22)

	-- Настройки: шестерёнка слева сверху, под значками Roblox.
	local settings = Style.button(gui, "", callbacks.Settings, true, "neutral")
	settings.Name = "Настройки"
	settings.AnchorPoint = Vector2.new(0, 0)
	settings.Position = UDim2.fromOffset(12, 8)
	settings.Size = UDim2.fromOffset(56, 56)
	Style.round(settings, 18)
	local gearHolder = Style.frame(settings)
	gearHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	gearHolder.Position = UDim2.fromScale(0.5, 0.5)
	gearHolder.Size = UDim2.fromOffset(34, 34)
	Icons.draw(gearHolder, "gear", Style.Amber, Style.Text)
	keycap(settings, "O")

	-- Подсказка в режиме первого лица: курсор заперт в центре, кнопки HUD доступны с зажатым Alt.
	cursorHint = label(
		gui,
		"Alt — курсор  ·  P перки  ·  G награда  ·  O настройки",
		13,
		Style.Muted
	)
	cursorHint.Name = "Подсказка курсора"
	cursorHint.AnchorPoint = Vector2.new(0.5, 1)
	cursorHint.Position = UDim2.new(0.5, 0, 1, -8)
	cursorHint.Size = UDim2.fromOffset(420, 18)
	cursorHint.TextXAlignment = Enum.TextXAlignment.Center
	cursorHint.Visible = false

	-- Перки и награда: справа внизу крупными кнопками, у большого пальца.
	local offset = sideOffset()
	local side = Style.frame(gui)
	side.Name = "Меню"
	side.AnchorPoint = Vector2.new(1, 1)
	side.Position = UDim2.new(1, -offset.X, 1, -sideBottom())
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			side.Position = UDim2.new(1, -offset.X, 1, -sideBottom())
		end)
	end
	sideColumn = side
	side.AutomaticSize = Enum.AutomaticSize.XY
	side.Size = UDim2.fromOffset(0, 0)
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 12)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	sideLayout.Parent = side
	perksButton = iconButton(side, "star", "Перки", "P", callbacks.Perks)
	perksButton.LayoutOrder = 1
	perksBadge = Style.frame(perksButton, Style.Signal, 10)
	perksBadge.AnchorPoint = Vector2.new(1, 0)
	perksBadge.Position = UDim2.new(1, 2, 0, -2)
	perksBadge.Size = UDim2.fromOffset(22, 22)
	perksBadge.Visible = false
	Style.outline(perksBadge, Style.Edge, 3)
	rewardButton = iconButton(side, "gift", "Награда", "G", callbacks.Reward)
	rewardButton.LayoutOrder = 2
	rewardBadge = Style.frame(rewardButton, Style.Warning, 10)
	rewardBadge.AnchorPoint = Vector2.new(1, 0)
	rewardBadge.Position = UDim2.new(1, 2, 0, -2)
	rewardBadge.Size = UDim2.fromOffset(22, 22)
	rewardBadge.Visible = false
	Style.outline(rewardBadge, Style.Edge, 3)

	toasts = Style.frame(gui)
	toasts.Name = "Уведомления"
	toasts.AnchorPoint = Vector2.new(0.5, 1)
	toasts.Position = UDim2.new(0.5, 0, 1, -18)
	toasts.Size = UDim2.new(1, -38, 0, 170)
	toasts.ZIndex = 6
	local toastBounds = Instance.new("UISizeConstraint")
	toastBounds.MaxSize = Vector2.new(430, 170)
	toastBounds.Parent = toasts
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = toasts
end

function Hud.update(data: Types.View, canClaim: boolean): ()
	balance.Text = Components.short(data.Coins)
	-- Плашка «подпрыгивает», когда баланс растёт.
	if lastCoins and data.Coins > lastCoins then
		Sfx.play("coin")
		popScale.Scale = 1.12
		Style.tween(popScale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
	end
	lastCoins = data.Coins

	local level, floor, ceiling = Catalog.levelRange(data.Opened)
	levelLabel.Text = `УР. {level}`
	if ceiling then
		Style.setMeter(levelFill, (data.Opened - floor) / (ceiling - floor))
		levelCount.Text = `{data.Opened} / {ceiling}`
	else
		Style.setMeter(levelFill, 1)
		levelCount.Text = "МАКС."
	end
	if lastLevel and level > lastLevel then
		Sfx.play("levelup")
		Hud.notice(`Новый уровень лаборатории: {level}!`)
	end
	lastLevel = level
	queueLabel.Text = `ЗАКАЗЫ {data.Orders}/{1 + (data.Perks.orders or 0)}`
	-- Зелёная точка на «Перках», когда есть навык, который можно улучшить.
	local upgradable = false
	for _, perk in Catalog.Perks do
		if Catalog.perkReady(perk, data.Perks, data.Coins, data.Opened, data.OrderPrice) then
			upgradable = true
			break
		end
	end
	perksBadge.Visible = upgradable
	Hud.setReward(canClaim)
end

-- Всплывающее сообщение: до трёх одновременно, старые вытесняются.
function Hud.notice(message: string): ()
	toastSerial += 1
	local tone = Style.Signal
	for _, fragment in WARNING_HINTS do
		if string.find(message, fragment, 1, true) then
			tone = Style.Warning
			break
		end
	end
	Sfx.play(if tone == Style.Warning then "error" else "notice")
	local pending = {}
	for _, child in toasts:GetChildren() do
		if child:IsA("Frame") then
			table.insert(pending, child)
		end
	end
	if #pending >= MAX_TOASTS then
		pending[1]:Destroy()
	end

	local toast = plate(toasts, Style.Ink, 14)
	toast.LayoutOrder = toastSerial
	toast.Size = UDim2.new(1, 0, 0, 50)
	local stroke = toast:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = tone
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = toast
	local text = label(toast, message, 17, Style.Text)
	text.TextWrapped = true
	Components.place(text, 12, 0, UDim.new(1, -24), 50)
	text.TextXAlignment = Enum.TextXAlignment.Center
	Style.tween(scale, { Scale = 1 }, 0.18, Enum.EasingStyle.Back)

	task.delay(TOAST_SECONDS, function()
		if not toast.Parent then
			return
		end
		Style.tween(toast, { BackgroundTransparency = 1 }, 0.25)
		if stroke then
			Style.tween(stroke, { Transparency = 1 }, 0.25)
		end
		Style.tween(text, { TextTransparency = 1 }, 0.25)
		task.wait(0.3)
		toast:Destroy()
	end)
end

-- Мигающая рамка вокруг кнопки: key = "perks" подсвечивает «Перки», nil убирает подсветку.
function Hud.pulse(key: string?): ()
	if pulseRing then
		pulseRing:Destroy()
		pulseRing = nil
	end
	if key ~= "perks" then
		return
	end
	local ring = Style.frame(perksButton, nil, 24)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.new(1, 12, 1, 12)
	local stroke = Style.outline(ring, Style.Amber, 5)
	TweenService:Create(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.85,
	}):Play()
	pulseRing = ring
end

-- Масштаб слоя HUD изменился (поворот экрана, смена окна): пересчитать отступ колонки кнопок.
function Hud.setScale(scale: number): ()
	hudScale = scale
	local side = sideColumn
	if side then
		side.Position = UDim2.new(1, -sideOffset().X, 1, -sideBottom())
	end
end

-- Показывает подсказку управления, пока камера в режиме первого лица (только на клавиатуре).
function Hud.setFirstPerson(active: boolean): ()
	cursorHint.Visible = active and UserInputService.KeyboardEnabled
end

function Hud.setReward(canClaim: boolean): ()
	rewardBadge.Visible = canClaim
	Style.setButton(rewardButton, true, if canClaim then "primary" else "neutral")
end

return Hud
