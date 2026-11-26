--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Containers = require(script.Parent.Parent.Visuals.Containers)
local DropEffects = require(script.Parent.Parent.Visuals.DropEffects)
local Sector = require(script.Parent.Sector)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.World)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Boards = require(script.Parent.Boards)
local Delivery = require(script.Parent.Delivery)
local Items = require(script.Parent.Items)
local Props = require(script.Parent.Props)
local ICE = Props.ICE
local AMBER = Props.AMBER
local INK = Props.INK
local PAPER = Props.PAPER
local MUTED = Props.MUTED
type Use = Props.Use
local part = Props.part
local surfaceLabel = Props.surfaceLabel
local prompt = Props.prompt
local requirePart = Props.requirePart
local authoredParts = Props.authoredParts
local boards = Boards.boards
local rankingBoard = Boards.rankingBoard
local makeItem = Items.makeItem
local addGlow = Items.addGlow
local GATE_MOVE_TIME = Delivery.GATE_MOVE_TIME
local DISPOSAL_TRAVEL_TIME = Delivery.DISPOSAL_TRAVEL_TIME
local CONTAINER_PIVOT_HEIGHT = Delivery.CONTAINER_PIVOT_HEIGHT
type Plot = Delivery.Plot
local moveGate = Delivery.moveGate
local shaftLight = Delivery.shaftLight
local animate = Delivery.animate
local setBackrooms = Delivery.setBackrooms
local deliverThroughPipe = Delivery.deliverThroughPipe

export type RankingEntry = Boards.RankingEntry

local World = {}

World.Board = Boards.Board

local function downlight(fixture: Part, color: Color3, brightness: number, range: number, angle: number): ()
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Angle = angle
	light.Parent = fixture
end

-- Подписи зон сектора и свет. Таблички необязательны: их надписи сборщик сцены может нарисовать сам.
local function dressSector(model: Model): ()
	for name, text in
		{
			["Панель экспозиции"] = Texts.panelDisplays,
			["Панель заказов"] = Texts.panelOrders,
			["Панель склада"] = Texts.panelStorage,
		}
	do
		local panel = model:FindFirstChild(name)
		if panel and panel:IsA("Part") then
			surfaceLabel(panel, text, 34)
		end
	end

	for _, fixture in authoredParts(model, "Светильник рабочей зоны") do
		downlight(fixture, Color3.fromRGB(229, 239, 233), 0.48, 22, 115)
	end
	for _, fixture in authoredParts(model, "Рассеиватель витрин") do
		downlight(fixture, Color3.fromRGB(255, 229, 187), 0.65, 10, 85)
	end
	for _, fixture in authoredParts(model, "Рассеиватель сервисного поста") do
		downlight(fixture, Color3.fromRGB(218, 239, 234), 0.5, 11, 95)
	end
end

