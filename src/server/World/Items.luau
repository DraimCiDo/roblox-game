--!strict
-- Models of finds and their quality glow.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local ItemModels = require(ReplicatedStorage.Shared.Models.ItemModels)
local ItemAssets = require(script.Parent.ItemAssets)

local Items = {}

-- Объявлена заранее: нужна при построении секторов, а определяется ниже вместе с моделями предметов.
local makeItem: (Types.Item, boolean?) -> Model

-- Цвет и сила свечения зависят от качества: чем выше качество, тем ярче и шире аура.
local GLOW_TIERS = {
	{ Max = 20, Color = Color3.fromRGB(170, 176, 204), Strength = 0.35 },
	{ Max = 49, Color = Color3.fromRGB(110, 214, 134), Strength = 0.55 },
	{ Max = 70, Color = Color3.fromRGB(80, 194, 255), Strength = 0.8 },
	{ Max = 99, Color = Color3.fromRGB(190, 124, 255), Strength = 1.1 },
	{ Max = 100, Color = Color3.fromRGB(255, 200, 60), Strength = 1.6 },
}

-- Свечение лута по форме предмета: контур (Highlight) цвета качества обвивает модель, лёгкая заливка
-- и слабый свет; у хороших находок — редкие искры. Highlight рисуется только снаружи стен (Occluded).
-- Клиент рисует не больше 31 Highlight одновременно — лута на площадках заметно меньше.
local function addGlow(model: Model, quality: number): ()
	local tier = 1
	for index, entry in GLOW_TIERS do
		if quality <= entry.Max then
			tier = index
			break
		end
	end
	local glow = GLOW_TIERS[tier]
	local outline = Instance.new("Highlight")
	outline.Name = "Свечение"
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.OutlineColor = glow.Color
	outline.OutlineTransparency = 0.1
	outline.FillColor = glow.Color
	outline.FillTransparency = 0.86 - 0.04 * tier
	outline.Parent = model
	local host = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not host then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "Свет находки"
	light.Color = glow.Color
	light.Brightness = glow.Strength * 0.7
	light.Range = 4 + 2 * tier
	light.Shadows = false
	light.Parent = host
	if tier >= 4 then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Rate = if tier == 5 then 7 else 3
		sparks.Lifetime = NumberRange.new(1.4, 2.4)
		sparks.Speed = NumberRange.new(0.4, 1.4)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Acceleration = Vector3.new(0, 1.6, 0)
		sparks.LightEmission = 1
		sparks.Color = ColorSequence.new(glow.Color)
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		sparks.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		sparks.Parent = host
	end
end

function makeItem(item: Types.Item, full: boolean?): Model
	local definition = Catalog.Items[item.Kind]
	-- Модель из Creator Store подключается только по явному включению; по умолчанию рисуем свою.
	local model = ItemAssets.clone(item.Kind) or Instance.new("Model")
	if #model:GetChildren() == 0 then
		ItemModels.build(item.Kind, model, { Full = full ~= false })
		model.WorldPivot = CFrame.new()
	end
	model.Name = definition.Name
	model:SetAttribute("ItemId", item.Id)
	model:SetAttribute("Quality", item.Quality)
	return model
end

Items.makeItem = makeItem
Items.addGlow = addGlow

return Items
