--!strict
-- Mopping job in the hall, a side income. The player takes a mop at the stand, steps into the hologram
-- marker over a dirty spot and scrubs every piece of mud away by moving the mop head over it.
-- The server decides everything: it watches where the mop head is, the client only presses the stand prompt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Data = require(script.Parent.Parent.Services.PlayerDataService)
local Economy = require(script.Parent.Parent.Economy.Economy)
local Rules = require(script.Parent.Parent.Config.Rules)
local Hall = require(script.Parent.Parent.World.Hall)
local Dirt = require(script.Parent.Parent.Visuals.Dirt)
local MopLooks = require(script.Parent.Parent.Visuals.Mop)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.Notices)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Mop = {}

type Worker = {
	Mop: Model,
	Head: Part,
	LastHead: Vector3,
	Spot: Dirt.Spot?,
	-- Set when the player has stepped into the marker of the current spot.
	StartedAt: number?,
	Count: number,
}

local TICK = 0.1

local workers: { [Player]: Worker } = {}
local station: Part
local folder: Folder
local floorY = 0
local rng = Random.new()
local notify: (Player, string) -> ()
local refresh: (Player) -> ()

-- Reward for the n-th spot of one shift: grows every few spots up to a limit.
local function rewardFor(count: number): number
	local steps = math.floor((count - 1) / Config.MopStreakStep)
	return math.min(Config.MopReward + steps * Config.MopRewardBonus, Config.MopRewardMax)
end

-- nil hides the progress bar of the client.
local function showProgress(player: Player, share: number?): ()
	Remotes.event(Remotes.Events.Interface):FireClient(player, "mop", share)
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
	-- The ray starts below the hall ceiling, otherwise it hits the roof.
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
		worker.Spot.Model:Destroy()
	end
	worker.Mop:Destroy()
	if player.Character then
		player.Character:SetAttribute("Mopping", nil)
	end
	if player.Parent then
		showProgress(player, nil)
		if not silent then
			notify(player, Format(Texts.mopStopped, { count = worker.Count }))
		end
	end
end

-- A free place for a spot: level floor without walls or decor. Falls back to a place next to the stand.
local function pickSpotCenter(): Vector3
	local center = station.Position
	for _ = 1, 30 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(Rules.Mop.SpotMinRadius, Rules.Mop.SpotMaxRadius)
		local candidate = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		if Hall.isFree(candidate, floorY, 6) then
			return Vector3.new(candidate.X, floorY, candidate.Z)
		end
	end
	return Vector3.new(center.X, floorY, center.Z + Rules.Mop.SpotMinRadius)
end

local function spawnSpot(player: Player, worker: Worker): ()
	local caption = Format(Texts.mopMarker, { name = player.DisplayName })
	worker.Spot = Dirt.spawn(folder, pickSpotCenter(), Rules.Mop.ChunkCount, Rules.Mop.MarkerRadius, caption)
	worker.StartedAt = nil
	showProgress(player, nil)
end

local function finish(player: Player, worker: Worker): ()
	local spot = worker.Spot
	if not spot then
		return
	end
	spot.Model:Destroy()
	worker.Spot = nil
	worker.Count += 1
	local reward = rewardFor(worker.Count)
	Data:Update(player, function(data: Types.PlayerData)
		Economy.credit(data, reward)
	end)
	refresh(player)
	notify(player, Format(Texts.mopReward, { reward = reward, count = worker.Count }))
	spawnSpot(player, worker)
end

local function flat(offset: Vector3): number
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

local function scrub(player: Player, worker: Worker): ()
	local spot = worker.Spot
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not spot or not root or not root:IsA("BasePart") then
		return
	end
	local at = worker.Head.Position
	-- Capped, so that a jump across the hall does not count as scrubbing.
	local moved = math.min(flat(at - worker.LastHead), Rules.Mop.MaxStep)
	worker.LastHead = at

	if not worker.StartedAt then
		if flat(root.Position - spot.Center) > Rules.Mop.MarkerRadius then
			return
		end
		worker.StartedAt = os.clock()
		spot.Marker:Destroy()
		showProgress(player, 0)
		return
	end

	local changed = false
	for index = #spot.Chunks, 1, -1 do
		local chunk = spot.Chunks[index]
		if moved > 0.05 and flat(at - chunk.Position) <= Rules.Mop.ScrubRadius then
			chunk.Progress = math.min(chunk.Progress + moved, Rules.Mop.ChunkWork)
			Dirt.fade(chunk, chunk.Progress / Rules.Mop.ChunkWork)
			changed = true
		end
	end
	local done = 0
	for _, chunk in spot.Chunks do
		done += chunk.Progress / Rules.Mop.ChunkWork
	end
	-- The last piece stays until the minimum time has passed.
	local early = os.clock() - (worker.StartedAt :: number) < Rules.Mop.MinCleanTime
	local left = 0
	for index = #spot.Chunks, 1, -1 do
		local chunk = spot.Chunks[index]
		if chunk.Progress >= Rules.Mop.ChunkWork then
			chunk.Model:Destroy()
		else
			left += 1
		end
	end
	if left == 0 and not early then
		finish(player, worker)
	elseif changed then
		showProgress(player, done / #spot.Chunks)
	end
end

local function toggle(player: Player): ()
	if workers[player] then
		stop(player)
		return
	end
	local character = player.Character
	if not character or not Data:Get(player) then
		return
	end
	local mop, head = MopLooks.equip(character)
	if not mop or not head then
		return
	end
	character:SetAttribute("Mopping", true)
	local worker: Worker = { Mop = mop, Head = head, LastHead = head.Position, Spot = nil, StartedAt = nil, Count = 0 }
	workers[player] = worker
	notify(player, Format(Texts.mopStarted, { reward = Config.MopReward, max = Config.MopRewardMax }))
	spawnSpot(player, worker)
end

-- center: middle of the work area; notice and update are callbacks of the main service.
function Mop.Start(center: Vector3, notice: (Player, string) -> (), update: (Player) -> ()): number
	notify = notice
	refresh = update
	floorY = floorAt(center)
	folder = Instance.new("Folder")
	folder.Name = "Мытьё полов"
	folder.Parent = Workspace
	station = MopLooks.station(folder, CFrame.new(center.X, floorY, center.Z))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MopStation"
	prompt.ObjectText = Texts.mopStationObject
	prompt.ActionText = Texts.mopTake
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = station
	prompt.Triggered:Connect(toggle)

	Players.PlayerRemoving:Connect(function(player)
		stop(player, true)
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed < TICK then
			return
		end
		elapsed = 0
		for player, worker in workers do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local gone = worker.Mop.Parent ~= player.Character or not root or not root:IsA("BasePart")
			if gone or ((root :: BasePart).Position - station.Position).Magnitude > Rules.Mop.MaxDistance then
				stop(player)
			else
				scrub(player, worker)
			end
		end
	end)
	return floorY
end

return Mop
