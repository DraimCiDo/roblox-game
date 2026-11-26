--!strict
-- The single menu window: a colored header with icon, title and a big close button, a scrolling body
-- and a dock below or beside it. It closes only by the close button (and its key or gamepad button):
-- a tap next to the window must not close it on a phone.
local Components = require(script.Parent.Components)
local Icons = require(script.Parent.Icons)
local Style = require(script.Parent.Style)

local HEADER_HEIGHT = 84
local DEFAULT_SIZE = Vector2.new(620, 660)

export type Window = {
	Panel: Frame,
	Backdrop: TextButton,
	Bounds: UISizeConstraint,
	Scale: UIScale,
	Close: TextButton,
	Content: ScrollingFrame,
	Dock: Frame,
	-- Header color, icon, title and caption of the menu being shown.
	SetHeader: (title: string, caption: string, accent: Color3, icon: Icons.IconName) -> (),
}

local Window = {}

Window.DefaultSize = DEFAULT_SIZE

function Window.build(gui: Instance, onClose: () -> ()): Window
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Style.Ink
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Selectable = false
	backdrop.Visible = false
	-- Modal frees the cursor while a menu is open, otherwise first person keeps the mouse locked.
	backdrop.Modal = true
	backdrop.ZIndex = 2
	backdrop.Parent = gui

	local panel = Style.frame(gui, Style.Panel, 20)
	panel.Name = "Menu"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -20, 1, -22)
	panel.Visible = false
	panel.Active = true
	panel.SelectionGroup = true
	panel.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	panel.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	panel.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	panel.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	panel.ZIndex = 3
	Style.outline(panel, Style.Edge, 4)
	Style.soft(panel, 0.2)
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = DEFAULT_SIZE
	bounds.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local header = Style.frame(panel, Style.Cyan, 20)
	header.Position = UDim2.fromOffset(8, 8)
	header.Size = UDim2.new(1, -16, 0, HEADER_HEIGHT)
	Style.outline(header, Style.Edge, 3)
	Style.gloss(header)

	local badge = Style.frame(header, nil)
	Components.place(badge, 12, 12, UDim.new(0, 58), 58)

	local title = Components.text(header, "", 28, Style.Text, true)
	title.FontFace = Style.Display
	Style.textStroke(title, 3)
	Components.place(title, 82, 12, UDim.new(1, -150), 34)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local caption = Components.text(header, "", 15, Style.Text)
	Style.textStroke(caption, 2)
	Components.place(caption, 82, 48, UDim.new(1, -150), 28)
	caption.TextYAlignment = Enum.TextYAlignment.Top
	caption.TextTruncate = Enum.TextTruncate.AtEnd

	local close = Style.button(header, "X", onClose, true, "danger")
	close.TextSize = 28
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -12, 0.5, 0)
	close.Size = UDim2.fromOffset(56, 56)

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(16, 102)
	content.Size = UDim2.new(1, -26, 1, -112)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 8
	content.ScrollBarImageColor3 = Style.Amber
	content.CanvasSize = UDim2.new()
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.Selectable = false
	content.Parent = panel

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = content
	local margin = Instance.new("UIPadding")
	margin.PaddingLeft = UDim.new(0, 4)
	margin.PaddingTop = UDim.new(0, 4)
	margin.PaddingBottom = UDim.new(0, 6)
	margin.PaddingRight = UDim.new(0, 4)
	margin.Parent = content

	local dock = Style.frame(panel, Style.Panel, 14)
	dock.Name = "Dock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -12)
	dock.Visible = false
	dock.ZIndex = 4

	return {
		Panel = panel,
		Backdrop = backdrop,
		Bounds = bounds,
		Scale = scale,
		Close = close,
		Content = content,
		Dock = dock,
		SetHeader = function(text: string, note: string, accent: Color3, icon: Icons.IconName): ()
			title.Text = text
			caption.Text = note
			header.BackgroundColor3 = accent
			badge:ClearAllChildren()
			Icons.draw(badge, icon, Style.Text, Style.Ink)
		end,
	}
end

return Window
