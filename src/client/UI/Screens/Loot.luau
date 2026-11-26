--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Components)
local Style = require(script.Parent.Parent.Style)

local Loot = {}

function Loot.render(data: Types.View): ()
	local open = data.OrderStage == "open" and data.RemainingLoot > 0
	local name, hint, tint = Components.status(data)
	local summary = Components.card(104)
	local current = Components.text(summary, name, 21, tint, true)
	Components.place(current, 14, 10, UDim.new(1, -28), 50)
	local caption = Components.text(summary, hint, 13, Style.Muted)
	Components.place(caption, 14, 62, UDim.new(1, -28), 34)

	local collect = (data.Perks.quickCollect or 0) > 0
	Components.row({
		Name = "Быстрый сбор",
		Details = if collect
			then "Переместить всю добычу на склад"
			else "Откройте перк «Быстрый сбор»",
		Tint = Style.Cyan,
		Caption = "Собрать",
		Enabled = open and collect,
		Callback = function()
			Components.send("quickCollect")
		end,
	})
	local sell = (data.Perks.quickSell or 0) > 0
	Components.row({
		Name = "Быстрая продажа",
		Details = if sell
			then "Продать всю добычу на площадке"
			else "Откройте перк «Быстрая продажа»",
		Tint = Style.Amber,
		Caption = "Продать",
		Tone = "reward",
		Enabled = open and sell,
		Callback = function()
			Components.send("quickSell")
		end,
	})
end

return Loot
