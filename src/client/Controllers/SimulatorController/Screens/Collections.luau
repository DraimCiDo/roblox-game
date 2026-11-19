--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Components)
local Style = require(script.Parent.Parent.Style)

local COLUMNS = 4
local GAP = 8

local Collections = {}
local picked: string?

function Collections.reset(): ()
	picked = nil
end

local function candidates(data: Types.View, kind: string, saved: Types.Item?): ()
	local found = false
	for _, item in data.Inventory do
		if item.Kind == kind then
			found = true
			local definition = Catalog.Items[kind]
			local delta = if saved then item.Quality - saved.Quality else nil
			local note = Components.itemDetails(item)
			if delta then
				note ..= if delta > 0 then `  ▲ +{delta}` elseif delta < 0 then `  ▼ {delta}` else "  ="
			end
			Components.row({
				Name = definition.Name,
				Details = `Со склада · {note}`,
				Tint = Components.qualityColor(item.Quality),
				Kind = kind,
				Caption = if saved then "Заменить" else "Внести",
				FocusKey = item.Id,
				Tone = if delta and delta < 0 then "neutral" else "primary",
				Callback = function()
					Components.send("collection", item.Id)
				end,
			})
		end
	end
	if not found then
		Components.paragraph("На складе нет подходящего экземпляра.", Style.Warning)
	end
end

function Collections.render(data: Types.View): ()
	Components.paragraph(
		"Внесённый предмет расходуется навсегда, но его можно заменить другим экземпляром того же типа."
	)
	for _, collection in Catalog.Collections do
		local total, count = 0, 0
		for _, kind in collection.Items do
			local saved = data.Collections[kind]
			if saved then
				count += 1
				total += saved.Quality
			end
		end
		local complete = count == #collection.Items
		local group = Components.group()

		local top = Style.frame(group)
		top.Size = UDim2.new(1, 0, 0, 50)
		top.LayoutOrder = 1
		local name = Components.text(top, collection.Name, 19, Style.Text, true)
		Components.place(name, 2, 0, UDim.new(0.6, 0), 26)
		local summary = if complete
			then string.format("+%.1f%% к продаже", total / count / 10)
			else `Собрано {count} / {#collection.Items}`
		local bonus = Components.text(top, summary, 13, if complete then Style.Signal else Style.Muted, true)
		bonus.TextXAlignment = Enum.TextXAlignment.Right
		Components.place(bonus, 0, 4, UDim.new(1, -2), 20)
		local track = Style.meter(top, count / #collection.Items, if complete then Style.Signal else Style.Cyan)
		Components.place(track, 2, 34, UDim.new(1, -4), 10)

		local grid = Components.grid(COLUMNS, GAP, group)
		for _, kind in collection.Items do
			local saved = data.Collections[kind]
			Components.tile(grid, kind, saved, {
				Ghost = saved == nil,
				Caption = if saved then nil else Catalog.Items[kind].Name,
				CaptionColor = Style.Muted,
				Selected = picked == kind,
				FocusKey = kind,
				Callback = function()
					picked = if picked == kind then nil else kind
					Components.redraw()
				end,
			})
		end
		if complete then
			Components.line(
				group,
				`Среднее качество {math.round(total / count)}. Бонус действует на предметы этой коллекции.`,
				12,
				Style.Muted
			)
		end

		for _, kind in collection.Items do
			if picked == kind then
				-- Список экземпляров показываем сразу под выбранной коллекцией.
				candidates(data, kind, data.Collections[kind])
			end
		end
	end
end

return Collections
