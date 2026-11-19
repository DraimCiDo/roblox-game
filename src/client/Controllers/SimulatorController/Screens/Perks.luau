--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Components)
local Style = require(script.Parent.Parent.Style)

local NODE_HEIGHT = 124
local INDENT = 22
local BRANCH_COLORS: { [string]: Color3 } = {
	logistics = Style.Violet,
	storage = Style.Cyan,
	trade = Style.Signal,
	luck = Style.Amber,
}

local Perks = {}

-- Глубина узла в ветке: корни имеют 0, потомки сдвигаются вправо.
local function depthOf(perk: Catalog.Perk, index: { [string]: Catalog.Perk }): number
	local depth = 0
	local current = perk
	while current.Parent do
		depth += 1
		current = index[current.Parent]
	end
	return depth
end

local function lockReason(
	perk: Catalog.Perk,
	data: Types.View,
	level: number,
	index: { [string]: Catalog.Perk }
): string?
	if perk.Parent and (data.Perks[perk.Parent] or 0) < (perk.Required or 1) then
		return `Нужен «{index[perk.Parent].Name}» · ур. {perk.Required or 1}`
	end
	local need = perk.Opened[level + 1]
	if need and data.Opened < need then
		return `Нужно открыть контейнеров: {need} (сейчас {data.Opened})`
	end
	return nil
end

local function node(
	perk: Catalog.Perk,
	data: Types.View,
	color: Color3,
	depth: number,
	index: { [string]: Catalog.Perk }
): ()
	local level = math.min(data.Perks[perk.Key] or 0, #perk.Costs)
	local cost = perk.Costs[level + 1]
	local locked = if cost then lockReason(perk, data, level, index) else nil
	local reserved = cost ~= nil and locked == nil and data.Coins - cost < data.OrderPrice
	local affordable = cost ~= nil and locked == nil and data.Coins >= cost and not reserved
	local accent = if locked then Style.Muted else color

	local slot = Components.strip(NODE_HEIGHT)
	local frame = Style.frame(slot, Style.Card, 14)
	frame.Position = UDim2.fromOffset(depth * INDENT, 0)
	frame.Size = UDim2.new(1, -depth * INDENT, 1, 0)
	frame.ClipsDescendants = true
	Style.outline(frame, if affordable then accent else Style.Edge, if affordable then 3 else 2)
	Style.soft(frame)

	-- Соединитель к родителю: вертикаль и короткая горизонталь слева от карточки.
	if depth > 0 then
		local stem = Style.frame(slot, accent, 2)
		stem.Position = UDim2.fromOffset(depth * INDENT - 14, -10)
		stem.Size = UDim2.fromOffset(4, NODE_HEIGHT / 2 + 10)
		local elbow = Style.frame(slot, accent, 2)
		elbow.Position = UDim2.fromOffset(depth * INDENT - 14, NODE_HEIGHT / 2 - 2)
		elbow.Size = UDim2.fromOffset(14, 4)
	end

	local name = Components.text(frame, perk.Name, 18, if locked then Style.Muted else Style.Text, true)
	Components.place(name, 12, 8, UDim.new(1, -150), 24)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local current =
		Components.text(frame, if level > 0 then perk.Describe(level) else "Не изучено", 13, Style.Text)
	Components.place(current, 12, 34, UDim.new(1, -150), 18)
	current.TextTruncate = Enum.TextTruncate.AtEnd
	local following = if cost
		then `Далее: {perk.Describe(level + 1)}`
		else "Максимальный уровень"
	local nextLine = Components.text(frame, following, 12, if cost then accent else Style.Signal)
	Components.place(nextLine, 12, 54, UDim.new(1, -150), 18)
	nextLine.TextTruncate = Enum.TextTruncate.AtEnd
	local reason = locked
		or (if reserved then `Оставьте {Components.coin(data.OrderPrice)} на заказ` else nil)
	if reason then
		local warning = Components.text(frame, reason, 12, Style.Warning)
		Components.place(warning, 12, 74, UDim.new(1, -150), 30)
		warning.TextYAlignment = Enum.TextYAlignment.Top
	end
	local pips = Components.pips(frame, #perk.Costs, level, accent)
	pips.AnchorPoint = Vector2.new(0, 1)
	pips.Position = UDim2.new(0, 12, 1, -10)
	pips.Size = UDim2.new(1, -150, 0, 6)

	local counter = Components.text(frame, `{level}/{#perk.Costs}`, 14, accent, true)
	counter.AnchorPoint = Vector2.new(1, 0)
	counter.Position = UDim2.new(1, -12, 0, 10)
	counter.Size = UDim2.fromOffset(110, 18)
	counter.TextXAlignment = Enum.TextXAlignment.Right

	local caption = if cost then Components.short(cost) else "Максимум"
	local buy = Style.button(frame, caption, function()
		Components.send("perk", perk.Key)
	end, affordable, if cost then "primary" else "neutral")
	buy.Name = perk.Key
	buy.AnchorPoint = Vector2.new(1, 1)
	buy.Position = UDim2.new(1, -10, 1, -10)
	buy.Size = UDim2.fromOffset(112, 50)
	Components.prefer(buy)
end

function Perks.render(data: Types.View): ()
	local level = Catalog.level(data.Opened)
	Components.paragraph(
		`Лаборатория: уровень {level}, открыто контейнеров {data.Opened}. Новые ступени открываются по мере открытия контейнеров и изучения предыдущих навыков.`
	)
	local index: { [string]: Catalog.Perk } = {}
	for _, perk in Catalog.Perks do
		index[perk.Key] = perk
	end

	for _, branch in Catalog.Branches do
		local color = BRANCH_COLORS[branch.Key] or Style.Cyan
		local members: { Catalog.Perk } = {}
		local owned, total = 0, 0
		for _, perk in Catalog.Perks do
			if perk.Branch == branch.Key then
				table.insert(members, perk)
				owned += math.min(data.Perks[perk.Key] or 0, #perk.Costs)
				total += #perk.Costs
			end
		end
		local header = Components.strip(34)
		local title = Components.text(header, branch.Name, 21, color, true)
		Components.place(title, 2, 0, UDim.new(0.6, 0), 30)
		local progress = Components.text(header, `{owned}/{total}`, 15, Style.Muted, true)
		progress.TextXAlignment = Enum.TextXAlignment.Right
		Components.place(progress, 0, 4, UDim.new(1, -4), 24)
		for _, perk in members do
			node(perk, data, color, depthOf(perk, index), index)
		end
	end
end

return Perks
