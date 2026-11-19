--!strict
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Data = require(script.Parent.DataController)
local Components = require(script.Components)
local Hud = require(script.Hud)
local Collections = require(script.Screens.Collections)
local Daily = require(script.Screens.Daily)
local Dial = require(script.Screens.Dial)
local Inventory = require(script.Screens.Inventory)
local Loot = require(script.Screens.Loot)
local Perks = require(script.Screens.Perks)
local Showcase = require(script.Screens.Showcase)
local Terminal = require(script.Screens.Terminal)
local Style = require(script.Style)

local TITLES: { [string]: string } = {
	terminal = "Терминал заказов",
	inventory = "Склад",
	collections = "Коллекции",
	loot = "Управление добычей",
	perks = "Древо перков",
	daily = "Ежедневная награда",
	dial = "Ручка сейфа",
}
local CAPTIONS: { [string]: string } = {
	terminal = "Случайные контейнеры и очередь доставки",
	inventory = "Выберите предмет, чтобы увидеть цену и продать",
	collections = "Заполните все слоты, чтобы получить бонус к продаже",
	loot = "Операции с открытым контейнером",
	perks = "Улучшайте сектор за монеты",
	daily = "Награда за время в лаборатории",
	dial = "Остановите указатель в выделенном секторе",
}
local ACCENTS: { [string]: Color3 } = {
	terminal = Style.Signal,
	inventory = Style.Cyan,
	collections = Style.Violet,
	loot = Style.Amber,
	perks = Style.Amber,
	daily = Style.Amber,
	dial = Style.Cyan,
}

type DialRound = Dial.Round

local SimulatorController = {}
local state: Types.View?
local menu: string?
local round: DialRound?
local signature = ""

local action: RemoteEvent
local title: TextLabel
local subtitle: TextLabel
local accent: Frame
local panel: Frame
local panelScale: UIScale
local backdrop: TextButton
local close: TextButton
local selectMenu: (string?) -> ()

