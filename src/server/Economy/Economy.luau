--!strict
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Balance = require(script.Parent.Parent.Config.Balance)
local Containers = require(script.Parent.Parent.Config.Loot)

local Economy = {}
Economy.DialStages = #Balance.Dial.Periods
Economy.DialTimeLimit = Balance.Dial.TimeLimit

local E = Catalog.Effects
local random = Random.new()
local prices: { [string]: number } = {}
local tierOf: { [string]: number } = {}
local collectionIndex: { [string]: { string } } = {}
local collectionPerk: { [string]: string } = {}
for index, name in Catalog.Kinds do
	local container = Containers[name]
	for _, entry in container.Drops do
		prices[entry.Kind] = entry.Price
		tierOf[entry.Kind] = tierOf[entry.Kind] or index
	end
	prices[container.Extra.Kind] = container.Extra.Price
	tierOf[container.Extra.Kind] = tierOf[container.Extra.Kind] or index
end
for _, collection in Catalog.Collections do
	for _, kind in collection.Items do
		collectionIndex[kind] = collection.Items
		collectionPerk[kind] = collection.Perk
	end
end

-- Ожидаемая выручка с контейнера каждого типа без перков: число предметов × средняя цена × средний множитель качества.
local tierValue: { number } = {}
for index, kind in Catalog.Kinds do
	local container = Containers[kind]
	local sum, weight = 0, 0
	for _, entry in container.Drops do
		sum += entry.Price * entry.Weight
		weight += entry.Weight
	end
	tierValue[index] = (container.Min + container.Max) / 2 * sum / weight * Balance.QualityMean
end

-- Параметры этапа взлома: цель (0..1), период оборота указателя и допуск попадания.
-- Навыки «Твёрдая рука» и «Замедление» расширяют зону и замедляют указатель.
function Economy.dial(order: Types.Order, stage: number, perks: { [string]: number }): (number, number, number)
	local target = order.Target
	if stage > 1 then
		target = 0.12 + ((order.Target + (stage - 1) * 0.3819) % 1) * 0.76
	end
	local tolerance =
		math.min(Balance.Dial.Tolerances[stage] * (1 + E.SteadyStep * (perks.steady or 0)), Balance.Dial.MaxTolerance)
	local period = Balance.Dial.Periods[stage] * (1 + E.SlowStep * (perks.slow or 0))
	return target, period, tolerance
end

function Economy.capacity(data: Types.PlayerData): number
	return Catalog.Storage.Base + Catalog.Storage.Step * (data.Perks.storage or 0)
end

function Economy.collectionBonus(data: Types.PlayerData, kind: string): number
	local collection = collectionIndex[kind]
	if not collection then
		return 0
	end
	local total = 0
	for _, required in collection do
		local item = data.Collections[required]
		if not item then
			return 0
		end
		total += item.Quality
	end
	local specific = data.Perks[collectionPerk[kind]] or 0
	local power = 1 + E.CollectionStep * (data.Perks.collection or 0) + E.SpecialtyStep * specific
	return total / #collection / Balance.CollectionDivisor * power
end

-- Сколько коллекций заполнено полностью.
function Economy.completedCollections(data: Types.PlayerData): number
	local count = 0
	for _, collection in Catalog.Collections do
		local complete = true
		for _, kind in collection.Items do
			if not data.Collections[kind] then
				complete = false
				break
			end
		end
		if complete then
			count += 1
		end
	end
	return count
end

function Economy.collectible(kind: string): boolean
	return collectionIndex[kind] ~= nil
end

