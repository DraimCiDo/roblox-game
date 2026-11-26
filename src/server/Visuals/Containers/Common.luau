--!strict
-- Shared parts of container models: types, colors, animation helpers and the part constructors.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Common = {}

export type Use = (Player, string, string?) -> ()
type Axis = "x" | "y" | "z"
type Hinge = { Pivot: Vector3, Axis: Vector3, Angle: number }

export type Kit = {
	Part: (Instance, string, CFrame, Vector3, Color3, Enum.Material?) -> Part,
	Prompt: (BasePart, string, string, Use, string, string?, number?) -> ProximityPrompt,
	Click: (Part, Use) -> (),
}

export type Layout = {
	Rest: { [Part]: CFrame },
	Hinges: { [Part]: Hinge },
	Named: { [string]: Part },
	Groups: { [string]: { Part } },
	Center: Vector3,
}

export type Build = { Kit: Kit, Model: Model, Layout: Layout, Use: Use, Variant: boolean }
export type Ctx = { Model: Model, Layout: Layout, Base: CFrame }

local STEEL = Color3.fromRGB(45, 56, 68)
local ICE = Color3.fromRGB(91, 232, 222)
local AMBER = Color3.fromRGB(255, 181, 86)
local INK = Color3.fromRGB(11, 20, 29)
local PAPER = Color3.fromRGB(240, 238, 228)
local IRON = Color3.fromRGB(122, 132, 146)
local RED = Color3.fromRGB(255, 70, 80)
local GREEN = Color3.fromRGB(80, 235, 130)

local rng = Random.new()

-- ============ Общие помощники ============

local function rand(low: number, high: number): number
	return rng:NextNumber(low, high)
end

local function swung(rest: CFrame, pivot: Vector3, axis: Vector3, angle: number): CFrame
	return CFrame.new(pivot) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-pivot) * rest
end

-- Плавно прогоняет step(alpha) от 0 до 1; при duration <= 0 сразу ставит конечное состояние.
local function drive(
	model: Model,
	duration: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection?,
	step: (number) -> (),
	done: (() -> ())?
): ()
	if duration <= 0 then
		step(1)
		if done then
			done()
		end
		return
	end
	local value = Instance.new("NumberValue")
	value.Parent = model
	local connection = value.Changed:Connect(function(alpha: number)
		if not model:GetAttribute("Releasing") then
			step(alpha)
		end
	end)
	local tween =
		TweenService:Create(value, TweenInfo.new(duration, style, direction or Enum.EasingDirection.Out), { Value = 1 })
	tween.Completed:Once(function(state: Enum.PlaybackState)
		connection:Disconnect()
		value:Destroy()
		if done and state == Enum.PlaybackState.Completed and not model:GetAttribute("Releasing") then
			done()
		end
	end)
	model.Destroying:Once(function()
		connection:Disconnect()
		tween:Cancel()
	end)
	tween:Play()
end

local function pose(ctx: Ctx, piece: Part, fraction: number): ()
	local hinge = ctx.Layout.Hinges[piece]
	piece.CFrame = ctx.Base * swung(ctx.Layout.Rest[piece], hinge.Pivot, hinge.Axis, hinge.Angle * fraction)
end

local function swingAll(
	ctx: Ctx,
	parts: { Part },
	duration: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection?,
	done: (() -> ())?
): ()
	-- Створки двигаются с плавным разгоном и торможением (Sine InOut), если направление не задано явно.
	drive(ctx.Model, duration, style, direction or Enum.EasingDirection.InOut, function(alpha)
		for _, piece in parts do
			pose(ctx, piece, alpha)
		end
	end, done)
end

local function fade(parts: { Part }, duration: number): ()
	for _, piece in parts do
		piece.CanCollide = false
		if duration <= 0 then
			piece.Transparency = 1
		else
			TweenService:Create(piece, TweenInfo.new(duration), { Transparency = 1 }):Play()
		end
	end
end

-- Искры и конфетти: короткий всплеск частиц без внешних текстур.
local function sparks(model: Model, at: CFrame, count: number, color: Color3, speed: number, gravity: number?): ()
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = at
	anchor.Parent = model
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -(gravity or 22), 0)
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.5
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(anchor, 2)
end

