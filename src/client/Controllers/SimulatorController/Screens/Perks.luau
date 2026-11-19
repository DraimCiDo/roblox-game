--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Components)
local Style = require(script.Parent.Parent.Style)

local NODE_HEIGHT = 140
local LINK_WIDTH = 28
local BRANCH_COLORS: { [string]: Color3 } = {
	storage = Style.Cyan,
	orders = Style.Violet,
	odds = Style.Amber,
	sale = Style.Signal,
}
local EFFECTS: { [string]: string } = {
	quickCollect = "Сбор всей добычи одним действием",
	quickSell = "Продажа всей добычи одним действием",
}
local NAMES: { [string]: string } = { storage = "Склад", sale = "Бонус продажи" }

local Perks = {}

local function benefit(perk: Catalog.Perk, level: number): string
	if perk.Key == "storage" then
		return `{15 + level * 5} мест на складе`
	elseif perk.Key == "orders" then
		return `Заказов одновременно: {1 + level}`
	elseif perk.Key == "sale" then
		return `+{level * 10}% к цене продажи`
	elseif perk.Key == "odds" then
		return "Больше шанс редких контейнеров"
	end
	return EFFECTS[perk.Key] or ""
end

local function node(parent: Frame, perk: Catalog.Perk, data: Types.View, color: Color3): ()
	local level = data.Perks[perk.Key] or 0
	local cost = perk.Costs[level + 1]
	local parentLevel = perk.Required or 1
	local unlocked = not perk.Parent or (data.Perks[perk.Parent] or 0) >= parentLevel
	local affordable = cost ~= nil and unlocked and data.Coins >= cost
	local accent = if unlocked then color else Style.Muted

	local frame = Style.frame(parent, Style.Card, 14)
	frame.Size = UDim2.fromScale(1, 1)
	Style.outline(frame, if affordable then accent else Style.Edge, if affordable then 3 else 2)

	local name = Components.text(frame, perk.Name, 17, if unlocked then Style.Text else Style.Muted, true)
	Components.place(name, 10, 7, UDim.new(1, -20), 22)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local detail = if unlocked
		then benefit(perk, level)
		else `Нужен «{NAMES[perk.Parent or ""] or "?"}» · ур. {parentLevel}`
	local info = Components.text(frame, detail, 12, if unlocked then Style.Muted else Style.Warning)
	Components.place(info, 10, 30, UDim.new(1, -20), 32)
	info.TextYAlignment = Enum.TextYAlignment.Top
	local pips = Components.pips(frame, #perk.Costs, level, accent)
	Components.place(pips, 10, 68, UDim.new(1, -20), 8)

	local caption = if cost then Components.coin(cost) else "Максимум"
	local buy = Style.button(frame, caption, function()
		Components.send("perk", perk.Key)
	end, affordable, if cost then "primary" else "neutral")
	buy.Name = perk.Key
	buy.AnchorPoint = Vector2.new(0.5, 1)
	buy.Position = UDim2.new(0.5, 0, 1, -8)
	buy.Size = UDim2.new(1, -20, 0, 46)
	Components.prefer(buy)
end

function Perks.render(data: Types.View): ()
	Components.paragraph(
		"Ветки открываются по порядку: улучшайте основу, чтобы получить доступ к умениям справа."
	)
	local children: { [string]: Catalog.Perk } = {}
	for _, perk in Catalog.Perks do
		if perk.Parent then
			children[perk.Parent] = perk
		end
	end

	for _, perk in Catalog.Perks do
		if not perk.Parent then
			local color = BRANCH_COLORS[perk.Key] or Style.Cyan
			local follower = children[perk.Key]
			local branch = Components.strip(NODE_HEIGHT)

			local root = Style.frame(branch)
			root.Size = if follower then UDim2.new(0.5, -LINK_WIDTH / 2, 1, 0) else UDim2.fromScale(1, 1)
			node(root, perk, data, color)
			if follower then
				local unlocked = (data.Perks[perk.Key] or 0) >= (follower.Required or 1)
				local link = Style.frame(branch, if unlocked then color else Style.Track, 3)
				link.AnchorPoint = Vector2.new(0.5, 0.5)
				link.Position = UDim2.fromScale(0.5, 0.5)
				link.Size = UDim2.fromOffset(LINK_WIDTH + 6, 6)
				local child = Style.frame(branch)
				child.AnchorPoint = Vector2.new(1, 0)
				child.Position = UDim2.fromScale(1, 0)
				child.Size = UDim2.new(0.5, -LINK_WIDTH / 2, 1, 0)
				node(child, follower, data, color)
			end

			if perk.Key == "odds" then
				local level = data.Perks.odds or 0
				local cost = perk.Costs[level + 1]
				Components.heading(
					if cost
						then "Шансы сейчас → после улучшения"
						else "Шансы доставки"
				)
				Components.odds(level, if cost then level + 1 else nil)
			end
		end
	end
end

return Perks
