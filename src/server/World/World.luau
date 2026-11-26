--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Containers = require(script.Parent.Parent.Visuals.Containers)
local DropEffects = require(script.Parent.Parent.Visuals.DropEffects)
local ItemModels = require(ReplicatedStorage.Shared.Models.ItemModels)
local Audio = require(script.Parent.Parent.Network.Audio)
local Sector = require(script.Parent.Sector)
local ItemAssets = require(script.Parent.ItemAssets)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local STEEL = Color3.fromRGB(45, 56, 68)
local ICE = Theme.Colors.Cyan
local AMBER = Theme.Colors.Amber
local INK = Theme.Colors.Ink
local PAPER = Theme.Colors.Text
local MUTED = Theme.Colors.Muted
local GATE_MOVE_TIME = 0.36
local DISPOSAL_TRAVEL_TIME = 1.05
local PIPE_TRAVEL_FRACTION = 0.55
local CONTAINER_PIVOT_HEIGHT = 1.05

export type Use = (Player, string, string?) -> ()
export type RankingEntry = { Name: string, Score: number, Opened: number? }
type RankingRow = { Frame: Frame, Name: TextLabel, Score: TextLabel, Opened: TextLabel? }
type RankingFace = { Rows: { RankingRow }, Status: TextLabel }
export type Plot = {
	Model: Model,
	Pad: CFrame,
	Owner: { TextLabel },
	Storage: { Part },
	Stations: { [string]: Part },
	Stands: { Part },
	StandSigns: { TextLabel },
	StandModels: { [number]: Model },
	Rank: number,
	Active: Model?,
	OrderId: string?,
	VisualState: string?,
	Releasing: boolean,
	DeliveryMotion: Tween?,
	Loot: { [string]: Model },
	LootPositions: { [string]: Vector3 },
	Clear: Part,
	Button: Part,
	Upper: { Part },
	Lower: { Part },
	Gates: { [string]: string },
	GateFrames: { [Part]: CFrame },
	PipeEntry: Part,
	PipeLight: PointLight,
	DeliveryPoint: Part,
	DisposalPoint: Part,
	GateSignals: { [string]: Part },
	GateLights: { [string]: PointLight },
	Spawn: SpawnLocation,
	OpenParts: { Part },
	Kit: Sector.Kit,
	-- Затвор камеры Backrooms в конце трубы: открыт только пока контейнер вылетает (необязательный).
	BackroomsDoors: { Part },
	BackroomsFrames: { [Part]: CFrame },
	BackroomsLamps: { Part },
}

local World = {}
-- Объявлена заранее: нужна при построении секторов, а определяется ниже вместе с моделями предметов.
local makeItem: (Types.Item, boolean?) -> Model
local boards: { [string]: { RankingFace } } = {}

