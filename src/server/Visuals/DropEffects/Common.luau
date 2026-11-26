--!strict
-- Part, particle and light helpers shared by drop effect styles.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Common = {}

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

Common.rng = rng
Common.configure = configure
Common.ring = ring
Common.flash = flash
Common.emitter = emitter
Common.flyer = flyer
Common.around = around

return Common
