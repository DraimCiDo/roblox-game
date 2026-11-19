--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemModels = require(ReplicatedStorage.Shared.ItemModels)
local Style = require(script.Parent.Style)

local ItemPreview = {}

-- Рисует ту же модель предмета, что и в мире, внутри ViewportFrame; камера подбирается по размерам модели.
-- ghost = true рисует тёмный силуэт для пустого слота.
function ItemPreview.draw(parent: Instance, kind: string, ghost: boolean?): ViewportFrame
	local preview = Instance.new("ViewportFrame")
	preview.Name = "Иконка"
	preview.BackgroundTransparency = 1
	preview.Ambient = Color3.fromRGB(176, 182, 214)
	preview.LightColor = Color3.fromRGB(255, 250, 236)
	preview.LightDirection = Vector3.new(-1, -2, -1)
	preview.Parent = parent

	local model = Instance.new("Model")
	model.Name = kind
	ItemModels.build(kind, model, { Full = false })
	model.Parent = preview
	if ghost then
		for _, object in model:GetDescendants() do
			if object:IsA("BasePart") then
				object.Color = Style.Edge
				object.Material = Enum.Material.SmoothPlastic
				object.Transparency = 0
			elseif object:IsA("SurfaceGui") or object:IsA("Light") then
				object:Destroy()
			end
		end
	end

	local center, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.CFrame =
		CFrame.lookAt(center.Position + Vector3.new(0.75, 0.5, -1.15).Unit * (radius * 2.1 + 1), center.Position)
	camera.Parent = preview
	preview.CurrentCamera = camera
	return preview
end

return ItemPreview