local function findGates(model: Model): (CFrame, { Part }, { Part }, { [Part]: CFrame })
	local shutters = authoredParts(model, "Створка шлюза")
	assert(#shutters == 4, `[World] {model.Name} needs four shutters`)
	table.sort(shutters, function(first, second)
		return first.Position.Y < second.Position.Y
	end)
	local lower = { shutters[1], shutters[2] }
	local upper = { shutters[3], shutters[4] }
	local center = (lower[1].Position + lower[2].Position) / 2
	local support = requirePart(model, "Опора над шахтой")
	local floorY = support.Position.Y + support.Size.Y / 2
	local pad = CFrame.new(center.X, floorY + 0.025 - CONTAINER_PIVOT_HEIGHT, center.Z) * lower[1].CFrame.Rotation
	local gateFrames = {}
	for _, halves in { lower, upper } do
		table.sort(halves, function(first, second)
			return pad:PointToObjectSpace(first.Position).X < pad:PointToObjectSpace(second.Position).X
		end)
		for _, shutter in halves do
			gateFrames[shutter] = shutter.CFrame
		end
	end
	return pad, upper, lower, gateFrames
end

function World.Build(useForPlot: (number, Player, string, string?) -> ()): { Plot }
	local root = Workspace:WaitForChild("CORPA — испытательная лаборатория", 10)
	assert(root, "[World] Lab model not found in the place")
	for _, name in { "Светильник перехода", "Светильник подхода" } do
		local hall = name == "Светильник подхода"
		for _, fixture in authoredParts(root, name) do
			downlight(fixture, Color3.fromRGB(224, 236, 232), if hall then 0.7 else 0.55, if hall then 32 else 16, 120)
		end
	end
	local leaderboardParts = authoredParts(root, "Терминал рейтинга")
	assert(#leaderboardParts == 2, "[World] Two ranking terminals are required")
	table.sort(leaderboardParts, function(first, second)
		return first.Position.X < second.Position.X
	end)
	boards.localLobby =
		rankingBoard(leaderboardParts[1], Texts.lobbyRanking, Texts.lobbyRankingNote, Config.MaxPlayers, ICE, true)
	boards.global = rankingBoard(leaderboardParts[2], Texts.globalRanking, Texts.globalRankingNote, 10, AMBER)

	local plots = {}
	for index = 1, Config.MaxPlayers do
		local model = root:FindFirstChild(`Сектор 0{index}`)
		assert(model and model:IsA("Model"), `[World] Sector 0{index} not found`)
		dressSector(model)
		local function use(player: Player, action: string, key: string?)
			useForPlot(index, player, action, key)
		end
		local sign = Format(Texts.sectorName, { index = index })
		local ownerBoard = requirePart(model, "Табло сектора")
		local owner = {
			surfaceLabel(ownerBoard, Format(Texts.sectorFree, { sector = sign }), 42),
			surfaceLabel(ownerBoard, Format(Texts.sectorFree, { sector = sign }), 42, Enum.NormalId.Back),
			-- Указатель перед входом в сектор тоже показывает ник владельца, чтобы игроки не путали сектора.
			surfaceLabel(
				requirePart(root, `Указатель сектора 0{index}`),
				Format(Texts.sectorFree, { sector = sign }),
				52
			),
		}
		local spawn = model:FindFirstChildWhichIsA("SpawnLocation")
		assert(spawn, `[World] {model.Name} has no entrance`)
		local stations: { [string]: Part } = {
			terminal = requirePart(model, "Заказы"),
			inventory = requirePart(model, "Склад"),
			collections = requirePart(model, "Коллекции"),
		}
		for _, decoration in authoredParts(stations.terminal, "Строка дисплея заказов") do
			decoration.Transparency = 1
		end
		for key, terminal in stations do
			local face = Instance.new("Attachment")
			face.Name = "Точка взаимодействия"
			face.Position = Vector3.new(0, 0.65, -terminal.Size.Z / 2 - 0.09)
			face.Parent = terminal
			local authored = terminal:FindFirstChildOfClass("ProximityPrompt")
			if authored then
				authored.Parent = face
			end
			prompt(face, Texts.open, terminal.Name, use, "menu", key, 5.5)
		end
		local storage = authoredParts(model, "Складской модуль")
		assert(#storage == 10, `[World] {model.Name} needs 10 storage modules`)
		table.sort(storage, function(first, second)
			if first.Position.Y ~= second.Position.Y then
				return first.Position.Y < second.Position.Y
			end
			return spawn.CFrame:PointToObjectSpace(first.Position).Z
				> spawn.CFrame:PointToObjectSpace(second.Position).Z
		end)
		local stands = {}
		local standSigns = {}
		for slot in Catalog.DisplaySizes do
			local stand = requirePart(model, `Витрина {slot}`)
			prompt(stand, Texts.manage, stand.Name, use, "menu", tostring(slot), 7)
			stands[slot] = stand
			local placard = part(
				stand,
				"Табличка экспоната",
				stand.CFrame * CFrame.new(0, stand.Size.Y * 0.26, -stand.Size.Z / 2 - 0.08),
				Vector3.new(math.min(stand.Size.X - 0.25, 4), 0.55, 0.12),
				INK
			)
			placard.CanCollide = false
			placard.CanQuery = false
			placard.CanTouch = false
			standSigns[slot] = surfaceLabel(placard, "", 18)
		end
		local button = requirePart(model, "Пульт добычи")
		prompt(button, Texts.loot, Texts.lootControl, use, "menu", "loot")
		local pad, upper, lower, gateFrames = findGates(model)
		local pipeEntry = requirePart(model, "Точка входа в трубу")
		local deliveryPoint = requirePart(model, "Верхняя точка подачи")
		local disposalPoint = requirePart(model, "Нижняя точка отвода")
		local deliverySignal = requirePart(model, "Сигнал подачи")
		local disposalSignal = requirePart(model, "Сигнал отвода")
		local backroomsDoors = authoredParts(model, "Затвор Backrooms")
		local backroomsFrames = {}
		for _, door in backroomsDoors do
			backroomsFrames[door] = door.CFrame
		end
		local backroomsLamps = authoredParts(model, "Лампа Backrooms")
		table.insert(plots, {
			Model = model,
			Pad = pad,
			Owner = owner,
			Storage = storage,
			Stations = stations,
			Stands = stands,
			StandSigns = standSigns,
			StandModels = {},
			Rank = index,
			Active = nil,
			OrderId = nil,
			VisualState = nil,
			Releasing = false,
			DeliveryMotion = nil,
			Loot = {},
			LootPositions = {},
			Clear = requirePart(model, "Индикация шлюза"),
			Button = button,
			Upper = upper,
			Lower = lower,
			Gates = {},
			GateFrames = gateFrames,
			PipeEntry = pipeEntry,
			PipeLight = shaftLight(pipeEntry, ICE),
			DeliveryPoint = deliveryPoint,
			DisposalPoint = disposalPoint,
			GateSignals = { upper = deliverySignal, lower = disposalSignal },
			GateLights = { upper = shaftLight(deliveryPoint, ICE), lower = shaftLight(disposalPoint, AMBER) },
			Spawn = spawn,
			OpenParts = {},
			BackroomsDoors = backroomsDoors,
			BackroomsFrames = backroomsFrames,
			BackroomsLamps = backroomsLamps,
			Kit = Sector.build(model, spawn, stands, storage, {
				OrderScreen = requirePart(stations.terminal, "Матовый экран заказа"),
				StorageDesk = stations.inventory,
				CollectionDesk = stations.collections,
				CollectionScreen = requirePart(stations.collections, "Панель каталогизации"),
				LootControl = button,
			}, function(item: Types.Item, full: boolean?): Model
				return makeItem(item, full)
			end),
		})
	end
	return plots
end

function World.Owner(plot: Plot, player: Player?): ()
	local title = if player then player.DisplayName else Texts.free
	for _, face in plot.Owner do
		face.Text = Format(Texts.sectorOwner, { index = plot.Rank, title = title })
		face.TextColor3 = if player then PAPER else MUTED
	end
	if player then
		plot.Model:SetAttribute("OwnerId", player.UserId)
		player.RespawnLocation = plot.Spawn
	else
		plot.Model:SetAttribute("OwnerId", nil)
	end
end

function World.Position(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then root.Position else nil
end

function World.Near(player: Player, stationPart: BasePart, range: number): boolean
	local position = World.Position(player)
	return position ~= nil and (position - stationPart.Position).Magnitude <= range
end

function World.InPad(plot: Plot, player: Player): boolean
	local position = World.Position(player)
	if not position then
		return false
	end
	local offset = plot.Pad:PointToObjectSpace(position)
	return math.abs(offset.X) <= 9.5 and math.abs(offset.Z) <= 9.5 and offset.Y >= -2 and offset.Y <= 13
end

function World.RecoverFromShaft(player: Player, plots: { Plot }): ()
	local position = World.Position(player)
	local character = player.Character
	if not position or not character or position.Y > 0 then
		return
	end
	for _, plot in plots do
		local offset = plot.Pad:PointToObjectSpace(position)
		if offset.Y < 0 and offset.Y > -14 and math.abs(offset.X) <= 9.5 and math.abs(offset.Z) <= 9.5 then
			character:PivotTo(plot.Pad * CFrame.new(0, 4.0, -12.2))
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
			return
		end
	end
end

function World.SpawnPlayer(plot: Plot, player: Player): ()
	local character = player.Character
	if character and World.Position(player) then
		character:PivotTo(plot.Spawn.CFrame * CFrame.new(0, 3.5, 0))
	end
end

function World.UpdateStorage(plot: Plot, capacity: number, inventory: { Types.Item }): ()
	Sector.setStorage(plot.Kit, capacity, inventory)
end

function World.UpdateCollections(plot: Plot, collections: { [string]: Types.Item }): ()
	Sector.setCollections(plot.Kit, collections)
end

-- Живые табло и голограмма сектора: заказ, добыча и заполнение склада.
function World.UpdateStatus(
	plot: Plot,
	orderState: string?,
	stage: string?,
	remaining: number,
	count: number,
	capacity: number
): ()
	Sector.setOrder(plot.Kit, orderState)
	Sector.setLoot(plot.Kit, stage, remaining)
	Sector.setStorageInfo(plot.Kit, count, capacity)
end

function World.UpdateInfo(plot: Plot, level: number, price: number, orders: number, maximum: number): ()
	Sector.setInfo(plot.Kit, level, price, orders, maximum)
end

function World.UpdateDisplays(plot: Plot, items: { [string]: Types.Item }): ()
	for slot, stand in plot.Stands do
		local item = items[tostring(slot)]
		local previous = plot.StandModels[slot]
		if previous and (not item or previous:GetAttribute("ItemId") ~= item.Id) then
			previous:Destroy()
			plot.StandModels[slot] = nil
			plot.StandSigns[slot].Text = ""
			Sector.setDisplay(plot.Kit, slot, nil)
		end
		if item and not plot.StandModels[slot] then
			local model = makeItem(item)
			local lift = plot.Kit.Lift[slot] or 0
			-- Лицевая сторона предмета (-Z) смотрит туда же, куда лицевая сторона витрины — в проход сектора.
			local top = stand.CFrame * CFrame.new(0, stand.Size.Y / 2 + 0.02 + lift, 0)
			local facing = stand.CFrame.LookVector * Vector3.new(1, 0, 1)
			if facing.Magnitude > 0.01 then
				model:PivotTo(CFrame.lookAt(top.Position, top.Position + facing.Unit))
			else
				model:PivotTo(top * CFrame.Angles(0, math.rad(plot.Kit.Yaw[slot] or 0), 0))
			end
			Sector.setDisplay(plot.Kit, slot, item)
			model.Parent = plot.Model
			plot.StandModels[slot] = model
			plot.StandSigns[slot].Text = `{Catalog.Items[item.Kind].Name} · {item.Quality}/100`
		end
	end
end

local function clickToOpen(body: Part, use: Use): ()
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 10
	detector.Parent = body
	detector.MouseClick:Connect(function(player)
		use(player, "open", nil)
	end)
end

local function containerModel(plot: Plot, order: Types.Order, use: Use): Model
	local model, openParts = Containers.build(order, use, { Part = part, Prompt = prompt, Click = clickToOpen })
	plot.OpenParts = openParts
	model.Parent = plot.Model
	return model
end

function World.RotateDial(plot: Plot, phase: number): ()
	if plot.Active then
		Containers.rotateDial(plot.Active, plot.Pad * CFrame.new(0, CONTAINER_PIVOT_HEIGHT, 0), phase)
	end
end

function World.Clear(plot: Plot): ()
	if plot.DeliveryMotion then
		plot.DeliveryMotion:Cancel()
		plot.DeliveryMotion = nil
	end
	plot.PipeLight.Enabled = false
	plot.GateLights.upper.Enabled = false
	setBackrooms(plot, false)
	if plot.Active then
		plot.Active:Destroy()
	end
	plot.Active, plot.OrderId, plot.VisualState = nil, nil, nil
	plot.Releasing = false
	for _, model in plot.Loot do
		model:Destroy()
	end
	table.clear(plot.Loot)
	table.clear(plot.LootPositions)
	table.clear(plot.OpenParts)
	moveGate(plot, "upper", false)
	moveGate(plot, "lower", false)
	plot.Clear.Color = ICE
end

function World.Release(plot: Plot): number
	local model = plot.Active
	if not model or plot.Releasing then
		return 0
	end
	plot.Releasing = true
	Containers.prepareRelease(model, GATE_MOVE_TIME)
	moveGate(plot, "lower", true)
	animate(model, model:GetPivot(), plot.DisposalPoint.CFrame, DISPOSAL_TRAVEL_TIME, 0, GATE_MOVE_TIME)
	local closeAt = GATE_MOVE_TIME + DISPOSAL_TRAVEL_TIME
	task.delay(closeAt, function()
		if plot.Active == model and plot.Releasing then
			moveGate(plot, "lower", false)
		end
	end)
	return closeAt + GATE_MOVE_TIME
end

-- Выбранный владельцем эффект выпадения для сектора.
function World.SetEffect(plot: Plot, key: string): ()
	plot.Model:SetAttribute("DropEffect", key)
end

function World.Sync(plot: Plot, order: Types.Order?, use: Use, scatter: boolean, remaining: number): ()
	if not order or order.Stage == "queued" then
		if plot.Active then
			World.Clear(plot)
		end
		return
	end
	local base = plot.Pad * CFrame.new(0, CONTAINER_PIVOT_HEIGHT, 0)
	local delivering = order.Stage == "delivery"
	if plot.OrderId ~= order.Id then
		World.Clear(plot)
		local model = containerModel(plot, order, function(player, action, key)
			if plot.OrderId == order.Id then
				use(player, action, key)
			end
		end)
		plot.Active, plot.OrderId = model, order.Id
		model:PivotTo(base)
		if delivering then
			plot.DeliveryMotion = deliverThroughPipe(plot, model, base, remaining)
		end
	end
	local model = plot.Active
	if not model then
		return
	end
	if not delivering then
		if plot.DeliveryMotion then
			plot.DeliveryMotion:Cancel()
			plot.DeliveryMotion = nil
			model:PivotTo(base)
		end
		plot.PipeLight.Enabled = false
		plot.GateLights.upper.Enabled = false
		moveGate(plot, "upper", false)
	end
	local lead = 0
	local visual = `{order.Stage}:{order.Progress}`
	if plot.VisualState ~= visual then
		-- Анимации проигрываем, только если контейнер уже был показан; при восстановлении состояние ставится сразу.
		local live = plot.VisualState ~= nil
		plot.VisualState = visual
		for _, child in model:GetDescendants() do
			if child:IsA("ProximityPrompt") then
				child.Enabled = order.Stage == "sealed"
			elseif child:IsA("ClickDetector") then
				child.MaxActivationDistance = if order.Stage == "sealed" then 10 else 0
			end
		end
		lead = Containers.update(model, order, base, live, plot.OpenParts)
	end
	local shouldExist: { [string]: boolean } = {}
	local effectPlayed = false
	for _, loot in order.Loot do
		local item = loot.Item
		shouldExist[item.Id] = true
		if not plot.Loot[item.Id] then
			if scatter and not effectPlayed then
				effectPlayed = true
				local effect = plot.Model:GetAttribute("DropEffect")
				local key = if typeof(effect) == "string" then effect else Catalog.DefaultEffect
				DropEffects.play(base * CFrame.new(0, 2.1, 0), key, lead)
			end
			local prop = makeItem(item)
			addGlow(prop, item.Quality)
			local target = base * CFrame.new(loot.X, if order.Kind == "cargo" then 0.3 else 0, loot.Z)
			-- Клиент по этим данным парит и вращает лут (как выпавшие предметы в Minecraft).
			prop:SetAttribute("Rest", target)
			CollectionService:AddTag(prop, "CorpaLoot")
			prop.Parent = plot.Model
			plot.Loot[item.Id] = prop
			plot.LootPositions[item.Id] = target.Position
			local primary = prop:FindFirstChildWhichIsA("BasePart")
			if primary then
				prompt(
					primary,
					Texts.toStorage,
					`{Catalog.Items[item.Kind].Name} · {item.Quality}/100`,
					use,
					"pickup",
					item.Id,
					if order.Kind == "cargo" then 5 else 8
				)
			end
			if scatter and order.Kind ~= "cargo" then
				local from = base * CFrame.new(0, 2.1, 0)
				prop:PivotTo(from)
				task.delay(lead, function()
					if prop.Parent then
						animate(prop, from, target, 0.55, 2.3)
					end
				end)
				-- Парение включается, когда предмет приземлился.
				task.delay(lead + 0.65, function()
					if prop.Parent then
						prop:SetAttribute("Settled", true)
					end
				end)
			else
				prop:PivotTo(target)
				prop:SetAttribute("Settled", true)
			end
		end
	end
	for id, prop in plot.Loot do
		if not shouldExist[id] then
			prop:Destroy()
			plot.Loot[id], plot.LootPositions[id] = nil, nil
		end
	end
	plot.Clear.Color = if order.Stage == "clear" then AMBER else ICE
end

return World
