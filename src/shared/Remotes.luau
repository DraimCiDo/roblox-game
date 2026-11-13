--!strict
-- Единый реестр сетевых событий. Любой новый Remote объявляется ТОЛЬКО здесь.
-- Сервер создаёт инстансы (Remotes.init()), клиент их ждёт.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {}

Remotes.Events = table.freeze({
	-- Сервер -> клиент: актуальные данные игрока
	DataChanged = "DataChanged",
})

Remotes.Functions = table.freeze({
	-- Клиент -> сервер: запросить свои данные
	GetData = "GetData",
})

local function getFolder(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Instance
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function getOrCreate(className: string, name: string): Instance
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local instance = Instance.new(className :: any)
		instance.Name = name
		instance.Parent = folder
		return instance
	end
	return folder:WaitForChild(name)
end

-- Вызывается один раз сервером при старте: создаёт все объявленные Remotes.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init() вызывается только на сервере")
	for _, name in Remotes.Events do
		getOrCreate("RemoteEvent", name)
	end
	for _, name in Remotes.Functions do
		getOrCreate("RemoteFunction", name)
	end
end

function Remotes.event(name: string): RemoteEvent
	assert((Remotes.Events :: any)[name], `Неизвестный RemoteEvent: {name}`)
	return getOrCreate("RemoteEvent", name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	assert((Remotes.Functions :: any)[name], `Неизвестный RemoteFunction: {name}`)
	return getOrCreate("RemoteFunction", name) :: RemoteFunction
end

return Remotes
