--!strict
-- Positions of perk nodes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)

local LayoutOf = {}

-- Ветки веером от общего ствола: соседние по смыслу и по зависимостям стоят рядом (угол от вертикали, градусы).
local BRANCH_ANGLES: { [string]: number } = {
	logistics = -86,
	storage = -58,
	collections = -29,
	trade = 0,
	luck = 29,
	mastery = 58,
	lockpick = 86,
}
-- Раскладка: расстояние от ствола задаёт глубина навыка, а соседние листья расходятся в стороны.
local FIRST_RADIUS = 290
local RADIUS_STEP = 140
local LEAF_SPACING = 104
local CANVAS_MARGIN = 140
-- Минимальный «габарит» узла с подписью: по горизонтали и вертикали; ближе узлы не располагаются.
local CLEARANCE_X = 128
local CLEARANCE_Y = 118
local CORE_CLEARANCE = 210
local ROOT_DIAMETER = 62
local NODE_DIAMETER = 52

export type Layout = {
	Points: { [string]: Vector2 },
	Heading: { [string]: Vector2 },
	Roots: { [string]: { Catalog.Perk } },
	Titles: { { Branch: string, At: Vector2 } },
	Hub: Vector2,
	Size: Vector2,
}

-- Радиальная раскладка: ветка растёт от ствола под своим углом, глубина — вдоль ветки, листья — поперёк.
local function layout(): Layout
	local points: { [string]: Vector2 } = {}
	local heading: { [string]: Vector2 } = {}
	local roots: { [string]: { Catalog.Perk } } = {}
	local titles: { { Branch: string, At: Vector2 } } = {}
	local own: { [string]: string } = {}
	for _, perk in Catalog.PerkNodes do
		own[perk.Key] = perk.Branch
	end
	local low, high = Vector2.zero, Vector2.zero
	local function track(at: Vector2): ()
		low = Vector2.new(math.min(low.X, at.X), math.min(low.Y, at.Y))
		high = Vector2.new(math.max(high.X, at.X), math.max(high.Y, at.Y))
	end
	for _, branch in Catalog.Branches do
		local angle = math.rad(BRANCH_ANGLES[branch.Key] or 0)
		local direction = Vector2.new(math.sin(angle), -math.cos(angle))
		local across = Vector2.new(math.cos(angle), math.sin(angle))
		local children: { [string]: { Catalog.Perk } } = {}
		local branchRoots: { Catalog.Perk } = {}
		for _, perk in Catalog.PerkNodes do
			if perk.Branch == branch.Key then
				if perk.Parent and own[perk.Parent] == branch.Key then
					children[perk.Parent] = children[perk.Parent] or {}
					table.insert(children[perk.Parent], perk)
				else
					table.insert(branchRoots, perk)
				end
			end
		end
		roots[branch.Key] = branchRoots
		local nextLeaf = 0
		local rows: { [string]: number } = {}
		local depths: { [string]: number } = {}
		local function place(perk: Catalog.Perk, depth: number): ()
			depths[perk.Key] = depth
			local list = children[perk.Key]
			if not list then
				rows[perk.Key] = nextLeaf
				nextLeaf += 1
				return
			end
			for _, child in list do
				place(child, depth + 1)
			end
			rows[perk.Key] = (rows[list[1].Key] + rows[list[#list].Key]) / 2
		end
		for _, root in branchRoots do
			place(root, 0)
		end
		local middle = (math.max(nextLeaf, 1) - 1) / 2
		for key, depth in depths do
			local at = direction * (FIRST_RADIUS + depth * RADIUS_STEP) + across * ((rows[key] - middle) * LEAF_SPACING)
			points[key] = at
			heading[key] = direction
			track(at)
		end
		local side = if angle < 0 then -1 else 1
		table.insert(titles, { Branch = branch.Key, At = direction * (FIRST_RADIUS * 0.45) + across * (side * 78) })
	end
	-- Разводим пересекающиеся узлы соседних веток: попарно отталкиваем их, пока габариты не перестанут пересекаться.
	local keys: { string } = {}
	for key in points do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _ = 1, 140 do
		local moved = false
		for i = 1, #keys do
			local a = points[keys[i]]
			local away = a.Magnitude
			if away < CORE_CLEARANCE and away > 0 then
				points[keys[i]] = a + a.Unit * (CORE_CLEARANCE - away)
				moved = true
			end
			for j = i + 1, #keys do
				local first, second = points[keys[i]], points[keys[j]]
				local scaled = Vector2.new((first.X - second.X) / CLEARANCE_X, (first.Y - second.Y) / CLEARANCE_Y)
				local gap = scaled.Magnitude
				if gap < 1 then
					local direction = if gap > 0.001 then scaled / gap else Vector2.new(1, 0)
					local push = direction * ((1 - gap) * 0.5)
					local shift = Vector2.new(push.X * CLEARANCE_X, push.Y * CLEARANCE_Y)
					points[keys[i]] = first + shift
					points[keys[j]] = second - shift
					moved = true
				end
			end
		end
		if not moved then
			break
		end
	end
	low, high = Vector2.zero, Vector2.zero
	for _, at in points do
		track(at)
	end
	local hub = Vector2.new(CANVAS_MARGIN - low.X, CANVAS_MARGIN - low.Y)
	local shifted: { [string]: Vector2 } = {}
	for key, at in points do
		shifted[key] = at + hub
	end
	for _, title in titles do
		title.At += hub
	end
	return {
		Points = shifted,
		Heading = heading,
		Roots = roots,
		Titles = titles,
		Hub = hub,
		Size = Vector2.new(high.X - low.X + CANVAS_MARGIN * 2, high.Y - low.Y + CANVAS_MARGIN * 2),
	}
end

LayoutOf.ROOT_DIAMETER = ROOT_DIAMETER
LayoutOf.NODE_DIAMETER = NODE_DIAMETER
LayoutOf.layout = layout

return LayoutOf
