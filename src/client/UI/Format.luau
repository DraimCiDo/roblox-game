--!strict
-- Values as shown to the player: coins, time, item and container status.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Style = require(script.Parent.Style)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.UI)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Formatting = {}

local SEALED_HELP: { [string]: string } = {
	box = Texts.sealedBox,
	crate = Texts.sealedCrate,
	safe = Texts.sealedSafe,
	cargo = Texts.sealedCargo,
	secret = Texts.sealedSecret,
}

function Formatting.coin(value: number): string
	local reversed = string.reverse(tostring(value))
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1 ")
	return (string.gsub(string.reverse(grouped), "^ ", ""))
end

function Formatting.clock(seconds: number): string
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

function Formatting.qualityColor(quality: number): Color3
	return Catalog.conditionColor(quality)
end

function Formatting.itemDetails(item: Types.Item): string
	return `{Catalog.condition(item.Quality)} · {item.Quality}/100`
end

function Formatting.dailyState(data: Types.View, now: number): (boolean, number, boolean)
	local claimed = data.DailyClaim >= math.floor(now / 86400)
	local remaining = math.max(0, math.ceil(data.DailyReadyAt - now))
	return claimed, remaining, not claimed and remaining == 0
end

function Formatting.containerName(data: Types.View): string
	local kind = data.OrderKind
	if kind then
		return (if data.OrderVariant then Catalog.Variants else Catalog.Containers)[kind]
	end
	return Texts.randomContainer
end

function Formatting.progressText(data: Types.View): string?
	if data.OrderProgress and data.OrderGoal then
		return Format(Texts.openingStep, { progress = data.OrderProgress, goal = data.OrderGoal })
	end
	return nil
end

function Formatting.status(data: Types.View): (string, string, Color3)
	local stage = data.OrderStage
	if stage == "queued" or stage == "delivery" then
		return Texts.statusDelivery, Texts.statusDeliveryHint, Style.Amber
	elseif stage == "sealed" then
		return Formatting.containerName(data), SEALED_HELP[data.OrderKind or "box"] or Texts.openContainer, Style.Cyan
	elseif stage == "open" then
		local hint = if data.OrderKind == "cargo" then Texts.hintCargoLoot else Texts.hintPadLoot
		return Format(Texts.statusLoot, { remaining = data.RemainingLoot }), hint, Style.Signal
	elseif stage == "clear" then
		return Texts.statusClear, Texts.statusClearHint, Style.Amber
	elseif #data.Inventory > 0 then
		return Texts.statusReady, Texts.statusReadyHint, Style.Signal
	end
	return Texts.statusReady, Texts.statusOrderHint, Style.Signal
end

-- Крупные числа для узких мест (плашка баланса, кнопки): 12 345, 480 К, 1,9 М, 2,4 Б.
function Formatting.short(value: number): string
	local function trim(number: number): string
		local text = string.format("%.2f", number)
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
		return (string.gsub(text, "%.", ","))
	end
	if value >= 1e9 then
		return Format(Texts.billions, { value = trim(value / 1e9) })
	elseif value >= 1e6 then
		return Format(Texts.millions, { value = trim(value / 1e6) })
	elseif value >= 1e5 then
		return Format(Texts.thousands, { value = math.floor(value / 1e3) })
	end
	return Formatting.coin(value)
end

return Formatting
