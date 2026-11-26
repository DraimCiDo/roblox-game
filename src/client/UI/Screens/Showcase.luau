--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Components)

local DISPLAY_TYPES: { [string]: string } =
	{ small = "Малые предметы", large = "Крупные предметы", car = "Автомобили" }

local Showcase = {}

function Showcase.render(data: Types.View, key: string): ()
	local size = Catalog.DisplaySizes[tonumber(key) or 0]
	if not size then
		return
	end
	Components.heading(DISPLAY_TYPES[size])
	local item = data.Displays[key]
	if item then
		local definition = Catalog.Items[item.Kind]
		Components.row({
			Name = definition.Name,
			Details = `{Components.itemDetails(item)} · выставлено`,
			Tint = Components.qualityColor(item.Quality),
			Kind = item.Kind,
			Caption = "На склад",
			Tone = "neutral",
			Callback = function()
				Components.send("removeDisplay", nil, key)
			end,
		})
		return
	end
	Components.paragraph(
		"Выставленный предмет нельзя продать или внести в коллекцию, пока он на витрине."
	)
	local found = false
	for _, candidate in data.Inventory do
		local definition = Catalog.Items[candidate.Kind]
		if definition.Size == size then
			found = true
			Components.row({
				Name = definition.Name,
				Details = Components.itemDetails(candidate),
				Tint = Components.qualityColor(candidate.Quality),
				Kind = candidate.Kind,
				Caption = "Выставить",
				FocusKey = candidate.Id,
				Callback = function()
					Components.send("display", candidate.Id, key)
				end,
			})
		end
	end
	if not found then
		Components.paragraph(
			"На складе пока нет предметов подходящего размера."
		)
	end
end

return Showcase
