--!strict
-- Хранит копию данных игрока на клиенте (только для отображения, не для решений!).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local DataController = {}

local current: Types.View? = nil
local listeners: { (data: Types.View) -> () } = {}

local function set(data: Types.View?)
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
	local initial = Remotes.func(Remotes.Functions.GetData):InvokeServer()
	if not current then
		set(initial)
	end
end

function DataController:Get(): Types.View?
	return current
end

function DataController:OnChanged(listener: (data: Types.View) -> ())
	table.insert(listeners, listener)
	if current then
		task.spawn(listener, current)
	end
end

return DataController
