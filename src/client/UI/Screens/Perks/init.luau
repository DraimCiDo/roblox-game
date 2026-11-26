--!strict
-- Perk tree: a tab per branch, a tidy left-to-right grid of the visible steps and a card with the
-- selected one. What is visible and where it stands is decided by Shared/PerkTree.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local PerkTree = require(ReplicatedStorage.Shared.PerkTree)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Components)
local Icons = require(script.Parent.Parent.Icons)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local Style = require(script.Parent.Parent.Style)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.UI)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Card = require(script.Card)
local Look = require(script.Look)
local Node = require(script.Node)

local Perks = {}

local COLUMN = 142
local ROW = 140
local MARGIN = 84
local TAB_HEIGHT = 52
local TAB_WIDTH = 150
local MOBILE_DOCK = 200
local SIDE_PANEL = 300
local MIN_ZOOM = 0.45
local MAX_ZOOM = 1.4

local selectedBranch: string? = nil
local selectedKey: string? = nil
local zoom = 1
local scroll: Vector2? = nil
local tabScroll = Vector2.zero
local connections: { RBXScriptConnection } = {}

local function disconnect(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

function Perks.reset(): ()
	selectedBranch = nil
	selectedKey = nil
	scroll = nil
	tabScroll = Vector2.zero
	-- Smaller on a short window (phone), so that more of the branch is visible.
	zoom = if Components.compact() then 0.65 else 1
	disconnect()
end

local function infoFor(perk: Catalog.Perk, state: PerkTree.State, data: Types.View): Node.Info
	local levels = Catalog.nodeLevels(data.Perks)
	local cost = Catalog.perkCost(perk, 0, levels)
	local reason: string? = nil
	if state == "available" and cost then
		reason = Catalog.perkLock(perk, 0, levels, data.Opened)
		if not reason then
			if data.Coins < cost then
				reason = Format(Texts.perkMissingCoins, { coins = Components.coin(cost - data.Coins) })
			elseif data.Coins - cost < data.OrderPrice then
				reason = Format(Texts.perkKeepCoins, { coins = Components.coin(data.OrderPrice) })
			end
		end
	end
	return { Perk = perk, State = state, Cost = cost, Reason = reason }
end

local function branchInfo(branch: string, data: Types.View): ({ [string]: Node.Info }, boolean)
	local infos: { [string]: Node.Info } = {}
	local ready = false
	for key, state in PerkTree.states(branch, data.Perks) do
		local perk = Catalog.perk(key)
		if perk then
			local info = infoFor(perk, state, data)
			infos[key] = info
			if state == "available" and not info.Reason then
				ready = true
			end
		end
	end
	return infos, ready
end

-- The first node worth looking at: one that can be bought, else one that is next.
local function firstSelection(infos: { [string]: Node.Info }): string?
	local available: string?
	for _, perk in Catalog.PerkNodes do
		local info = infos[perk.Key]
		if info and info.State == "available" then
			if not info.Reason then
				return perk.Key
			end
			available = available or perk.Key
		end
	end
	if available then
		return available
	end
	for _, perk in Catalog.PerkNodes do
		if infos[perk.Key] then
			return perk.Key
		end
	end
	return nil
end

local function drawTabs(parent: Frame, data: Types.View, current: string): TextButton?
	local strip = Instance.new("ScrollingFrame")
	strip.Name = "Branches"
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.Size = UDim2.new(1, 0, 0, TAB_HEIGHT)
	strip.CanvasSize = UDim2.new()
	strip.AutomaticCanvasSize = Enum.AutomaticSize.X
	strip.ScrollingDirection = Enum.ScrollingDirection.X
	strip.ScrollBarThickness = 0
	strip.Selectable = false
	strip.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = strip
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 3)
	pad.PaddingTop = UDim.new(0, 3)
	pad.Parent = strip

	local active: TextButton? = nil
	for index, branch in Catalog.Branches do
		local infos, ready = branchInfo(branch.Key, data)
		local locked = next(infos) == nil
		local tab = Style.button(strip, branch.Name, function()
			selectedBranch = branch.Key
			selectedKey = nil
			scroll = nil
			tabScroll = strip.CanvasPosition
			Components.redraw()
		end, true, "neutral")
		tab.Name = `Branch:{branch.Key}`
		tab.LayoutOrder = index
		tab.Size = UDim2.fromOffset(TAB_WIDTH, TAB_HEIGHT - 6)
		tab.TextSize = 16
		local color = Look.BranchColors[branch.Key] or Style.Cyan
		tab.BackgroundColor3 = if locked then Style.Track else color
		tab.TextColor3 = if locked then Style.Muted else Style.Text
		if branch.Key == current then
			active = tab
			local outline = tab:FindFirstChild("Outline") :: UIStroke?
			if outline then
				outline.Color = Style.Text
			end
		else
			tab.BackgroundTransparency = if locked then 0 else 0.35
		end
		if locked then
			local lock = Icons.draw(tab, "lock", Style.Muted)
			lock.Position = UDim2.fromOffset(8, 11)
			lock.Size = UDim2.fromOffset(22, 22)
		elseif ready then
			local mark = Style.frame(tab, Style.Signal, 20)
			mark.AnchorPoint = Vector2.new(1, 0)
			mark.Position = UDim2.new(1, -4, 0, 4)
			mark.Size = UDim2.fromOffset(14, 14)
			Style.circle(mark)
			Style.outline(mark, Style.Edge, 2)
		end
	end
	task.defer(function()
		strip.CanvasPosition = tabScroll
	end)
	return active
