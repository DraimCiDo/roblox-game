--!strict
-- One perk node, its links and the details panel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Parent.Components)
local Icons = require(script.Parent.Parent.Parent.Icons)
local Style = require(script.Parent.Parent.Parent.Style)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.UI)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Look = require(script.Parent.Look)
local BOARD = Look.BOARD
local PANEL = Look.PANEL
local RAIL = Look.RAIL
local BRANCH_COLORS = Look.BRANCH_COLORS
local PERK_ICONS = Look.PERK_ICONS

local Node = {}

export type NodeState = {
	Perk: Catalog.Perk,
	Level: number,
	Cost: number?,
	Locked: boolean,
	Reason: string?,
	-- Можно улучшить прямо сейчас: навык открыт, хватает монет и остаётся запас на заказ.
	Ready: boolean,
	Color: Color3,
}
export type NodeWidget = { Button: TextButton, Apply: (boolean) -> (), State: NodeState }

local function stateFor(perk: Catalog.Perk, data: Types.View): NodeState
	local level = math.min(data.Perks[perk.Key] or 0, #perk.Costs)
	local cost = Catalog.perkCost(perk, level, data.Perks)
	local lock = if cost then Catalog.perkLock(perk, level, data.Perks, data.Opened) else nil
	local reason: string? = lock
	if cost and not lock then
		if data.Coins < cost then
			reason = Format(Texts.perkMissingCoins, { coins = Components.coin(cost - data.Coins) })
		elseif data.Coins - cost < data.OrderPrice then
			reason = Format(Texts.perkKeepCoins, { coins = Components.coin(data.OrderPrice) })
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
		then Format(Texts.perkStep, {
			step = perk.Step,
			steps = perk.Steps,
			state = if state.Level > 0 then Texts.perkLearned else Texts.perkNotLearned,
		})
		else Format(Texts.perkLevel, { level = state.Level, max = #perk.Costs })
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

	local currentText = if state.Level > 0 then perk.Describe(state.Level) else Texts.perkNothing
	local current =
		Components.text(panel, Format(Texts.perkNow, { text = currentText }), if wide then 14 else 12, Style.Muted)
	Components.place(current, inset, if wide then 126 else 57, width, if wide then 40 else 26)
	local nextText = if state.Cost
		then Format(Texts.perkNext, { text = perk.Describe(state.Level + 1) })
		else Texts.perkStepDone
	local nextEffect = Components.text(panel, nextText, if wide then 16 else 13, Style.Text)
	Components.place(nextEffect, inset, if wide then 170 else 83, width, if wide then 60 else 35)

	local note = state.Reason
	if note then
		local reason = Components.text(panel, note, if wide then 13 else 11, Style.Warning)
		Components.place(reason, inset, if wide then 237 else 117, width, if wide then 44 else 28)
	end
	local affordable = state.Cost ~= nil and state.Reason == nil
	local caption = if state.Cost
		then Format(Texts.perkBuy, { cost = Components.coin(state.Cost) })
		else Texts.perkBought
	local buy = Style.button(panel, caption, function()
		Components.send("perk", perk.Key)
	end, affordable, if affordable then "primary" else "neutral")
	buy.Name = "Покупка перка"
	buy.TextSize = 16
	buy.AnchorPoint = Vector2.new(0, 1)
	buy.Position = UDim2.new(0, inset, 1, -9)
	buy.Size = UDim2.new(width, UDim.new(0, if wide then 48 else 39))
end

Node.stateFor = stateFor
Node.curve = curve
Node.centerText = centerText
Node.drawNode = drawNode
Node.details = details

return Node
