--!strict
local ContextActionService = game:GetService("ContextActionService")
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
local Guide = require(script.Guide)
local Hud = require(script.Hud)
local Icons = require(script.Icons)
local Collections = require(script.Screens.Collections)
local Daily = require(script.Screens.Daily)
local Dial = require(script.Screens.Dial)
local Inventory = require(script.Screens.Inventory)
local Loot = require(script.Screens.Loot)
local Perks = require(script.Screens.Perks)
local Showcase = require(script.Screens.Showcase)
local Settings = require(script.Screens.Settings)
local Terminal = require(script.Screens.Terminal)
local Sfx = require(script.Sfx)
local Style = require(script.Style)

local TITLES: { [string]: string } = {
	terminal = "Терминал заказов",
	inventory = "Склад",
	collections = "Коллекции",
	loot = "Управление добычей",
	perks = "Древо перков",
	daily = "Ежедневная награда",
	dial = "Взлом сейфа",
	settings = "Настройки",
}
local CAPTIONS: { [string]: string } = {
	terminal = "Случайные контейнеры и очередь доставки",
	inventory = "Выберите предмет, чтобы увидеть цену и продать",
	collections = "Заполните все слоты, чтобы получить бонус к продаже",
	loot = "Операции с открытым контейнером",
	perks = "Выберите узел, чтобы посмотреть улучшение",
	daily = "Награда за время в лаборатории",
	dial = "Три штифта: каждый следующий быстрее",
	settings = "Громкость и эффекты выпадения",
}
local ACCENTS: { [string]: Color3 } = {
	terminal = Style.Signal,
	inventory = Style.Cyan,
	collections = Style.Violet,
	loot = Style.Amber,
	perks = Style.Amber,
	daily = Style.Amber,
	dial = Style.Cyan,
	settings = Style.Cyan,
}
local ICONS: { [string]: Icons.IconName } = {
	terminal = "screen",
	inventory = "box",
	collections = "grid",
	loot = "box",
	perks = "star",
	daily = "gift",
	dial = "lock",
	settings = "gear",
}
local DIAL_CLOSE_DELAY = 0.7
local STOP_LOCK = 1.5

type DialRound = Dial.Round

local SimulatorController = {}
local state: Types.View?
local menu: string?
local round: DialRound?
local signature = ""
local stopLocked = false

local action: RemoteEvent
local title: TextLabel
local subtitle: TextLabel
local badge: Frame
local badgeStroke: UIStroke
local panel: Frame
local panelScale: UIScale
local panelBounds: UISizeConstraint
local perksWide = false
local backdrop: TextButton
local cursorFree: TextButton
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
		tostring(data.Opened),
		tostring(data.OrderPrice),
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

local function widePerks(): boolean
	local camera = Workspace.CurrentCamera
	return camera ~= nil and camera.ViewportSize.X >= 900
end

-- Камера почти в голове персонажа — режим первого лица (приближение колесом или LockFirstPerson).
local function firstPerson(): boolean
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not camera or not head then
		return false
	end
	return (camera.CFrame.Position - head.Position).Magnitude < 1.5
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

-- Останавливает указатель; повторные нажатия блокируются до ответа сервера.
local function stopDial(current: DialRound): ()
	if stopLocked then
		return
	end
	stopLocked = true
	send("open", current.Id)
	task.delay(STOP_LOCK, function()
		stopLocked = false
	end)
end

-- Пробел останавливает указатель и не вызывает прыжок, пока открыт взлом сейфа.
local function bindStop(active: boolean): ()
	if active then
		ContextActionService:BindActionAtPriority("CorpaDialStop", function(_, inputState)
			if inputState == Enum.UserInputState.Begin and round then
				stopDial(round)
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space)
	else
		ContextActionService:UnbindAction("CorpaDialStop")
	end
end

