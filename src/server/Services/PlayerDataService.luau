--!strict
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)
local Types = require(ReplicatedStorage.Shared.Types)

local SESSION_SECONDS = 180
type Profile = {
	Data: Types.PlayerData,
	Store: DataStore?,
	Busy: boolean,
	Closing: boolean,
	Ranked: number,
	SessionId: string,
}
local profiles: { [Player]: Profile } = {}
local loading: { [Player]: boolean } = {}
local studioProgress: { [number]: Types.PlayerData } = {}
local store: DataStore?
local ordered: OrderedDataStore?
local shuttingDown = false
local pendingLoads = 0
local PlayerDataService = {}

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

local function retry(fn: () -> any): (boolean, any)
	local result: any
	for attempt = 1, 3 do
		local ok
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	return false, result
end

local function migrate(saved: any): Types.PlayerData
	if saved == nil then
		return TableUtil.deepCopy(Config.DefaultData)
	end
	if (saved.Version or 1) < 2 then
		if not saved.Coins or saved.Coins == 0 then
			saved.Coins = Config.DefaultData.Coins
		end
		saved.Version = 2
	end
	return TableUtil.reconcile(saved, Config.DefaultData) :: Types.PlayerData
end

local function load(player: Player): ()
	local sessionId = HttpService:GenerateGUID(false)
	local memoryOnly = RunService:IsStudio() and (game.PlaceId == 0 or player.UserId <= 0)
	local currentStore = if memoryOnly then nil else store
	if currentStore == nil and not memoryOnly then
		player:Kick(
			"Хранилище прогресса недоступно. Попробуйте ещё раз позже."
		)
		return
	end
	local data = if memoryOnly then migrate(studioProgress[player.UserId]) else migrate(nil)
	if currentStore then
		local deadline = os.clock() + 12
		repeat
			local ok, saved = retry(function()
				return currentStore:UpdateAsync(keyFor(player), function(previous)
					if previous ~= nil and type(previous) ~= "table" then
						return nil
					end
					local lock = if previous then previous.Session else nil
					if lock and lock.Id ~= sessionId and lock.Expires > os.time() then
						return nil
					end
					local raw = if type(previous) == "table" then previous.Data or previous else nil
					if raw and (raw.Version or 1) > Config.DataSchemaVersion then
						return nil
					end
					return { Data = migrate(raw), Session = { Id = sessionId, Expires = os.time() + SESSION_SECONDS } }, {
						player.UserId,
					}
				end)
			end)
			if ok and saved then
				data = saved.Data
				break
			end
			if not ok or os.clock() >= deadline or player.Parent ~= Players or shuttingDown then
				player:Kick(
					"Не удалось загрузить прогресс. Попробуйте ещё раз позже."
				)
				return
			end
			task.wait(1)
		until false
	end
	if player.Parent ~= Players or shuttingDown then
		if currentStore then
			retry(function()
				return currentStore:UpdateAsync(keyFor(player), function(previous)
					if previous and previous.Session and previous.Session.Id == sessionId then
						previous.Session = nil
						return previous, { player.UserId }
					end
					return nil
				end)
			end)
		end
		return
	end
	if memoryOnly then
		studioProgress[player.UserId] = nil
	end
	profiles[player] =
		{ Data = data, Store = currentStore, Busy = false, Closing = false, Ranked = 0, SessionId = sessionId }
end

local function save(player: Player, closing: boolean)
	local profile = profiles[player]
	if not profile or profile.Closing then
		return
	end
	if closing then
		profile.Closing = true
		while profile.Busy do
			task.wait()
		end
	elseif profile.Busy then
		return
	end
	profile.Busy = true
	local currentStore = profile.Store
	local snapshot = TableUtil.deepCopy(profile.Data)
	if currentStore then
		local ok, result = retry(function()
			return currentStore:UpdateAsync(keyFor(player), function(previous)
				if not (previous and previous.Session and previous.Session.Id == profile.SessionId) then
					return nil
				end
				local lock = if closing then nil else { Id = profile.SessionId, Expires = os.time() + SESSION_SECONDS }
				return { Data = snapshot, Session = lock }, { player.UserId }
			end)
		end)
		if not ok or not result then
			warn(`[PlayerDataService] Не удалось сохранить {player.UserId}: {result}`)
			if not closing and not result and ok then
				player:Kick("Сессия сохранения завершилась. Войдите снова.")
			end
		elseif ordered and snapshot.Earned > profile.Ranked then
			local leaderboard = ordered
			local ranked, err = pcall(function()
				leaderboard:UpdateAsync(tostring(player.UserId), function(previous)
					return math.max(previous or 0, snapshot.Earned)
				end)
			end)
			if ranked then
				profile.Ranked = snapshot.Earned
			else
				warn(`[PlayerDataService] Не удалось обновить рейтинг: {err}`)
			end
		end
	elseif closing then
		studioProgress[player.UserId] = snapshot
	end
	profile.Busy = false
	if closing then
		profiles[player] = nil
	end
end

function PlayerDataService:Init(): ()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn(`[PlayerDataService] DataStore недоступен: {result}`)
	end
	if not RunService:IsStudio() then
		local rankingOk, rankingStore = pcall(function()
			return DataStoreService:GetOrderedDataStore("LifetimeCoinsEarned_v1")
		end)
		if rankingOk then
			ordered = rankingStore
		else
			warn(`[PlayerDataService] Хранилище рейтинга недоступно: {rankingStore}`)
		end
	end
end

local function loadProfile(player: Player): ()
	if shuttingDown or loading[player] or profiles[player] or player.Parent ~= Players then
		return
	end
	loading[player] = true
	pendingLoads += 1
	local ok, err = pcall(load :: (Player) -> any, player)
	pendingLoads -= 1
	loading[player] = nil
	if not ok and player.Parent == Players then
		warn(`[PlayerDataService] Не удалось подготовить профиль {player.UserId}: {err}`)
		player:Kick(
			"Не удалось загрузить прогресс. Попробуйте ещё раз позже."
		)
	end
end

function PlayerDataService:Start(): ()
	Players.PlayerAdded:Connect(loadProfile)
	Players.PlayerRemoving:Connect(function(player)
		loading[player] = nil
		save(player, true)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
	game:BindToClose(function()
		shuttingDown = true
		for player in profiles do
			task.spawn(save, player, true)
		end
		local deadline = os.clock() + 25
		while (next(profiles) or pendingLoads > 0) and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	while not shuttingDown do
		task.wait(Config.AutosaveInterval)
		for player in profiles do
			task.spawn(save, player, false)
		end
	end
end

function PlayerDataService:Get(player: Player): Types.PlayerData?
	local profile = profiles[player]
	return if profile and not profile.Closing then profile.Data else nil
end

function PlayerDataService:Update(player: Player, mutator: (data: Types.PlayerData) -> ()): ()
	local profile = profiles[player]
	local data = if profile and not profile.Closing then profile.Data else nil
	if data then
		mutator(data)
	end
end

function PlayerDataService:GetRanking(): { { Key: string, Value: number } }?
	local leaderboard = ordered
	if not leaderboard then
		return nil
	end
	local ok, result = pcall(function()
		return leaderboard:GetSortedAsync(false, 10):GetCurrentPage()
	end)
	if not ok then
		warn(`[PlayerDataService] Не удалось прочитать рейтинг: {result}`)
		return nil
	end
	local entries = {}
	for _, entry in result do
		table.insert(entries, { Key = entry.key, Value = entry.value })
	end
	return entries
end

return PlayerDataService
