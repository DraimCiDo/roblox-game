--!strict
-- What the owner sees: client data, leaderstats, tutorial hint and the sector in the world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.Notices)
local Data = require(script.Parent.Parent.Services.PlayerDataService)
local Economy = require(script.Parent.Parent.Economy.Economy)
local World = require(script.Parent.Parent.World.World)
local State = require(script.Parent.State)
local Tutorial = require(script.Parent.Tutorial)

local View = {}

function View.get(player: Player): Types.View?
	local session, data = State.sessions[player], Data:Get(player)
	if not session or not session.Initialized or not data then
		return nil
	end
	local order = data.Orders[1]
	local visible = order and order.Stage ~= "queued" and order.Stage ~= "delivery"
	local showProgress = order and order.Stage == "sealed" and order.Kind ~= "safe"
	local prices = {}
	for _, item in data.Inventory do
		prices[item.Id] = Economy.price(data, item)
	end
	return {
		Coins = data.Coins,
		Earned = data.Earned,
		Opened = data.Opened,
		OrderPrice = Economy.orderPrice(data),
		DailyReward = Economy.dailyReward(data),
		VolumeUi = data.VolumeUi,
		VolumeWorld = data.VolumeWorld,
		Inventory = data.Inventory,
		Collections = data.Collections,
		Displays = data.Displays,
		Perks = data.Perks,
		Orders = #data.Orders,
		OrderStage = if order then order.Stage else nil,
		OrderKind = if visible then order.Kind else nil,
		OrderVariant = if visible then order.Variant else nil,
		OrderProgress = if showProgress then Economy.openingProgress(order) else nil,
		OrderGoal = if showProgress then Economy.openingGoal(order) else nil,
		OrderDeadline = if order and order.Stage == "delivery" then order.Deadline else nil,
		RemainingLoot = if order then #order.Loot else 0,
		Prices = prices,
		DailyReadyAt = session.ReadyAt,
		DailyClaim = data.DailyClaim,
		Effect = data.Effect,
		Effects = data.Effects,
	}
end
-- Папка leaderstats показывается в списке игроков Roblox: баланс и число открытых контейнеров.
function View.updateStats(player: Player, data: Types.PlayerData): ()
	local values = State.stats[player]
	if not values then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local coins = Instance.new("IntValue")
		coins.Name = Texts.statCoins
		coins.Parent = folder
		local opened = Instance.new("IntValue")
		opened.Name = Texts.statOpened
		opened.Parent = folder
		folder.Parent = player
		values = { Coins = coins, Opened = opened }
		State.stats[player] = values
	end
	values.Coins.Value = data.Coins
	values.Opened.Value = data.Opened
end
function View.publish(player: Player): ()
	local data = Data:Get(player)
	if data then
		View.updateStats(player, data)
	end
	local output = View.get(player)
	if output then
		State.changed:FireClient(player, output)
	end
end
-- Отправляет клиенту текущую подсказку обучения; повторно только при смене шага или цели.
function View.updateGuide(player: Player, session: State.Session, data: Types.PlayerData): ()
	if data.TutorialDone then
		return
	end
	local step = Tutorial.evaluate(data, session.Plot)
	local last = State.guides[player]
	if not step then
		State.guides[player] = nil
		Data:Update(player, function(current)
			current.TutorialDone = true
		end)
		State.interface:FireClient(player, "guide", nil)
		-- Поздравление только тем, кто проходил обучение; опытные игроки завершают его молча.
		if last then
			State.tell(player, Texts.tutorialDone)
		end
		return
	end
	if last and last.Id == step.Id and last.Target == step.Target then
		return
	end
	State.guides[player] = { Id = step.Id, Target = step.Target }
	State.interface:FireClient(player, "guide", step.Text, step.Target, step.Pulse)
end
function View.sync(player: Player, session: State.Session, scatter: boolean?): ()
	local data = Data:Get(player)
	if not data then
		return
	end
	local order = data.Orders[1]
	World.Sync(
		session.Plot,
		order,
		session.Use,
		scatter == true,
		if order then order.Deadline - Workspace:GetServerTimeNow() else 0
	)
	World.UpdateStorage(session.Plot, Economy.capacity(data), data.Inventory)
	World.UpdateCollections(session.Plot, data.Collections)
	local active = data.Orders[1]
	local revealed = active ~= nil and active.Stage ~= "queued" and active.Stage ~= "delivery"
	World.UpdateStatus(
		session.Plot,
		if not active then nil elseif revealed then active.Kind else "?",
		if active then active.Stage else nil,
		if active then #active.Loot else 0,
		#data.Inventory,
		Economy.capacity(data)
	)
	World.UpdateInfo(
		session.Plot,
		Catalog.level(data.Opened),
		Economy.orderPrice(data),
		#data.Orders,
		1 + (data.Perks.orders or 0)
	)
	World.UpdateDisplays(session.Plot, data.Displays)
	World.SetEffect(session.Plot, data.Effect)
	View.updateGuide(player, session, data)
	View.publish(player)
end

return View
