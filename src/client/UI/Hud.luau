--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(ReplicatedStorage.Shared.Config.UiTheme)
local Components = require(script.Parent.Components)
local Icons = require(script.Parent.Icons)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local Style = require(script.Parent.Style)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.UI)
local Format = require(ReplicatedStorage.Shared.Util.Format)

export type Callbacks = { Perks: () -> (), Reward: () -> (), Settings: () -> () }

local MAX_TOASTS = 3
local TOAST_SECONDS = 3.4
local BUTTON_SIZE = 72

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

-- Raised plate with a thick outline.
local function plate(parent: Instance, color: Color3, radius: number): Frame
	local frame = Style.frame(parent, color, radius)
	Style.outline(frame, Style.Edge, 4)
	Style.soft(frame)
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

-- Square menu button with an icon and a caption, colored by section.
local function iconButton(
	parent: Instance,
	icon: Icons.IconName,
	caption: string,
	hotkey: string?,
	color: Color3,
	callback: () -> ()
): TextButton
	local control = Style.button(parent, "", callback, true, "neutral")
	control.Name = caption
	control.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	control.BackgroundColor3 = color
	local holder = Style.frame(control)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 6)
	holder.Size = UDim2.fromOffset(40, 40)
	Icons.draw(holder, icon, Style.Text, Style.Ink)
	local text = label(control, caption, 14)
	text.AnchorPoint = Vector2.new(0.5, 1)
	text.Position = UDim2.new(0.5, 0, 1, -4)
	text.Size = UDim2.new(1, -4, 0, 18)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 14
	limit.Parent = text
	if hotkey then
		keycap(control, hotkey)
	end
	return control
end

-- Dot on a button: something is waiting there.
local function dot(button: TextButton, color: Color3): Frame
	local mark = Style.frame(button, color, 20)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.new(1, -4, 0, 4)
	mark.Size = UDim2.fromOffset(22, 22)
	mark.Visible = false
	Style.circle(mark)
	Style.outline(mark, Style.Edge, 3)
	return mark
end

