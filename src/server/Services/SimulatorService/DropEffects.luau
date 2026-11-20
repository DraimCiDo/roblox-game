--!strict
-- Визуальные эффекты выпадения добычи из контейнера. Какой эффект играть, выбирает владелец сектора.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)

local DropEffects = {}

local function ring(at: CFrame, effect: Catalog.DropEffect): ()
	local disc = Instance.new("Part")
	disc.Name = "Волна эффекта"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.12, 2, 2)
	disc.CFrame = at * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = effect.Primary
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.35
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Parent = Workspace
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(disc, info, { Size = Vector3.new(0.12, 13, 13), Transparency = 1 }):Play()
	Debris:AddItem(disc, 1)
end

-- Проигрывает эффект в точке at. delay — пауза до момента вылета добычи.
function DropEffects.play(at: CFrame, key: string, delay: number): ()
	local effect = Catalog.dropEffect(key) or Catalog.dropEffect(Catalog.DefaultEffect)
	if not effect then
		return
	end
	task.delay(delay, function()
		local anchor = Instance.new("Part")
		anchor.Name = "Эффект выпадения"
		anchor.Size = Vector3.one * 0.4
		anchor.CFrame = at
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Parent = Workspace

		local emitter = Instance.new("ParticleEmitter")
		emitter.Enabled = false
		emitter.Color = ColorSequence.new(effect.Primary, effect.Secondary)
		emitter.LightEmission = 0.8
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.8, 1.5)
		emitter.Speed = NumberRange.new(effect.Speed * 0.5, effect.Speed)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, effect.Gravity, 0)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-120, 120)
		emitter.Parent = anchor
		emitter:Emit(effect.Count)

		local light = Instance.new("PointLight")
		light.Color = effect.Primary
		light.Range = 16
		light.Brightness = 3
		light.Parent = anchor
		TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()

		ring(at, effect)
		Debris:AddItem(anchor, 2)
	end)
end

return DropEffects