local function refresh(preserveScroll: boolean?): ()
	local key, data = menu, state
	panel.Visible, backdrop.Visible = key ~= nil, key ~= nil
	if not key then
		return
	end
	perksWide = key == "perks" and widePerks()
	panelBounds.MaxSize = if perksWide then Vector2.new(1050, 700) else Vector2.new(600, 660)
	local content = panel:FindFirstChild("Содержимое") :: ScrollingFrame
	local canvas = content.CanvasPosition
	local oldSelection = GuiService.SelectedObject
	local selectedName = oldSelection and oldSelection:IsDescendantOf(content) and oldSelection.Name
	Components.begin()
	title.Text = TITLES[key] or `Витрина {key}`
	subtitle.Text = CAPTIONS[key] or "Экспозиция вашего сектора"
	badgeStroke.Color = ACCENTS[key] or Style.Cyan
	for _, child in badge:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	Icons.draw(badge, ICONS[key] or "grid", ACCENTS[key] or Style.Cyan, Style.Text).Size = UDim2.fromScale(0.62, 0.62)

	if not data then
		Components.paragraph("Синхронизация данных сектора…")
	elseif key == "terminal" then
		Terminal.render(data)
	elseif key == "inventory" then
		Inventory.render(data)
	elseif key == "collections" then
		Collections.render(data)
	elseif key == "perks" then
		Perks.render(data, perksWide)
	elseif key == "loot" then
		Loot.render(data)
	elseif key == "daily" then
		Daily.render()
	elseif key == "settings" then
		Settings.render(data)
	elseif key == "dial" then
		local current = round
		if current then
			Dial.render(current, function()
				stopDial(current)
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
	-- Окно по высоте содержимого: короткие экраны (награда, сейф) не оставляют пустоты под собой.
	-- Карта перков всегда занимает всё доступное место.
	if key ~= "perks" then
		task.defer(function()
			if menu ~= key then
				return
			end
			local dock = panel:FindFirstChild("Нижняя панель") :: Frame
			local docked = dock.Visible and dock.AnchorPoint.Y == 1
			-- Высота самого списка (AbsoluteCanvasSize не бывает меньше видимой области прокрутки).
			local list = content:FindFirstChildOfClass("UIListLayout")
			-- Замер может попасть на анимацию открытия (UIScale < 1): переводим в размеры без масштаба.
			local scale = math.max(panelScale.Scale, 0.5)
			local used = (if list then list.AbsoluteContentSize.Y else content.AbsoluteCanvasSize.Y) / scale + 16
			local dockHeight = dock.AbsoluteSize.Y / scale
			local needed = used + 116 + (if docked then dockHeight + 10 else 0)
			if dock.Visible and not docked then
				-- Боковая панель (телефон) не должна вылезать за низ окна.
				needed = math.max(needed, dockHeight + 104)
			end
			panelBounds.MaxSize = Vector2.new(panelBounds.MaxSize.X, math.clamp(needed, 220, 660))
		end)
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
		Perks.reset()
		Settings.reset()
	end
	signature = ""
	if state then
		signature = if key == "settings" then Settings.effectsSignature(state) else fingerprint(state)
	end
	bindStop(key == "dial")
	refresh(previous == key)
	if key and not previous then
		Sfx.play("menuOpen")
		panelScale.Scale = 0.9
		Style.tween(panelScale, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
		backdrop.BackgroundTransparency = 1
		Style.tween(backdrop, { BackgroundTransparency = 0.35 }, 0.2)
	end
	if not key and previous then
		Sfx.play("menuClose")
	end
	if not key and previous and gamepadActive() then
		GuiService.SelectedObject = nil
	end
end

-- Открывает меню по горячей клавише; повторное нажатие закрывает его.
local function toggle(key: string): ()
	if menu == key then
		selectMenu(nil)
	elseif menu == nil then
		selectMenu(key)
	end
end

local function build(): ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CORPA"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Слой HUD с общим масштабом: на низком экране (ландшафтный телефон) плашки и обучение мельче,
	-- чтобы не перекрывать друг друга и центр экрана. Размер слоя 1/scale, поэтому после UIScale он
	-- снова ровно во весь экран.
	local hudLayer = Instance.new("Frame")
	hudLayer.Name = "HUD"
	hudLayer.BackgroundTransparency = 1
	hudLayer.Parent = gui
	local hudScale = Instance.new("UIScale")
	hudScale.Parent = hudLayer
	local function fitHud(): ()
		local camera = Workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 800
		local scale = math.clamp(height / 760, 0.68, 1)
		hudScale.Scale = scale
		hudLayer.Size = UDim2.fromScale(1 / scale, 1 / scale)
		Hud.setScale(scale)
	end
	fitHud()
	local hudCamera = Workspace.CurrentCamera
	if hudCamera then
		hudCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitHud)
	end

	Hud.build(hudLayer, {
		Perks = function()
			toggle("perks")
		end,
		Reward = function()
			toggle("daily")
		end,
		Settings = function()
			toggle("settings")
		end,
	})

	Guide.build(hudLayer, function()
		send("skipTutorial")
		Guide.hide()
	end, Hud.pulse)

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
	-- Modal освобождает курсор, пока меню открыто: иначе в режиме первого лица мышь заперта в центре экрана.
	backdrop.Modal = true
	backdrop.ZIndex = 2
	backdrop.Parent = gui

	-- Невидимая модальная кнопка: пока зажат Alt, курсор в первом лице свободен и кнопки HUD нажимаются.
	cursorFree = Instance.new("TextButton")
	cursorFree.Name = "Свободный курсор"
	cursorFree.BackgroundTransparency = 1
	cursorFree.Text = ""
	cursorFree.Size = UDim2.fromOffset(1, 1)
	cursorFree.Selectable = false
	cursorFree.Modal = true
	cursorFree.Visible = false
	cursorFree.Parent = gui
	backdrop.Activated:Connect(function()
		selectMenu(nil)
	end)

	panel = Style.frame(gui, Style.Panel, 20)
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
	Style.soft(panel, 0.16)
	panelBounds = Instance.new("UISizeConstraint")
	panelBounds.MaxSize = Vector2.new(600, 660)
	panelBounds.Parent = panel
	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	Style.brackets(panel, Style.Cyan, 16, 2)

	local banner = Style.frame(panel, Style.Card, 16)
	banner.Position = UDim2.fromOffset(8, 8)
	banner.Size = UDim2.new(1, -16, 0, 84)
	Style.outline(banner, Style.Edge, 2)
	Style.soft(banner, 0.1)
	Style.accent(banner, Style.Cyan)
	badge = Style.frame(banner, Style.Track, 14)
	Components.place(badge, 12, 12, UDim.new(0, 60), 60)
	badgeStroke = Style.outline(badge, Style.Signal, 3)
	title = Components.text(banner, "", 26, Style.Text, true)
	Components.place(title, 84, 8, UDim.new(1, -148), 38)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	subtitle = Components.text(banner, "", 13, Style.Muted)
	Components.place(subtitle, 84, 46, UDim.new(1, -148), 34)
	subtitle.TextYAlignment = Enum.TextYAlignment.Top
	close = Style.button(banner, "×", function()
		selectMenu(nil)
	end, true, "danger")
	close.TextSize = 28
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -12, 0.5, 0)
	close.Size = UDim2.fromOffset(52, 52)

	local content = Instance.new("ScrollingFrame")
	content.Name = "Содержимое"
	content.Position = UDim2.fromOffset(16, 102)
	content.Size = UDim2.new(1, -26, 1, -112)
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
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if menu == "perks" and perksWide ~= widePerks() then
				refresh()
			end
		end)
	end
