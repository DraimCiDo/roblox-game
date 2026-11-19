--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Containers = require(script.Parent.Containers)

local STEEL = Color3.fromRGB(45, 56, 68)
local ICE = Color3.fromRGB(91, 232, 222)
local AMBER = Color3.fromRGB(255, 181, 86)
local INK = Color3.fromRGB(11, 20, 29)

export type Use = (Player, string, string?) -> ()
export type Plot = {
	Model: Model,
	Pad: CFrame,
	Owner: TextLabel,
	Storage: { Part },
	Stations: { [string]: Part },
	Stands: { Part },
	StandModels: { [number]: Model },
	Rank: number,
	Active: Model?,
	OrderId: string?,
	VisualState: string?,
	Releasing: boolean,
	Loot: { [string]: Model },
	LootPositions: { [string]: Vector3 },
	Clear: Part,
	Button: Part,
	Upper: { Part },
	Lower: { Part },
	Gates: { [string]: string },
	GateFrames: { [Part]: CFrame },
	Spawn: SpawnLocation,
	OpenParts: { Part },
}

local World = {}
local boards: { [string]: TextLabel } = {}

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

local function label(parent: BasePart, text: string, dimensions: UDim2, offset: Vector3): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Size = dimensions
	billboard.StudsOffsetWorldSpace = offset
	billboard.MaxDistance = 70
	billboard.Parent = parent
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(1, 1)
	caption.BackgroundTransparency = 0.12
	caption.BackgroundColor3 = INK
	caption.TextColor3 = ICE
	caption.Text = text
	caption.TextScaled = true
	caption.TextWrapped = true
	caption.Font = Enum.Font.GothamBold
	caption.Parent = billboard
	local margin = Instance.new("UIPadding")
	margin.PaddingLeft = UDim.new(0.045, 0)
	margin.PaddingRight = UDim.new(0.045, 0)
	margin.PaddingTop = UDim.new(0.08, 0)
	margin.PaddingBottom = UDim.new(0.08, 0)
	margin.Parent = caption
	return caption
end

