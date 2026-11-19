--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local STEEL = Color3.fromRGB(45, 56, 68)
local FLOOR = Color3.fromRGB(25, 37, 48)
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
	Spawn: SpawnLocation,
	OpenParts: { Part },
}

local World = {}
local plots: { Plot } = {}
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
	local result = Instance.new("ProximityPrompt")
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

local function station(parent: Instance, frame: CFrame, name: string, key: string, color: Color3, use: Use): Part
	local base = part(parent, name, frame, Vector3.new(4.4, 3.6, 2.4), STEEL)
	part(
		parent,
		"Панель",
		frame * CFrame.new(0, 1.15, -1.25),
		Vector3.new(3.8, 0.55, 0.13),
		color,
		Enum.Material.Neon
	)
	label(base, name, UDim2.fromScale(5.7, 1.05), Vector3.new(0, 2.45, 0))
	prompt(base, "Открыть", name, use, "menu", key)
	return base
end

local function gate(model: Model, pad: CFrame, y: number): { Part }
	local shutters = {}
	for _, side in { -1, 1 } do
		local panel = part(
			model,
			"Створка шлюза",
			pad * CFrame.new(4.4 * side, y, 0),
			Vector3.new(8.8, 0.65, 17.6),
			STEEL
		)
		table.insert(shutters, panel)
		part(
			model,
			"Направляющая",
			pad * CFrame.new(9.2 * side, y, 0),
			Vector3.new(0.45, 0.8, 17.6),
			ICE,
			Enum.Material.Neon
		)
	end
	return shutters
end

local function moveGate(plot: Plot, name: string, open: boolean): ()
	local state = if open then "open" else "closed"
	if plot.Gates[name] == state then
		return
	end
	plot.Gates[name] = state
	local pieces: { Part } = if name == "upper" then plot.Upper else plot.Lower
	local y = if name == "upper" then 12 else 0.7
	for index, piece in pieces do
		local side = if index == 1 then -1 else 1
		if name == "lower" then
			piece.CanCollide = not open
		end
		local target = plot.Pad * CFrame.new((if open then 13.4 else 4.4) * side, y, 0)
		TweenService:Create(piece, TweenInfo.new(0.36, Enum.EasingStyle.Quad), { CFrame = target }):Play()
	end
end

