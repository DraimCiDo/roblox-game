--!strict
local Components = require(script.Parent.Parent.Components)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local Style = require(script.Parent.Parent.Style)

export type Round = {
	Id: string,
	Start: number,
	Target: number,
	Period: number,
	Tolerance: number,
	Stage: number,
	Total: number,
}

local TIME_LIMIT = 20
local FACE = 240
local TICKS = 36

local Dial = {}
local wasInside = false
Dial.TimeLimit = TIME_LIMIT

-- Угол по часовой стрелке в UI; физическая ручка сейфа вращается в ту же сторону, что и указатель.
local function angle(phase: number): number
	return -phase * 360
end

local function spoke(parent: Instance, rotation: number): Frame
	local holder = Style.frame(parent)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.Rotation = rotation
	return holder
end

local function bar(holder: Frame, color: Color3, width: number, length: number, inset: number, radius: number): Frame
	local piece = Style.frame(holder, color, radius)
	piece.AnchorPoint = Vector2.new(0.5, 0)
	piece.Position = UDim2.new(0.5, 0, 0, inset)
	piece.Size = UDim2.fromOffset(width, length)
	return piece
end

function Dial.render(round: Round, stop: () -> ()): ()
	local group = Components.group()

	local caption = Components.line(group, `Штифт {round.Stage} из {round.Total}`, 22, Style.Text, true)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.LayoutOrder = 1

	local pins = Style.frame(group)
	pins.LayoutOrder = 2
	pins.Size = UDim2.new(1, 0, 0, 14)
	local row = Style.frame(pins)
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.fromScale(0.5, 0)
	row.Size = UDim2.fromOffset(round.Total * 62, 14)
	for index = 1, round.Total do
		local state = if index < round.Stage
			then Style.Signal
			elseif index == round.Stage then Style.Amber
			else Style.Track
		local pin = Style.frame(row, state, 7)
		pin.Position = UDim2.new((index - 1) / round.Total, 0, 0, 0)
		pin.Size = UDim2.new(1 / round.Total, -6, 1, 0)
		Style.outline(pin, Style.Edge, 2)
	end

	local area = Style.frame(group)
	area.LayoutOrder = 3
	area.Size = UDim2.new(1, 0, 0, FACE + 14)
	local face = Style.frame(area, Style.Track, FACE / 2)
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromOffset(FACE, FACE)
	local glow = Style.outline(face, Style.Edge, 5)
	local plate = Style.frame(face, Style.Card, 80)
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromOffset(160, 160)
	Style.outline(plate, Style.Edge, 2)

	for tick = 0, TICKS - 1 do
		local major = tick % 3 == 0
		bar(spoke(face, tick * 360 / TICKS), Style.Muted, if major then 4 else 2, if major then 12 else 7, 6, 1)
	end

	-- Зелёная зона: чем дальше этап, тем она уже.
	local half = round.Tolerance * 360
	local segments = math.ceil(half * 2 / 3.4)
	for index = 0, segments do
		local offset = -half + (2 * half) * index / segments
		bar(spoke(face, angle(round.Target) + offset), Style.Signal, 7, 24, 4, 2)
	end

	local needle = spoke(face, 0)
	local blade = bar(needle, Style.Amber, 7, FACE * 0.4, FACE * 0.1, 3)
	Style.outline(blade, Style.Edge, 2)
	local hub = Style.frame(face, Style.Amber, 20)
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(40, 40)
	Style.outline(hub, Style.Edge, 3)
	local time = Components.text(face, "", 17, Style.Muted, true)
	time.AnchorPoint = Vector2.new(0.5, 0.5)
	time.Position = UDim2.fromScale(0.5, 0.72)
	time.Size = UDim2.fromOffset(120, 24)
	time.TextXAlignment = Enum.TextXAlignment.Center

	local hint = Components.line(
		group,
		"Остановите указатель в зелёной зоне. Пробел или кнопка ниже.",
		14,
		Style.Muted
	)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.LayoutOrder = 4

	Components.Live.Dial = { Needle = needle, Time = time, Glow = glow }
	Components.command("Остановить", stop, true, "primary")
end

-- Двигает указатель и подсвечивает циферблат, когда указатель в зелёной зоне (подсказка; решает сервер).
function Dial.update(round: Round, elapsed: number): ()
	local widgets = Components.Live.Dial
	if not widgets then
		return
	end
	local phase = (elapsed % round.Period) / round.Period
	widgets.Needle.Rotation = angle(phase)
	local distance = math.abs(phase - round.Target)
	local inside = math.min(distance, 1 - distance) <= round.Tolerance
	-- Короткий щелчок, когда указатель входит в зелёную зону.
	if inside and not wasInside then
		Sfx.play("tick")
	end
	wasInside = inside
	widgets.Glow.Color = if inside then Style.Signal else Style.Edge
	widgets.Glow.Thickness = if inside then 7 else 5
	widgets.Time.Text = `{math.ceil(TIME_LIMIT - elapsed)} с`
end

function Dial.flash(success: boolean): ()
	local widgets = Components.Live.Dial
	if widgets then
		widgets.Glow.Color = if success then Style.Signal else Style.Warning
		widgets.Glow.Thickness = 10
	end
end

return Dial
