--!strict
-- Обучение новичка. Шаг определяется по реальному состоянию игры, поэтому он не зависит от порядка действий
-- и корректно продолжается после повторного входа.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Texts = require(ReplicatedStorage.Shared.Config.Texts.Tutorial)
local Economy = require(script.Parent.Parent.Economy.Economy)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local World = require(script.Parent.Parent.World.World)

export type Step = {
	Id: string,
	Text: string,
	-- Объект в мире, который подсвечивается на клиенте.
	Target: Instance?,
	-- Кнопка интерфейса, которую нужно подсветить ("perks").
	Pulse: string?,
}

-- Сколько контейнеров нужно открыть, чтобы обучение завершилось, даже если перки не покупались.
local OPENED_TO_FINISH = 5
-- Первый перк доступен от этой суммы монет (самый дешёвый уровень без порога по контейнерам).
local FIRST_PERK_COINS = 8000
local OPENED_FOR_PERKS = 2

local OPEN_HELP: { [string]: string } = {
	box = Texts.openBox,
	crate = Texts.openCrate,
	safe = Texts.openSafe,
	cargo = Texts.openCargo,
	secret = Texts.openSecret,
}

local Tutorial = {}

local function step(id: string, text: string, target: Instance?, pulse: string?): Step
	return { Id = id, Text = text, Target = target, Pulse = pulse }
end

-- Возвращает текущий шаг или nil, когда обучение пройдено.
function Tutorial.evaluate(data: Types.PlayerData, plot: World.Plot): Step?
	if next(data.Perks) ~= nil or data.Opened >= OPENED_TO_FINISH then
		return nil
	end
	local order = data.Orders[1]
	if order then
		if order.Stage == "queued" or order.Stage == "delivery" then
			return step("wait", Texts.waitDelivery, plot.Clear)
		elseif order.Stage == "sealed" then
			return step("open", OPEN_HELP[order.Kind] or Texts.openAny, plot.Active)
		elseif order.Stage == "open" then
			local _, loot = next(plot.Loot)
			return step("collect", Texts.pickUp, loot)
		end
		return step("leave", Texts.leavePad, plot.Clear)
	end
	if #data.Inventory > 0 then
		return step("sell", Texts.sell, plot.Stations.inventory)
	end
	if data.Opened >= OPENED_FOR_PERKS and data.Coins >= FIRST_PERK_COINS then
		return step("perks", Texts.firstPerk, nil, "perks")
	end
	if data.Coins >= Economy.orderPrice(data) then
		return step("order", Texts.order, plot.Stations.terminal)
	end
	return step("money", Texts.noCoins)
end

return Tutorial
