--!strict
-- Обучение новичка. Шаг определяется по реальному состоянию игры, поэтому он не зависит от порядка действий
-- и корректно продолжается после повторного входа.
local Economy = require(script.Parent.Economy)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local World = require(script.Parent.World)

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
	box = "Подойдите к коробке и нажимайте E: сорвите ленту, откройте створки и раскройте коробку.",
	crate = "Сломайте четыре скобы на ящике: подходите к каждой и нажимайте E или F.",
	safe = "Нажмите E у ручки сейфа и остановите указатель в зелёной зоне. Остановить можно пробелом.",
	cargo = "Разблокируйте оба фиксатора (E), затем откройте створки у центра контейнера.",
	secret = "Нажимайте E у контейнера, пока ядро не вспыхнет.",
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
			return step(
				"wait",
				"Контейнер уже в пути! Дождитесь, пока он опустится на площадку у шахты.",
				plot.Clear
			)
		elseif order.Stage == "sealed" then
			return step("open", OPEN_HELP[order.Kind] or "Откройте контейнер.", plot.Active)
		elseif order.Stage == "open" then
			local _, loot = next(plot.Loot)
			return step(
				"collect",
				"Подберите выпавшие предметы: подойдите и нажмите E. Они попадут на склад.",
				loot
			)
		end
		return step(
			"leave",
			"Отойдите от шахты: пустой контейнер уберётся сам, и можно заказывать следующий.",
			plot.Clear
		)
	end
	if #data.Inventory > 0 then
		return step(
			"sell",
			"Отнесите находки на склад (справа): нажмите E у стола и продайте предметы за монеты.",
			plot.Stations.inventory
		)
	end
	if data.Opened >= OPENED_FOR_PERKS and data.Coins >= FIRST_PERK_COINS then
		return step(
			"perks",
			"Монет хватает на первое улучшение! Откройте «Перки» (кнопка справа внизу или клавиша P).",
			nil,
			"perks"
		)
	end
	if data.Coins >= Economy.orderPrice(data) then
		return step(
			"order",
			"Закажите контейнер: подойдите к терминалу заказов и нажмите «Заказать».",
			plot.Stations.terminal
		)
	end
	return step(
		"money",
		"Монет на заказ не хватает. Продайте находки или заберите ежедневную награду (кнопка G)."
	)
end

return Tutorial
