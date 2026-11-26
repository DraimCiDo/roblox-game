--!strict
-- Daily reward and passive gallery income.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.Notices)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Data = require(script.Parent.Parent.Services.PlayerDataService)
local Audio = require(script.Parent.Parent.Network.Audio)
local Economy = require(script.Parent.Parent.Economy.Economy)
local Rules = require(script.Parent.Parent.Config.Rules)
local State = require(script.Parent.State)
local View = require(script.Parent.View)

local Rewards = {}

function Rewards.claimDaily(player: Player, session: State.Session, data: Types.PlayerData, now: number): boolean
	local updated = false
	local day = math.floor(now / 86400)
	if data.DailyClaim >= day then
		State.tell(player, Texts.dailyAlreadyClaimed)
	elseif now < session.ReadyAt then
		State.tell(player, Texts.dailyNotReady)
	else
		data.DailyClaim = day
		local reward = Economy.dailyReward(data)
		Economy.credit(data, reward)
		updated = true
		State.tell(player, Format(Texts.dailyReward, { reward = reward }))
		Audio.to(player, "claim")
	end
	return updated
end

-- «Галерея»: раз в несколько секунд начисляет доход от выставленных на витринах предметов.
function Rewards.payGallery(player: Player, session: State.Session, now: number): ()
	if not session.Initialized or now - (State.galleryAt[player] or now) < Rules.GalleryInterval then
		State.galleryAt[player] = State.galleryAt[player] or now
		return
	end
	State.galleryAt[player] = now
	local data = Data:Get(player)
	if not data then
		return
	end
	local amount = math.round(Economy.galleryIncome(data) * Rules.GalleryInterval / 60)
	if amount <= 0 then
		return
	end
	Data:Update(player, function(current)
		Economy.credit(current, amount)
	end)
	View.publish(player)
end

return Rewards