-- Цена предмета: аддитивно складываются качество, коллекция и навыки торговли. extra — разовая надбавка (оптовик).
function Economy.price(data: Types.PlayerData, item: Types.Item, extra: number?): number
	local quality = item.Quality
	local curve = Balance.Price
	local multiplier = if quality <= curve.Middle
		then curve.Base + quality * curve.PerPoint
		else curve.UpperBase + (quality - curve.Middle) * curve.UpperPerPoint
	local perks = data.Perks
	local bonus = Economy.collectionBonus(data, item.Kind) + (perks.sale or 0) * E.SaleStep + (extra or 0)
	if quality >= Balance.HaggleFrom then
		bonus += (perks.haggle or 0) * E.HaggleStep
	elseif quality <= Balance.JunkUpTo then
		bonus += (perks.junk or 0) * E.JunkStep
	end
	local mastery = Balance.MasteryPerks[tierOf[item.Kind]]
	if mastery then
		bonus += (perks[mastery] or 0) * E.MasteryStep
	end
	return math.round(prices[item.Kind] * (multiplier + bonus))
end

-- Выручка с продажи: цена и шанс «Джекпота» удвоить её. Использовать только при реальной продаже.
function Economy.payout(data: Types.PlayerData, item: Types.Item, extra: number?): number
	local value = Economy.price(data, item, extra)
	if random:NextNumber() < E.JackpotStep * (data.Perks.jackpot or 0) then
		return value * 2
	end
	return value
end

-- Надбавка к цене при быстрой продаже («Оптовик»).
function Economy.bulkBonus(data: Types.PlayerData): number
	return E.BulkStep * (data.Perks.bulk or 0)
end

-- Предметы качества не выше этого значения продаются сразу при сборе («Утилизатор»).
function Economy.recycleLimit(data: Types.PlayerData): number
	return E.RecyclerStep * (data.Perks.recycler or 0)
end

-- Возврат части цены заказа («Кэшбэк»).
function Economy.cashback(data: Types.PlayerData, price: number): number
	return math.round(price * E.CashbackStep * (data.Perks.cashback or 0))
end

-- Доход витрин за минуту («Галерея»), усиленный полными коллекциями («Музейный фонд»).
function Economy.galleryIncome(data: Types.PlayerData): number
	local level = data.Perks.gallery or 0
	if level <= 0 then
		return 0
	end
	local total = 0
	for _, item in data.Displays do
		total += Economy.price(data, item)
	end
	local museum = 1 + E.MuseumStep * (data.Perks.museum or 0) * Economy.completedCollections(data)
	return total * E.GalleryStep * level * museum
end

function Economy.credit(data: Types.PlayerData, amount: number): ()
	data.Coins += amount
	data.Earned += amount
end

-- Цена нового заказа зависит от уровня лаборатории (числа открытых контейнеров) и скидки.
function Economy.orderPrice(data: Types.PlayerData): number
	local expected = 0
	for tier, chance in Catalog.odds(data.Opened, {}) do
		expected += chance / 100 * tierValue[tier]
	end
	local base =
		math.max(Config.OrderPrice, math.round(expected * Balance.PriceShare / Balance.PriceStep) * Balance.PriceStep)
	return math.max(
		Balance.MinOrderPrice,
		math.round(base * (1 - E.DiscountStep * (data.Perks.discount or 0)) / 10) * 10
	)
end

function Economy.dailyReward(data: Types.PlayerData): number
	return math.round(
		Economy.orderPrice(data) * Balance.DailyRewardOrders * (1 + E.DailyStep * (data.Perks.daily or 0))
	)
end

function Economy.newOrder(data: Types.PlayerData, starter: boolean): Types.Order
	local roll = random:NextNumber() * 100
	local kind = "box"
	if not starter then
		for tier, chance in Catalog.odds(data.Opened, data.Perks) do
			roll -= chance
			if chance > 0 and roll <= 0 then
				kind = Catalog.Kinds[tier]
				break
			end
		end
	end
	local variantChance = E.VariantBase + E.VariantStep * (data.Perks.variant or 0)
	return {
		Id = HttpService:GenerateGUID(false),
		Kind = kind,
		Variant = not starter and random:NextNumber() * 100 < variantChance,
		Stage = "queued",
		Deadline = 0,
		Progress = 0,
		Target = random:NextNumber(0.18, 0.82),
		DialStarted = 0,
		Loot = {},
	}