end

local function animate(): ()
	local current = round
	if menu ~= "dial" or not current then
		return
	end
	local elapsed = math.max(0, Workspace:GetServerTimeNow() - current.Start)
	if elapsed > Dial.TimeLimit then
		selectMenu(nil)
		Hud.notice("Время вышло. Поверните ручку снова.")
		return
	end
	Dial.update(current, elapsed)
end

function SimulatorController:Start(): ()
	action = Remotes.event(Remotes.Events.Action)
	Sfx.preload()
	build()
	Remotes.event(Remotes.Events.Interface).OnClientEvent:Connect(function(mode, value, ...)
		if mode == "menu" then
			selectMenu(value)
		elseif mode == "notice" then
			Hud.notice(value)
		elseif mode == "dial" then
			local start, target, period, tolerance, stage, total = ...
			stopLocked = false
			round = {
				Id = value,
				Start = start,
				Target = target,
				Period = period,
				Tolerance = tolerance,
				Stage = stage or 1,
				Total = total or 1,
			}
			if (stage or 1) > 1 then
				Sfx.play("dialOk")
				Hud.notice(`Штифт {stage - 1} на месте!`)
			end
			selectMenu("dial")
		elseif mode == "sfx" then
			local target, pitch = ...
			Sfx.playAt(value, target, pitch)
		elseif mode == "guide" then
			if value then
				local target, pulse = ...
				Guide.show(value, target, pulse)
			else
				Guide.hide()
			end
		elseif mode == "dialEnd" then
			stopLocked = false
			Dial.flash(value == true)
			if value == true then
				Sfx.play("claim")
				Hud.notice("Сейф вскрыт!")
			end
			task.delay(DIAL_CLOSE_DELAY, function()
				if menu == "dial" then
					selectMenu(nil)
				end
			end)
		end
	end)
	Data:OnChanged(function(data)
		state = data
		local _, _, canClaim = Components.dailyState(data, Workspace:GetServerTimeNow())
		Hud.update(data, canClaim)
		if not Settings.isDragging() then
			Sfx.setVolumes(data.VolumeUi, data.VolumeWorld)
		end
		if menu == "settings" and not Settings.isDragging() then
			local current = Settings.effectsSignature(data)
			if current ~= signature then
				signature = current
				refresh(true)
			end
		elseif menu and menu ~= "dial" and menu ~= "settings" then
			local current = fingerprint(data)
			if current ~= signature then
				signature = current
				refresh(true)
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, consumed)
		if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
			cursorFree.Visible = true
			return
		end
		if consumed then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonB and menu then
			selectMenu(nil)
		elseif input.KeyCode == Enum.KeyCode.P then
			toggle("perks")
		elseif input.KeyCode == Enum.KeyCode.G then
			toggle("daily")
		elseif input.KeyCode == Enum.KeyCode.O then
			toggle("settings")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
			cursorFree.Visible = false
		end
	end)
	RunService.RenderStepped:Connect(animate)
	while true do
		task.wait(0.25)
		updateClocks()
		Hud.setFirstPerson(firstPerson())
	end
end

return SimulatorController
