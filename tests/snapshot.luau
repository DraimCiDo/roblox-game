--!nocheck
-- Characterization snapshot of game rules and content.
--   lune run tests/snapshot.luau            compare with tests/snapshot.txt
--   lune run tests/snapshot.luau --update   rewrite it (only when a change in behaviour is intended)

local fs = require("@lune/fs")
local process = require("@lune/process")
local Harness = require("./harness")

local FILE = "tests/snapshot.txt"

-- Adapter: the only part that follows module moves.
local Catalog = Harness.require("ReplicatedStorage.Shared.Catalog")
local GameConfig = Harness.require("ReplicatedStorage.Shared.Config.GameConfig")
local Sounds = Harness.require("ReplicatedStorage.Shared.Config.Sounds")
local Theme = Harness.require("ReplicatedStorage.Shared.Config.Theme")
local Economy = Harness.require("ServerScriptService.Server.Economy.Economy")

local lines: { string } = {}

local function show(value: any): string
	local kind = type(value)
	if kind == "number" then
		return string.format("%.10g", value)
	elseif kind == "string" then
		return string.format("%q", value)
	elseif kind == "boolean" or kind == "nil" then
		return tostring(value)
	elseif kind == "table" then
		local keys = {}
		for key, inner in value do
			if type(inner) ~= "function" then
				table.insert(keys, key)
			end
		end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then
				return a < b
			end
			return type(a) == "number"
		end)
		local parts = {}
		for _, key in keys do
			table.insert(parts, `{key}={show(value[key])}`)
		end
		return `\{{table.concat(parts, ",")}}`
	end
	return tostring(value)
end

local function out(name: string, ...: any)
	local parts = {}
	for index = 1, select("#", ...) do
		table.insert(parts, show((select(index, ...))))
	end
	table.insert(lines, `{name}: {table.concat(parts, " | ")}`)
end

local function sorted(map): { any }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- Content ---------------------------------------------------------------------
for _, key in { "Kinds", "Containers", "Variants", "Effects", "Levels", "TierUnlock", "TierWeights" } do
	out(key, Catalog[key])
end
for _, kind in sorted(Catalog.Items) do
	out(`item {kind}`, Catalog.Items[kind])
end
out("collections", Catalog.Collections)
out("displaySizes", Catalog.DisplaySizes)
out("branches", Catalog.Branches)
out("dropEffects", Catalog.DropEffects)
out("defaultEffect", Catalog.DefaultEffect)
out("gameConfig", GameConfig)
for _, name in sorted(Sounds) do
	out(`sound {name}`, Sounds[name])
end
for _, name in sorted(Theme.Colors) do
	out(`color {name}`, tostring(Theme.Colors[name]))
end

for _, list in { Catalog.Perks, Catalog.PerkNodes } do
	for _, perk in list do
		out(`perk {perk.Key}`, perk)
		local texts = {}
		for level = 0, #perk.Costs do
			table.insert(texts, perk.Describe(level))
		end
		out(`describe {perk.Key}`, texts)
	end
end

-- Rules -----------------------------------------------------------------------
local function maxed(): { [string]: number }
	local perks = {}
	for _, perk in Catalog.Perks do
		perks[perk.Key] = #perk.Costs
	end
	return perks
end

