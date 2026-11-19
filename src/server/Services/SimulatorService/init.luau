--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Data = require(script.Parent.PlayerDataService)
local Audio = require(script.Audio)
local Economy = require(script.Economy)
local World = require(script.World)
local Tutorial = require(script.Tutorial)
local ItemAssets = require(script.ItemAssets)

type Session = {
	Plot: World.Plot,
	ReadyAt: number,
	RemoteAt: number,
	PhysicalAt: { [string]: number },
	Initialized: boolean,
	ReleaseAt: number?,
	Use: World.Use,
}

local ACTION_INTERVAL = 0.14
local REMOTE_ACTIONS: { [string]: boolean } = {
	buy = true,
	open = true,
	perk = true,
	daily = true,
	sell = true,
	collection = true,
	display = true,
	removeDisplay = true,
	quickSell = true,
	quickCollect = true,
	skipTutorial = true,
}

local SimulatorService = {}
local sessions: { [Player]: Session } = {}
local occupants: { [number]: Player } = {}
local lastProfileQuery: { [Player]: number } = {}
local dialStages: { [Player]: number } = {}
local stats: { [Player]: { Coins: IntValue, Opened: IntValue } } = {}
local guides: { [Player]: { Id: string, Target: Instance? } } = {}
local galleryAt: { [Player]: number } = {}
local GALLERY_INTERVAL = 10
local plots: { World.Plot } = {}
local perks: { [string]: Catalog.Perk } = {}
for _, perk in Catalog.Perks do
	perks[perk.Key] = perk
end

local changed: RemoteEvent
local interface: RemoteEvent

local function view(player: Player): Types.View?
	local session, data = sessions[player], Data:Get(player)
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
	}
end

-- Папка leaderstats показывается в списке игроков Roblox: баланс и число открытых контейнеров.
local function updateStats(player: Player, data: Types.PlayerData): ()
	local values = stats[player]
	if not values then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local coins = Instance.new("IntValue")
		coins.Name = "Монеты"
		coins.Parent = folder
		local opened = Instance.new("IntValue")
		opened.Name = "Открыто"
		opened.Parent = folder
		folder.Parent = player
		values = { Coins = coins, Opened = opened }
		stats[player] = values
	end
	values.Coins.Value = data.Coins
	values.Opened.Value = data.Opened
end

local function publish(player: Player): ()
	local data = Data:Get(player)
	if data then
		updateStats(player, data)
	end
	local output = view(player)
	if output then
		changed:FireClient(player, output)
	end
end

local function tell(player: Player, text: string): ()
	interface:FireClient(player, "notice", text)
end

-- Отправляет клиенту текущую подсказку обучения; повторно только при смене шага или цели.
local function updateGuide(player: Player, session: Session, data: Types.PlayerData): ()
	if data.TutorialDone then
		return
	end
	local step = Tutorial.evaluate(data, session.Plot)
	local last = guides[player]
	if not step then
		guides[player] = nil
		Data:Update(player, function(current)
			current.TutorialDone = true
		end)
		interface:FireClient(player, "guide", nil)
		-- Поздравление только тем, кто проходил обучение; опытные игроки завершают его молча.
		if last then
			tell(
				player,
				"Обучение пройдено! Собирайте коллекции и выставляйте находки на витрины."
			)
		end
		return
	end
	if last and last.Id == step.Id and last.Target == step.Target then
		return
	end
	guides[player] = { Id = step.Id, Target = step.Target }
	interface:FireClient(player, "guide", step.Text, step.Target, step.Pulse)
end

local function sync(player: Player, session: Session, scatter: boolean?): ()
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
	updateGuide(player, session, data)
	publish(player)
end

