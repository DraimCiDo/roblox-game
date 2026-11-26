--!strict
-- Rules of the perk tree shown to the player: which nodes of a branch are visible and where they stand.
-- A node is one step of a perk (Catalog.PerkNodes). Purely a view: buying rules are in Catalog.
local Catalog = require(script.Parent.Catalog)

-- owned: bought; available: the previous step is bought; hidden: one step further, shown as "?".
export type State = "owned" | "available" | "hidden"
-- Column grows with the distance from the branch root, Row separates side chains.
export type Cell = { Column: number, Row: number }

local PerkTree = {}

local function bought(levels: { [string]: number }, node: Catalog.Perk): boolean
	return (levels[node.Base :: string] or 0) >= (node.Step :: number)
end

local function branchNodes(branch: string): { Catalog.Perk }
	local list = {}
	for _, node in Catalog.PerkNodes do
		if node.Branch == branch then
			table.insert(list, node)
		end
	end
	return list
end

-- Visible nodes of a branch. Empty when the whole branch is still locked.
-- levels are saved perk levels, not node levels.
function PerkTree.states(branch: string, levels: { [string]: number }): { [string]: State }
	local nodes = branchNodes(branch)
	local result: { [string]: State } = {}
	local opened = false
	for _, node in nodes do
		local parent = if node.Parent then Catalog.perk(node.Parent) else nil
		if bought(levels, node) then
			result[node.Key] = "owned"
			opened = true
		elseif not parent or bought(levels, parent) then
			result[node.Key] = "available"
			opened = true
		end
	end
	if not opened then
		return {}
	end
	for _, node in nodes do
		local parent = if node.Parent then Catalog.perk(node.Parent) else nil
		if not result[node.Key] and parent then
			-- A root waiting for another branch, or the step right after an available one.
			if parent.Branch ~= branch or result[parent.Key] == "available" then
				result[node.Key] = "hidden"
			end
		end
	end
	return result
end

-- The step of another branch that opens a locked branch.
function PerkTree.unlockedBy(branch: string): Catalog.Perk?
	for _, node in branchNodes(branch) do
		local parent = if node.Parent then Catalog.perk(node.Parent) else nil
		if parent and parent.Branch ~= branch then
			return parent
		end
	end
	return nil
end

-- Grid positions of the visible nodes: the next step of a perk continues its row,
-- every other child starts a new row below.
function PerkTree.layout(branch: string, states: { [string]: State }): ({ [string]: Cell }, number, number)
	local children: { [string]: { Catalog.Perk } } = {}
	local roots: { Catalog.Perk } = {}
	for _, node in branchNodes(branch) do
		if not states[node.Key] then
			continue
		end
		local parent = node.Parent
		if parent and states[parent] then
			children[parent] = children[parent] or {}
			if parent == `{node.Base}#{(node.Step :: number) - 1}` then
				table.insert(children[parent], 1, node)
			else
				table.insert(children[parent], node)
			end
		else
			table.insert(roots, node)
		end
	end
	local cells: { [string]: Cell } = {}
	local columns, rows = 0, 0
	local function place(node: Catalog.Perk, column: number, row: number): ()
		cells[node.Key] = { Column = column, Row = row }
		columns = math.max(columns, column + 1)
		for index, child in children[node.Key] or {} do
			if index > 1 then
				rows += 1
			end
			place(child, column + 1, if index == 1 then row else rows)
		end
	end
	for index, root in roots do
		if index > 1 then
			rows += 1
		end
		place(root, 0, rows)
	end
	return cells, columns, if #roots > 0 then rows + 1 else 0
end

return PerkTree