local function half(): { [string]: number }
	local perks = {}
	for _, perk in Catalog.Perks do
		perks[perk.Key] = math.ceil(#perk.Costs / 2)
	end
	return perks
end

local PROFILES = { { "none", {} }, { "half", half() }, { "max", maxed() } }
local OPENED = { 0, 1, 12, 30, 70, 150, 400, 900, 2000, 5000, 9000 }

for _, opened in OPENED do
	out(`level {opened}`, Catalog.levelRange(opened))
	for _, profile in PROFILES do
		out(`odds {opened} {profile[1]}`, Catalog.odds(opened, profile[2]))
	end
end

for quality = 1, 100 do
	out(`condition {quality}`, Catalog.condition(quality))
end

for _, profile in PROFILES do
	local name, perks = profile[1], profile[2]
	local levels = Catalog.nodeLevels(perks)
	for _, perk in Catalog.Perks do
		for level = 0, #perk.Costs do
			out(
				`perk rules {name} {perk.Key} {level}`,
				Catalog.perkCost(perk, level, perks),
				Catalog.perkLock(perk, level, perks, 0),
				Catalog.perkLock(perk, level, perks, 100000)
			)
		end
		out(`perk ready {name} {perk.Key}`, Catalog.perkReady(perk, perks, 1e12, 100000, 2500))
	end
	for _, node in Catalog.PerkNodes do
		out(`node rules {name} {node.Key}`, Catalog.perkCost(node, 0, levels), Catalog.perkLock(node, 0, levels, 100))
	end
end

for _, effect in Catalog.DropEffects do
	out(
		`effect {effect.Key}`,
		Catalog.dropEffect(effect.Key) == effect,
		Catalog.effectAvailable(effect, 0, {}),
		Catalog.effectAvailable(effect, 1000, {}),
		Catalog.effectAvailable(effect, 0, { [effect.Key] = true })
	)
end

local function playerData(perks, opened: number)
	local collections = {}
	for index, collection in Catalog.Collections do
		for position, kind in collection.Items do
			-- The last collection stays incomplete.
			if index < #Catalog.Collections or position > 1 then
				collections[kind] = { Id = kind, Kind = kind, Quality = 40 + position * 11 }
			end
		end
	end
	return {
		Coins = 1000,
		Earned = 0,
		Opened = opened,
		Perks = perks,
		Collections = collections,
		Displays = {
			["1"] = { Id = "a", Kind = "gold", Quality = 90 },
			["2"] = { Id = "b", Kind = "tv", Quality = 30 },
		},
		Orders = {},
	}
end

for _, profile in PROFILES do
	local name, perks = profile[1], profile[2]
	local data = playerData(perks, 400)
	out(
		`economy {name}`,
		Economy.capacity(data),
		Economy.completedCollections(data),
		Economy.bulkBonus(data),
		Economy.recycleLimit(data),
		Economy.cashback(data, 12345),
		Economy.galleryIncome(data),
		Economy.dailyReward(data)
	)
	for _, kind in sorted(Catalog.Items) do
		local prices = {}
		for _, quality in { 1, 20, 49, 50, 51, 70, 71, 99, 100 } do
			table.insert(prices, Economy.price(data, { Id = "x", Kind = kind, Quality = quality }))
		end
		out(`price {name} {kind}`, prices, Economy.collectionBonus(data, kind), Economy.collectible(kind))
	end
	for _, opened in OPENED do
		local at = playerData(perks, opened)
		out(`order price {name} {opened}`, Economy.orderPrice(at), Economy.dailyReward(at))
	end
	for stage = 1, Economy.DialStages do
		out(`dial {name} {stage}`, Economy.dial({ Target = 0.37 }, stage, perks))
	end
end
out("dial config", Economy.DialStages, Economy.DialTimeLimit)
local wallet = { Coins = 5, Earned = 7 }
Economy.credit(wallet, 3)
out("credit", wallet)

-- Seeded random rolls ---------------------------------------------------------
for _, profile in PROFILES do
	local name, perks = profile[1], profile[2]
	Harness.reseed(12345)
	local data = playerData(perks, 9000)
	for index = 1, 60 do
		local order = Economy.newOrder(data, index == 1)
		out(`order {name} {index}`, order, Economy.deliveryTime(order, data), Economy.openingGoal(order))
		Economy.open(order, data)
		out(`loot {name} {index}`, order.Stage, order.Loot)
	end
	for index = 1, 100 do
		out(`payout {name} {index}`, Economy.payout(data, { Id = "p", Kind = "gold", Quality = 80 }, 0.1))
	end
end
for _, kind in Catalog.Kinds do
	for progress = 0, 15 do
		out(`progress {kind} {progress}`, Economy.openingProgress({ Kind = kind, Progress = progress }))
	end
end

local text = table.concat(lines, "\n") .. "\n"

if table.find(process.args, "--update") then
	fs.writeFile(FILE, text)
	print(`snapshot written: {#lines} lines`)
	return
end

local expected = string.split((fs.readFile(FILE):gsub("\r", "")), "\n")
local actual = string.split(text, "\n")
local differences = 0
for index = 1, math.max(#expected, #actual) do
	if expected[index] ~= actual[index] then
		differences += 1
		if differences <= 5 then
			print(`line {index}\n  expected: {expected[index]}\n  actual:   {actual[index]}`)
		end
	end
end
if differences > 0 then
	print(`snapshot FAILED: {differences} differing lines`)
	process.exit(1)
end
print(`snapshot OK: {#lines} lines`)
