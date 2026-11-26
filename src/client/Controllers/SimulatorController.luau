--!strict
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Data = require(script.Parent.DataController)
local Components = require(script.Parent.Parent.UI.Components)
local Guide = require(script.Parent.Parent.UI.Guide)
local Hud = require(script.Parent.Parent.UI.Hud)
local Window = require(script.Parent.Parent.UI.Window)
local Collections = require(script.Parent.Parent.UI.Screens.Collections)
local Daily = require(script.Parent.Parent.UI.Screens.Daily)
local Dial = require(script.Parent.Parent.UI.Screens.Dial)
local Inventory = require(script.Parent.Parent.UI.Screens.Inventory)
local Loot = require(script.Parent.Parent.UI.Screens.Loot)
local Perks = require(script.Parent.Parent.UI.Screens.Perks)
local Showcase = require(script.Parent.Parent.UI.Screens.Showcase)
local Settings = require(script.Parent.Parent.UI.Screens.Settings)
local Terminal = require(script.Parent.Parent.UI.Screens.Terminal)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local Style = require(script.Parent.Parent.UI.Style)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.UI)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Menus = require(script.Parent.Parent.UI.Menus)
local TITLES = Menus.TITLES
local CAPTIONS = Menus.CAPTIONS
local ACCENTS = Menus.ACCENTS
local ICONS = Menus.ICONS

local SimulatorController = {}

local DIAL_CLOSE_DELAY = 0.7
local STOP_LOCK = 1.5

type DialRound = Dial.Round
local state: Types.View?
local menu: string?
local round: DialRound?
local signature = ""
local stopLocked = false

local action: RemoteEvent
local perksWide = false
local cursorFree: TextButton
local window: Window.Window
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
	window.Panel.Visible, window.Backdrop.Visible = key ~= nil, key ~= nil
	if not key then
		return
	end
	perksWide = key == "perks" and widePerks()
	-- Дерево навыков — на весь экран, чтобы карта помещалась целиком; остальные меню — компактное окно.
	window.Bounds.MaxSize = if key == "perks" then Vector2.new(10000, 10000) else Window.DefaultSize
	local content = window.Content
	local canvas = content.CanvasPosition
	local oldSelection = GuiService.SelectedObject
	local selectedName = oldSelection and oldSelection:IsDescendantOf(content) and oldSelection.Name
	window.SetCompact(Components.compact())
	Components.begin()
	window.SetHeader(
		TITLES[key] or Format(Texts.titleShowcase, { slot = key }),
		CAPTIONS[key] or Texts.captionShowcase,
		ACCENTS[key] or Style.Cyan,
		ICONS[key] or "grid"
	)

	if not data then
		Components.paragraph(Texts.syncing)
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
	if gamepadActive() and oldSelection ~= window.Close then
		local nextFocus = Components.preferred() or window.Close
		if selectedName then
			for _, descendant in window.Panel:GetDescendants() do
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
			local dock = window.Dock
			local docked = dock.Visible and dock.AnchorPoint.Y == 1
			-- Высота самого списка (AbsoluteCanvasSize не бывает меньше видимой области прокрутки).
			local list = content:FindFirstChildOfClass("UIListLayout")
			-- Замер может попасть на анимацию открытия (UIScale < 1): переводим в размеры без масштаба.
			local scale = math.max(window.Scale.Scale, 0.5)
			local used = (if list then list.AbsoluteContentSize.Y else content.AbsoluteCanvasSize.Y) / scale + 16
			local dockHeight = dock.AbsoluteSize.Y / scale
			local needed = used + Components.inset() + 8 + (if docked then dockHeight + 10 else 0)
			if dock.Visible and not docked then
				-- Боковая панель (телефон) не должна вылезать за низ окна.
				needed = math.max(needed, dockHeight + 104)
			end
			window.Bounds.MaxSize = Vector2.new(window.Bounds.MaxSize.X, math.clamp(needed, 220, Window.DefaultSize.Y))
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
		window.Scale.Scale = 0.85
		Style.tween(window.Scale, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
		window.Backdrop.BackgroundTransparency = 1
		Style.tween(window.Backdrop, { BackgroundTransparency = 0.45 }, 0.2)
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
	}, gui)

	Guide.build(hudLayer, function()
		send("skipTutorial")
		Guide.hide()
	end, Hud.pulse)

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
	window = Window.build(gui, function()
		selectMenu(nil)
	end)
	Components.setup(window.Content, window.Dock, send, function()
		refresh(true)
	end)
	local camera = Workspace.CurrentCamera
	if camera then
		-- Карта перков растянута на экран: при смене размера окна перерисовываем её (с небольшой задержкой,
		-- пока размер окна меняется) — высота карты и колонка описания считаются от размера экрана.
		local resizeSerial = 0
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if menu ~= "perks" then
				return
			end
			resizeSerial += 1
			local serial = resizeSerial
			task.delay(0.25, function()
				if serial == resizeSerial and menu == "perks" then
					Perks.reset()
					refresh()
				end
			end)
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
		Hud.notice(Texts.dialTimeout, true)
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
			Hud.notice(value, (...) == "warning")
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
				Hud.notice(Format(Texts.dialPinSet, { pin = stage - 1 }))
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
				Hud.notice(Texts.dialOpened)
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
		end
	end)
	-- O приходит с gameProcessed = true (её занимает штатное управление камерой), поэтому через InputBegan она
	-- не срабатывала — привязываем действие с высоким приоритетом.
	ContextActionService:BindActionAtPriority("CorpaSettings", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			toggle("settings")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.O)
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
