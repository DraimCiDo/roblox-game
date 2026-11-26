--!strict
-- Player preferences: volume, drop effects and skipping the tutorial.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.Notices)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local State = require(script.Parent.State)

local Settings = {}

-- Volume arrives as a whole percentage; it is validated and rounded to 5% steps.
function Settings.setVolume(data: Types.PlayerData, argument: string?, extra: string?): boolean
	local updated = false
	local percent = if extra then tonumber(extra) else nil
	if
		percent
		and percent == percent
		and math.abs(percent) ~= math.huge
		and (argument == "ui" or argument == "world")
	then
		local value = math.clamp(math.round(percent / 5) * 5, 0, 100) / 100
		if argument == "ui" then
			data.VolumeUi = value
		else
			data.VolumeWorld = value
		end
		updated = true
	end
	return updated
end

-- action is "effect" (select) or "buyEffect".
function Settings.effect(player: Player, data: Types.PlayerData, action: string, argument: string?): boolean
	local updated = false
	local effect = if argument then Catalog.dropEffect(argument) else nil
	if effect then
		local available = Catalog.effectAvailable(effect, data.Opened, data.Effects)
		if action == "buyEffect" and not available and effect.Price then
			if data.Coins < effect.Price then
				State.tell(player, Texts.notEnoughForEffect)
			else
				data.Coins -= effect.Price
				data.Effects[effect.Key] = true
				data.Effect = effect.Key
				State.tell(player, Format(Texts.effectBought, { name = effect.Name }))
				updated = true
			end
		elseif action == "effect" and available then
			data.Effect = effect.Key
			updated = true
		end
	end
	return updated
end

function Settings.skipTutorial(player: Player, data: Types.PlayerData): boolean
	data.TutorialDone = true
	State.guides[player] = nil
	State.interface:FireClient(player, "guide", nil)
	return true
end

return Settings
