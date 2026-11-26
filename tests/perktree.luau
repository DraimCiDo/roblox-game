--!nocheck
-- Visibility and layout rules of the perk tree.
--   lune run tests/perktree.luau

local Harness = require("./harness")

local Catalog = Harness.require("ReplicatedStorage.Shared.Catalog")
local PerkTree = Harness.require("ReplicatedStorage.Shared.PerkTree")

local checks = 0

local function expect(condition: any, message: string)
	checks += 1
	assert(condition, message)
end

local function count(map): number
	local total = 0
	for _ in map do
		total += 1
	end
	return total
end

-- A new player: open branches show their first step and one "?" after it.
local trade = PerkTree.states("trade", {})
expect(trade["sale#1"] == "available", "first sale step is available")
expect(trade["sale#2"] == "hidden", "the step after it is hidden")
expect(trade["sale#3"] == nil, "further steps are not shown")
expect(count(trade) == 2, "nothing else in trade")

for _, branch in { "mastery", "collections", "lockpick" } do
	expect(count(PerkTree.states(branch, {})) == 0, `{branch} starts locked`)
	expect(PerkTree.unlockedBy(branch) ~= nil, `{branch} names what opens it`)
end

-- Buying moves the frontier and opens side chains.
local later = PerkTree.states("trade", { sale = 2 })
expect(later["sale#2"] == "owned", "bought steps stay")
expect(later["sale#3"] == "available", "next step")
expect(later["junk#1"] == "available", "side chain opens at its parent step")
expect(later["haggle#1"] == nil, "a chain needing sale 4 is not shown yet")

-- Another branch opens a locked one; a root still waiting is a "?".
local mastery = PerkTree.states("mastery", { sale = 2 })
expect(mastery["boxMaster#1"] == "available", "sale 2 opens mastery")
expect(mastery["crateLuck#1"] == "hidden", "root waiting for another branch")

-- Layout: no two visible nodes share a cell, children stand right of their parent, and a
-- completed tree shows every node exactly once.
local maxed = {}
for _, perk in Catalog.Perks do
	maxed[perk.Key] = #perk.Costs
end
local shown = 0
for _, levels in { {}, { sale = 4, odds = 3 }, maxed } do
	for _, branch in Catalog.Branches do
		local states = PerkTree.states(branch.Key, levels)
		local cells, columns, rows = PerkTree.layout(branch.Key, states)
		expect(count(cells) == count(states), `{branch.Key}: every visible node is placed`)
		local taken = {}
		for key, cell in cells do
			local at = `{cell.Column}:{cell.Row}`
			expect(not taken[at], `{branch.Key}: {key} overlaps {taken[at]}`)
			taken[at] = key
			expect(cell.Column < columns and cell.Row < rows, `{branch.Key}: {key} inside the grid`)
			local parent = Catalog.perk(key).Parent
			if parent and cells[parent] then
				expect(cells[parent].Column + 1 == cell.Column, `{key} is right of its parent`)
				expect(cells[parent].Row <= cell.Row, `{key} is not above its parent`)
			end
		end
		if levels == maxed then
			shown += count(states)
		end
	end
end
expect(shown == #Catalog.PerkNodes, "a completed tree shows all nodes")

print(`perktree OK: {checks} checks`)
