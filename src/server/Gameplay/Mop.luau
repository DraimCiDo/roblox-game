--!strict
-- Мини-игра «Мытьё полов» в центре карты: подзаработок для тех, кому не хватает на контейнер.
-- Игрок берёт швабру у стойки, сервер выдаёт ему по одному пятну на полу; за каждое вымытое пятно — монеты.
-- Остановиться можно, снова подойдя к стойке. Всё решает сервер: клиент только нажимает кнопки подсказок.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Data = require(script.Parent.Parent.Services.PlayerDataService)
local Economy = require(script.Parent.Parent.Economy.Economy)
local Rules = require(script.Parent.Parent.Config.Rules)
local Hall = require(script.Parent.Parent.World.Hall)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.Notices)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Mop = {}

type Worker = { Spot: Part?, Count: number, LastAt: number }

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
	-- Луч начинается под потолком зала: сверху от +40 он попадал в крышу и декор вставал на неё.
	local hit = Workspace:Raycast(origin + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), params)
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
		notify(player, Format(Texts.mopStopped, { count = worker.Count }))
	end
end

-- Подбирает свободное место для пятна: пол на уровне зала, нет стен и декора. Если не нашлось — рядом со стойкой.
local function pickSpotCenter(): Vector3
	for _ = 1, 20 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(Rules.Mop.SpotMinRadius, Rules.Mop.SpotMaxRadius)
		local candidate = station.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		if Hall.isFree(candidate, floorY, 4.5) then
			return candidate
		end
	end
	return station.Position + Vector3.new(0, 0, 5)
end

local function spawnSpot(player: Player, worker: Worker): ()
	local center = pickSpotCenter()
	local spot = part(
		`Пятно ({player.Name})`,
		Enum.PartType.Cylinder,
		Vector3.new(0.08, 4.2, 4.2),
		CFrame.new(center.X, floorY + 0.06, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 184, 64),
		Workspace
	)
	-- Метка яркая и светится янтарём (цвет акцента CORPA): хорошо видна на тёмном полу зала.
	spot.Material = Enum.Material.Neon
	spot.Transparency = 0.3
	local ring = Instance.new("Part")
	ring.Name = "Кайма пятна"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.09, 4.8, 4.8)
	ring.CFrame = spot.CFrame
	ring.Color = Color3.fromRGB(255, 244, 200)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.1
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = spot
	local pulse = Instance.new("PointLight")
	pulse.Color = Color3.fromRGB(255, 184, 64)
	pulse.Range = 10
	pulse.Brightness = 1.2
	pulse.Parent = spot
	spot:SetAttribute("OwnerId", player.UserId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Texts.mopWash
	prompt.ObjectText = Format(Texts.mopSpotObject, { name = player.DisplayName })
	prompt.HoldDuration = Rules.Mop.CleanTime
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot
	prompt.Triggered:Connect(function(actor)
		local current = workers[actor]
		if actor ~= player or not current or current.Spot ~= spot then
			return
		end
		local root = actor.Character and actor.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - spot.Position).Magnitude > Rules.Mop.SpotReach then
			return
		end
		local now = os.clock()
		if now - current.LastAt < Rules.Mop.MinInterval then
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
		notify(actor, Format(Texts.mopReward, { reward = Config.MopReward }))
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
	notify(player, Format(Texts.mopStarted, { reward = Config.MopReward }))
	spawnSpot(player, worker)
end

-- center — центр общей зоны; notice и update — колбэки основного сервиса (уведомление и обновление интерфейса).
function Mop.Start(center: Vector3, notice: (Player, string) -> (), update: (Player) -> ()): number
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
		Color3.fromRGB(98, 106, 178),
		folder
	)
	station.CanQuery = true
	part(
		"Ведро",
		Enum.PartType.Cylinder,
		Vector3.new(1.8, 1.5, 1.5),
		CFrame.new(center.X - 0.5, floorY + 1.15, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(70, 196, 255),
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
	stationPrompt.ObjectText = Texts.mopStationObject
	stationPrompt.ActionText = Texts.mopTake
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
					far = (root.Position - station.Position).Magnitude > Rules.Mop.MaxDistance
				end
				if far then
					stop(player)
				end
			end
			task.wait(1)
		end
	end)
	return floorY
end

return Mop