end

local function lockedMessage(view: Frame, branch: string): ()
	local needed = PerkTree.unlockedBy(branch)
	local icon = Style.frame(view)
	icon.AnchorPoint = Vector2.new(0.5, 1)
	icon.Position = UDim2.new(0.5, 0, 0.5, -10)
	icon.Size = UDim2.fromOffset(72, 72)
	Icons.draw(icon, "lock", Style.Amber, Style.Ink)
	local note = Components.text(
		view,
		if needed then Format(Texts.perkBranchLocked, { name = needed.Name }) else Texts.perkHiddenName,
		20,
		Style.Text,
		true
	)
	note.AnchorPoint = Vector2.new(0.5, 0)
	note.Position = UDim2.fromScale(0.5, 0.5)
	note.Size = UDim2.new(1, -40, 0, 90)
	note.TextXAlignment = Enum.TextXAlignment.Center
	note.TextYAlignment = Enum.TextYAlignment.Top
	Style.textStroke(note, 2)
end

function Perks.render(data: Types.View, _wide: boolean): ()
	disconnect()
	local current = selectedBranch
	if not current then
		-- Open on the first branch that has something to buy.
		for _, branch in Catalog.Branches do
			local _, ready = branchInfo(branch.Key, data)
			if ready then
				current = branch.Key
				break
			end
		end
		current = current or Catalog.Branches[1].Key
		selectedBranch = current
	end
	local branch = current :: string
	local branchName = branch
	for _, entry in Catalog.Branches do
		if entry.Key == branch then
			branchName = entry.Name
		end
	end
	local infos = branchInfo(branch, data)

	local shell = Components.strip(Components.fillHeight())
	local activeTab = drawTabs(shell, data, branch)
	local view = Style.frame(shell, Style.Track, 14)
	view.Position = UDim2.fromOffset(0, TAB_HEIGHT + 4)
	view.Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + 4))
	view.ClipsDescendants = true
	Style.outline(view, Style.Edge, 3)

	local owned = 0
	local total = 0
	for _, perk in Catalog.PerkNodes do
		total += 1
		if (data.Perks[perk.Base :: string] or 0) >= (perk.Step :: number) then
			owned += 1
		end
	end
	local summary =
		Components.text(view, Format(Texts.perkTotal, { owned = owned, total = total }), 14, Style.Muted, true)
	summary.AnchorPoint = Vector2.new(0, 1)
	summary.Position = UDim2.new(0, 10, 1, -6)
	summary.Size = UDim2.fromOffset(260, 18)
	summary.ZIndex = 10
	Style.textStroke(summary, 2)

	if next(infos) == nil then
		lockedMessage(view, branch)
		if activeTab then
			Components.prefer(activeTab)
		end
		return
	end

	local dock = Components.dock(MOBILE_DOCK, true, SIDE_PANEL)

	local host = Instance.new("ScrollingFrame")
	host.Name = "Tree"
	host.BackgroundTransparency = 1
	host.BorderSizePixel = 0
	host.Size = UDim2.fromScale(1, 1)
	host.ScrollingDirection = Enum.ScrollingDirection.XY
	-- Touch uses the built-in scrolling; with a mouse it would swallow the wheel, so the mouse drags by hand.
	host.ScrollingEnabled = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	host.Active = true
	host.ScrollBarThickness = 0
	host.Selectable = false
	host.Parent = view
	local chart = Style.frame(host, nil)
	local scale = Instance.new("UIScale")
	scale.Parent = chart
	-- Transparent button under the nodes, so that pressing empty space starts a drag.
	local surface = Instance.new("TextButton")
	surface.Name = "Surface"
	surface.BackgroundTransparency = 1
	surface.Text = ""
	surface.AutoButtonColor = false
	surface.Selectable = false
	surface.Size = UDim2.fromScale(1, 1)
	surface.ZIndex = 1
	surface.Parent = chart

	local states: { [string]: PerkTree.State } = {}
	for key, info in infos do
		states[key] = info.State
	end
	local cells, columns, rows = PerkTree.layout(branch, states)
	local content = Vector2.new((columns - 1) * COLUMN, (rows - 1) * ROW) + Vector2.one * MARGIN * 2
	chart.Size = UDim2.fromOffset(content.X, content.Y)
	local function pointOf(key: string): Vector2
		local cell = cells[key]
		return Vector2.new(MARGIN + cell.Column * COLUMN, MARGIN + cell.Row * ROW)
	end

	-- Centers a small tree in the window and sizes the canvas of a big one.
	local function fit(): ()
		scale.Scale = zoom
		local size = host.AbsoluteSize
		local scaled = content * zoom
		chart.Position = UDim2.fromOffset(math.max(0, (size.X - scaled.X) / 2), math.max(0, (size.Y - scaled.Y) / 2))
		host.CanvasSize = UDim2.fromOffset(scaled.X, scaled.Y)
	end
	local function setZoom(value: number, anchor: Vector2?): ()
		local previous = zoom
		zoom = math.clamp(value, MIN_ZOOM, MAX_ZOOM)
		local focus = anchor or host.AbsoluteSize / 2
		local before = host.CanvasPosition
		fit()
		host.CanvasPosition = (before + focus) * (zoom / previous) - focus
	end

	local color = Look.BranchColors[branch] or Style.Cyan
	for key in cells do
		local parent = infos[key].Perk.Parent
		if parent and cells[parent] then
			local lit = infos[key].State == "owned"
			Node.link(chart, pointOf(parent), pointOf(key), if lit then color else Style.Edge)
		end
	end

	local selectors: { [string]: (boolean) -> () } = {}
	local buttons: { [string]: TextButton } = {}
	local function pick(key: string): ()
		selectedKey = key
		for other, apply in selectors do
			apply(other == key)
		end
		Card.render(dock, infos[key], branchName)
	end

	local dragging = false
	-- Pixels moved during a press: more than a few means a drag, not a click on a node.
	local travelled = 0
	local lastMouse = Vector2.zero
	local function beginDrag(input: InputObject): ()
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			travelled = 0
			lastMouse = UserInputService:GetMouseLocation()
		end
	end
	table.insert(connections, surface.InputBegan:Connect(beginDrag))
	table.insert(connections, view.InputBegan:Connect(beginDrag))

	for _, perk in Catalog.PerkNodes do
		local info = infos[perk.Key]
		if not info or not cells[perk.Key] then
			continue
		end
		local button, apply = Node.draw(chart, info, pointOf(perk.Key))
		selectors[perk.Key] = apply
		buttons[perk.Key] = button
		table.insert(connections, button.InputBegan:Connect(beginDrag))
		button.Activated:Connect(function()
			if travelled > 6 then
				return
			end
			Sfx.play("click")
			pick(perk.Key)
		end)
	end

	local chosen = if selectedKey and infos[selectedKey] then selectedKey else firstSelection(infos)
	if chosen then
		pick(chosen)
		Components.prefer(buttons[chosen])
	end

	fit()
	task.defer(function()
		if not host.Parent then
			return
		end
		fit()
		if scroll then
			host.CanvasPosition = scroll
		elseif chosen then
			host.CanvasPosition = pointOf(chosen) * zoom - host.AbsoluteSize / 2
		end
		table.insert(
			connections,
			host:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
				scroll = host.CanvasPosition
			end)
		)
	end)
	table.insert(connections, host:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))

	local toolbar = Style.frame(view, nil)
	toolbar.AnchorPoint = Vector2.new(1, 0)
	toolbar.Position = UDim2.new(1, -8, 0, 8)
	toolbar.Size = UDim2.fromOffset(Style.TouchSize, Style.TouchSize * 2 + 8)
	toolbar.ZIndex = 10
	for index, tool in { { Caption = "+", Factor = 1.2 }, { Caption = "-", Factor = 1 / 1.2 } } do
		local control = Style.button(toolbar, tool.Caption, function()
			setZoom(zoom * tool.Factor)
		end, true, "neutral")
		control.Position = UDim2.fromOffset(0, (index - 1) * (Style.TouchSize + 8))
		control.Size = UDim2.fromOffset(Style.TouchSize, Style.TouchSize)
		control.TextSize = 24
		control.ZIndex = 10
	end

	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
				-- Activated fires right after release, so the distance is cleared a little later.
				task.delay(0.1, function()
					travelled = 0
				end)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				-- Cursor position, not input.Delta: Delta can be zero here.
				local mouse = UserInputService:GetMouseLocation()
				local delta = mouse - lastMouse
				lastMouse = mouse
				travelled += delta.Magnitude
				host.CanvasPosition -= delta
			end
		end)
	)
	table.insert(
		connections,
		host.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				local anchor = Vector2.new(input.Position.X, input.Position.Y) - host.AbsolutePosition
				setZoom(zoom * (if input.Position.Z > 0 then 1.1 else 1 / 1.1), anchor)
			end
		end)
	)
	local pinchStart = zoom
	table.insert(
		connections,
		UserInputService.TouchPinch:Connect(function(touches, scaleFactor, _, state)
			local first = touches[1]
			if not first then
				return
			end
			local at, size = host.AbsolutePosition, host.AbsoluteSize
			local point = Vector2.new(first.X, first.Y) - GuiService:GetGuiInset()
			if point.X < at.X or point.Y < at.Y or point.X > at.X + size.X or point.Y > at.Y + size.Y then
				return
			end
			if state == Enum.UserInputState.Begin then
				pinchStart = zoom
			end
			setZoom(pinchStart * scaleFactor)
		end)
	)
end

return Perks