-- Осколки и обломки, которые разлетаются по физике и быстро исчезают.
local function shards(model: Model, source: Part, count: number, power: number): ()
	for _ = 1, count do
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(rand(0.2, 0.6), rand(0.1, 0.4), rand(0.2, 0.6))
		shard.Color = source.Color
		shard.Material = source.Material
		local offset = Vector3.new(
			(rng:NextNumber() - 0.5) * source.Size.X,
			(rng:NextNumber() - 0.5) * source.Size.Y,
			(rng:NextNumber() - 0.5) * source.Size.Z
		)
		shard.CFrame = source.CFrame * CFrame.new(offset) * CFrame.Angles(rand(0, 6), rand(0, 6), rand(0, 6))
		shard.CanQuery = false
		shard.CanTouch = false
		shard.Parent = model
		shard.AssemblyLinearVelocity =
			Vector3.new((rng:NextNumber() - 0.5) * power, power * rand(0.5, 1.2), (rng:NextNumber() - 0.5) * power)
		shard.AssemblyAngularVelocity = Vector3.new(rand(-12, 12), rand(-12, 12), rand(-12, 12))
		Debris:AddItem(shard, 1.8)
	end
end

-- Отлетающая копия детали (скоба, доска, крышка): оригинал остаётся на месте и скрывается.
local function launch(model: Model, source: Part, velocity: Vector3): ()
	local piece = Instance.new("Part")
	piece.Size = source.Size
	piece.Color = source.Color
	piece.Material = source.Material
	piece.CFrame = source.CFrame
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CanCollide = false
	piece.Parent = model
	piece.AssemblyLinearVelocity = velocity
	piece.AssemblyAngularVelocity = Vector3.new(rand(-8, 8), rand(-8, 8), rand(-8, 8))
	Debris:AddItem(piece, 1.5)
end

local function flash(light: PointLight, peak: number, rest: number): ()
	TweenService:Create(light, TweenInfo.new(0.12), { Brightness = peak }):Play()
	task.delay(0.14, function()
		if light.Parent then
			TweenService:Create(light, TweenInfo.new(0.5), { Brightness = rest }):Play()
		end
	end)
end

local function setPrompt(owner: Part?, text: string): ()
	local action = if owner then owner:FindFirstChildWhichIsA("ProximityPrompt") else nil
	if action then
		action.ActionText = text
	end
end

local function sign(piece: Part, face: Enum.NormalId, text: string, color: Color3): ()
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = piece
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(1, 1)
	caption.BackgroundTransparency = 1
	caption.Text = text
	caption.TextColor3 = color
	caption.TextScaled = true
	caption.Font = Enum.Font.GothamBlack
	caption.Parent = gui
end

local function bits(mask: number): number
	local count = 0
	for index = 0, 7 do
		if bit32.btest(mask, bit32.lshift(1, index)) then
			count += 1
		end
	end
	return count
end

-- ============ Конструктор моделей ============

local function add(b: Build, name: string, frame: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	local piece = b.Kit.Part(b.Model, name, frame, size, color, material)
	b.Layout.Rest[piece] = frame
	return piece
end

local function addCylinder(
	b: Build,
	name: string,
	position: Vector3,
	axis: Axis,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	local turn = if axis == "y"
		then CFrame.Angles(0, 0, math.pi / 2)
		elseif axis == "z" then CFrame.Angles(0, math.pi / 2, 0)
		else CFrame.identity
	local piece = add(b, name, CFrame.new(position) * turn, Vector3.new(length, diameter, diameter), color, material)
	piece.Shape = Enum.PartType.Cylinder
	return piece
end

local function join(b: Build, group: string, piece: Part): ()
	local list = b.Layout.Groups[group]
	if not list then
		list = {}
		b.Layout.Groups[group] = list
	end
	table.insert(list, piece)
end

local function hinge(b: Build, piece: Part, pivot: Vector3, axis: Vector3, angle: number): ()
	b.Layout.Hinges[piece] = { Pivot = pivot, Axis = axis, Angle = angle }
end

local function light(owner: Part, color: Color3, range: number): PointLight
	local result = Instance.new("PointLight")
	result.Color = color
	result.Range = range
	result.Brightness = 0
	result.Parent = owner
	return result
end

Common.bits = bits
Common.ICE = ICE
Common.INK = INK
Common.PAPER = PAPER
Common.drive = drive
Common.swingAll = swingAll
Common.fade = fade
Common.sparks = sparks
Common.flash = flash
Common.setPrompt = setPrompt
Common.sign = sign
Common.add = add
Common.join = join
Common.hinge = hinge
Common.light = light
Common.AMBER = AMBER
Common.IRON = IRON
Common.rand = rand
Common.launch = launch
Common.STEEL = STEEL
Common.RED = RED
Common.GREEN = GREEN
Common.addCylinder = addCylinder
Common.rng = rng
Common.shards = shards

return Common
