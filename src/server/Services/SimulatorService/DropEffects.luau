--!strict
-- Эффекты выпадения добычи из контейнера. Какой эффект играть, выбирает владелец сектора; у каждого эффекта
-- своя анимация (Style в Catalog.DropEffects), а не только свой цвет: конфетти — разлетающиеся бумажки,
-- огонь — вспышка и языки пламени, лёд — кристаллы и снег, пустота — воронка, затягивающая и выбрасывающая
-- частицы, золото — дождь из монет.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)

local DropEffects = {}

local rng = Random.new()

local function configure(piece: BasePart): ()
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
end

-- Расходящаяся волна по полу.
local function ring(at: CFrame, color: Color3, radius: number?, life: number?): ()
	local disc = Instance.new("Part")
	disc.Name = "Волна эффекта"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.12, 2, 2)
	disc.CFrame = at * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = color
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.35
	disc.Anchored = true
	configure(disc)
	disc.Parent = Workspace
	local size = (radius or 13)
	TweenService:Create(
		disc,
		TweenInfo.new(life or 0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.12, size, size), Transparency = 1 }
	):Play()
	Debris:AddItem(disc, (life or 0.7) + 0.3)
end

-- Вспышка света в точке эффекта.
local function flash(parent: Instance, color: Color3, brightness: number, range: number, life: number): ()
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	TweenService:Create(light, TweenInfo.new(life), { Brightness = 0 }):Play()
end

-- Базовый излучатель частиц: общий набор настроек, поверх которого каждый стиль меняет своё.
local function emitter(parent: Instance, color: ColorSequence, size: number, lifetime: NumberRange): ParticleEmitter
	local result = Instance.new("ParticleEmitter")
	result.Enabled = false
	result.Color = color
	result.LightEmission = 0.8
	result.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	result.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	result.Lifetime = lifetime
	result.SpreadAngle = Vector2.new(180, 180)
	result.Rotation = NumberRange.new(0, 360)
	result.RotSpeed = NumberRange.new(-120, 120)
	result.Parent = parent
	return result
end

