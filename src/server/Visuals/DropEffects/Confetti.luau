--!strict
-- Конфетти: настоящие разноцветные бумажки, которые вылетают вверх, кружатся и медленно падают.
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
