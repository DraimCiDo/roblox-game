--!strict
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)

type Drop = { Kind: string, Price: number, Weight: number }
type Container = { Min: number, Max: number, Deliver: number, OpenSteps: number, Drops: { Drop }, Extra: Drop }

local function drop(kind: string, price: number, weight: number): Drop
	return { Kind = kind, Price = price, Weight = weight }
end

local Containers: { [string]: Container } = {
	box = {
		Min = 1,
		Max = 2,
		Deliver = 2,
		OpenSteps = 4,
		Drops = {
			drop("ball", 2600, 13),
			drop("trash", 2300, 16),
			drop("bell", 3100, 10),
			drop("bowl", 2500, 13),
			drop("painting", 4200, 5),
			drop("fish", 3200, 8),
			drop("dumbbell", 2900, 11),
			drop("brush", 2400, 14),
			drop("parcel", 2500, 15),
			drop("elfhat", 4800, 4),
		},
		Extra = drop("prism", 6000, 8),
	},
	crate = {
		Min = 2,
		Max = 4,
		Deliver = 2.5,
		OpenSteps = 4,
		Drops = {
			drop("flower", 4000, 15),
			drop("meteor", 10000, 4),
			drop("bin", 3900, 15),
			drop("computer", 6500, 9),
			drop("tv", 7100, 8),
			drop("fan", 4500, 13),
			drop("trophy", 8300, 6),
			drop("rockart", 6000, 10),
			drop("radio", 5000, 12),
			drop("camera", 6200, 10),
		},
		Extra = drop("crateGem", 10000, 8),
	},
	safe = {
		Min = 3,
		Max = 4,
		Deliver = 3,
		OpenSteps = 1,
		Drops = {
			drop("gold", 21000, 10),
			drop("dollars", 15000, 15),
			drop("gpu", 23000, 7),
			drop("glasses", 20000, 10),
			drop("boombox", 31000, 4),
			drop("button", 22000, 9),
			drop("console", 17000, 13),
			drop("phone", 17000, 14),
			drop("davinci", 32000, 4),
			drop("bomb", 14000, 15),
		},
		Extra = drop("diamond", 55000, 8),
	},
	cargo = {
		Min = 2,
		Max = 3,
		Deliver = 4,
		OpenSteps = 3,
		Drops = {
			drop("rover", 150000, 12),
			drop("coupe", 230000, 6),
			drop("robot", 110000, 14),
			drop("crateGem", 10000, 14),
		},
		Extra = drop("concept", 550000, 8),
	},
	secret = {
		Min = 3,
		Max = 4,
		Deliver = 3.5,
		OpenSteps = 5,
		Drops = {
			drop("diamond", 55000, 10),
			drop("core", 390000, 10),
			drop("concept", 550000, 6),
			drop("anomaly", 300000, 14),
		},
		Extra = drop("prism", 6000, 8),
	},
}

local Economy = {}
-- Взлом сейфа идёт в три этапа: с каждым этапом указатель быстрее, а сектор уже.
Economy.DialStages = 3
Economy.DialTimeLimit = 20
local DIAL_PERIODS = { 3, 2.4, 1.9 }
local DIAL_TOLERANCES = { 0.12, 0.1, 0.08 }

local E = Catalog.Effects
-- Цена заказа составляет эту долю от ожидаемой выручки с контейнера на текущем уровне лаборатории.
local PRICE_SHARE = 0.6
local PRICE_STEP = 50
local QUALITY_MEAN = 0.9626

-- Навыки «Знаток …»: бонус к цене находок из контейнеров своего типа (индекс = тип контейнера).
local MASTERY_PERKS = { "boxMaster", "crateMaster", "safeMaster", "cargoMaster", "secretMaster" }
-- Редкими считаются предметы с весом выпадения не выше этого значения.
local RARE_WEIGHT = 9

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
	tierValue[index] = (container.Min + container.Max) / 2 * sum / weight * QUALITY_MEAN
end

-- Параметры этапа взлома: цель (0..1), период оборота указателя и допуск попадания.
-- Навыки «Твёрдая рука» и «Замедление» расширяют зону и замедляют указатель.
function Economy.dial(order: Types.Order, stage: number, perks: { [string]: number }): (number, number, number)
	local target = order.Target
	if stage > 1 then
		target = 0.12 + ((order.Target + (stage - 1) * 0.3819) % 1) * 0.76
	end
	local tolerance = math.min(DIAL_TOLERANCES[stage] * (1 + E.SteadyStep * (perks.steady or 0)), 0.3)
	local period = DIAL_PERIODS[stage] * (1 + E.SlowStep * (perks.slow or 0))
	return target, period, tolerance
end

function Economy.capacity(data: Types.PlayerData): number
	return 15 + 5 * (data.Perks.storage or 0)
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
	return total / #collection / 1000 * power
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
	local multiplier = if quality <= 50 then 0.5 + quality * 0.01 else 1 + (quality - 50) * 0.015
	local perks = data.Perks
	local bonus = Economy.collectionBonus(data, item.Kind) + (perks.sale or 0) * E.SaleStep + (extra or 0)
	if quality >= 71 then
		bonus += (perks.haggle or 0) * E.HaggleStep
	elseif quality <= 49 then
		bonus += (perks.junk or 0) * E.JunkStep
	end
	local mastery = MASTERY_PERKS[tierOf[item.Kind]]
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
	local base = math.max(Config.OrderPrice, math.round(expected * PRICE_SHARE / PRICE_STEP) * PRICE_STEP)
	return math.max(10, math.round(base * (1 - E.DiscountStep * (data.Perks.discount or 0)) / 10) * 10)
end

function Economy.dailyReward(data: Types.PlayerData): number
	return math.round(Economy.orderPrice(data) * 2 * (1 + E.DailyStep * (data.Perks.daily or 0)))
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
		return 0.6
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
	if roll <= 20 then
		return random:NextInteger(1, 20)
	elseif roll <= 60 then
		return random:NextInteger(21, 49)
	elseif roll <= 90 then
		return random:NextInteger(50, 70)
	elseif roll <= 98 then
		return random:NextInteger(71, 99)
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

local function pick(container: Container, variant: boolean, rarity: number): string
	local pool = table.clone(container.Drops)
	if variant then
		table.insert(pool, container.Extra)
	end
	local weights = {}
	local total = 0
	for i, entry in pool do
		local emphasis = if variant and i <= #container.Drops and entry.Weight <= RARE_WEIGHT then 2 else 1
		local boost = if entry.Weight <= RARE_WEIGHT then 1 + E.RarityStep * rarity else 1
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
