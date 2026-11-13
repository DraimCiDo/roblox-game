--!strict
-- Загрузка/сохранение данных игроков в DataStore.
-- Сервер — единственный источник истины. Клиент получает копию через DataChanged.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)
local Types = require(ReplicatedStorage.Shared.Types)

local MAX_RETRIES = 3

local PlayerDataService = {}

local store: DataStore? = nil
local profiles: { [Player]: Types.PlayerData } = {}

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

local function retry(fn: () -> any): (boolean, any)
	local ok, result = false, nil
	for attempt = 1, MAX_RETRIES do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		task.wait(attempt)
	end
	return false, result
end

local function push(player: Player)
	local data = profiles[player]
	if data then
		Remotes.event(Remotes.Events.DataChanged):FireClient(player, data)
	end
end

local function load(player: Player)
	local data: Types.PlayerData = TableUtil.deepCopy(GameConfig.DefaultData) :: any
	local currentStore = store
	if currentStore then
		local ok, saved = retry(function()
			return currentStore:GetAsync(keyFor(player))
		end)
		if not ok then
			-- Не даём играть с пустыми данными, чтобы не перезаписать сохранение.
			player:Kick("Не удалось загрузить данные. Попробуйте зайти позже.")
			return
		end
		if type(saved) == "table" then
			data = TableUtil.reconcile(saved, GameConfig.DefaultData) :: any
		end
	end
	if player.Parent ~= Players then
		return
	end
	profiles[player] = data
	push(player)
end

local function save(player: Player)
	local data = profiles[player]
	local currentStore = store
	if not data or not currentStore then
		return
	end
	local ok, err = retry(function()
		return currentStore:SetAsync(keyFor(player), data, { player.UserId })
	end)
	if not ok then
		warn(`[PlayerDataService] Не удалось сохранить {player.Name}: {err}`)
	end
end

function PlayerDataService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn(`[PlayerDataService] DataStore недоступен (включите API Services в Studio): {result}`)
	end
end

function PlayerDataService:Start()
	Remotes.func(Remotes.Functions.GetData).OnServerInvoke = function(player: Player)
		return profiles[player]
	end

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)

	game:BindToClose(function()
		local threads = {}
		for player in profiles do
			table.insert(threads, task.spawn(save, player))
		end
		-- Ждём завершения сохранений (лимит BindToClose — 30 сек).
		local deadline = os.clock() + 25
		while os.clock() < deadline do
			local pending = false
			for _, thread in threads do
				if coroutine.status(thread) ~= "dead" then
					pending = true
				end
			end
			if not pending then
				break
			end
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)
end

-- Публичный API для других сервисов --------------------------------------

function PlayerDataService:Get(player: Player): Types.PlayerData?
	return profiles[player]
end

-- Единственный правильный способ менять данные: через колбэк; клиент сразу получает обновление.
function PlayerDataService:Update(player: Player, mutator: (data: Types.PlayerData) -> ())
	local data = profiles[player]
	if not data then
		return
	end
	mutator(data)
	push(player)
end

return PlayerDataService
