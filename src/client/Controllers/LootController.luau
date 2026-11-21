--!strict
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Лут на площадке парит, покачивается и вращается, как выпавшие предметы в Minecraft.
-- Движение считается только у игрока: сервер хранит лишь точку покоя (Rest) и признак «приземлился» (Settled).
local LootController = {}

local TAG = "CorpaLoot"
local LIFT = 1.15
local BOB = 0.22
local BOB_SPEED = 2.1
local SPIN_SPEED = 1.1
-- Дальше этого расстояния от камеры лут не анимируется.
local ACTIVE_DISTANCE = 90

local phases: { [Model]: number } = {}
local random = Random.new()

function LootController:Start(): ()
	local function track(object: Instance): ()
		if object:IsA("Model") then
			phases[object] = random:NextNumber(0, math.pi * 2)
		end
	end
	for _, object in CollectionService:GetTagged(TAG) do
		track(object)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(object)
		if object:IsA("Model") then
			phases[object] = nil
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local origin = camera.CFrame.Position
		local now = os.clock()
		for model, phase in phases do
			if not model.Parent then
				phases[model] = nil
				continue
			end
			local rest = model:GetAttribute("Rest")
			if
				model:GetAttribute("Settled")
				and typeof(rest) == "CFrame"
				and (rest.Position - origin).Magnitude < ACTIVE_DISTANCE
			then
				local height = LIFT + math.sin(now * BOB_SPEED + phase) * BOB
				model:PivotTo(rest * CFrame.new(0, height, 0) * CFrame.Angles(0, now * SPIN_SPEED + phase, 0))
			end
		end
	end)
end

return LootController