local function occupy(player: Player): ()
	if sessions[player] then
		return
	end
	local plot: World.Plot?
	for index, candidate in plots do
		if not occupants[index] then
			plot = candidate
			occupants[index] = player
			break
		end
	end
	if not plot then
		player:Kick("На этом сервере все шесть территорий заняты.")
		return
	end
	local owned = plot
	local session: Session = {
		Plot = owned,
		ReadyAt = Workspace:GetServerTimeNow() + Config.DailySeconds,
		RemoteAt = -math.huge,
		PhysicalAt = {},
		Initialized = false,
		ReleaseAt = nil,
		Use = function(actingPlayer, action, argument)
			if actingPlayer == player then
				SimulatorService:Use(player, action, argument, true, nil)
			end
		end,
	}
	sessions[player] = session
	World.Owner(owned, player)
	World.SpawnPlayer(owned, player)
	while player.Parent == Players and sessions[player] == session do
		if Data:Get(player) then
			Data:Update(player, function(data)
				if not data.StarterGranted then
					table.insert(data.Orders, Economy.newOrder(data, true))
					data.StarterGranted = true
				end
				local active = data.Orders[1]
				if active then
					active.DialStarted = 0
					if active.Stage == "delivery" and active.Deadline <= Workspace:GetServerTimeNow() then
						active.Stage, active.Deadline = "sealed", 0
					end
				end
			end)
			session.Initialized = true
			sync(player, session)
			return
		end
		task.wait(0.15)
	end
end

-- «Галерея»: раз в несколько секунд начисляет доход от выставленных на витринах предметов.
local function payGallery(player: Player, session: Session, now: number): ()
	if not session.Initialized or now - (galleryAt[player] or now) < GALLERY_INTERVAL then
		galleryAt[player] = galleryAt[player] or now
		return
	end
	galleryAt[player] = now
	local data = Data:Get(player)
	if not data then
		return
	end
	local amount = math.round(Economy.galleryIncome(data) * GALLERY_INTERVAL / 60)
	if amount <= 0 then
		return
	end
	Data:Update(player, function(current)
		Economy.credit(current, amount)
	end)
	publish(player)
end

local function tickPlayer(player: Player, session: Session, now: number): ()
	if not session.Initialized then
		return
	end
	local data = Data:Get(player)
	local order = data and data.Orders[1]
	if not data or not order then
		return
	end
	if order.Stage == "queued" then
		Data:Update(player, function()
			order.Stage = "delivery"
			order.Deadline = now + Economy.deliveryTime(order, data)
		end)
		Audio.at(session.Plot.Clear, "whoosh")
		sync(player, session)
	elseif order.Stage == "delivery" and now >= order.Deadline then
		Data:Update(player, function()
			order.Stage = "sealed"
			order.Deadline = 0
		end)
		Audio.at(session.Plot.Clear, "thud")
		sync(player, session)
	elseif order.Stage == "sealed" and order.DialStarted > 0 then
		local elapsed = now - order.DialStarted
		if elapsed <= Economy.DialTimeLimit then
			local _, period = Economy.dial(order, dialStages[player] or 1, data.Perks)
			World.RotateDial(session.Plot, (elapsed % period) / period)
		else
			Data:Update(player, function()
				order.DialStarted = 0
			end)
			dialStages[player] = nil
			World.RotateDial(session.Plot, 0)
		end
	elseif order.Stage == "clear" then
		local releaseAt = session.ReleaseAt
		if releaseAt then
			if now >= releaseAt then
				World.Clear(session.Plot)
				Data:Update(player, function(current)
					table.remove(current.Orders, 1)
				end)
				session.ReleaseAt = nil
				sync(player, session)
			end
		elseif World.Position(player) and not World.InPad(session.Plot, player) then
			session.ReleaseAt = now + World.Release(session.Plot)
		end
	end
end

local function member(value: string?, maximum: number): number?
	local index = if value then tonumber(value) else nil
	if index and index >= 1 and index <= maximum and index % 1 == 0 and tostring(index) == value then
		return index
	end
	return nil
end