-- Деталь-«конфетти»: летит под действием физики, но почти без веса, плавно гаснет и удаляется.
-- gravityShare — доля тяжести, которую компенсирует сила (0 — падает как обычно, 1 — парит).
local function flyer(
	at: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	velocity: Vector3,
	spin: Vector3,
	gravityShare: number,
	life: number
): Part
	local piece = Instance.new("Part")
	piece.Name = "Элемент эффекта"
	piece.Size = size
	piece.CFrame = at * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
	piece.Color = color
	piece.Material = material
	piece.Massless = false
	configure(piece)
	piece.Parent = Workspace
	local attachment = Instance.new("Attachment")
	attachment.Parent = piece
	local force = Instance.new("VectorForce")
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.new(0, piece.AssemblyMass * Workspace.Gravity * gravityShare, 0)
	force.Parent = piece
	piece.AssemblyLinearVelocity = velocity
	piece.AssemblyAngularVelocity = spin
	task.delay(life * 0.65, function()
		if piece.Parent then
			TweenService:Create(piece, TweenInfo.new(life * 0.35), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(piece, life)
	return piece
end

local function around(radius: number): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = radius * math.sqrt(rng:NextNumber())
	return Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

-- ===== Стили =====

local STYLES: { [string]: (anchor: Part, at: CFrame, effect: Catalog.DropEffect) -> () } = {}

-- Тёплые искры (эффект по умолчанию).
STYLES.sparks = function(anchor, at, effect)
	local sparks = emitter(anchor, ColorSequence.new(effect.Primary, effect.Secondary), 0.7, NumberRange.new(0.8, 1.5))
	sparks.Speed = NumberRange.new(effect.Speed * 0.5, effect.Speed)
	sparks.Acceleration = Vector3.new(0, effect.Gravity, 0)
	sparks:Emit(effect.Count)
	flash(anchor, effect.Primary, 3, 16, 0.8)
	ring(at, effect.Primary)
end

-- Конфетти: настоящие разноцветные бумажки, которые вылетают вверх, кружатся и медленно падают.
STYLES.confetti = function(anchor, at, effect)
	local palette = {
		Color3.fromRGB(255, 99, 160),
		Color3.fromRGB(91, 232, 222),
		Color3.fromRGB(255, 214, 90),
		Color3.fromRGB(130, 235, 120),
		Color3.fromRGB(170, 132, 255),
		Color3.fromRGB(255, 140, 70),
	}
	for index = 1, math.min(effect.Count, 44) do
		local lateral = around(rng:NextNumber(6, 17))
		flyer(
			at,
			Vector3.new(0.38, 0.04, 0.24),
			palette[(index - 1) % #palette + 1],
			Enum.Material.SmoothPlastic,
			Vector3.new(lateral.X, rng:NextNumber(20, 36), lateral.Z),
			Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(-14, 14), rng:NextNumber(-14, 14)),
			0.88,
			rng:NextNumber(2.2, 3.2)
		)
	end
	local pop = emitter(anchor, ColorSequence.new(effect.Primary, effect.Secondary), 0.5, NumberRange.new(0.4, 0.8))
	pop.Speed = NumberRange.new(10, 24)
	pop.Acceleration = Vector3.new(0, -20, 0)
	pop:Emit(18)
	flash(anchor, effect.Primary, 2, 14, 0.5)
	ring(at, effect.Primary, 10, 0.5)
end

-- Огненный взрыв: огненный шар, языки пламени вверх, дым и россыпь углей.
STYLES.fire = function(anchor, at, effect)
	local ball = Instance.new("Part")
	ball.Name = "Огненный шар"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 3
	ball.CFrame = at
	ball.Color = effect.Primary
	ball.Material = Enum.Material.Neon
	ball.Transparency = 0.15
	ball.Anchored = true
	configure(ball)
	ball.Parent = Workspace
	TweenService:Create(
		ball,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * 13, Transparency = 1 }
	):Play()
	Debris:AddItem(ball, 0.7)

	local flames = emitter(
		anchor,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 140)),
			ColorSequenceKeypoint.new(0.35, effect.Primary),
			ColorSequenceKeypoint.new(1, effect.Secondary),
		}),
		3.4,
		NumberRange.new(0.7, 1.3)
	)
	flames.LightEmission = 1
	flames.SpreadAngle = Vector2.new(65, 65)
	flames.Speed = NumberRange.new(8, 17)
	flames.Acceleration = Vector3.new(0, 16, 0)
	flames:Emit(34)

	local embers = emitter(anchor, ColorSequence.new(effect.Primary, effect.Secondary), 0.35, NumberRange.new(1.2, 2.2))
	embers.Speed = NumberRange.new(effect.Speed * 0.5, effect.Speed)
	embers.Acceleration = Vector3.new(0, effect.Gravity, 0)
	embers:Emit(effect.Count)

	local smoke = emitter(anchor, ColorSequence.new(Color3.fromRGB(60, 50, 46)), 4, NumberRange.new(1.2, 2))
	smoke.LightEmission = 0
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	smoke.Speed = NumberRange.new(2, 5)
	smoke.Acceleration = Vector3.new(0, 6, 0)
	smoke:Emit(14)

	flash(anchor, effect.Primary, 8, 26, 1.0)
	ring(at, effect.Primary, 17, 0.55)
end

-- Ледяная пыль: кристаллы льда, холодный туман и медленно падающий иней.
STYLES.frost = function(anchor, at, effect)
	for _ = 1, 16 do
		local lateral = around(rng:NextNumber(5, 14))
		local shard = flyer(
			at,
			Vector3.new(0.28, rng:NextNumber(0.9, 1.7), 0.28),
			effect.Primary:Lerp(effect.Secondary, rng:NextNumber()),
			Enum.Material.Ice,
			Vector3.new(lateral.X, rng:NextNumber(10, 22), lateral.Z),
			Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6), rng:NextNumber(-6, 6)),
			0.8,
			rng:NextNumber(2, 2.8)
		)
		shard.Reflectance = 0.2
		shard.Transparency = 0.2
	end
	local mist = emitter(anchor, ColorSequence.new(effect.Primary, effect.Secondary), 5, NumberRange.new(1.4, 2.2))
	mist.LightEmission = 0.4
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
	mist.Speed = NumberRange.new(2, 6)
	mist.Acceleration = Vector3.new(0, -1, 0)
	mist:Emit(14)
	local snow = emitter(anchor, ColorSequence.new(Color3.new(1, 1, 1), effect.Primary), 0.3, NumberRange.new(2.2, 3.2))
	snow.Speed = NumberRange.new(2, effect.Speed)
	snow.Acceleration = Vector3.new(0, -3, 0)
	snow:Emit(effect.Count)
	flash(anchor, effect.Primary, 4, 18, 1.2)
	ring(at, effect.Primary, 15, 0.8)
