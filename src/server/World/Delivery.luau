--!strict
-- Container movement: gates, the pipe from Backrooms, the rift and path animation.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Audio = require(script.Parent.Parent.Network.Audio)
local Sector = require(script.Parent.Sector)
local Props = require(script.Parent.Props)
local STEEL = Props.STEEL
local ICE = Props.ICE
local AMBER = Props.AMBER

local Delivery = {}

local GATE_MOVE_TIME = 0.36
local DISPOSAL_TRAVEL_TIME = 1.05
local PIPE_TRAVEL_FRACTION = 0.55
local CONTAINER_PIVOT_HEIGHT = 1.05
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

local function shaftLight(parent: Part, color: Color3): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 0.65
	light.Range = 15
	light.Enabled = false
	light.Parent = parent
	return light
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

Delivery.GATE_MOVE_TIME = GATE_MOVE_TIME
Delivery.DISPOSAL_TRAVEL_TIME = DISPOSAL_TRAVEL_TIME
Delivery.CONTAINER_PIVOT_HEIGHT = CONTAINER_PIVOT_HEIGHT
Delivery.moveGate = moveGate
Delivery.shaftLight = shaftLight
Delivery.animate = animate
Delivery.setBackrooms = setBackrooms
Delivery.deliverThroughPipe = deliverThroughPipe

return Delivery
