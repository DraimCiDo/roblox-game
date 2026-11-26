--!strict
-- Ледяная пыль: кристаллы льда, холодный туман и медленно падающий иней.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Common = require(script.Parent.Common)
local rng = Common.rng
local ring = Common.ring
local flash = Common.flash
local emitter = Common.emitter
local flyer = Common.flyer
local around = Common.around

return function(anchor: Part, at: CFrame, effect: Catalog.DropEffect): ()
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
