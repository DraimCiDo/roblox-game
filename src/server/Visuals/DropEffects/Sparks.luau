--!strict
-- Тёплые искры (эффект по умолчанию).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Common = require(script.Parent.Common)
local ring = Common.ring
local flash = Common.flash
local emitter = Common.emitter

return function(anchor: Part, at: CFrame, effect: Catalog.DropEffect): ()
	local sparks = emitter(anchor, ColorSequence.new(effect.Primary, effect.Secondary), 0.7, NumberRange.new(0.8, 1.5))
	sparks.Speed = NumberRange.new(effect.Speed * 0.5, effect.Speed)
	sparks.Acceleration = Vector3.new(0, effect.Gravity, 0)
	sparks:Emit(effect.Count)
	flash(anchor, effect.Primary, 3, 16, 0.8)
	ring(at, effect.Primary)
end