local function standPart(plot: World.Plot, key: string?): Part?
	local index = member(key, #plot.Stands)
	return if index then plot.Stands[index] else nil
end

local function menuPart(plot: World.Plot, key: string): Part?
	return if key == "loot" then plot.Button else plot.Stations[key] or standPart(plot, key)
end

local function finishLoot(order: Types.Order): ()
	if #order.Loot == 0 then
		order.Stage = "clear"
	end
end

local function openOrder(
	player: Player,
	plot: World.Plot,
	data: Types.PlayerData,
	order: Types.Order,
	argument: string?,
	physical: boolean
): (boolean, boolean)
	if order.Stage ~= "sealed" or not plot.Active then
		return false, false
	end
	local position = World.Position(player)
	if not position then
		return false, false
	end
	local kind = order.Kind
	local targetPart: Part?
	if kind == "crate" then
		local index = member(argument, 4)
		targetPart = if index then plot.OpenParts[index] else nil
	elseif kind == "cargo" then
		local index = member(argument, 2)
		targetPart = if index then plot.OpenParts[index * 2] else if argument == "doors" then plot.OpenParts[5] else nil
	elseif kind == "safe" then
		targetPart = plot.OpenParts[3]
	else
		local body = plot.Active:FindFirstChild("Корпус")
		targetPart = if body and body:IsA("Part") then body else nil
	end
	if
		not targetPart
		or (position - targetPart.Position).Magnitude > (if kind == "cargo" or kind == "crate" then 8 else 11)
	then
		if not physical and kind == "safe" and argument == order.Id then
			tell(player, "Подойдите к сейфу и поверните ручку снова.")
		end
		return false, false
	end
	local opened = false
	if kind == "safe" then
		if physical then
			if argument then
				return false, false
			end
			order.DialStarted = Workspace:GetServerTimeNow()
			dialStages[player] = 1
			local target, period, tolerance = Economy.dial(order, 1, data.Perks)
			interface:FireClient(
				player,
				"dial",
				order.Id,
				order.DialStarted,
				target,
				period,
				tolerance,
				1,
				Economy.DialStages
			)
			return true, false
		else
			if argument ~= order.Id or order.DialStarted <= 0 then
				return false, false
			end
			local stage = dialStages[player] or 1
			local target, period, tolerance = Economy.dial(order, stage, data.Perks)
			local now = Workspace:GetServerTimeNow()
			local elapsed = now - order.DialStarted
			local phase = (elapsed % period) / period
			local hit = elapsed > 0.3 and elapsed <= Economy.DialTimeLimit and math.abs(phase - target) <= tolerance
			if hit and stage < Economy.DialStages then
				-- Штифт встал на место: сразу начинается следующий, более быстрый этап.
				dialStages[player] = stage + 1
				order.DialStarted = now
				local nextTarget, nextPeriod, nextTolerance = Economy.dial(order, stage + 1, data.Perks)
				interface:FireClient(
					player,
					"dial",
					order.Id,
					now,
					nextTarget,
					nextPeriod,
					nextTolerance,
					stage + 1,
					Economy.DialStages
				)
				return true, false
			end
			order.DialStarted = 0
			dialStages[player] = nil
			opened = hit
			interface:FireClient(player, "dialEnd", hit)
			if not hit then
				World.RotateDial(plot, 0)
				tell(player, "Штифт сорвался. Начните взлом заново.")
			end
		end
	elseif not physical then
		return false, false
	elseif kind == "box" or kind == "secret" then
		order.Progress += 1
		opened = order.Progress >= Economy.openingGoal(order)
	elseif kind == "crate" or kind == "cargo" then
		if argument == "doors" then
			if kind ~= "cargo" or Economy.openingProgress(order) ~= Economy.openingGoal(order) - 1 then
				return false, false
			end
			opened = true
		else
			local index = member(argument, if kind == "crate" then 4 else 2)
			if not index then
				return false, false
			end
			local mask = bit32.lshift(1, index - 1)
			if bit32.btest(order.Progress, mask) then
				return false, false
			end
			order.Progress = bit32.bor(order.Progress, mask)
			opened = kind == "crate" and Economy.openingProgress(order) == Economy.openingGoal(order)
		end
	end
	if opened then
		Economy.open(order, data)
	end
	return true, opened
end

local function inventoryAction(
	player: Player,
	plot: World.Plot,
	data: Types.PlayerData,
	action: string,
	itemId: string?,
	slotKey: string?
): boolean
	if action == "removeDisplay" then
		local stand = standPart(plot, slotKey)
		local displayed = slotKey and data.Displays[slotKey]
		if not stand or not slotKey or not displayed then
			return false
		end
		if not World.Near(player, stand, 9) then
			tell(player, "Подойдите к своей витрине.")
			return false
		end
		if #data.Inventory >= Economy.capacity(data) then
			tell(player, "Склад заполнен")
			return false
		end
		table.insert(data.Inventory, displayed)
		data.Displays[slotKey] = nil
		return true
	end
	local itemIndex: number?
	for index, item in data.Inventory do
		if item.Id == itemId then
			itemIndex = index
			break
		end
	end
	if not itemIndex then
		tell(player, "Этой находки больше нет на складе.")
		return false
	end
	local item = data.Inventory[itemIndex]
	if action == "sell" then
		if not World.Near(player, plot.Stations.inventory, 11) then
			tell(player, "Подойдите к складу, чтобы продать находку.")
			return false
		end
		local total = Economy.payout(data, item)
		Economy.credit(data, total)
		tell(player, `Продано · +{total} монет`)
		Audio.to(player, "sell")
	elseif action == "collection" then
		if not Economy.collectible(item.Kind) then
			return false
		end
		if not World.Near(player, plot.Stations.collections, 11) then
			tell(player, "Подойдите к терминалу коллекций.")
			return false
		end
		local replaced = data.Collections[item.Kind] ~= nil
		data.Collections[item.Kind] = item
		tell(
			player,
			if replaced
				then "Экземпляр в коллекции заменён."
				else "Экземпляр внесён в коллекцию."
		)
		Audio.to(player, "deposit")
	elseif action == "display" and slotKey then
		local stand = standPart(plot, slotKey)
		local index = member(slotKey, #Catalog.DisplaySizes)
		if not stand or not index or data.Displays[slotKey] then
			return false
		end
		if Catalog.Items[item.Kind].Size ~= Catalog.DisplaySizes[index] then
			return false
		end
		if not World.Near(player, stand, 9) then
			tell(player, "Подойдите к своей витрине.")
			return false
		end
		data.Displays[slotKey] = item
		tell(player, "Находка выставлена.")
		Audio.to(player, "place")
	else
		return false
	end
	table.remove(data.Inventory, itemIndex)
	return true
end

local function lootAction(
	player: Player,
	plot: World.Plot,
	data: Types.PlayerData,
	order: Types.Order,
	action: string,
	itemId: string?,
	physical: boolean
): boolean
	if order.Stage ~= "open" then
		return false
	end
	if action == "pickup" and physical and itemId then
		local position, target = World.Position(player), plot.LootPositions[itemId]
		if
			not position
			or not target
			or (position - target).Magnitude > (if order.Kind == "cargo" then 5.8 else 8.9)
		then
			return false
		end
		if order.Kind == "cargo" then
			local inside = plot.Pad:PointToObjectSpace(position)
			if math.abs(inside.X) > 6.6 or math.abs(inside.Z) > 7.8 then
				return false
			end
		end
		for index, loot in order.Loot do
			if loot.Item.Id == itemId then
				if loot.Item.Quality <= Economy.recycleLimit(data) then
					-- «Утилизатор»: дешёвая находка продаётся сразу и не занимает место на складе.
					local value = Economy.payout(data, loot.Item)
					Economy.credit(data, value)
					table.remove(order.Loot, index)
					finishLoot(order)
					tell(player, `Утилизатор · {Catalog.Items[loot.Item.Kind].Name} +{value}`)
					Audio.to(player, "coin")
					return true
				end
				if #data.Inventory >= Economy.capacity(data) then
					tell(player, "Склад заполнен")
					return false
				end
				table.insert(data.Inventory, loot.Item)
				table.remove(order.Loot, index)
				finishLoot(order)
				tell(player, `На складе · {Catalog.Items[loot.Item.Kind].Name}`)
				Audio.to(player, "pickup")
				return true
			end
		end
	elseif (action == "quickSell" or action == "quickCollect") and (data.Perks[action] or 0) > 0 then
		if not World.Near(player, plot.Button, 11) then
			tell(player, "Подойдите к пульту добычи.")
			return false
		end
		if action == "quickSell" then
			local total = 0
			local bonus = Economy.bulkBonus(data)
			for _, loot in order.Loot do
				total += Economy.payout(data, loot.Item, bonus)
			end
			table.clear(order.Loot)
			Economy.credit(data, total)
			tell(player, `Быстрая продажа · +{total} монет`)
			Audio.to(player, "sell")
		else
			local limit = Economy.recycleLimit(data)
			local stored, sold, earned = 0, 0, 0
			local index = 1
			while index <= #order.Loot do
				local loot = order.Loot[index]
				if loot.Item.Quality <= limit then
					earned += Economy.payout(data, loot.Item)
					table.remove(order.Loot, index)
					sold += 1
				elseif #data.Inventory < Economy.capacity(data) then
					table.insert(data.Inventory, loot.Item)
					table.remove(order.Loot, index)
					stored += 1
				else
					index += 1
				end
			end
			if stored + sold == 0 then
				tell(player, "Склад заполнен")
				return false
			end
			if earned > 0 then
				Economy.credit(data, earned)
			end
			local note = if sold > 0 then ` · утилизировано {sold} (+{earned})` else ""
			if #order.Loot > 0 then
				tell(player, `Склад заполнен · осталось {#order.Loot}{note}`)
			else
				tell(player, `Собрано находок · {stored}{note}`)
				Audio.to(player, "pickup")
			end
		end
		finishLoot(order)
		return true
	end
	return false
end

function SimulatorService:Use(player: Player, action: string, argument: string?, physical: boolean, extra: string?): ()
	local session = sessions[player]
	if not session or not session.Initialized or not Data:Get(player) or player.Parent ~= Players then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if physical then
		if now - (session.PhysicalAt[action] or -math.huge) < ACTION_INTERVAL then
			return
		end
		session.PhysicalAt[action] = now
	else
		if not REMOTE_ACTIONS[action] or now - session.RemoteAt < ACTION_INTERVAL then
			return
		end
		session.RemoteAt = now
	end
	local plot = session.Plot
	if action == "menu" then
		if not physical or not argument then
			return
		end
		local station = menuPart(plot, argument)
		if station and World.Near(player, station, 11) then
			interface:FireClient(player, "menu", argument)
		end
		return
	end
	local updated, scatter = false, false
	Data:Update(player, function(data)
		local order = data.Orders[1]
		if action == "buy" then
			if not World.Near(player, plot.Stations.terminal, 11) then
				tell(player, "Подойдите к терминалу заказов.")
			elseif #data.Orders >= 1 + (data.Perks.orders or 0) then
				tell(player, "Все слоты заказов заняты.")
			elseif data.Coins < Economy.orderPrice(data) then
				tell(player, "Недостаточно монет.")
			else
				local price = Economy.orderPrice(data)
				local refund = Economy.cashback(data, price)
				data.Coins += refund - price
				table.insert(data.Orders, Economy.newOrder(data, false))
				updated = true
				local text = if #data.Orders == 1
					then "Заказ принят."
					else `Заказ принят · место в очереди {#data.Orders}`
				tell(player, if refund > 0 then `{text} Кэшбэк +{refund}` else text)
				Audio.to(player, "order")
			end
		elseif action == "open" and order then
			updated, scatter = openOrder(player, plot, data, order, argument, physical)
			if scatter then
				data.Opened += 1
			end
		elseif action == "perk" and argument then
			local perk = perks[argument]
			local level = data.Perks[argument] or 0
			local cost = if perk then Catalog.perkCost(perk, level, data.Perks) else nil
			if not perk or not cost then
				return
			end
			local lock = Catalog.perkLock(perk, level, data.Perks, data.Opened)
			if lock then
				tell(player, lock)
			elseif data.Coins < cost then
				tell(player, "Недостаточно монет.")
			elseif data.Coins - cost < Economy.orderPrice(data) then
				-- Защита от тупика: после покупки должно хватать на следующий заказ.
				tell(player, "Оставьте монет на следующий заказ.")
			else
				data.Coins -= cost
				data.Perks[argument] = level + 1
				Audio.to(player, "perk")
				updated = true
			end
		elseif action == "skipTutorial" then
			data.TutorialDone = true
			guides[player] = nil
			interface:FireClient(player, "guide", nil)
			updated = true
		elseif action == "daily" then
			local day = math.floor(now / 86400)
			if data.DailyClaim >= day then
				tell(player, "Сегодня награда уже получена.")
			elseif now < session.ReadyAt then
				tell(player, "Награда откроется после 15 минут в игре.")
			else
				data.DailyClaim = day
				local reward = Economy.dailyReward(data)
				Economy.credit(data, reward)
				updated = true
				tell(player, `Ежедневная награда · +{reward} монет`)
				Audio.to(player, "claim")
			end
		elseif action == "sell" or action == "collection" or action == "display" or action == "removeDisplay" then
			updated = inventoryAction(player, plot, data, action, argument, extra)
		elseif order and (action == "pickup" or action == "quickSell" or action == "quickCollect") then
			updated = lootAction(player, plot, data, order, action, argument, physical)
		end
	end)
	if updated then
		sync(player, session, scatter)
	end
end

local function startRankings(): ()
	task.spawn(function()
		local names: { [string]: string } = {}
		local loaded = false
		while true do
			local rank = Data:GetRanking()
			if rank then
				local entries: { World.RankingEntry } = {}
				for _, row in rank do
					local userId = tonumber(row.Key)
					if userId and not names[row.Key] then
						local ok, name = pcall(function()
							return Players:GetNameFromUserIdAsync(userId)
						end)
						if ok then
							names[row.Key] = name
						end
					end
					table.insert(entries, { Name = names[row.Key] or row.Key, Score = row.Value })
				end
				World.Board("global", entries, "Пока нет результатов")
				loaded = true
			elseif not loaded then
				World.Board("global", {}, "Общий рейтинг сейчас недоступен")
			end
			task.wait(90)
		end
	end)
	task.spawn(function()
		while true do
			local entries: { World.RankingEntry } = {}
			for player in sessions do
				local data = Data:Get(player)
				if data then
					table.insert(entries, {
						Name = player.DisplayName,
						Score = data.Earned,
						Opened = data.Opened,
					})
				end
			end
			table.sort(entries, function(first, second)
				if first.Score == second.Score then
					return first.Name < second.Name
				end
				return first.Score > second.Score
			end)
			World.Board("localLobby", entries, "Ожидание игроков")
			task.wait(3)
		end
	end)
end

function SimulatorService:Start(): ()
	changed = Remotes.event(Remotes.Events.DataChanged)
	interface = Remotes.event(Remotes.Events.Interface)
	ItemAssets.preload()
	plots = World.Build(function(index, player, action, argument)
		local session = sessions[player]
		if session and session.Plot.Rank == index then
			SimulatorService:Use(player, action, argument, true, nil)
		end
	end)
	Remotes.func(Remotes.Functions.GetData).OnServerInvoke = function(player: Player): Types.View?
		local now = os.clock()
		if now - (lastProfileQuery[player] or -math.huge) < 0.5 then
			return nil
		end
		lastProfileQuery[player] = now
		return view(player)
	end
	Remotes.event(Remotes.Events.Action).OnServerEvent
		:Connect(function(player: Player, action: unknown, argument: unknown, extra: unknown)
			if typeof(action) ~= "string" or #action > 16 then
				return
			end
			if argument ~= nil and (typeof(argument) ~= "string" or #argument > 40) then
				return
			end
			if extra ~= nil and (typeof(extra) ~= "string" or #extra > 4) then
				return
			end
			SimulatorService:Use(player, action, argument :: string?, false, extra :: string?)
		end)
	Players.PlayerAdded:Connect(occupy)
	Players.PlayerRemoving:Connect(function(player)
		lastProfileQuery[player] = nil
		dialStages[player] = nil
		stats[player] = nil
		guides[player] = nil
		galleryAt[player] = nil
		local session = sessions[player]
		if session then
			World.Clear(session.Plot)
			World.UpdateDisplays(session.Plot, {})
			World.UpdateStorage(session.Plot, 15, {})
			World.UpdateCollections(session.Plot, {})
			World.UpdateStatus(session.Plot, nil, nil, 0, 0, 15)
			World.Owner(session.Plot, nil)
			occupants[session.Plot.Rank] = nil
			sessions[player] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(occupy, player)
	end
	startRankings()
	while true do
		local now = Workspace:GetServerTimeNow()
		for player, session in sessions do
			World.RecoverFromShaft(player, plots)
			tickPlayer(player, session, now)
			payGallery(player, session, now)
		end
		task.wait(0.1)
	end
end

return SimulatorService
