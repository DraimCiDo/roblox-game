--!strict
-- Серверные звуки: событие отправляется клиентам, а те воспроизводят его с проверкой загрузки и запасным звуком.
-- target: деталь или модель в мире (звук играет у неё); nil — личный звук игрока без позиции.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Audio = {}
local interface: RemoteEvent?

local function remote(): RemoteEvent
	if not interface then
		interface = Remotes.event(Remotes.Events.Interface)
	end
	return interface :: RemoteEvent
end

-- Звук в мире: слышат все игроки поблизости.
function Audio.at(target: Instance, name: string, pitch: number?): ()
	remote():FireAllClients("sfx", name, target, pitch)
end

-- Звук интерфейса для одного игрока: покупка, продажа, награда.
function Audio.to(player: Player, name: string, pitch: number?): ()
	remote():FireClient(player, "sfx", name, nil, pitch)
end

return Audio
