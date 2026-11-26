--!strict
-- Золотой дождь: монеты падают сверху, кувыркаются, ложатся на пол и гаснут; сверху — золотая пыль.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Common = require(script.Parent.Common)
local rng = Common.rng
local configure = Common.configure
local ring = Common.ring
local flash = Common.flash
local emitter = Common.emitter
local around = Common.around

return function(anchor: Part, at: CFrame, effect: Catalog.DropEffect): ()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { anchor }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	for _ = 1, 30 do
		local top = at.Position + around(7) + Vector3.new(0, rng:NextNumber(6, 12), 0)
		local hit = Workspace:Raycast(top, Vector3.new(0, -40, 0), params)
		local floorY = if hit then hit.Position.Y + 0.06 else at.Position.Y - 2
		local coin = Instance.new("Part")
		coin.Name = "Элемент эффекта"
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.1, 0.95, 0.95)
		coin.Color = effect.Primary:Lerp(effect.Secondary, rng:NextNumber())
		coin.Material = Enum.Material.Metal
		coin.Reflectance = 0.35
		coin.Anchored = true
		configure(coin)
		coin.CFrame = CFrame.new(top)
			* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
		coin.Parent = Workspace
		local fall = rng:NextNumber(0.7, 1.2)
		-- Падение с кувырком; цилиндр лежит осью вверх после поворота на 90° вокруг Z.
		TweenService:Create(
			coin,
			TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = CFrame.new(top.X, floorY, top.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(90)) }
		):Play()
		task.delay(fall + 0.55, function()
			if coin.Parent then
				TweenService:Create(coin, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(coin, fall + 1.4)
	end
	local glitter = emitter(anchor, ColorSequence.new(effect.Primary, effect.Secondary), 0.4, NumberRange.new(1, 1.8))
	glitter.Speed = NumberRange.new(effect.Speed * 0.4, effect.Speed)
	glitter.Acceleration = Vector3.new(0, effect.Gravity, 0)
	glitter:Emit(effect.Count)
	flash(anchor, effect.Primary, 5, 20, 1.0)
	ring(at, effect.Primary, 14, 0.6)
end
