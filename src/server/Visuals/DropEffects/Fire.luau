--!strict
-- Огненный взрыв: огненный шар, языки пламени вверх, дым и россыпь углей.
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
