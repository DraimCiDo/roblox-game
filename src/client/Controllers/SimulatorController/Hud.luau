--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Components)
local Icons = require(script.Parent.Icons)
local Style = require(script.Parent.Style)

export type Callbacks = { Perks: () -> (), Reward: () -> () }

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
local BUTTON_SIZE = 72

local Hud = {}

local heading: TextLabel
local hint: TextLabel
local signal: Frame
local queue: TextLabel
local balance: TextLabel
local popScale: UIScale
local rewardButton: TextButton
local rewardBadge: Frame
local toasts: Frame
local toastSerial = 0
local lastCoins: number?

-- Отступы справа снизу зависят от платформы: на телефоне выше кнопки прыжка, на консоли — за безопасной зоной.
local function sideOffset(): Vector2
	if GuiService:IsTenFootInterface() then
		return Vector2.new(48, 48)
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return Vector2.new(16, 200)
	end
	return Vector2.new(16, 16)
end

local function iconButton(
	parent: Instance,
	icon: Icons.IconName,
	label: string,
	hotkey: string?,
	callback: () -> ()
): TextButton
	local control = Style.button(parent, "", callback, true, "neutral")
	control.Name = label
	control.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	Style.round(control, 20)
	local holder = Style.frame(control)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.62, 0.62)
	Icons.draw(holder, icon, Style.Amber, Style.Text)
	if hotkey and UserInputService.KeyboardEnabled then
		local key = Components.text(control, hotkey, 12, Style.Muted, true)
		key.AnchorPoint = Vector2.new(0, 1)
		key.Position = UDim2.new(0, 7, 1, -3)
		key.Size = UDim2.fromOffset(20, 14)
	end
	return control
end

function Hud.build(gui: ScreenGui, callbacks: Callbacks): ()
	-- Монеты: крупная плашка сверху по центру.
	local pill = Style.frame(gui, Style.Ink, 30)
	pill.Name = "Баланс"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 8)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 60)
	Style.outline(pill, Style.Amber, 4)
	Style.soft(pill, 0.1)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(190, 60)
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
	pillPadding.PaddingRight = UDim.new(0, 20)
	pillPadding.Parent = pill
	local coin = Style.frame(pill)
	coin.LayoutOrder = 1
	coin.Size = UDim2.fromOffset(42, 42)
	Icons.draw(coin, "coin", Style.Amber)
	balance = Components.text(pill, "", 30, Style.Amber, true)
	balance.LayoutOrder = 2
	balance.AutomaticSize = Enum.AutomaticSize.X
	balance.Size = UDim2.fromOffset(0, 60)
	balance.TextWrapped = false

	-- Статус заказа: под монетами.
	local status = Style.frame(gui, Style.Ink, 14)
	status.Name = "Статус"
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 74)
	status.Size = UDim2.new(1, -24, 0, 60)
	Style.outline(status, Style.Edge, 3)
	Style.soft(status, 0.08)
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(380, 60)
	bounds.Parent = status
	signal = Style.frame(status, Style.Amber, 3)
	Components.place(signal, 10, 10, UDim.new(0, 6), 40)
	heading = Components.text(status, "Синхронизация сектора…", 16, Style.Text, true)
	Components.place(heading, 24, 5, UDim.new(1, -128), 26)
	heading.TextTruncate = Enum.TextTruncate.AtEnd
	hint = Components.text(status, "", 13, Style.Muted)
	Components.place(hint, 24, 31, UDim.new(1, -36), 26)
	hint.TextYAlignment = Enum.TextYAlignment.Top
	queue = Components.text(status, "", 15, Style.Cyan, true)
	queue.AnchorPoint = Vector2.new(1, 0)
	queue.Position = UDim2.new(1, -10, 0, 7)
	queue.Size = UDim2.fromOffset(104, 22)
	queue.TextXAlignment = Enum.TextXAlignment.Right

	-- Перки и награда: справа внизу иконками, у большого пальца.
	local offset = sideOffset()
	local side = Style.frame(gui)
	side.Name = "Меню"
	side.AnchorPoint = Vector2.new(1, 1)
	side.Position = UDim2.new(1, -offset.X, 1, -offset.Y)
	side.AutomaticSize = Enum.AutomaticSize.XY
	side.Size = UDim2.fromOffset(0, 0)
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 12)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	sideLayout.Parent = side
	local perks = iconButton(side, "star", "Перки", "P", callbacks.Perks)
	perks.LayoutOrder = 1
	rewardButton = iconButton(side, "gift", "Награда", "G", callbacks.Reward)
	rewardButton.LayoutOrder = 2
	rewardBadge = Style.frame(rewardButton, Style.Warning, 9)
	rewardBadge.AnchorPoint = Vector2.new(1, 0)
	rewardBadge.Position = UDim2.new(1, -2, 0, 2)
	rewardBadge.Size = UDim2.fromOffset(20, 20)
	rewardBadge.Visible = false
	Style.outline(rewardBadge, Style.Edge, 2)

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
	local title, tip, tint = Components.status(data)
	local progress = Components.progressText(data)
	heading.Text = if progress then `{title} · {progress}` else title
	hint.Text = tip
	signal.BackgroundColor3 = tint
	queue.Text = `ур. {Catalog.level(data.Opened)} · {data.Orders}/{1 + (data.Perks.orders or 0)}`
	balance.Text = Components.short(data.Coins)
	-- Плашка «подпрыгивает», когда баланс растёт.
	if lastCoins and data.Coins > lastCoins then
		popScale.Scale = 1.12
		Style.tween(popScale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
	end
	lastCoins = data.Coins
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
	local pending = {}
	for _, child in toasts:GetChildren() do
		if child:IsA("Frame") then
			table.insert(pending, child)
		end
	end
	if #pending >= MAX_TOASTS then
		pending[1]:Destroy()
	end

	local toast = Style.frame(toasts, Style.Ink, 12)
	toast.LayoutOrder = toastSerial
	toast.Size = UDim2.new(1, 0, 0, 46)
	local stroke = Style.outline(toast, tone, 3)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = toast
	local text = Components.text(toast, message, 16, tone, true)
	Components.place(text, 12, 0, UDim.new(1, -24), 46)
	text.TextXAlignment = Enum.TextXAlignment.Center
	Style.tween(scale, { Scale = 1 }, 0.18, Enum.EasingStyle.Back)

	task.delay(TOAST_SECONDS, function()
		if not toast.Parent then
			return
		end
		Style.tween(toast, { BackgroundTransparency = 1 }, 0.25)
		Style.tween(stroke, { Transparency = 1 }, 0.25)
		Style.tween(text, { TextTransparency = 1 }, 0.25)
		task.wait(0.3)
		toast:Destroy()
	end)
end

function Hud.setReward(canClaim: boolean): ()
	rewardBadge.Visible = canClaim
	Style.setButton(rewardButton, true, if canClaim then "primary" else "neutral")
end

return Hud
