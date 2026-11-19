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

function Hud.build(gui: ScreenGui, callbacks: Callbacks): ()
	local hud = Style.frame(gui)
	hud.Name = "Сектор"
	hud.AnchorPoint = Vector2.new(0.5, 0)
	hud.Position = UDim2.new(0.5, 0, 0, 8)
	hud.Size = UDim2.new(1, -20, 0, 124)
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(400, 124)
	bounds.Parent = hud

	local status = Style.frame(hud, Style.Ink, 14)
	status.Size = UDim2.new(1, 0, 0, 72)
	Style.outline(status, Style.Edge, 3)
	signal = Style.frame(status, Style.Amber, 3)
	Components.place(signal, 10, 12, UDim.new(0, 6), 48)
	heading = Components.text(status, "Синхронизация сектора…", 16, Style.Text, true)
	Components.place(heading, 24, 6, UDim.new(1, -92), 32)
	heading.TextTruncate = Enum.TextTruncate.AtEnd
	hint = Components.text(status, "", 12, Style.Muted)
	Components.place(hint, 24, 38, UDim.new(1, -36), 30)
	queue = Components.text(status, "", 14, Style.Cyan, true)
	queue.AnchorPoint = Vector2.new(1, 0)
	queue.Position = UDim2.new(1, -10, 0, 8)
	queue.Size = UDim2.fromOffset(62, 24)
	queue.TextXAlignment = Enum.TextXAlignment.Right

	local pill = Style.frame(hud, Style.Ink, 20)
	pill.Position = UDim2.fromOffset(0, 80)
	pill.Size = UDim2.new(0.42, -4, 0, 40)
	Style.outline(pill, Style.Amber, 2)
	local coin = Style.frame(pill, Style.Amber, 11)
	Components.place(coin, 9, 9, UDim.new(0, 22), 22)
	Style.outline(coin, Style.Edge, 2)
	balance = Components.text(pill, "", 16, Style.Amber, true)
	Components.place(balance, 38, 0, UDim.new(1, -44), 40)
	balance.TextTruncate = Enum.TextTruncate.AtEnd

	local perkButton = Style.button(hud, "Перки", callbacks.Perks, true, "neutral")
	perkButton.Position = UDim2.new(0.42, 4, 0, 80)
	perkButton.Size = UDim2.new(0.25, -4, 0, 40)
	rewardButton = Style.button(hud, "Награда", callbacks.Reward, true, "neutral")
	rewardButton.Position = UDim2.new(0.67, 4, 0, 80)
	rewardButton.Size = UDim2.new(0.33, -4, 0, 40)
	rewardBadge = Style.frame(rewardButton, Style.Warning, 8)
	rewardBadge.AnchorPoint = Vector2.new(1, 0)
	rewardBadge.Position = UDim2.new(1, 4, 0, -4)
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
