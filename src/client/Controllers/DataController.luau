--!strict
-- Хранит копию данных игрока на клиенте (только для отображения, не для решений!).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local DataController = {}

local current: Types.PlayerData? = nil
local listeners: { (data: Types.PlayerData) -> () } = {}

local function set(data: Types.PlayerData?)
	if not data then
		return
	end
	current = data
	for _, listener in listeners do
		task.spawn(listener, data)
	end
end

function DataController:Start()
	Remotes.event(Remotes.Events.DataChanged).OnClientEvent:Connect(set)
	set(Remotes.func(Remotes.Functions.GetData):InvokeServer())
end

function DataController:Get(): Types.PlayerData?
	return current
end

function DataController:OnChanged(listener: (data: Types.PlayerData) -> ())
	table.insert(listeners, listener)
	if current then
		task.spawn(listener, current)
	end
end

return DataController