function World.Build(useForPlot: (number, Player, string, string?) -> ()): { Plot }
	Lighting.Ambient = Color3.fromRGB(140, 152, 167)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 153, 173)
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = 0.3
	Lighting.ClockTime = 0
	local root = Instance.new("Folder")
	root.Name = "CORPA — испытательная лаборатория"
	root.Parent = Workspace

	local corners = {
		Vector3.new(-49, 0, -57),
		Vector3.new(49, 0, -57),
		Vector3.new(75, 0, -41),
		Vector3.new(75, 0, 41),
		Vector3.new(49, 0, 57),
		Vector3.new(-49, 0, 57),
		Vector3.new(-75, 0, 41),
		Vector3.new(-75, 0, -41),
	}
	part(root, "Пол лаборатории", CFrame.new(0, -3, 0), Vector3.new(152, 2, 115), FLOOR)
	for index, from in corners do
		local to = corners[index % #corners + 1]
		local center = (from + to) / 2
		local frame = CFrame.lookAt(center, to)
		part(
			root,
			"Стена октагона",
			frame * CFrame.new(0, 8, 0),
			Vector3.new(1.8, 22, (to - from).Magnitude + 1),
			STEEL
		)
		part(
			root,
			"Световая полоса",
			frame * CFrame.new(0, 13.7, 0),
			Vector3.new(1.95, 0.24, (to - from).Magnitude - 1),
			ICE,
			Enum.Material.Neon
		)
	end
	part(root, "Перекрытие", CFrame.new(0, 19.5, 0), Vector3.new(153, 1, 115), INK).CastShadow = false
	part(
		root,
		"Главный коридор",
		CFrame.new(0, -0.6, 0),
		Vector3.new(145, 1.2, 18),
		FLOOR,
		Enum.Material.Slate
	)
	for _, z in { -8.7, 8.7 } do
		part(
			root,
			"Разметка коридора",
			CFrame.new(0, 0.02, z),
			Vector3.new(138, 0.04, 0.2),
			ICE,
			Enum.Material.Neon
		).CanCollide =
			false
	end
	for _, x in { -52, -26, 0, 26, 52 } do
		local beam = part(
			root,
			"Рабочий свет",
			CFrame.new(x, 18.6, 0),
			Vector3.new(2, 0.4, 15),
			ICE,
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Range = 52
		light.Brightness = 2
		light.Color = Color3.fromRGB(204, 232, 255)
		light.Parent = beam
	end
	local boardPositions: { [string]: number } = { localLobby = -21, global = 21 }
	for key, x in boardPositions do
		local frame = CFrame.new(x, 1.6, 0)
		local stand = part(root, "Терминал рейтинга", frame, Vector3.new(8, 3.2, 2.4), STEEL)
		boards[key] = label(stand, "", UDim2.fromScale(14, 8.5), Vector3.new(0, 6.2, 0))
	end

	for index = 1, Config.MaxPlayers do
		local row = if index <= 3 then 1 else -1
		local x = ((index - 1) % 3 - 1) * 44
		local origin = CFrame.new(x, 0, row * 30) * CFrame.Angles(0, if row == 1 then 0 else math.pi, 0)
		local pad = origin * CFrame.new(1.8, -0.525, 2)
		local model = Instance.new("Model")
		model.Name = `Сектор 0{index}`
		model.Parent = root
		local function use(player: Player, action: string, key: string?)
			useForPlot(index, player, action, key)
		end
		local color = if row == 1 then ICE else AMBER
		local fixture = part(
			model,
			"Освещение сектора",
			origin * CFrame.new(-6, 16, 0),
			Vector3.new(2, 0.24, 19),
			Color3.fromRGB(221, 241, 255),
			Enum.Material.Neon
		)
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = 145
		light.Range = 33
		light.Brightness = 2.8
		light.Color = fixture.Color
		light.Parent = fixture
		-- Пол состоит из плит вокруг проёма нижнего шлюза.
		for _, strip in
			{
				{ -13.5, 0, 13, 36 },
				{ 15.3, 0, 9.4, 36 },
				{ 1.8, -12.4, 17.6, 11.2 },
				{ 1.8, 14.4, 17.6, 7.2 },
			}
		do
			part(
				model,
				"Настил сектора",
				origin * CFrame.new(strip[1], -0.45, strip[2]),
				Vector3.new(strip[3], 0.9, strip[4]),
				FLOOR,
				Enum.Material.DiamondPlate
			)
		end
		for _, side in { -1, 1 } do
			part(
				model,
				"Граница сектора",
				origin * CFrame.new(20 * side, 1.3, 0),
				Vector3.new(0.26, 2.6, 36),
				STEEL
			)
			part(
				model,
				"Разметка",
				origin * CFrame.new(19.65 * side, 0.05, 0),
				Vector3.new(0.16, 0.1, 35),
				color,
				Enum.Material.Neon
			)
		end
		part(model, "Перекладина", origin * CFrame.new(0, 8, -17), Vector3.new(39, 1, 1), STEEL)
		local ownerPart = part(
			model,
			"Табло сектора",
			origin * CFrame.new(0, 7.6, -17.4),
			Vector3.new(12, 0.3, 0.6),
			color,
			Enum.Material.Neon
		)
		local owner = label(
			ownerPart,
			`СЕКТОР 0{index} · СВОБОДЕН`,
			UDim2.fromScale(14, 1.5),
			Vector3.new(0, 1.3, 0)
		)
		part(
			model,
			"Входной настил",
			origin * CFrame.new(-4.2, -0.4, -19.5),
			Vector3.new(12, 0.8, 3.1),
			FLOOR,
			Enum.Material.DiamondPlate
		)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = `Вход 0{index}`
		spawn.CFrame = origin * CFrame.new(-4.2, 0.2, -15) * CFrame.Angles(0, math.pi, 0)
		spawn.Size = Vector3.new(3, 0.4, 3)
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.Transparency = 1
		spawn.Duration = 0
		spawn.Parent = model
		local stations = {
			terminal = station(model, origin * CFrame.new(-15.5, 1.8, -7), "Заказы", "terminal", color, use),
			inventory = station(model, origin * CFrame.new(-15.5, 1.8, 0), "Склад", "inventory", color, use),
			collections = station(
				model,
				origin * CFrame.new(-15.5, 1.8, 7),
				"Коллекции",
				"collections",
				color,
				use
			),
		}
		local storage = {}
		for i = 1, 10 do
			local shelf = part(
				model,
				"Складской модуль",
				origin * CFrame.new(-18.6, 0.8 + ((i - 1) % 5) * 1.55, 2.1 + 3 * math.floor((i - 1) / 5)),
				Vector3.new(1.4, 1.4, 2.6),
				STEEL
			)
			table.insert(storage, shelf)
		end
		local stands = {}
		for slot, size in Catalog.DisplaySizes do
			local isSmall = size == "small"
			local standX = if isSmall then 12.9 + ((slot - 1) % 2) * 4.3 else if slot == 7 then -6.6 else 5
			local standZ = if isSmall then -10 + math.floor((slot - 1) / 2) * 5 else 14.5
			local width = if isSmall then 3.4 else if slot == 7 then 5 else 8
			local base = part(
				model,
				`Витрина {slot}`,
				origin * CFrame.new(standX, 0.65, standZ),
				Vector3.new(width, 1.3, if isSmall then 3.5 else 5.5),
				STEEL
			)
			part(
				model,
				"Подсветка витрины",
				base.CFrame * CFrame.new(0, -0.48, 0),
				Vector3.new(width + 0.08, 0.13, base.Size.Z + 0.08),
				color,
				Enum.Material.Neon
			)
			prompt(base, "Управлять", `Витрина {slot}`, use, "menu", tostring(slot), 7)
			stands[slot] = base
		end
		local clear = part(
			model,
			"Индикация шлюза",
			pad * CFrame.new(0, 0.88, -8.5),
			Vector3.new(16.8, 0.08, 0.18),
			color,
			Enum.Material.Neon
		)
		clear.CanCollide = false
		local button =
			part(model, "Пульт добычи", pad * CFrame.new(-9.2, 1.9, -7), Vector3.new(1, 2.2, 1), STEEL)
		prompt(button, "Добыча", "Управление добычей", use, "menu", "loot")
		for _, xPost in { -9, 9 } do
			for _, zPost in { -9, 9 } do
				part(
					model,
					"Стойка шлюза",
					pad * CFrame.new(xPost, 6.2, zPost),
					Vector3.new(0.5, 12, 0.5),
					STEEL
				)
			end
		end
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
			Clear = clear,
			Button = button,
			Upper = gate(model, pad, 12),
			Lower = gate(model, pad, 0.7),
			Gates = {},
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
	local model = Instance.new("Model")
	model.Name = if order.Variant then Catalog.Variants[order.Kind] else Catalog.Containers[order.Kind]
	plot.OpenParts = {}
	local function component(name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
		return part(model, name, cf, size, color, material)
	end
	if order.Kind == "cargo" then
		local blue = if order.Variant then Color3.fromRGB(85, 108, 148) else Color3.fromRGB(59, 97, 130)
		component("Пол контейнера", CFrame.new(0, 0.15, 0), Vector3.new(14, 0.3, 15.9), blue)
		component("Крыша", CFrame.new(0, 7.1, 0), Vector3.new(14, 0.4, 16), blue)
		component("Задняя стенка", CFrame.new(0, 3.6, 7.8), Vector3.new(14, 7, 0.4), blue)
		for _, side in { -1, 1 } do
			component("Борт", CFrame.new(6.8 * side, 3.6, 0), Vector3.new(0.4, 7, 16), blue)
			for z = -6, 6, 2 do
				component("Ребро", CFrame.new(7 * side, 3.6, z), Vector3.new(0.34, 6.6, 0.32), STEEL)
			end
			local door =
				component("Створка", CFrame.new(3.45 * side, 3.6, -7.8), Vector3.new(6.85, 6.9, 0.35), blue)
			table.insert(plot.OpenParts, door)
			local lock =
				component("Фиксатор", CFrame.new(2.2 * side, 3.3, -8.16), Vector3.new(0.42, 2.7, 0.36), AMBER)
			table.insert(plot.OpenParts, lock)
			prompt(lock, "Разблокировать", model.Name, use, "open", tostring(if side == -1 then 1 else 2))
		end
		local handle =
			component("Открыть створки", CFrame.new(0, 3.5, -8.16), Vector3.new(0.65, 1, 0.35), ICE)
		table.insert(plot.OpenParts, handle)
		prompt(handle, "Открыть створки", model.Name, use, "open", "doors")
	else
		local colors: { [string]: Color3 } = {
			box = Color3.fromRGB(155, 108, 67),
			crate = Color3.fromRGB(116, 82, 57),
			safe = Color3.fromRGB(78, 94, 108),
			secret = Color3.fromRGB(79, 53, 115),
		}
		local height = if order.Kind == "box" then 2.7 else 4.2
		local width = if order.Kind == "box" then 4.6 else 6
		local body = component(
			"Корпус",
			CFrame.new(0, height * 0.5, 0),
			Vector3.new(width, height, width),
			colors[order.Kind],
			if order.Kind == "crate" then Enum.Material.WoodPlanks else nil
		)
		for _, side in { -1, 1 } do
			component(
				"Кромка",
				CFrame.new(side * (width / 2 - 0.17), height - 0.2, 0),
				Vector3.new(0.25, 0.25, width),
				if order.Variant then ICE else STEEL
			)
		end
		if order.Kind == "box" then
			for index = 1, 4 do
				local tape = component(
					"Скотч",
					CFrame.new(0, height + 0.035, (index - 2.5) * 1.08),
					Vector3.new(0.65, 0.08, 1.09),
					AMBER,
					Enum.Material.SmoothPlastic
				)
				table.insert(plot.OpenParts, tape)
			end
			prompt(body, "Отклеить скотч", model.Name, use, "open", nil, 10)
			clickToOpen(body, use)
		elseif order.Kind == "crate" then
			for index = 1, 4 do
				local x = if index % 2 == 1 then -2.2 else 2.2
				local z = if index <= 2 then -3.1 else 3.1
				local fastener =
					component("Крепление", CFrame.new(x, 2.6, z), Vector3.new(0.48, 0.74, 0.28), AMBER)
				table.insert(plot.OpenParts, fastener)
				local interaction =
					prompt(fastener, "Сломать крепление", model.Name, use, "open", tostring(index), 7)
				interaction.KeyboardKeyCode = if index % 2 == 1 then Enum.KeyCode.E else Enum.KeyCode.F
				interaction.GamepadKeyCode = if index % 2 == 1 then Enum.KeyCode.ButtonX else Enum.KeyCode.ButtonY
			end
		elseif order.Kind == "safe" then
			local door = component(
				"Дверца сейфа",
				CFrame.new(0, height / 2, -3.04),
				Vector3.new(width - 0.45, height - 0.45, 0.26),
				STEEL
			)
			table.insert(plot.OpenParts, door)
			local dial = component(
				"Ручка",
				CFrame.new(0.8, 2.3, -3.28) * CFrame.Angles(0, math.pi / 2, 0),
				Vector3.new(0.3, 0.92, 0.92),
				AMBER
			)
			dial.Shape = Enum.PartType.Cylinder
			local marker =
				component("Метка ручки", CFrame.new(0.8, 2.62, -3.46), Vector3.new(0.12, 0.17, 0.045), INK)
			marker.CanCollide = false
			table.insert(plot.OpenParts, marker)
			table.insert(plot.OpenParts, dial)
			prompt(dial, "Вращать ручку", model.Name, use, "open", nil, 9)
		else
			local orb = component(
				"Заряд",
				CFrame.new(0, height + 0.15, 0),
				Vector3.new(3.6, 0.35, 3.6),
				Color3.fromRGB(146, 87, 208),
				Enum.Material.Neon
			)
			table.insert(plot.OpenParts, orb)
			local glow = Instance.new("PointLight")
			glow.Color = orb.Color
			glow.Range = 14
			glow.Brightness = 0.4
			glow.Parent = orb
			prompt(body, "Усилить свечение", model.Name, use, "open", nil, 10)
			clickToOpen(body, use)
		end
	end
	model.WorldPivot = CFrame.new()
	model.Parent = plot.Model
	return model
end

function World.RotateDial(plot: Plot, phase: number): ()
	local marker = plot.OpenParts[3]
	if marker then
		local center = plot.Pad * CFrame.new(0.8, 3.35, -3.46)
		marker.CFrame = center * CFrame.Angles(0, 0, -math.pi * 2 * phase) * CFrame.new(0, 0.32, 0)
	end
end

local function progress(order: Types.Order, marker: number): boolean
	return bit32.btest(order.Progress, bit32.lshift(1, marker - 1))
end

local function enabled(partObject: Part, active: boolean): ()
	local action = partObject:FindFirstChildOfClass("ProximityPrompt")
	if action then
		action.Enabled = active
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
	local opened = order.Stage == "open" or order.Stage == "clear"
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
	local visual = `{order.Stage}:{order.Progress}`
	if plot.VisualState ~= visual then
		plot.VisualState = visual
		for _, child in model:GetDescendants() do
			if child:IsA("ProximityPrompt") then
				child.Enabled = order.Stage == "sealed"
			elseif child:IsA("ClickDetector") then
				child.MaxActivationDistance = if order.Stage == "sealed" then 10 else 0
			end
		end
		if order.Kind == "box" or order.Kind == "crate" then
			for index, piece in plot.OpenParts do
				local removed = if order.Kind == "box" then index <= order.Progress else progress(order, index)
				piece.Transparency = if removed then 1 else 0
				piece.CanCollide = not removed
				if removed then
					enabled(piece, false)
				end
			end
		elseif order.Kind == "cargo" then
			for index = 1, 2 do
				local door, lock = plot.OpenParts[index * 2 - 1], plot.OpenParts[index * 2]
				local removed = progress(order, index)
				lock.Transparency = if removed then 1 else 0
				lock.CanCollide = not removed
				enabled(lock, not removed and order.Stage == "sealed")
				if opened then
					door.CanCollide = false
					local side = if index == 1 then -1 else 1
					local goal = base * CFrame.new(6.85 * side, 3.6, -11.2) * CFrame.Angles(0, math.pi / 2, 0)
					if scatter then
						TweenService:Create(door, TweenInfo.new(0.45), { CFrame = goal }):Play()
					else
						door.CFrame = goal
					end
				end
			end
			local handle = plot.OpenParts[5]
			handle.CanCollide = false
			handle.Transparency = if opened then 1 else 0
			enabled(handle, order.Progress == 3 and order.Stage == "sealed")
		elseif order.Kind == "secret" then
			local orb = plot.OpenParts[1]
			local glow = orb:FindFirstChildOfClass("PointLight")
			if glow then
				glow.Brightness = 0.4 + order.Progress * 0.75
			end
		end
		if opened and order.Kind ~= "cargo" then
			local body = model:FindFirstChild("Корпус") :: Part
			body.Size = Vector3.new(body.Size.X, 0.5, body.Size.Z)
			body.CFrame = base * CFrame.new(0, 0.25, 0)
			body.CanCollide = false
			for _, object in model:GetChildren() do
				if object:IsA("BasePart") and object ~= body then
					object.CanCollide = false
					object.Transparency = if order.Kind == "safe" and object.Name == "Дверца сейфа"
						then 0
						else 1
				end
			end
			if order.Kind == "safe" then
				local door = plot.OpenParts[1]
				door.CFrame = base * CFrame.new(-2.8, 2.1, -5.8) * CFrame.Angles(0, -math.pi / 2, 0)
			end
		end
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
				animate(prop, base * CFrame.new(0, 2.1, 0), target, 0.55, 2.3)
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