local function part(
	parent: Instance,
	name: string,
	frame: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Anchored = true
	result.Size = size
	result.CFrame = frame
	result.Color = color
	result.Material = material or Enum.Material.Metal
	result.TopSurface = Enum.SurfaceType.Smooth
	result.BottomSurface = Enum.SurfaceType.Smooth
	result.Parent = parent
	return result
end

local function boardLabel(
	parent: Instance,
	value: string,
	x: number,
	y: number,
	width: number,
	height: number,
	size: number,
	bold: boolean
): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(x, y)
	text.Size = UDim2.fromOffset(width, height)
	text.Text = value
	text.TextColor3 = PAPER
	text.TextSize = size
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.FontFace = if bold then Theme.Fonts.Bold else Theme.Fonts.Body
	text.Parent = parent
	return text
end

local function rankingBoard(
	terminal: Part,
	title: string,
	subtitle: string,
	rowCount: number,
	accent: Color3,
	showOpened: boolean?
): { RankingFace }
	local screen = part(
		terminal,
		"Экран рейтинга",
		terminal.CFrame * CFrame.new(0, terminal.Size.Y / 2 + 3.25, 0),
		Vector3.new(8.8, 6.6, 0.42),
		INK
	)
	local faces = {}
	for _, side in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Face = side
		surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surface.CanvasSize = Vector2.new(640, 480)
		surface.LightInfluence = 0
		surface.MaxDistance = 80
		surface.Parent = screen

		local panel = Instance.new("Frame")
		panel.BorderSizePixel = 0
		panel.BackgroundColor3 = INK
		panel.Size = UDim2.fromScale(1, 1)
		panel.Parent = surface

		local stripe = Instance.new("Frame")
		stripe.BorderSizePixel = 0
		stripe.BackgroundColor3 = accent
		stripe.Size = UDim2.new(1, 0, 0, 6)
		stripe.Parent = panel
		boardLabel(panel, title, 24, 15, 592, 43, 36, true)
		boardLabel(panel, subtitle, 24, 59, 592, 26, 19, false).TextColor3 = MUTED
		boardLabel(panel, "Место", 24, 91, 68, 26, 17, true).TextColor3 = accent
		local coinEdge = if showOpened then 490 else 616
		boardLabel(panel, "Игрок", 108, 91, 230, 26, 17, true).TextColor3 = accent
		local coinHeading = boardLabel(panel, "Монеты", 350, 91, coinEdge - 350, 26, 17, true)
		coinHeading.TextColor3 = accent
		coinHeading.TextXAlignment = Enum.TextXAlignment.Right
		if showOpened then
			local opened = boardLabel(panel, "Открыто", 505, 91, 111, 26, 17, true)
			opened.TextColor3 = accent
			opened.TextXAlignment = Enum.TextXAlignment.Right
		end

		local rows = {}
		local step = if rowCount <= 6 then 58 else 34
		for index = 1, rowCount do
			local row = Instance.new("Frame")
			row.BackgroundColor3 = if index % 2 == 1 then Color3.fromRGB(26, 42, 49) else Color3.fromRGB(19, 33, 41)
			row.BorderSizePixel = 0
			row.Position = UDim2.fromOffset(16, 122 + (index - 1) * step)
			row.Size = UDim2.fromOffset(608, step - 3)
			row.Visible = false
			row.Parent = panel

			local height = step - 3
			local size = if rowCount <= 6 then 27 else 21
			local rank = boardLabel(row, string.format("%02d", index), 8, 0, 64, height, size, true)
			rank.TextColor3 = if index == 1 then accent else MUTED
			local name = boardLabel(row, "", 92, 0, 230, height, size, true)
			local score = boardLabel(row, "", 334, 0, coinEdge - 350, height, size, true)
			score.TextXAlignment = Enum.TextXAlignment.Right
			local opened = if showOpened then boardLabel(row, "", 489, 0, 111, height, size, true) else nil
			if opened then
				opened.TextXAlignment = Enum.TextXAlignment.Right
			end
			table.insert(rows, { Frame = row, Name = name, Score = score, Opened = opened })
		end
		local status = boardLabel(panel, "Загрузка рейтинга…", 24, 154, 592, 96, 26, false)
		status.TextColor3 = MUTED
		status.TextWrapped = true
		status.TextXAlignment = Enum.TextXAlignment.Center
		table.insert(faces, { Rows = rows, Status = status })
	end
	return faces
end

local function surfaceLabel(parent: BasePart, text: string, distance: number, face: Enum.NormalId?): TextLabel
	local surface = Instance.new("SurfaceGui")
	surface.Face = face or Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 72
	surface.LightInfluence = 0
	surface.MaxDistance = distance
	surface.Parent = parent
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(1, 1)
	caption.BorderSizePixel = 0
	caption.BackgroundColor3 = INK
	caption.TextColor3 = PAPER
	caption.Text = text
	caption.TextScaled = true
	caption.TextWrapped = true
	caption.FontFace = Theme.Fonts.Display
	caption.Parent = surface
	local margin = Instance.new("UIPadding")
	margin.PaddingLeft = UDim.new(0.045, 0)
	margin.PaddingRight = UDim.new(0.045, 0)
	margin.PaddingTop = UDim.new(0.08, 0)
	margin.PaddingBottom = UDim.new(0.08, 0)
	margin.Parent = caption
	return caption
end

local function prompt(
	parent: BasePart | Attachment,
	action: string,
	title: string,
	use: Use,
	command: string,
	key: string?,
	range: number?
): ProximityPrompt
	local result = parent:FindFirstChildWhichIsA("ProximityPrompt") or Instance.new("ProximityPrompt")
	result.Name = command
	result.ActionText = action
	result.ObjectText = title
	result.MaxActivationDistance = range or 9
	result.RequiresLineOfSight = false
	result.Parent = parent
	result.Triggered:Connect(function(player)
		use(player, command, key)
	end)
	return result
end

local function moveGate(plot: Plot, name: string, open: boolean, duration: number?): ()
	local state = if open then "open" else "closed"
	if plot.Gates[name] == state then
		return
	end
	plot.Gates[name] = state
	local signal = plot.GateSignals[name]
	signal.Color = if open then (if name == "upper" then ICE else AMBER) else STEEL
	plot.GateLights[name].Enabled = open
	local pieces: { Part } = if name == "upper" then plot.Upper else plot.Lower
	Audio.at(pieces[1], "hiss")
	for index, piece in pieces do
		local side = if index == 1 then -1 else 1
		if name == "lower" then
			piece.CanCollide = not open
		end
		local closed = plot.GateFrames[piece]
		local travel = if open then side * (piece.Size.X + 0.2) else 0
		local target = closed * CFrame.new(travel, 0, 0)
		TweenService
			:Create(piece, TweenInfo.new(duration or GATE_MOVE_TIME, Enum.EasingStyle.Quad), { CFrame = target })
			:Play()
	end
end

local function requirePart(parent: Instance, name: string): Part
	local child = parent:FindFirstChild(name)
	assert(child and child:IsA("Part"), `[World] В {parent.Name} отсутствует деталь «{name}»`)
	return child
end

local function shaftLight(parent: Part, color: Color3): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 0.65
	light.Range = 15
	light.Enabled = false
	light.Parent = parent
	return light
end

local function authoredParts(parent: Instance, name: string): { Part }
	local found = {}
	for _, child in parent:GetChildren() do
		if child:IsA("Part") and child.Name == name then
			table.insert(found, child)
		end
	end
	return found
end

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
			["Панель экспозиции"] = "ВИТРИНЫ",
			["Панель заказов"] = "ЗАКАЗЫ",
			["Панель склада"] = "СКЛАД",
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
	assert(#shutters == 4, `[World] В {model.Name} требуется четыре створки`)
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
	assert(root, "[World] Не найдена модель лаборатории Roblox Studio")
	for _, name in { "Светильник перехода", "Светильник подхода" } do
		local hall = name == "Светильник подхода"
		for _, fixture in authoredParts(root, name) do
			downlight(fixture, Color3.fromRGB(224, 236, 232), if hall then 0.7 else 0.55, if hall then 32 else 16, 120)
		end
	end
	local leaderboardParts = authoredParts(root, "Терминал рейтинга")
	assert(#leaderboardParts == 2, "[World] Требуются два терминала рейтинга")
	table.sort(leaderboardParts, function(first, second)
		return first.Position.X < second.Position.X
	end)
	boards.localLobby = rankingBoard(
		leaderboardParts[1],
		"Рейтинг лобби",
		"Игроки на этом сервере · заработано за всё время",
		Config.MaxPlayers,
		ICE,
		true
	)
	boards.global = rankingBoard(
		leaderboardParts[2],
		"Общий рейтинг",
		"Топ-10 · заработано за всё время",
		10,
		AMBER
	)

	local plots = {}
	for index = 1, Config.MaxPlayers do
		local model = root:FindFirstChild(`Сектор 0{index}`)
		assert(model and model:IsA("Model"), `[World] Не найден сектор 0{index}`)
		dressSector(model)
		local function use(player: Player, action: string, key: string?)
			useForPlot(index, player, action, key)
		end
		local sign = `СЕКТОР 0{index}`
		local ownerBoard = requirePart(model, "Табло сектора")
		local owner = {
			surfaceLabel(ownerBoard, `{sign}\nСВОБОДЕН`, 42),
			surfaceLabel(ownerBoard, `{sign}\nСВОБОДЕН`, 42, Enum.NormalId.Back),
			-- Указатель перед входом в сектор тоже показывает ник владельца, чтобы игроки не путали сектора.
			surfaceLabel(
				requirePart(root, `Указатель сектора 0{index}`),
				`{sign}\nСВОБОДЕН`,
				52
			),
		}
		local spawn = model:FindFirstChildWhichIsA("SpawnLocation")
		assert(spawn, `[World] В {model.Name} отсутствует вход`)
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
			prompt(face, "Открыть", terminal.Name, use, "menu", key, 5.5)
		end
		local storage = authoredParts(model, "Складской модуль")
		assert(#storage == 10, `[World] В {model.Name} требуется 10 складских модулей`)
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
			prompt(stand, "Управлять", stand.Name, use, "menu", tostring(slot), 7)
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
		prompt(button, "Добыча", "Управление добычей", use, "menu", "loot")
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
	local title = if player then player.DisplayName else "СВОБОДЕН"
	for _, face in plot.Owner do
		face.Text = `СЕКТОР 0{plot.Rank}\n{title}`
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

function World.Board(key: string, entries: { RankingEntry }, emptyText: string): ()
	for _, face in boards[key] do
		face.Status.Text = emptyText
		face.Status.Visible = #entries == 0
		for index, row in face.Rows do
			local entry = entries[index]
			row.Frame.Visible = entry ~= nil
			if entry then
				row.Name.Text = entry.Name
				local grouped = string.reverse(string.format("%.0f", entry.Score)):gsub("(%d%d%d)", "%1 ")
				row.Score.Text = string.reverse(grouped):gsub("^ ", "")
				if row.Opened then
					row.Opened.Text = tostring(entry.Opened or 0)
				end
			end
		end
	end
end

local function animatePath(
	model: Model,
	length: number,
	frameAt: (number) -> CFrame,
	style: Enum.EasingStyle,
	delay: number?
): Tween?
	if length <= 0 then
		model:PivotTo(frameAt(1))
		return nil
	end
	model:PivotTo(frameAt(0))
	local motion = Instance.new("NumberValue")
	motion.Parent = model
	local connection = motion.Changed:Connect(function(alpha: number)
		model:PivotTo(frameAt(alpha))
	end)
	local info = TweenInfo.new(length, style, Enum.EasingDirection.Out, 0, false, delay or 0)
	local tween = TweenService:Create(motion, info, { Value = 1 })
	local destroying: RBXScriptConnection
	tween.Completed:Once(function()
		connection:Disconnect()
		destroying:Disconnect()
		motion:Destroy()
	end)
	destroying = model.Destroying:Once(function()
		connection:Disconnect()
		tween:Cancel()
	end)
	tween:Play()
	return tween
end

local function animate(model: Model, first: CFrame, last: CFrame, length: number, arc: number, delay: number?): ()
	animatePath(model, length, function(alpha)
		return first:Lerp(last, alpha) + Vector3.new(0, math.sin(math.pi * alpha) * arc, 0)
	end, Enum.EasingStyle.Quad, delay)
end

-- «Бэкрумс»: контейнер падает не из трубы, а из мерцающего разрыва с жёлтым флуоресцентным светом и пылью.
local BACKROOMS_YELLOW = Color3.fromRGB(226, 204, 112)
local BACKROOMS_DIRTY = Color3.fromRGB(150, 128, 62)

local function backroomsRift(at: CFrame, duration: number): ()
	local rift = Instance.new("Part")
	rift.Name = "Разрыв бэкрумс"
	rift.Shape = Enum.PartType.Ball
	rift.Size = Vector3.one * 2
	rift.CFrame = at
	rift.Color = BACKROOMS_YELLOW
	rift.Material = Enum.Material.Neon
	rift.Transparency = 1
	rift.Anchored = true
	rift.CanCollide = false
	rift.CanQuery = false
	rift.CanTouch = false
	rift.CastShadow = false
	rift.Parent = Workspace
	-- Грязноватая «обёртка» вокруг светящегося ядра: обои и пыльный потолок.
	local shell = rift:Clone()
	shell.Name = "Оболочка разрыва"
	shell.Color = BACKROOMS_DIRTY
	shell.Material = Enum.Material.Fabric
	shell.Size = Vector3.one * 3
	shell.Parent = rift
	local light = Instance.new("PointLight")
	light.Color = BACKROOMS_YELLOW
	light.Range = 22
	light.Brightness = 0
	light.Parent = rift
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(BACKROOMS_YELLOW, BACKROOMS_DIRTY)
	dust.LightEmission = 0.4
	dust.Size = NumberSequence.new(0.25, 0)
	dust.Transparency = NumberSequence.new(0.2, 1)
	dust.Lifetime = NumberRange.new(0.8, 1.6)
	dust.Speed = NumberRange.new(1, 4)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Rate = 22
	dust.Parent = rift
	local open = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	-- Разрыв открывается внутри камеры Backrooms в конце трубы (высота камеры ~7.7): не крупнее неё.
	TweenService:Create(rift, open, { Size = Vector3.one * 6, Transparency = 0.2 }):Play()
	TweenService:Create(shell, open, { Size = Vector3.one * 7, Transparency = 0.55 }):Play()
	-- Лампа дневного света мигает, как в бэкрумс.
	local rng = Random.new()
	task.spawn(function()
		local deadline = os.clock() + duration
		while os.clock() < deadline and rift.Parent do
			light.Brightness = if rng:NextNumber() < 0.25 then rng:NextNumber(0, 0.8) else rng:NextNumber(1.6, 2.6)
			task.wait(rng:NextNumber(0.05, 0.16))
		end
		if rift.Parent then
			local close = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			TweenService:Create(rift, close, { Size = Vector3.one * 1, Transparency = 1 }):Play()
			TweenService:Create(shell, close, { Size = Vector3.one * 1.5, Transparency = 1 }):Play()
			TweenService:Create(light, close, { Brightness = 0 }):Play()
			dust.Enabled = false
			task.delay(1.8, function()
				rift:Destroy()
			end)
		end
	end)
end

local BACKROOMS_DOOR_TIME = 0.55
local BACKROOMS_LAMP_ON = Color3.fromRGB(255, 251, 228)
local BACKROOMS_LAMP_OFF = Color3.fromRGB(70, 66, 52)

-- Затвор Backrooms: створки разъезжаются в стороны (каждая на свою ширину), лампы внутри загораются.
-- Закрытый затвор полностью скрывает камеру — Backrooms видны только во время вылета контейнера.
local function setBackrooms(plot: Plot, open: boolean): ()
	for _, door in plot.BackroomsDoors do
		local closed = plot.BackroomsFrames[door]
		local pairCenter = Vector3.zero
		for _, other in plot.BackroomsDoors do
			pairCenter += plot.BackroomsFrames[other].Position
		end
		pairCenter /= #plot.BackroomsDoors
		local side = if closed:PointToObjectSpace(pairCenter).X > 0 then -1 else 1
		local target = if open then closed * CFrame.new(side * door.Size.X, 0, 0) else closed
		TweenService:Create(door, TweenInfo.new(BACKROOMS_DOOR_TIME, Enum.EasingStyle.Quad), { CFrame = target }):Play()
	end
	for _, lamp in plot.BackroomsLamps do
		lamp.Color = if open then BACKROOMS_LAMP_ON else BACKROOMS_LAMP_OFF
		lamp.Material = if open then Enum.Material.Neon else Enum.Material.SmoothPlastic
		for _, light in lamp:GetChildren() do
			if light:IsA("Light") then
				light.Enabled = open
			end
		end
	end
end

local function deliverThroughPipe(plot: Plot, model: Model, base: CFrame, remaining: number): Tween?
	if remaining <= 0 then
		model:PivotTo(base)
		return nil
	end
	local entry = plot.PipeEntry.CFrame
	local outlet = plot.DeliveryPoint.CFrame
	plot.PipeLight.Enabled = true
	plot.GateLights.upper.Enabled = true
	-- Точка входа лежит на уровне пола трубы: разрыв — в центре камеры Backrooms по высоте.
	backroomsRift(entry * CFrame.new(0, 3.8, 0), remaining * PIPE_TRAVEL_FRACTION + 0.4)
	setBackrooms(plot, true)
	-- Затвор закрывается, когда контейнер прошёл трубу и опускается в шлюз.
	task.delay(remaining * PIPE_TRAVEL_FRACTION + BACKROOMS_DOOR_TIME, function()
		if plot.Active == model then
			setBackrooms(plot, false)
		end
	end)
	local gateLead = math.min(GATE_MOVE_TIME, remaining * 0.22)
	local descentStart = PIPE_TRAVEL_FRACTION + gateLead / remaining
	task.delay(remaining * PIPE_TRAVEL_FRACTION, function()
		if plot.Active == model and plot.DeliveryMotion then
			moveGate(plot, "upper", true, gateLead)
		end
	end)
	return animatePath(model, remaining, function(alpha)
		if alpha < PIPE_TRAVEL_FRACTION then
			return entry:Lerp(outlet, alpha / PIPE_TRAVEL_FRACTION)
		elseif alpha < descentStart then
			return outlet
		end
		local down = (alpha - descentStart) / (1 - descentStart)
		return outlet:Lerp(base, down * (2 - down))
	end, Enum.EasingStyle.Linear)
end

-- Цвет и сила свечения зависят от качества: чем выше качество, тем ярче и шире аура.
local GLOW_TIERS = {
	{ Max = 20, Color = Color3.fromRGB(170, 176, 204), Strength = 0.35 },
	{ Max = 49, Color = Color3.fromRGB(110, 214, 134), Strength = 0.55 },
	{ Max = 70, Color = Color3.fromRGB(80, 194, 255), Strength = 0.8 },
	{ Max = 99, Color = Color3.fromRGB(190, 124, 255), Strength = 1.1 },
	{ Max = 100, Color = Color3.fromRGB(255, 200, 60), Strength = 1.6 },
}

-- Свечение лута по форме предмета: контур (Highlight) цвета качества обвивает модель, лёгкая заливка
-- и слабый свет; у хороших находок — редкие искры. Highlight рисуется только снаружи стен (Occluded).
-- Клиент рисует не больше 31 Highlight одновременно — лута на площадках заметно меньше.
local function addGlow(model: Model, quality: number): ()
	local tier = 1
	for index, entry in GLOW_TIERS do
		if quality <= entry.Max then
			tier = index
			break
		end
	end
	local glow = GLOW_TIERS[tier]
	local outline = Instance.new("Highlight")
	outline.Name = "Свечение"
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.OutlineColor = glow.Color
	outline.OutlineTransparency = 0.1
	outline.FillColor = glow.Color
	outline.FillTransparency = 0.86 - 0.04 * tier
	outline.Parent = model
	local host = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not host then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "Свет находки"
	light.Color = glow.Color
	light.Brightness = glow.Strength * 0.7
	light.Range = 4 + 2 * tier
	light.Shadows = false
	light.Parent = host
	if tier >= 4 then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Rate = if tier == 5 then 7 else 3
		sparks.Lifetime = NumberRange.new(1.4, 2.4)
		sparks.Speed = NumberRange.new(0.4, 1.4)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Acceleration = Vector3.new(0, 1.6, 0)
		sparks.LightEmission = 1
		sparks.Color = ColorSequence.new(glow.Color)
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		sparks.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		sparks.Parent = host
	end
end

function makeItem(item: Types.Item, full: boolean?): Model
	local definition = Catalog.Items[item.Kind]
	-- Модель из Creator Store подключается только по явному включению; по умолчанию рисуем свою.
	local model = ItemAssets.clone(item.Kind) or Instance.new("Model")
	if #model:GetChildren() == 0 then
		ItemModels.build(item.Kind, model, { Full = full ~= false })
		model.WorldPivot = CFrame.new()
	end
	model.Name = definition.Name
	model:SetAttribute("ItemId", item.Id)
	model:SetAttribute("Quality", item.Quality)
	return model
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
					"На склад",
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
