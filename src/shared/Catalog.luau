--!strict
-- Read API over the configs in Config/: lookup, odds and perk rules shared by server and client.
-- Change numbers and texts in Config/, not here.
local Config = script.Parent.Config
local Collections = require(Config.Collections)
local Conditions = require(Config.Conditions)
local Containers = require(Config.Containers)
local DropEffects = require(Config.DropEffects)
local Items = require(Config.Items)
local Perks = require(Config.Perks)
local Texts = require(Config.Texts.Rules)
local Format = require(script.Parent.Util.Format)

export type ItemDefinition = Items.ItemDefinition
export type DropEffect = DropEffects.DropEffect
export type Perk = {
	Key: string,
	Name: string,
	Branch: string,
	Costs: { number },
	-- Сколько контейнеров нужно открыть, чтобы купить соответствующий уровень.
	Opened: { number },
	Parent: string?,
	Required: number?,
	-- Дополнительные условия: уровни других навыков, которые нужно изучить заранее.
	Needs: { { Key: string, Level: number } }?,
	Describe: (level: number) -> string,
	-- Только у узлов дерева (Catalog.PerkNodes): исходный навык, номер ступени и число ступеней.
	Base: string?,
	Step: number?,
	Steps: number?,
}

local Catalog = {}

Catalog.Kinds = Containers.Kinds
Catalog.Containers = Containers.Names
Catalog.Variants = Containers.Variants
Catalog.Levels = Containers.Levels
Catalog.TierUnlock = Containers.TierUnlock
Catalog.TierWeights = Containers.TierWeights
Catalog.TierLuckPerks = Containers.TierLuckPerks
Catalog.DisplaySizes = Containers.DisplaySizes
Catalog.Items = Items
Catalog.Collections = Collections
Catalog.Effects = Perks.Effects
Catalog.Storage = Perks.Storage
Catalog.Branches = Perks.Branches
Catalog.DefaultEffect = DropEffects.DefaultEffect
Catalog.DropEffects = DropEffects.List

function Catalog.level(opened: number): number
	local level = 1
	for index, need in Catalog.Levels do
		if opened >= need then
			level = index
		end
	end
	return level
end

-- Возвращает уровень, порог его начала и порог следующего (nil на максимальном уровне).
function Catalog.levelRange(opened: number): (number, number, number?)
	local level = Catalog.level(opened)
	return level, Catalog.Levels[level], Catalog.Levels[level + 1]
end

-- Вероятности типов контейнеров в процентах: учитывают уровень лаборатории и навыки шансов.
function Catalog.odds(opened: number, perks: { [string]: number }): { number }
	local level = Catalog.level(opened)
	local weights: { number } = {}
	local total = 0
	-- Навык шанса типа усиливает этот тип и все более редкие, поэтому прокачка
	-- младшего типа никогда не снижает долю старших.
	local luckBoost = 1
	for tier, base in Catalog.TierWeights do
		local luck = Catalog.TierLuckPerks[tier]
		if luck ~= "" then
			luckBoost *= 1 + Catalog.Effects.TierLuckStep * (perks[luck] or 0)
		end
		local weight = 0
		if level >= Catalog.TierUnlock[tier] then
			weight = base * (1 + Catalog.Effects.OddsStep * (perks.odds or 0)) ^ (tier - 1) * luckBoost
		end
		weights[tier] = weight
		total += weight
	end
	for tier, weight in weights do
		weights[tier] = weight / total * 100
	end
	return weights
end

local function describe(entry): (level: number) -> string
	return function(level: number): string
		local value = entry.Value
		if not value then
			return if level > 0 then entry.TextOwned else entry.Text
		end
		local amount: any
		if not value.Percent then
			amount = (value.Base or 0) + level * value.Step
		elseif value.Decimals then
			amount = string.format(`%.{value.Decimals}f`, level * value.Step * 100)
		else
			amount = math.round(level * value.Step * 100)
		end
		return Format(entry.Text, { value = amount })
	end
end

Catalog.Perks = {} :: { Perk }
for _, entry: any in Perks.List do
	table.insert(Catalog.Perks, {
		Key = entry.Key,
		Name = entry.Name,
		Branch = entry.Branch,
		Costs = entry.Costs,
		Opened = entry.Opened,
		Parent = entry.Parent,
		Required = entry.Required,
		Needs = entry.Needs,
		Describe = describe(entry),
	})
end

local perkIndex: { [string]: Perk } = {}
for _, perk in Catalog.Perks do
	perkIndex[perk.Key] = perk
end

