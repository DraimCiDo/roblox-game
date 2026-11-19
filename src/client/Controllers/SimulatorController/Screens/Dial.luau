--!strict
local Components = require(script.Parent.Parent.Components)
local Style = require(script.Parent.Parent.Style)

export type Round = { Id: string, Start: number, Target: number, Period: number, Tolerance: number }

local TIME_LIMIT = 20

local Dial = {}
Dial.TimeLimit = TIME_LIMIT

function Dial.render(round: Round, stop: () -> ()): ()
	local summary = Components.card(150, Style.Track)
	local left = Components.text(summary, "0", 13, Style.Muted, true)
	Components.place(left, 16, 11, UDim.new(0, 28), 24)
	local time = Components.text(summary, "", 17, Style.Amber, true)
	time.TextXAlignment = Enum.TextXAlignment.Right
	time.AnchorPoint = Vector2.new(1, 0)
	time.Position = UDim2.new(1, -16, 0, 11)
	time.Size = UDim2.fromOffset(150, 24)

	local track = Style.frame(summary, Style.Card, 10)
	Components.place(track, 16, 42, UDim.new(1, -32), 56)
	Style.outline(track)
	local sector = Style.frame(track, Style.Signal, 6)
	sector.AnchorPoint = Vector2.new(0.5, 0)
	sector.Position = UDim2.new(round.Target, 0, 0, 5)
	sector.Size = UDim2.new(round.Tolerance * 2, 0, 1, -10)
	Style.gloss(sector)
	local target = Components.text(sector, "ЦЕЛЬ", 13, Style.Ink, true)
	target.TextXAlignment = Enum.TextXAlignment.Center
	target.Size = UDim2.fromScale(1, 1)
	for tick = 0, 10 do
		local mark = Style.frame(summary, Style.Muted)
		mark.AnchorPoint = Vector2.new(0.5, 0)
		mark.Position = UDim2.new(tick / 10, 16 - (tick / 10) * 32, 0, 108)
		mark.Size = UDim2.fromOffset(2, if tick % 5 == 0 then 14 else 7)
	end
	local needle = Style.frame(track, Style.Amber, 4)
	needle.AnchorPoint = Vector2.new(0.5, 0)
	needle.Size = UDim2.new(0, 8, 1, 10)
	needle.Position = UDim2.fromOffset(0, -5)
	Style.outline(needle, Style.Ink, 2)
	Components.Live.Dial = { Needle = needle, Time = time }
	Components.command("Остановить ручку", stop, true, "primary")
end

return Dial
