--!strict
-- Разлом пустоты: частицы затягиваются внутрь, шар схлопывается и выбрасывает всё наружу.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Common = require(script.Parent.Common)
local configure = Common.configure
local ring = Common.ring
local flash = Common.flash
local emitter = Common.emitter

return function(anchor: Part, at: CFrame, effect: Catalog.DropEffect): ()
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
