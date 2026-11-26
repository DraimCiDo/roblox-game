--!strict
-- Description of the selected node with the buy button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Components = require(script.Parent.Parent.Parent.Components)
local Style = require(script.Parent.Parent.Parent.Style)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.UI)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Look = require(script.Parent.Look)
local Node = require(script.Parent.Node)

local Card = {}

local BUY_HEIGHT = 54

-- What the step needs from other branches, written out instead of drawn as a line.
local function requirements(perk: Catalog.Perk): string?
	local lines = {}
	local parent = if perk.Parent then Catalog.perk(perk.Parent) else nil
	if parent and parent.Branch ~= perk.Branch then
		table.insert(lines, Format(Texts.perkAlso, { name = parent.Name }))
	end
	if perk.Needs then
		for _, need in perk.Needs do
			local other = Catalog.perk(need.Key)
			if other then
				table.insert(lines, Format(Texts.perkAlso, { name = other.Name }))
			end
		end
	end
	return if #lines > 0 then table.concat(lines, "\n") else nil
end

local function paragraph(parent: Instance, text: string, size: number, color: Color3, order: number): TextLabel
	local label = Components.text(parent, text, size, color)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, -4, 0, 0)
	label.LayoutOrder = order
	label.ZIndex = 5
	return label
end

function Card.render(panel: Frame, info: Node.Info, branchName: string): ()
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local perk = info.Perk
	local color = Look.BranchColors[perk.Branch] or Style.Cyan
	local hidden = info.State == "hidden"

	local body = Instance.new("ScrollingFrame")
	body.Name = "Text"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(12, 10)
	body.Size = UDim2.new(1, -20, 1, -(BUY_HEIGHT + 30))
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.ScrollBarThickness = 4
	body.Selectable = false
	body.ZIndex = 5
	body.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	paragraph(body, branchName, 14, color, 1)
	local title = paragraph(body, if hidden then Texts.perkHiddenName else perk.Name, 22, Style.Text, 2)
	title.FontFace = Style.Display
	Style.textStroke(title, 2)

	if hidden then
		local parent = if perk.Parent then Catalog.perk(perk.Parent) else nil
		if parent then
			paragraph(body, Format(Texts.perkHiddenHint, { name = parent.Name }), 16, Style.Muted, 3)
		end
	else
		local step, steps = perk.Step :: number, perk.Steps :: number
		if steps > 1 then
			local state = if info.State == "owned" then Texts.perkLearned else Texts.perkNotLearned
			paragraph(body, Format(Texts.perkStep, { step = step, steps = steps, state = state }), 14, Style.Muted, 3)
		end
		paragraph(body, perk.Describe(1), 18, Style.Text, 4)
		local extra = requirements(perk)
		if extra then
			paragraph(body, extra, 14, Style.Muted, 5)
		end
		if info.Reason then
			paragraph(body, info.Reason, 15, Style.Amber, 6)
		end
	end

	local caption = if info.State == "owned"
		then Texts.perkBought
		elseif hidden or not info.Cost then Texts.perkHiddenName
		else Format(Texts.perkBuy, { cost = Components.coin(info.Cost) })
	local buy = Style.button(panel, caption, function()
		Components.send("perk", perk.Key)
	end, info.State == "available" and info.Reason == nil, "primary")
	buy.Name = "BuyPerk"
	buy.AnchorPoint = Vector2.new(0.5, 1)
	buy.Position = UDim2.new(0.5, 0, 1, -10)
	buy.Size = UDim2.new(1, -20, 0, BUY_HEIGHT)
	buy.TextSize = 20
	buy.ZIndex = 6
end

return Card