local function sortedKeys(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- Короткий отпечаток данных: экран перерисовывается, только когда он изменился.
local function fingerprint(data: Types.View): string
	local parts: { string } = {
		tostring(data.Coins),
		tostring(data.Orders),
		tostring(data.OrderStage),
		tostring(data.OrderKind),
		tostring(data.OrderVariant),
		tostring(data.OrderProgress),
		tostring(data.OrderDeadline),
		tostring(data.RemainingLoot),
		tostring(data.DailyClaim),
		tostring(data.DailyReadyAt),
	}
	for _, item in data.Inventory do
		table.insert(parts, `{item.Id}:{item.Quality}`)
	end
	for _, group in { data.Collections, data.Displays } do
		for _, key in sortedKeys(group) do
			table.insert(parts, `{key}={group[key].Id}`)
		end
	end
	for _, key in sortedKeys(data.Perks) do
		table.insert(parts, `{key}#{data.Perks[key]}`)
	end
	return table.concat(parts, "|")
end

local function send(name: string, argument: string?, extra: string?): ()
	action:FireServer(name, argument, extra)
end

local function gamepadActive(): boolean
	return UserInputService:GetLastInputType().Name:sub(1, 7) == "Gamepad"
end

local function updateClocks(): ()
	local data = state
	if not data then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local _, _, canClaim = Components.dailyState(data, now)
	Hud.setReward(canClaim)
	if menu == "terminal" then
		Terminal.tick(data, now)
	elseif menu == "daily" then
		Daily.tick(data, now)
	end
end

local function refresh(preserveScroll: boolean?): ()
	local key, data = menu, state
	panel.Visible, backdrop.Visible = key ~= nil, key ~= nil
	if not key then
		return
	end
	local content = panel:FindFirstChild("Содержимое") :: ScrollingFrame
	local canvas = content.CanvasPosition
	local oldSelection = GuiService.SelectedObject
	local selectedName = oldSelection and oldSelection:IsDescendantOf(content) and oldSelection.Name
	Components.begin()
	title.Text = TITLES[key] or `Витрина {key}`
	subtitle.Text = CAPTIONS[key] or "Экспозиция вашего сектора"
	accent.BackgroundColor3 = ACCENTS[key] or Style.Cyan

	if not data then
		Components.paragraph("Синхронизация данных сектора…")
	elseif key == "terminal" then
		Terminal.render(data)
	elseif key == "inventory" then
		Inventory.render(data)
	elseif key == "collections" then
		Collections.render(data)
	elseif key == "perks" then
		Perks.render(data)
	elseif key == "loot" then
		Loot.render(data)
	elseif key == "daily" then
		Daily.render()
	elseif key == "dial" then
		local current = round
		if current then
			Dial.render(current, function()
				send("open", current.Id)
				selectMenu(nil)
			end)
		end
	else
		Showcase.render(data, key)
	end

	updateClocks()
	if preserveScroll then
		task.defer(function()
			if menu == key then
				content.CanvasPosition = canvas
			end
		end)
	else
		content.CanvasPosition = Vector2.zero
	end
	if gamepadActive() and oldSelection ~= close then
		local nextFocus = Components.preferred() or close
		if selectedName then
			for _, descendant in panel:GetDescendants() do
				if descendant:IsA("GuiButton") and descendant.Name == selectedName and descendant.Selectable then
					nextFocus = descendant
					break
				end
			end
		end
		GuiService.SelectedObject = nextFocus
	end
end

selectMenu = function(key: string?): ()
	local previous = menu
	menu = key
	if key ~= "dial" then
		round = nil
	end
	if key ~= previous then
		Inventory.reset()
		Collections.reset()
	end
	signature = if state then fingerprint(state) else ""
	refresh(previous == key)
	if key and not previous then
		panelScale.Scale = 0.9
		Style.tween(panelScale, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
		backdrop.BackgroundTransparency = 1
		Style.tween(backdrop, { BackgroundTransparency = 0.35 }, 0.2)
	end
	if not key and previous and gamepadActive() then
		GuiService.SelectedObject = nil
	end
end

local function build(): ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CORPA"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Hud.build(gui, {
		Perks = function()
			selectMenu("perks")
		end,
		Reward = function()
			selectMenu("daily")
		end,
	})

	backdrop = Instance.new("TextButton")
	backdrop.Name = "Затемнение"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Style.Ink
	backdrop.BackgroundTransparency = 0.35
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Selectable = false
	backdrop.Visible = false
	backdrop.ZIndex = 2
	backdrop.Parent = gui
	backdrop.Activated:Connect(function()
		selectMenu(nil)
	end)

	panel = Style.frame(gui, Style.Panel, 18)
	panel.Name = "Меню сектора"
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
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(580, 640)
	bounds.Parent = panel
	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	local banner = Style.frame(panel, Style.Card, 16)
	banner.Position = UDim2.fromOffset(8, 8)
	banner.Size = UDim2.new(1, -16, 0, 80)
	accent = Style.frame(banner, Style.Signal, 3)
	Components.place(accent, 14, 14, UDim.new(0, 6), 52)
	title = Components.text(banner, "", 25, Style.Text, true)
	Components.place(title, 30, 8, UDim.new(1, -92), 36)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	subtitle = Components.text(banner, "", 12, Style.Muted)
	Components.place(subtitle, 30, 44, UDim.new(1, -92), 32)
	subtitle.TextYAlignment = Enum.TextYAlignment.Top
	close = Style.button(banner, "×", function()
		selectMenu(nil)
	end, true, "danger")
	close.TextSize = 26
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -12, 0.5, 0)
	close.Size = UDim2.fromOffset(48, 48)

	local content = Instance.new("ScrollingFrame")
	content.Name = "Содержимое"
	content.Position = UDim2.fromOffset(16, 98)
	content.Size = UDim2.new(1, -26, 1, -108)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 6
	content.ScrollBarImageColor3 = Style.Amber
	content.CanvasSize = UDim2.new()
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.Selectable = false
	content.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content
	local margin = Instance.new("UIPadding")
	margin.PaddingLeft = UDim.new(0, 2)
	margin.PaddingTop = UDim.new(0, 2)
	margin.PaddingBottom = UDim.new(0, 6)
	margin.PaddingRight = UDim.new(0, 2)
	margin.Parent = content

	local dock = Style.frame(panel, Style.Panel, 14)
	dock.Name = "Нижняя панель"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -12)
	dock.Visible = false
	dock.ZIndex = 4
	Components.setup(content, dock, send, function()
		refresh(true)
	end)
end

local function animate(): ()
	local widgets, current = Components.Live.Dial, round
	if menu ~= "dial" or not widgets or not current then
		return
	end
	local elapsed = math.max(0, Workspace:GetServerTimeNow() - current.Start)
	if elapsed > Dial.TimeLimit then
		selectMenu(nil)
		Hud.notice("Время вышло. Поверните ручку снова.")
		return
	end
	widgets.Needle.Position = UDim2.new((elapsed % current.Period) / current.Period, 0, 0, -5)
	widgets.Time.Text = `Осталось {math.ceil(Dial.TimeLimit - elapsed)} с`
end

function SimulatorController:Start(): ()
	action = Remotes.event(Remotes.Events.Action)
	build()
	Remotes.event(Remotes.Events.Interface).OnClientEvent:Connect(function(mode, value, ...)
		if mode == "menu" then
			selectMenu(value)
		elseif mode == "notice" then
			Hud.notice(value)
		elseif mode == "dial" then
			local start, target, period, tolerance = ...
			round = { Id = value, Start = start, Target = target, Period = period, Tolerance = tolerance }
			selectMenu("dial")
		end
	end)
	Data:OnChanged(function(data)
		state = data
		local _, _, canClaim = Components.dailyState(data, Workspace:GetServerTimeNow())
		Hud.update(data, canClaim)
		if menu and menu ~= "dial" then
			local current = fingerprint(data)
			if current ~= signature then
				signature = current
				refresh(true)
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, consumed)
		if not consumed and input.KeyCode == Enum.KeyCode.ButtonB and menu then
			selectMenu(nil)
		end
	end)
	RunService.RenderStepped:Connect(animate)
	while true do
		task.wait(0.25)
		updateClocks()
	end
end

return SimulatorController
