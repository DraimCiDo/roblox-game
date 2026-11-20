--!strict
-- Мини-игра «Мытьё полов» в центре карты: подзаработок для тех, кому не хватает на контейнер.
-- Игрок берёт швабру у стойки, сервер выдаёт ему по одному пятну на полу; за каждое вымытое пятно — монеты.
-- Остановиться можно, снова подойдя к стойке. Всё решает сервер: клиент только нажимает кнопки подсказок.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Data = require(script.Parent.Parent.PlayerDataService)
local Economy = require(script.Parent.Economy)

local Mop = {}

type Worker = { Spot: Part?, Count: number, LastAt: number }

local SPOT_MIN_RADIUS = 7
local SPOT_MAX_RADIUS = 20
local SPOT_REACH = 14
local MAX_DISTANCE = 70
local MIN_INTERVAL = 0.6
local CLEAN_TIME = 0.9

local workers: { [Player]: Worker } = {}
local station: Part
local stationPrompt: ProximityPrompt
local floorY = 0
local rng = Random.new()
local notify: (Player, string) -> ()
local refresh: (Player) -> ()

local function part(
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	parent: Instance
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Shape = shape
	result.Size = size
	result.CFrame = frame
	result.Color = color
	result.Material = Enum.Material.SmoothPlastic
	result.Anchored = true
	result.CanCollide = false
	result.CanQuery = false
	result.CanTouch = false
	result.Parent = parent
	return result
end

local function floorAt(origin: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(origin + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
	return if hit then hit.Position.Y else origin.Y
end

local function stop(player: Player, silent: boolean?): ()
	local worker = workers[player]
	if not worker then
		return
	end
	workers[player] = nil
	if worker.Spot then
		worker.Spot:Destroy()
	end
	if not silent and player.Parent then
		notify(player, `Работа закончена: вымыто пятен — {worker.Count}`)
	end
end

local function spawnSpot(player: Player, worker: Worker): ()
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(SPOT_MIN_RADIUS, SPOT_MAX_RADIUS)
	local center = station.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	local spot = part(
		`Пятно ({player.Name})`,
		Enum.PartType.Cylinder,
		Vector3.new(0.08, 4.2, 4.2),
		CFrame.new(center.X, floorY + 0.06, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(104, 84, 58),
		Workspace
	)
	spot.Transparency = 0.15
	spot:SetAttribute("OwnerId", player.UserId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Вымыть"
	prompt.ObjectText = `Пятно · {player.DisplayName}`
	prompt.HoldDuration = CLEAN_TIME
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot
	prompt.Triggered:Connect(function(actor)
		local current = workers[actor]
		if actor ~= player or not current or current.Spot ~= spot then
			return
		end
		local root = actor.Character and actor.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - spot.Position).Magnitude > SPOT_REACH then
			return
		end
		local now = os.clock()
		if now - current.LastAt < MIN_INTERVAL then
			return
		end
		current.LastAt = now
		current.Count += 1
		spot:Destroy()
		current.Spot = nil
		Data:Update(actor, function(data: Types.PlayerData)
			Economy.credit(data, Config.MopReward)
		end)
		refresh(actor)
		notify(actor, `+{Config.MopReward} монет за уборку`)
		spawnSpot(actor, current)
	end)
	worker.Spot = spot
end

local function toggle(player: Player): ()
	if workers[player] then
		stop(player)
		return
	end
	if not Data:Get(player) then
		return
	end
	local worker: Worker = { Spot = nil, Count = 0, LastAt = 0 }
	workers[player] = worker
	notify(player, `Вы взяли швабру. Мойте пятна на полу — {Config.MopReward} монет за каждое`)
	spawnSpot(player, worker)
end

-- center — центр общей зоны; notice и update — колбэки основного сервиса (уведомление и обновление интерфейса).
function Mop.Start(center: Vector3, notice: (Player, string) -> (), update: (Player) -> ()): ()
	notify = notice
	refresh = update
	floorY = floorAt(center)
	local folder = Instance.new("Folder")
	folder.Name = "Мытьё полов"
	folder.Parent = Workspace
	station = part(
		"Стойка со шваброй",
		Enum.PartType.Block,
		Vector3.new(2.4, 0.4, 2.4),
		CFrame.new(center.X, floorY + 0.2, center.Z),
		Color3.fromRGB(52, 62, 76),
		folder
	)
	station.CanQuery = true
	part(
		"Ведро",
		Enum.PartType.Cylinder,
		Vector3.new(1.8, 1.5, 1.5),
		CFrame.new(center.X - 0.5, floorY + 1.15, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(91, 232, 222),
		folder
	)
	part(
		"Швабра",
		Enum.PartType.Cylinder,
		Vector3.new(4.6, 0.2, 0.2),
		CFrame.new(center.X + 0.5, floorY + 2.6, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(196, 204, 214),
		folder
	)
	part(
		"Насадка швабры",
		Enum.PartType.Block,
		Vector3.new(1.4, 0.3, 0.7),
		CFrame.new(center.X + 0.5, floorY + 0.55, center.Z),
		Color3.fromRGB(232, 234, 238),
		folder
	)
	stationPrompt = Instance.new("ProximityPrompt")
	stationPrompt.ObjectText = "Мытьё полов"
	stationPrompt.ActionText = "Взять швабру"
	stationPrompt.MaxActivationDistance = 9
	stationPrompt.RequiresLineOfSight = false
	stationPrompt.Parent = station
	stationPrompt.Triggered:Connect(toggle)

	Players.PlayerRemoving:Connect(function(player)
		stop(player, true)
	end)
	task.spawn(function()
		while true do
			for player in workers do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local far = true
				if root and root:IsA("BasePart") then
					far = (root.Position - station.Position).Magnitude > MAX_DISTANCE
				end
				if far then
					stop(player)
				end
			end
			task.wait(1)
		end
	end)
end

return Mop
