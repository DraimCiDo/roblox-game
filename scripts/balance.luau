--!nocheck
-- Progression pace simulator: lune run scripts/balance.luau [seconds per container]
-- Plays a "greedy" player through the real game rules and configs: orders a container, sells all loot,
-- buys the cheapest available perk while keeping money for the next order. Collections are ignored.

local process = require("@lune/process")
local Harness = require("../tests/harness")

local Catalog = Harness.require("ReplicatedStorage.Shared.Catalog")
local Economy = Harness.require("ServerScriptService.Server.Economy.Economy")

local SECONDS = tonumber(process.args[1]) or 35
local MAX_CONTAINERS = 14000
local REPORT_AT = { 10, 25, 50, 100, 250, 500, 1000, 2000, 4000, 6000, 8000, 10000 }

Harness.reseed(1)

local data = { Coins = 2500, Earned = 0, Opened = 0, Perks = {}, Collections = {}, Displays = {} }

local function totalLevels(): (number, number)
	local owned, all = 0, 0
	for _, perk in Catalog.Perks do
		owned += data.Perks[perk.Key] or 0
		all += #perk.Costs
	end
	return owned, all
end

local function cheapest(): (any, number?)
	local best, price = nil, nil
	for _, perk in Catalog.Perks do
		local level = data.Perks[perk.Key] or 0
		local cost = Catalog.perkCost(perk, level, data.Perks)
		if cost and not Catalog.perkLock(perk, level, data.Perks, data.Opened) and (not price or cost < price) then
			best, price = perk, cost
		end
	end
	return best, price
end

print("Laboratory levels (opened, order price, odds %):")
for level, need in Catalog.Levels do
	local shares = {}
	for _, chance in Catalog.odds(need, {}) do
		table.insert(shares, string.format("%5.1f", chance))
	end
	local price = Economy.orderPrice({ Opened = need, Perks = {} })
	print(`  L{level} from {need}: price {price}  [{table.concat(shares, " ")}]`)
end

local seconds = 0
local first: { string } = {}
while data.Opened < MAX_CONTAINERS do
	local price = Economy.orderPrice(data)
	if data.Coins < price then
		-- Out of money: roughly one mopping session.
		data.Coins += 300
		seconds += SECONDS
		continue
	end
	data.Coins += Economy.cashback(data, price) - price
	local order = Economy.newOrder(data, false)
	Economy.open(order, data)
	for _, loot in order.Loot do
		data.Coins += Economy.payout(data, loot.Item)
	end
	data.Opened += 1
	seconds += SECONDS * (1 - Catalog.Effects.DeliveryStep * (data.Perks.delivery or 0))

	while true do
		local perk, cost = cheapest()
		if not perk or cost > data.Coins - Economy.orderPrice(data) then
			break
		end
		data.Coins -= cost
		data.Perks[perk.Key] = (data.Perks[perk.Key] or 0) + 1
		if #first < 18 then
			table.insert(first, `  container {data.Opened}: {perk.Key} -> {data.Perks[perk.Key]}`)
		end
	end

	local owned, all = totalLevels()
	if table.find(REPORT_AT, data.Opened) then
		print(
			`opened {data.Opened} · {string.format("%.1f", seconds / 3600)} h · coins {math.round(data.Coins)} · perk levels {owned}/{all}`
		)
	end
	if owned == all then
		print(`All perks bought at container {data.Opened}, {string.format("%.1f", seconds / 3600)} h`)
		break
	end
end

print("First purchases:")
print(table.concat(first, "\n"))