local function prompt(
	parent: BasePart,
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

local function moveGate(plot: Plot, name: string, open: boolean): ()
	local state = if open then "open" else "closed"
	if plot.Gates[name] == state then
		return
	end
	plot.Gates[name] = state
	local pieces: { Part } = if name == "upper" then plot.Upper else plot.Lower
	for index, piece in pieces do
		local side = if index == 1 then -1 else 1
		if name == "lower" then
			piece.CanCollide = not open
		end
		local closed = plot.GateFrames[piece]
		local travel = if open then side * (piece.Size.X + 0.2) else 0
		local target = closed * CFrame.new(travel, 0, 0)
		TweenService:Create(piece, TweenInfo.new(0.36, Enum.EasingStyle.Quad), { CFrame = target }):Play()
	end
end

local function requirePart(parent: Instance, name: string): Part
	local child = parent:FindFirstChild(name)
	assert(child and child:IsA("Part"), `[World] В {parent.Name} отсутствует деталь «{name}»`)
	return child
end

local function requireSign(parent: Instance): TextLabel
	local text = parent:FindFirstChildWhichIsA("TextLabel", true)
	assert(text, `[World] В {parent.Name} отсутствует надпись`)
	return text
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

local function findGates(model: Model): (CFrame, { Part }, { Part }, { [Part]: CFrame })
	local shutters = authoredParts(model, "Створка шлюза")
	assert(#shutters == 4, `[World] В {model.Name} требуется четыре створки`)
	table.sort(shutters, function(first, second)
		return first.Position.Y < second.Position.Y
	end)
	local lower = { shutters[1], shutters[2] }
	local upper = { shutters[3], shutters[4] }
	local center = (lower[1].Position + lower[2].Position) / 2
	local pad = (CFrame.new(center) * lower[1].CFrame.Rotation) * CFrame.new(0, -0.7, 0)
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
	local leaderboardParts = authoredParts(root, "Терминал рейтинга")
	assert(#leaderboardParts == 2, "[World] Требуются два терминала рейтинга")
	table.sort(leaderboardParts, function(first, second)
		return first.Position.X < second.Position.X
	end)
	boards.localLobby = requireSign(leaderboardParts[1])
	boards.global = requireSign(leaderboardParts[2])

	local plots = {}
	for index = 1, Config.MaxPlayers do
		local model = root:FindFirstChild(`Сектор 0{index}`)
		assert(model and model:IsA("Model"), `[World] Не найден сектор 0{index}`)
		local function use(player: Player, action: string, key: string?)
			useForPlot(index, player, action, key)
		end
		local owner = requireSign(requirePart(model, "Табло сектора"))
		local spawn = model:FindFirstChildWhichIsA("SpawnLocation")
		assert(spawn, `[World] В {model.Name} отсутствует вход`)
		local stations: { [string]: Part } = {
			terminal = requirePart(model, "Заказы"),
			inventory = requirePart(model, "Склад"),
			collections = requirePart(model, "Коллекции"),
		}
		for key, terminal in stations do
			prompt(terminal, "Открыть", terminal.Name, use, "menu", key, 4.2)
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
		for slot in Catalog.DisplaySizes do
			local stand = requirePart(model, `Витрина {slot}`)
			prompt(stand, "Управлять", stand.Name, use, "menu", tostring(slot), 7)
			stands[slot] = stand
		end
		local button = requirePart(model, "Пульт добычи")
		prompt(button, "Добыча", "Управление добычей", use, "menu", "loot")
		local pad, upper, lower, gateFrames = findGates(model)
		table.insert(plots, {
			Model = model,
			Pad = pad,
			Owner = owner,
			Storage = storage,
			Stations = stations,
			Stands = stands,
			StandModels = {},
			Rank = index,
			Active = nil,
			OrderId = nil,
			VisualState = nil,
			Releasing = false,
			Loot = {},
			LootPositions = {},
			Clear = requirePart(model, "Индикация шлюза"),
			Button = button,
			Upper = upper,
			Lower = lower,
			Gates = {},
			GateFrames = gateFrames,
			Spawn = spawn,
			OpenParts = {},
		})
	end
	return plots
end

function World.Owner(plot: Plot, player: Player?): ()
	local title = if player then player.DisplayName else "СВОБОДЕН"
	plot.Owner.Text = `СЕКТОР 0{plot.Rank} · {title}`
	plot.Owner.TextColor3 = if player then ICE else Color3.fromRGB(156, 173, 185)
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

function World.SpawnPlayer(plot: Plot, player: Player): ()
	local character = player.Character
	if character and World.Position(player) then
		character:PivotTo(plot.Spawn.CFrame * CFrame.new(0, 3.5, 0))
	end
end

function World.Board(key: string, text: string): ()
	boards[key].Text = text
end

local function animate(model: Model, first: CFrame, last: CFrame, length: number, arc: number): ()
	model:PivotTo(first)
	if length <= 0 then
		model:PivotTo(last)
		return
	end
	local motion = Instance.new("NumberValue")
	motion.Parent = model
	local connection = motion.Changed:Connect(function(alpha: number)
		model:PivotTo(first:Lerp(last, alpha) + Vector3.new(0, math.sin(math.pi * alpha) * arc, 0))
	end)
	local tween = TweenService:Create(
		motion,
		TweenInfo.new(length, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = 1 }
	)
	tween.Completed:Once(function()
		connection:Disconnect()
		motion:Destroy()
	end)
	model.Destroying:Once(function()
		connection:Disconnect()
		tween:Cancel()
	end)
	tween:Play()
end

local function makeItem(item: Types.Item): Model
	local definition = Catalog.Items[item.Kind]
	local color = definition.Color
	local model = Instance.new("Model")
	model.Name = definition.Name
	model:SetAttribute("ItemId", item.Id)
	model:SetAttribute("Quality", item.Quality)
	local scale = if definition.Size == "car" then 2 else if definition.Size == "large" then 1.55 else 1
	local function shape(
		x: number,
		y: number,
		z: number,
		sx: number,
		sy: number,
		sz: number,
		tint: Color3?,
		kind: Enum.PartType?,
		material: Enum.Material?
	): Part
		local piece = part(
			model,
			"Деталь",
			CFrame.new(x * scale, y * scale, z * scale),
			Vector3.new(sx, sy, sz) * scale,
			tint or color,
			material
		)
		piece.Shape = kind or Enum.PartType.Block
		piece.CanCollide = false
		return piece
	end
	local style = definition.Style
	if style == "car" then
		shape(0, 0.59, 0, 1.9, 0.55, 3.1)
		shape(0, 1.02, 0.12, 1.48, 0.47, 1.42, INK, nil, Enum.Material.Glass)
		for _, x in { -0.96, 0.96 } do
			for _, z in { -0.97, 0.97 } do
				shape(x, 0.38, z, 0.36, 0.76, 0.76, INK, Enum.PartType.Cylinder)
			end
			shape(x * 0.7, 0.64, -1.56, 0.33, 0.16, 0.08, ICE, nil, Enum.Material.Neon)
		end
	elseif style == "ball" then
		shape(0, 0.59, 0, 1.18, 1.18, 1.18, nil, Enum.PartType.Ball)
		if item.Kind == "ball" then
			for i = 1, 5 do
				local angle = i * math.pi * 0.4
				shape(math.cos(angle) * 0.49, 0.65, math.sin(angle) * 0.49, 0.25, 0.25, 0.25, INK, Enum.PartType.Ball)
			end
		elseif item.Kind == "bomb" or item.Kind == "trash" then
			shape(0, 1.27, 0, 0.17, 0.22, 0.17, if item.Kind == "bomb" then AMBER else color)
		elseif item.Kind == "core" then
			shape(0, 0.62, 0, 1.38, 0.105, 1.38, ICE, nil, Enum.Material.Neon)
		end
	elseif style == "screen" or style == "picture" then
		local portrait = item.Kind == "phone" or item.Kind == "button"
		local width, height = if portrait then 0.67 else 1.44, if portrait then 1.37 else 1.05
		shape(0, height / 2, 0, width, height, if style == "picture" then 0.15 else 0.47)
		shape(
			0,
			height / 2,
			-0.25,
			width * 0.81,
			height * 0.76,
			0.09,
			if style == "screen" then INK else AMBER,
			nil,
			if style == "screen" then Enum.Material.Glass else nil
		)
	elseif style == "radio" or style == "camera" then
		shape(0, 0.42, 0, 1.6, 0.82, 0.66)
		local lensPositions: { number } = if style == "radio" then { -0.47, 0.47 } else { 0 }
		for _, x in lensPositions do
			shape(x, 0.44, -0.38, 0.2, 0.47, 0.47, INK, Enum.PartType.Cylinder).Orientation = Vector3.new(0, 90, 0)
		end
		shape(0, 0.92, 0, 0.69, 0.16, 0.2, STEEL)
	elseif style == "flower" or style == "brush" or style == "fan" then
		shape(0, 0.62, 0, 0.14, 1.2, 0.14, if style == "flower" then Color3.fromRGB(84, 172, 99) else STEEL)
		shape(0, 0.11, 0, 0.69, 0.21, 0.69, STEEL)
		for i = 1, (if style == "brush" then 1 else 5) do
			local angle = i * math.pi * 0.4
			shape(math.sin(angle) * 0.27, 1.14 + math.cos(angle) * 0.25, 0, 0.31, 0.32, 0.24, nil, Enum.PartType.Ball)
		end
	elseif style == "bowl" or style == "bell" or style == "hat" then
		shape(0, 0.17, 0, 0.28, 1.05, 1.05, nil, Enum.PartType.Cylinder).Orientation = Vector3.new(0, 0, 90)
		shape(0, 0.4, 0, 0.7, if style == "hat" then 0.95 else 0.52, 0.7, nil, Enum.PartType.Ball)
		shape(0, if style == "hat" then 0.88 else 0.66, 0, 0.22, 0.2, 0.22, AMBER, Enum.PartType.Ball)
	elseif style == "fish" or style == "dumbbell" then
		shape(0, 0.42, 0, 1.17, 0.4, 0.35, nil, Enum.PartType.Ball)
		shape(
			-0.6,
			0.42,
			0,
			0.26,
			0.56,
			0.44,
			nil,
			if style == "fish" then Enum.PartType.Wedge else Enum.PartType.Cylinder
		)
		shape(0.48, 0.42, 0, 0.26, 0.46, 0.43, if style == "fish" then AMBER else color, Enum.PartType.Ball)
	elseif style == "gem" then
		local gem = shape(0, 0.67, 0, 0.8, 0.8, 0.8, nil, nil, Enum.Material.Glass)
		gem.Orientation = Vector3.new(25, 40, 45)
		shape(0, 0.62, 0, 0.38, 0.38, 0.38, nil, Enum.PartType.Ball, Enum.Material.Neon)
	elseif style == "tower" then
		shape(0, 0.75, 0, 0.78, 1.5, 0.68)
		shape(0, 0.83, -0.37, 0.5, 0.23, 0.09, ICE, nil, Enum.Material.Neon)
		shape(0, 0.05, 0, 1.05, 0.1, 0.87, STEEL)
	else
		local height = if style == "bar" then 0.38 else 0.76
		shape(0, height / 2, 0, 1.2, height, 0.91)
		shape(0, height + 0.025, 0, 0.27, 0.05, 0.81, if style == "bar" then AMBER else STEEL)
	end
	model.WorldPivot = CFrame.new()
	return model
end

function World.UpdateStorage(plot: Plot, capacity: number): ()
	for index, module in plot.Storage do
		local built = index <= capacity / 5
		module.Transparency = if built then 0 else 1
		module.CanCollide = built
	end
end

function World.UpdateDisplays(plot: Plot, items: { [string]: Types.Item }): ()
	for slot, stand in plot.Stands do
		local item = items[tostring(slot)]
		local previous = plot.StandModels[slot]
		if previous and (not item or previous:GetAttribute("ItemId") ~= item.Id) then
			previous:Destroy()
			plot.StandModels[slot] = nil
		end
		if item and not plot.StandModels[slot] then
			local model = makeItem(item)
			model:PivotTo(stand.CFrame * CFrame.new(0, 0.67, 0))
			model.Parent = plot.Model
			plot.StandModels[slot] = model
			local primary = model:FindFirstChildWhichIsA("BasePart")
			if primary then
				label(
					primary,
					`{Catalog.Items[item.Kind].Name} · {item.Quality}/100`,
					UDim2.fromScale(5.1, 1.28),
					Vector3.new(0, 1.8, 0)
				)
			end
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
		Containers.rotateDial(plot.Active, plot.Pad * CFrame.new(0, 1.05, 0), phase)
	end
end

function World.Clear(plot: Plot): ()
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

function World.Release(plot: Plot): ()
	local model = plot.Active
	if plot.Releasing then
		return
	end
	plot.Releasing = true
	moveGate(plot, "lower", true)
	if model then
		local base = plot.Pad * CFrame.new(0, 1.05, 0)
		animate(model, base, base * CFrame.new(0, -10, 0), 1.05, 0)
	end
end

function World.Sync(plot: Plot, order: Types.Order?, use: Use, scatter: boolean, remaining: number): ()
	if not order or order.Stage == "queued" then
		if plot.Active then
			World.Clear(plot)
		end
		return
	end
	local base = plot.Pad * CFrame.new(0, 1.05, 0)
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
			moveGate(plot, "upper", true)
			animate(model, base * CFrame.new(0, 13, 0), base, remaining, 0)
		end
	end
	local model = plot.Active
	if not model then
		return
	end
	if not delivering then
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
	for _, loot in order.Loot do
		local item = loot.Item
		shouldExist[item.Id] = true
		if not plot.Loot[item.Id] then
			local prop = makeItem(item)
			local target = base * CFrame.new(loot.X, if order.Kind == "cargo" then 0.3 else 0, loot.Z)
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
			else
				prop:PivotTo(target)
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