-- Узлы дерева навыков: каждая ступень навыка — отдельный узел с единственным уровнем (куплен или нет).
-- Ступени одного навыка идут цепочкой, первая ступень крепится к нужной ступени родителя.
-- Сохранённые уровни не меняются: узел «ключ#N» куплен, если уровень навыка не меньше N.
Catalog.PerkNodes = {} :: { Perk }
for _, perk in Catalog.Perks do
	local steps = #perk.Costs
	for step = 1, steps do
		local parent: string? = nil
		if step > 1 then
			parent = `{perk.Key}#{step - 1}`
		elseif perk.Parent then
			parent = `{perk.Parent}#{perk.Required or 1}`
		end
		local needs: { { Key: string, Level: number } }? = nil
		if step == 1 and perk.Needs then
			local list: { { Key: string, Level: number } } = {}
			for _, need in perk.Needs do
				table.insert(list, { Key = `{need.Key}#{need.Level}`, Level = 1 })
			end
			needs = list
		end
		table.insert(Catalog.PerkNodes, {
			Key = `{perk.Key}#{step}`,
			Name = if steps > 1 then `{perk.Name} {step}` else perk.Name,
			Branch = perk.Branch,
			Costs = { perk.Costs[step] },
			Opened = { perk.Opened[step] or 0 },
			Parent = parent,
			Required = 1,
			Needs = needs,
			Describe = function(_level: number)
				return perk.Describe(step)
			end,
			Base = perk.Key,
			Step = step,
			Steps = steps,
		})
	end
end
for _, node in Catalog.PerkNodes do
	perkIndex[node.Key] = node
end

-- Уровни узлов (0 или 1) вместе с обычными уровнями навыков: годится для Catalog.perkCost и Catalog.perkLock.
function Catalog.nodeLevels(perks: { [string]: number }): { [string]: number }
	local levels = table.clone(perks)
	for _, node in Catalog.PerkNodes do
		levels[node.Key] = if (perks[node.Base :: string] or 0) >= (node.Step :: number) then 1 else 0
	end
	return levels
end

function Catalog.perk(key: string): Perk?
	return perkIndex[key]
end

-- Стоимость следующего уровня навыка с учётом навыка «Научный грант».
function Catalog.perkCost(perk: Perk, level: number, perks: { [string]: number }): number?
	local base = perk.Costs[level + 1]
	if not base then
		return nil
	end
	return math.round(base * (1 - Catalog.Effects.GrantStep * (perks.grant or 0)) / 10) * 10
end

-- Можно ли купить следующий уровень навыка прямо сейчас: условия выполнены, монет хватает и остаётся на заказ.
function Catalog.perkReady(
	perk: Perk,
	perks: { [string]: number },
	coins: number,
	opened: number,
	orderPrice: number
): boolean
	local level = math.min(perks[perk.Key] or 0, #perk.Costs)
	local cost = Catalog.perkCost(perk, level, perks)
	if not cost or Catalog.perkLock(perk, level, perks, opened) then
		return false
	end
	return coins >= cost and coins - cost >= orderPrice
end

-- Проверка условий открытия уровня навыка: родитель, дополнительные навыки и число открытых контейнеров.
-- Возвращает причину отказа или nil, если навык доступен.
function Catalog.perkLock(perk: Perk, level: number, perks: { [string]: number }, opened: number): string?
	if perk.Parent and (perks[perk.Parent] or 0) < (perk.Required or 1) then
		local parent = perkIndex[perk.Parent]
		return Format(
			Texts.needPerk,
			{ name = if parent then parent.Name else perk.Parent, level = perk.Required or 1 }
		)
	end
	if perk.Needs then
		for _, need in perk.Needs do
			if (perks[need.Key] or 0) < need.Level then
				local other = perkIndex[need.Key]
				return Format(Texts.needPerk, { name = if other then other.Name else need.Key, level = need.Level })
			end
		end
	end
	local need = perk.Opened[level + 1]
	if need and opened < need then
		return Format(Texts.needOpened, { need = need, opened = opened })
	end
	return nil
end

local function conditionOf(quality: number)
	for _, condition in Conditions do
		if quality <= condition.Max then
			return condition
		end
	end
	return Conditions[#Conditions]
end

function Catalog.condition(quality: number): string
	return conditionOf(quality).Name
end

function Catalog.conditionColor(quality: number): Color3
	return conditionOf(quality).Color
end

local effectIndex: { [string]: DropEffect } = {}
for _, effect in Catalog.DropEffects do
	effectIndex[effect.Key] = effect
end

function Catalog.dropEffect(key: string): DropEffect?
	return effectIndex[key]
end

-- Можно ли применить эффект: бесплатный, куплен или получен за достижение.
function Catalog.effectAvailable(effect: DropEffect, opened: number, owned: { [string]: boolean }): boolean
	if owned[effect.Key] then
		return true
	end
	if effect.Opened then
		return opened >= effect.Opened
	end
	return effect.Price == nil
end

return Catalog
