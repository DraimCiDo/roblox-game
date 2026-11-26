--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Components)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.UI)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local DISPLAY_TYPES: { [string]: string } = { small = Texts.sizeSmall, large = Texts.sizeLarge, car = Texts.sizeCar }

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
			Details = Format(Texts.displayedDetails, { details = Components.itemDetails(item) }),
			Tint = Components.qualityColor(item.Quality),
			Kind = item.Kind,
			Caption = Texts.toStorage,
			Tone = "neutral",
			Callback = function()
				Components.send("removeDisplay", nil, key)
			end,
		})
		return
	end
	Components.paragraph(Texts.showcaseHelp)
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
				Caption = Texts.showcasePlace,
				FocusKey = candidate.Id,
				Callback = function()
					Components.send("display", candidate.Id, key)
				end,
			})
		end
	end
	if not found then
		Components.paragraph(Texts.showcaseEmpty)
	end
end

return Showcase
