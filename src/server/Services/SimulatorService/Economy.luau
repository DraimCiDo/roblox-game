--!strict
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)

type Drop = { Kind: string, Price: number, Weight: number }
type Container = { Min: number, Max: number, Deliver: number, Drops: { Drop }, Extra: Drop }

local function drop(kind: string, price: number, weight: number): Drop
	return { Kind = kind, Price = price, Weight = weight }
end

local Containers: { [string]: Container } = {
	box = {
		Min = 1,
		Max = 2,
		Deliver = 2,
		Drops = {
			drop("ball", 3200, 13),
			drop("trash", 2800, 16),
			drop("bell", 3800, 10),
			drop("bowl", 3100, 13),
			drop("painting", 5100, 5),
			drop("fish", 3900, 8),
			drop("dumbbell", 3500, 11),
			drop("brush", 2950, 14),
			drop("parcel", 3000, 15),
			drop("elfhat", 5800, 4),
		},
		Extra = drop("prism", 9500, 8),
	},
	crate = {
		Min = 2,
		Max = 4,
		Deliver = 2.5,
		Drops = {
			drop("flower", 5500, 15),
			drop("meteor", 14000, 4),
			drop("bin", 5400, 15),
			drop("computer", 9000, 9),
			drop("tv", 9800, 8),
			drop("fan", 6300, 13),
			drop("trophy", 11500, 6),
			drop("rockart", 8300, 10),
			drop("radio", 7000, 12),
			drop("camera", 8600, 10),
		},
		Extra = drop("crateGem", 17500, 8),
	},
	safe = {
		Min = 3,
		Max = 4,
		Deliver = 3,
		Drops = {
			drop("gold", 44000, 10),
			drop("dollars", 32000, 15),
			drop("gpu", 49000, 7),
			drop("glasses", 41500, 10),
			drop("boombox", 65000, 4),
			drop("button", 47000, 9),
			drop("console", 36000, 13),
			drop("phone", 35000, 14),
			drop("davinci", 68000, 4),
			drop("bomb", 30000, 15),
		},
		Extra = drop("diamond", 125000, 8),
	},
	cargo = {
		Min = 2,
		Max = 3,
		Deliver = 4,
		Drops = {
			drop("rover", 360000, 12),
			drop("coupe", 560000, 6),
			drop("robot", 260000, 14),
			drop("crateGem", 17500, 14),
		},
		Extra = drop("concept", 1350000, 8),
	},
	secret = {
		Min = 3,
		Max = 4,
		Deliver = 3.5,
		Drops = {
			drop("diamond", 125000, 10),
			drop("core", 950000, 10),
			drop("concept", 1350000, 6),
			drop("anomaly", 720000, 14),
		},
		Extra = drop("prism", 9500, 8),
	},
}

local Economy = {}
Economy.DailyReward = 5000
Economy.VariantChance = 5
Economy.DialPeriod = 3
Economy.DialTolerance = 0.12

local random = Random.new()
local prices: { [string]: number } = {}
local collectionIndex: { [string]: { string } } = {}
for _, container in Containers do
	for _, entry in container.Drops do
		prices[entry.Kind] = entry.Price
	end
	prices[container.Extra.Kind] = container.Extra.Price
end
for _, collection in Catalog.Collections do
	for _, kind in collection.Items do
		collectionIndex[kind] = collection.Items
	end
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
	return total / #collection / 1000
end

function Economy.collectible(kind: string): boolean
	return collectionIndex[kind] ~= nil
end

function Economy.price(data: Types.PlayerData, item: Types.Item): number
	local quality = item.Quality
	local multiplier = if quality <= 50 then 0.5 + quality * 0.01 else 1 + (quality - 50) * 0.015
	return math.round(
		prices[item.Kind] * (multiplier + Economy.collectionBonus(data, item.Kind) + (data.Perks.sale or 0) * 0.1)
	)
end

function Economy.credit(data: Types.PlayerData, amount: number): ()
	data.Coins += amount
	data.Earned += amount
end

function Economy.newOrder(data: Types.PlayerData, starter: boolean): Types.Order
	local odds = Catalog.Odds[(data.Perks.odds or 0) + 1]
	local roll = random:NextInteger(1, 100)
	local kind = "box"
	if not starter then
		for i, chance in odds do
			roll -= chance
			if roll <= 0 then
				kind = Catalog.Kinds[i]
				break
			end
		end
	end
	return {
		Id = HttpService:GenerateGUID(false),
		Kind = kind,
		Variant = not starter and random:NextInteger(1, 100) <= Economy.VariantChance,
		Stage = "queued",
		Deadline = 0,
		Progress = 0,
		Target = random:NextNumber(0.18, 0.82),
		DialStarted = 0,
		Loot = {},
	}
end

function Economy.deliveryTime(order: Types.Order): number
	return Containers[order.Kind].Deliver
end

local function quality(): number
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

local function pick(container: Container, variant: boolean): string
	local pool = table.clone(container.Drops)
	if variant then
		table.insert(pool, container.Extra)
	end
	local weights = {}
	local total = 0
	for i, entry in pool do
		local emphasis = if variant and i <= #container.Drops and entry.Weight <= 9 then 2 else 1
		local weight = entry.Weight * emphasis
		weights[i] = weight
		total += weight
	end
	local roll = random:NextInteger(1, total)
	for i, weight in weights do
		roll -= weight
		if roll <= 0 then
			return pool[i].Kind
		end
	end
	error("Пустая таблица добычи")
end

function Economy.open(order: Types.Order): ()
	local container = Containers[order.Kind]
	local count = random:NextInteger(container.Min, container.Max)
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
			Item = { Id = HttpService:GenerateGUID(false), Kind = pick(container, order.Variant), Quality = quality() },
			X = x,
			Z = z,
		})
	end
	order.Stage = "open"
end

return Economy