end

-- Разлом пустоты: частицы затягиваются внутрь, шар схлопывается и выбрасывает всё наружу.
STYLES.void = function(anchor, at, effect)
	anchor.Size = Vector3.one * 11
	local pull = emitter(anchor, ColorSequence.new(effect.Primary, effect.Secondary), 0.9, NumberRange.new(0.4, 0.6))
	pull.Shape = Enum.ParticleEmitterShape.Sphere
	pull.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pull.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	pull.SpreadAngle = Vector2.zero
	pull.Speed = NumberRange.new(14, 22)
	pull:Emit(effect.Count)

	local core = Instance.new("Part")
	core.Name = "Ядро разлома"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * 7
	core.CFrame = at
	core.Color = effect.Secondary
	core.Material = Enum.Material.Neon
	core.Transparency = 0.1
	core.Anchored = true
	configure(core)
	core.Parent = Workspace
	TweenService
		:Create(core, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 0.8 })
		:Play()
	task.delay(0.4, function()
		TweenService:Create(
			core,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.one * 12, Transparency = 1, Color = effect.Primary }
		):Play()
		if anchor.Parent then
			local burst =
				emitter(anchor, ColorSequence.new(effect.Primary, effect.Secondary), 0.8, NumberRange.new(0.7, 1.3))
			burst.Speed = NumberRange.new(effect.Speed * 0.6, effect.Speed)
			burst.Acceleration = Vector3.new(0, effect.Gravity, 0)
			burst:Emit(effect.Count)
			flash(anchor, effect.Primary, 6, 22, 0.9)
		end
		ring(at, effect.Primary, 16, 0.6)
	end)
	Debris:AddItem(core, 1)
	flash(anchor, effect.Secondary, 3, 14, 0.5)
end

-- Золотой дождь: падающие вращающиеся монеты и золотая пыль.
STYLES.gold = function(anchor, at, effect)
	for _ = 1, 34 do
		local start = at * CFrame.new(around(7) + Vector3.new(0, rng:NextNumber(5, 11), 0))
		local coin = flyer(
			start,
			Vector3.new(0.1, 0.95, 0.95),
			effect.Primary:Lerp(effect.Secondary, rng:NextNumber()),
			Enum.Material.Metal,
			Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-12, 2), rng:NextNumber(-3, 3)),
			Vector3.new(rng:NextNumber(-16, 16), rng:NextNumber(-16, 16), rng:NextNumber(-16, 16)),
			0.55,
			rng:NextNumber(1.8, 2.6)
		)
		coin.Shape = Enum.PartType.Cylinder
		coin.Reflectance = 0.35
	end
	local glitter = emitter(anchor, ColorSequence.new(effect.Primary, effect.Secondary), 0.4, NumberRange.new(1, 1.8))
	glitter.Speed = NumberRange.new(effect.Speed * 0.4, effect.Speed)
	glitter.Acceleration = Vector3.new(0, effect.Gravity, 0)
	glitter:Emit(effect.Count)
	flash(anchor, effect.Primary, 5, 20, 1.0)
	ring(at, effect.Primary, 14, 0.6)
end

-- Проигрывает эффект в точке at. delay — пауза до момента вылета добычи.
function DropEffects.play(at: CFrame, key: string, delay: number): ()
	local effect = Catalog.dropEffect(key) or Catalog.dropEffect(Catalog.DefaultEffect)
	if not effect then
		return
	end
	local style = STYLES[effect.Style] or STYLES.sparks
	task.delay(delay, function()
		local anchor = Instance.new("Part")
		anchor.Name = "Эффект выпадения"
		anchor.Size = Vector3.one * 0.4
		anchor.CFrame = at
		anchor.Transparency = 1
		anchor.Anchored = true
		configure(anchor)
		anchor.Parent = Workspace
		style(anchor, at, effect)
		Debris:AddItem(anchor, 3.5)
	end)
end

return DropEffects