end

-- Время доставки: «Быстрая доставка» сокращает его, «Срочная доставка» с шансом делает почти мгновенным.
function Economy.deliveryTime(order: Types.Order, data: Types.PlayerData): number
	if random:NextNumber() < E.ExpressStep * (data.Perks.express or 0) then
		return Balance.ExpressDelivery
	end
	return Containers[order.Kind].Deliver * (1 - E.DeliveryStep * (data.Perks.delivery or 0))
end

function Economy.openingGoal(order: Types.Order): number
	return Containers[order.Kind].OpenSteps
end

function Economy.openingProgress(order: Types.Order): number
	if order.Kind ~= "crate" and order.Kind ~= "cargo" then
		return order.Progress
	end
	local count = 0
	for index = 0, Economy.openingGoal(order) - 1 do
		if bit32.btest(order.Progress, bit32.lshift(1, index)) then
			count += 1
		end
	end
	return count
end

local function rollQuality(): number
	local roll = random:NextInteger(1, 100)
	for _, band in Balance.Quality do
		roll -= band.Chance
		if roll <= 0 then
			-- A single value band does not consume a second random number.
			return if band.Min == band.Max then band.Min else random:NextInteger(band.Min, band.Max)
		end
	end
	return 100
end

-- Качество находки с учётом навыков: лучшее из двух бросков, шанс идеального качества и нижняя граница.
local function quality(perks: { [string]: number }): number
	local luck = perks.quality or 0
	local value = rollQuality()
	if luck > 0 and random:NextNumber() < E.QualityStep * luck then
		value = math.max(value, rollQuality())
	end
	if random:NextNumber() < E.PerfectStep * (perks.perfect or 0) then
		value = 100
	end
	return math.max(value, math.min(E.FloorStep * (perks.floor or 0), 100))
end

local function pick(container: Containers.Container, variant: boolean, rarity: number): string
	local pool = table.clone(container.Drops)
	if variant then
		table.insert(pool, container.Extra)
	end
	local weights = {}
	local total = 0
	for i, entry in pool do
		local rare = entry.Weight <= Balance.RareWeight
		local emphasis = if variant and i <= #container.Drops and rare then Balance.VariantRareEmphasis else 1
		local boost = if rare then 1 + E.RarityStep * rarity else 1
		local weight = entry.Weight * emphasis * boost
		weights[i] = weight
		total += weight
	end
	local roll = random:NextNumber() * total
	for i, weight in weights do
		roll -= weight
		if roll <= 0 then
			return pool[i].Kind
		end
	end
	error("Пустая таблица добычи")
end

function Economy.open(order: Types.Order, data: Types.PlayerData): ()
	local container = Containers[order.Kind]
	local count = random:NextInteger(container.Min, container.Max)
	if random:NextNumber() < E.LootStep * (data.Perks.bonusLoot or 0) then
		count += 1
	end
	if order.Variant then
		count += E.VariantLootStep * (data.Perks.variantLoot or 0)
	end
	for index = 1, count do
		local x, z
		if order.Kind == "cargo" then
			x, z = if index % 2 == 1 then -3.8 else 3.8, if index <= 2 then 3.1 else -3.6
		else
			local angle = math.pi * 2 * (index - 1) / count + random:NextNumber(-0.17, 0.17)
			local radius = random:NextNumber(5.2, 6.8)
			x, z = math.cos(angle) * radius, math.sin(angle) * radius
		end
		table.insert(order.Loot, {
			Item = {
				Id = HttpService:GenerateGUID(false),
				Kind = pick(container, order.Variant, data.Perks.rarity or 0),
				Quality = quality(data.Perks),
			},
			X = x,
			Z = z,
		})
	end
	order.Stage = "open"
end

return Economy
