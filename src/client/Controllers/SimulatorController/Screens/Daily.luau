--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Components = require(script.Parent.Parent.Components)
local Style = require(script.Parent.Parent.Style)

local Daily = {}

function Daily.render(): ()
	local summary = Components.card(172, Style.Track)
	local remaining = Components.text(summary, "", 52, Style.Amber, true)
	Components.place(remaining, 14, 14, UDim.new(1, -28), 76)
	remaining.TextXAlignment = Enum.TextXAlignment.Center
	local caption = Components.text(summary, "", 15, Style.Muted)
	Components.place(caption, 14, 94, UDim.new(1, -28), 26)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	local track, fill = Style.meter(summary, 0, Style.Amber)
	Components.place(track, 24, 136, UDim.new(1, -48), 14)
	local control = Components.command("Забрать награду", function()
		Components.send("daily")
	end, false, "reward")
	Components.Live.Daily = { Time = remaining, Caption = caption, Fill = fill, Button = control }
end

-- Обновляет таймер награды без перерисовки экрана.
function Daily.tick(data: Types.View, now: number): ()
	local widgets = Components.Live.Daily
	if not widgets then
		return
	end
	local claimed, remaining, canClaim = Components.dailyState(data, now)
	widgets.Time.Text = if claimed
		then "ПОЛУЧЕНО"
		elseif canClaim then "ГОТОВО"
		else Components.clock(remaining)
	local reward = Components.coin(data.DailyReward)
	widgets.Caption.Text = if claimed
		then "Награда сегодня получена"
		elseif canClaim then `Награда доступна · +{reward} монет`
		else `До получения награды · +{reward} монет`
	widgets.Fill.Size = UDim2.fromScale(if claimed then 1 else math.clamp(1 - remaining / Config.DailySeconds, 0, 1), 1)
	Style.setButton(widgets.Button, canClaim, "reward")
	Components.prefer(widgets.Button)
end

return Daily
