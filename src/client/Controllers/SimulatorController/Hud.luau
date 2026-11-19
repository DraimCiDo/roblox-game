--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Components)
local Style = require(script.Parent.Style)

export type Callbacks = { Perks: () -> (), Reward: () -> () }

local MAX_TOASTS = 3
local TOAST_SECONDS = 3.4
-- Фрагменты без первой буквы, чтобы не зависеть от регистра.
local WARNING_HINTS =
	{ "аполнен", "едостаточ", "ельзя", "ремя вышло", "е хватает", "лишком" }
-- Боковые панели лежат по краям по вертикали в центре: там свободно и на телефоне, и на ПК, и на консоли.
local SIDE_MARGIN = 10

local Hud = {}

local heading: TextLabel
local hint: TextLabel
local signal: Frame
local queue: TextLabel
local balance: TextLabel
local rewardButton: TextButton
local rewardBadge: Frame
local toasts: Frame
local toastSerial = 0

local function sideButton(parent: Instance, caption: string, order: number, callback: () -> ()): TextButton
	local control = Style.button(parent, caption, callback, true, "neutral")
	control.LayoutOrder = order
	control.Size = UDim2.fromOffset(88, 54)
	control.TextSize = 15
	return control
end

function Hud.build(gui: ScreenGui, callbacks: Callbacks): ()
	-- Статус заказа: компактная плашка сверху по центру.
	local status = Style.frame(gui, Style.Ink, 14)
	status.Name = "Статус"
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 8)
	status.Size = UDim2.new(1, -24, 0, 62)
	Style.outline(status, Style.Edge, 3)
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(360, 62)
	bounds.Parent = status
	signal = Style.frame(status, Style.Amber, 3)
	Components.place(signal, 10, 11, UDim.new(0, 6), 40)
	heading = Components.text(status, "Синхронизация сектора…", 15, Style.Text, true)
	Components.place(heading, 24, 6, UDim.new(1, -84), 26)
	heading.TextTruncate = Enum.TextTruncate.AtEnd
	hint = Components.text(status, "", 12, Style.Muted)
	Components.place(hint, 24, 32, UDim.new(1, -36), 26)
	hint.TextYAlignment = Enum.TextYAlignment.Top
	queue = Components.text(status, "", 14, Style.Cyan, true)
	queue.AnchorPoint = Vector2.new(1, 0)
	queue.Position = UDim2.new(1, -10, 0, 8)
	queue.Size = UDim2.fromOffset(52, 22)
	queue.TextXAlignment = Enum.TextXAlignment.Right

	-- Баланс: слева по центру экрана.
	local pill = Style.frame(gui, Style.Ink, 22)
	pill.Name = "Баланс"
	pill.AnchorPoint = Vector2.new(0, 0.5)
	pill.Position = UDim2.new(0, SIDE_MARGIN, 0.5, 0)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 44)
	Style.outline(pill, Style.Amber, 3)
	local pillLayout = Instance.new("UIListLayout")
	pillLayout.FillDirection = Enum.FillDirection.Horizontal
	pillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pillLayout.Padding = UDim.new(0, 8)
	pillLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pillLayout.Parent = pill
	local pillPadding = Instance.new("UIPadding")
	pillPadding.PaddingLeft = UDim.new(0, 10)
	pillPadding.PaddingRight = UDim.new(0, 14)
	pillPadding.Parent = pill
	local coin = Style.frame(pill, Style.Amber, 12)
	coin.LayoutOrder = 1
	coin.Size = UDim2.fromOffset(24, 24)
	Style.outline(coin, Style.Edge, 2)
	balance = Components.text(pill, "", 18, Style.Amber, true)
	balance.LayoutOrder = 2
	balance.AutomaticSize = Enum.AutomaticSize.X
	balance.Size = UDim2.fromOffset(0, 44)
	balance.TextWrapped = false

	-- Перки и награда: справа по центру, большими кнопками для пальца.
	local side = Style.frame(gui)
	side.Name = "Меню"
	side.AnchorPoint = Vector2.new(1, 0.5)
	side.Position = UDim2.new(1, -SIDE_MARGIN, 0.5, 0)
	side.AutomaticSize = Enum.AutomaticSize.XY
	side.Size = UDim2.fromOffset(0, 0)
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 10)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = side
	sideButton(side, "Перки", 1, callbacks.Perks)
	rewardButton = sideButton(side, "Награда", 2, callbacks.Reward)
	rewardBadge = Style.frame(rewardButton, Style.Warning, 8)
	rewardBadge.AnchorPoint = Vector2.new(1, 0)
	rewardBadge.Position = UDim2.new(1, -2, 0, 2)
	rewardBadge.Size = UDim2.fromOffset(16, 16)
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
	queue.Text = `{data.Orders}/{1 + (data.Perks.orders or 0)}`
	balance.Text = Components.coin(data.Coins)
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
	toast.Size = UDim2.new(1, 0, 0, 44)
	local stroke = Style.outline(toast, tone, 3)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = toast
	local text = Components.text(toast, message, 15, tone, true)
	Components.place(text, 12, 0, UDim.new(1, -24), 44)
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
	rewardButton.Text = if canClaim then "Забрать!" else "Награда"
	Style.setButton(rewardButton, true, if canClaim then "reward" else "neutral")
end

return Hud
