--!strict
-- One perk node of the tree and the elbow lines between nodes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local PerkTree = require(ReplicatedStorage.Shared.PerkTree)
local Components = require(script.Parent.Parent.Parent.Components)
local Icons = require(script.Parent.Parent.Parent.Icons)
local Style = require(script.Parent.Parent.Parent.Style)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.UI)
local Look = require(script.Parent.Look)

export type Info = {
	Perk: Catalog.Perk,
	State: PerkTree.State,
	Cost: number?,
	-- Why it cannot be bought right now; nil when it can, or is already owned.
	Reason: string?,
}

local Node = {}

Node.Size = 92
local LINE = 8

local function bar(parent: Instance, from: Vector2, to: Vector2, color: Color3): ()
	local piece = Style.frame(parent, color)
	local low = from:Min(to)
	local size = from:Max(to) - low
	piece.Position = UDim2.fromOffset(low.X - LINE / 2, low.Y - LINE / 2)
	piece.Size = UDim2.fromOffset(size.X + LINE, size.Y + LINE)
	piece.ZIndex = 2
end

-- Parent to child: down the column of the parent, then right.
function Node.link(parent: Instance, from: Vector2, to: Vector2, color: Color3): ()
	if from.Y == to.Y then
		bar(parent, from, to, color)
		return
	end
	local corner = Vector2.new(from.X, to.Y)
	bar(parent, from, corner, color)
	bar(parent, corner, to, color)
end

-- Returns the button and a function that marks it as selected.
function Node.draw(parent: Instance, info: Info, center: Vector2): (TextButton, (boolean) -> ())
	local perk = info.Perk
	local color = Look.BranchColors[perk.Branch] or Style.Cyan
	local hidden = info.State == "hidden"
	local owned = info.State == "owned"
	local ready = info.State == "available" and info.Reason == nil

	local button = Instance.new("TextButton")
	button.Name = perk.Key
	button.Text = ""
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromOffset(center.X, center.Y)
	button.Size = UDim2.fromOffset(Node.Size, Node.Size)
	button.BackgroundColor3 = if owned or ready then color elseif hidden then Style.Track else Style.Card
	button.ZIndex = 3
	button.Parent = parent
	Style.round(button, 20)
	local restColor = if info.State == "available" and not ready then color else Style.Edge
	local outline = Style.outline(button, restColor, 3)
	Style.gloss(button)

	if hidden then
		local mark = Components.text(button, Texts.perkHiddenName, 36, Style.Muted, true)
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.Size = UDim2.fromScale(1, 1)
		mark.ZIndex = 4
	else
		local icon = Style.frame(button)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 10)
		icon.Size = UDim2.fromOffset(46, 46)
		icon.ZIndex = 4
		Icons.draw(icon, Look.Icons[perk.Base :: string] or "star", Style.Text, Style.Ink).ZIndex = 4

		-- Bottom chip: the price, or a check mark once owned.
		local chip = Style.frame(button, Style.Ink, 6)
		chip.AnchorPoint = Vector2.new(0.5, 1)
		chip.Position = UDim2.new(0.5, 0, 1, -8)
		chip.Size = UDim2.fromOffset(Node.Size - 18, 22)
		chip.ZIndex = 4
		if owned then
			local check = Icons.draw(chip, "check", Style.Signal)
			check.AnchorPoint = Vector2.new(0.5, 0.5)
			check.Position = UDim2.fromScale(0.5, 0.5)
			check.Size = UDim2.fromOffset(20, 20)
			check.ZIndex = 5
		else
			local value = if info.Cost then Components.short(info.Cost) else ""
			local price = Components.text(chip, value, 15, if ready then Style.Amber else Style.Muted, true)
			price.TextXAlignment = Enum.TextXAlignment.Center
			price.Size = UDim2.fromScale(1, 1)
			price.ZIndex = 5
		end

		local name = Components.text(button, perk.Name, 14, Style.Text, true)
		name.AnchorPoint = Vector2.new(0.5, 0)
		name.Position = UDim2.new(0.5, 0, 1, 4)
		name.Size = UDim2.fromOffset(Node.Size + 36, 34)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextYAlignment = Enum.TextYAlignment.Top
		name.ZIndex = 4
		Style.textStroke(name, 2)
	end

	-- A node that can be bought now breathes.
	if ready then
		local scale = Instance.new("UIScale")
		scale.Parent = button
		local breathe = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(scale, breathe, { Scale = 1.07 }):Play()
	end

	local function select(selected: boolean): ()
		outline.Color = if selected then Style.Text else restColor
	end
	return button, select
end

return Node