-- overlay: the ScreenGui itself, so that notices stay above an open menu window.
function Hud.build(gui: GuiBase2d, callbacks: Callbacks, overlay: ScreenGui): ()
	-- Balance and laboratory level: one block at the top center.
	local top = Style.frame(gui)
	top.Name = "Top"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 8)
	top.Size = UDim2.fromOffset(280, 112)

	local pill = plate(top, Style.Panel, 20)
	pill.Name = "Balance"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 58)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(200, 58)
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
	coin.Size = UDim2.fromOffset(40, 40)
	Icons.draw(coin, "coin", Style.Amber)
	balance = label(pill, "", 30, Style.Amber)
	balance.FontFace = Style.Mono
	balance.LayoutOrder = 2
	balance.AutomaticSize = Enum.AutomaticSize.X
	balance.Size = UDim2.fromOffset(0, 58)

	local card = plate(top, Style.Panel, 14)
	card.Name = "Level"
	card.Position = UDim2.fromOffset(0, 64)
	card.Size = UDim2.new(1, 0, 0, 48)
	levelLabel = label(card, Texts.levelInitial, 18, Style.Cyan)
	Components.place(levelLabel, 12, 3, UDim.new(0.4, 0), 22)
	queueLabel = label(card, "", 14, Style.Text)
	queueLabel.AnchorPoint = Vector2.new(1, 0)
	queueLabel.Position = UDim2.new(1, -12, 0, 3)
	queueLabel.Size = UDim2.new(0.6, 0, 0, 22)
	queueLabel.TextXAlignment = Enum.TextXAlignment.Right
	local track, fill = Style.meter(card, 0, Style.Signal)
	Components.place(track, 12, 27, UDim.new(1, -24), 14)
	levelFill = fill
	levelCount = label(track, "", 12, Style.Text)
	levelCount.Size = UDim2.fromScale(1, 1)
	levelCount.TextXAlignment = Enum.TextXAlignment.Center
	levelCount.ZIndex = 2

	-- Menu buttons: a column on the left, above the thumbstick area. Bottom right stays free for jumping.
	local menu = Style.frame(gui)
	menu.Name = "Menus"
	menu.AnchorPoint = Vector2.new(0, 0.5)
	menu.Position = UDim2.new(0, if GuiService:IsTenFootInterface() then 48 else 12, 0.42, 0)
	menu.AutomaticSize = Enum.AutomaticSize.XY
	menu.Size = UDim2.fromOffset(0, 0)
	local menuLayout = Instance.new("UIListLayout")
	menuLayout.Padding = UDim.new(0, 10)
	menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
	menuLayout.Parent = menu

	perksButton = iconButton(menu, "star", Texts.perksButton, "P", Theme.Colors.Purple, callbacks.Perks)
	perksButton.LayoutOrder = 1
	perksBadge = dot(perksButton, Style.Signal)
	rewardButton = iconButton(menu, "gift", Texts.rewardButton, "G", Theme.Colors.Orange, callbacks.Reward)
	rewardButton.LayoutOrder = 2
	rewardBadge = dot(rewardButton, Style.Warning)
	local settings = iconButton(menu, "gear", Texts.settingsButton, "O", Theme.Colors.Blue, callbacks.Settings)
	settings.LayoutOrder = 3

	cursorHint = label(gui, Texts.cursorHint, 13, Style.Muted)
	cursorHint.Name = "CursorHint"
	cursorHint.AnchorPoint = Vector2.new(0.5, 1)
	cursorHint.Position = UDim2.new(0.5, 0, 1, -4)
	cursorHint.Size = UDim2.fromOffset(420, 18)
	cursorHint.TextXAlignment = Enum.TextXAlignment.Center
	cursorHint.Visible = false

	toasts = Style.frame(overlay)
	toasts.Name = "Notices"
	toasts.AnchorPoint = Vector2.new(0.5, 0)
	toasts.Position = UDim2.new(0.5, 0, 0, 128)
	toasts.Size = UDim2.new(1, -38, 0, 170)
	toasts.ZIndex = 8
	local toastBounds = Instance.new("UISizeConstraint")
	toastBounds.MaxSize = Vector2.new(430, 170)
	toastBounds.Parent = toasts
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
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
	levelLabel.Text = Format(Texts.levelShort, { level = level })
	if ceiling then
		Style.setMeter(levelFill, (data.Opened - floor) / (ceiling - floor))
		levelCount.Text = `{data.Opened} / {ceiling}`
	else
		Style.setMeter(levelFill, 1)
		levelCount.Text = Texts.levelMax
	end
	if lastLevel and level > lastLevel then
		Sfx.play("levelup")
		Hud.notice(Format(Texts.levelUp, { level = level }))
	end
	lastLevel = level
	queueLabel.Text = Format(Texts.ordersCount, { orders = data.Orders, maximum = 1 + (data.Perks.orders or 0) })
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
function Hud.notice(message: string, warning: boolean?): ()
	toastSerial += 1
	local tone = if warning then Style.Warning else Style.Signal
	Sfx.play(if warning then "error" else "notice")
	local pending = {}
	for _, child in toasts:GetChildren() do
		if child:IsA("Frame") then
			table.insert(pending, child)
		end
	end
	if #pending >= MAX_TOASTS then
		pending[1]:Destroy()
	end

	-- Below the balance; on a low screen over the window header, so it never hides the content.
	toasts.Position = UDim2.new(0.5, 0, 0, if Components.compact() then 4 else 128)

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

-- Показывает подсказку управления, пока камера в режиме первого лица (только на клавиатуре).
function Hud.setFirstPerson(active: boolean): ()
	cursorHint.Visible = active and UserInputService.KeyboardEnabled
end

function Hud.setReward(canClaim: boolean): ()
	rewardBadge.Visible = canClaim
end

return Hud
