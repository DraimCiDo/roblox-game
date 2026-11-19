--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Data = require(script.Parent.PlayerDataService)
local Economy = require(script.Economy)
local World = require(script.World)

type Session = {
	Plot: World.Plot,
	ReadyAt: number,
	LastAction: number,
	Initialized: boolean,
	ReleaseAt: number?,
	Use: World.Use,
}

local SimulatorService = {}
local sessions: { [Player]: Session } = {}
local occupants: { [number]: Player } = {}
local lastProfileQuery: { [Player]: number } = {}
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
	local prices = {}
	for _, item in data.Inventory do
		prices[item.Id] = Economy.price(data, item)
	end
	return {
		Coins = data.Coins,
		Earned = data.Earned,
		Inventory = data.Inventory,
		Collections = data.Collections,
		Displays = data.Displays,
		Perks = data.Perks,
		Orders = #data.Orders,
		OrderStage = if order then order.Stage else nil,
		OrderKind = if visible then order.Kind else nil,
		OrderVariant = if visible then order.Variant else nil,
		RemainingLoot = if order then #order.Loot else 0,
		Prices = prices,
		DailyReadyAt = session.ReadyAt,
		DailyClaim = data.DailyClaim,
	}
end

local function publish(player: Player): ()
	local output = view(player)
	if output then
		changed:FireClient(player, output)
	end
end

local function tell(player: Player, text: string): ()
	interface:FireClient(player, "notice", text)
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
	World.UpdateStorage(session.Plot, Economy.capacity(data))
	World.UpdateDisplays(session.Plot, data.Displays)
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
		LastAction = -math.huge,
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

local function tickPlayer(player: Player, session: Session, now: number): ()
	if not session.Initialized then
		return
	end
	local data = Data:Get(player)
	local order = data and data.Orders[1]
	if not order then
		return
	end
	if order.Stage == "queued" then
		Data:Update(player, function()
			order.Stage = "delivery"
			order.Deadline = now + Economy.deliveryTime(order)
		end)
		sync(player, session)
	elseif order.Stage == "delivery" and now >= order.Deadline then
		Data:Update(player, function()
			order.Stage = "sealed"
			order.Deadline = 0
		end)
		sync(player, session)
	elseif order.Stage == "sealed" and order.DialStarted > 0 then
		local elapsed = now - order.DialStarted
		if elapsed <= 20 then
			World.RotateDial(session.Plot, (elapsed % Economy.DialPeriod) / Economy.DialPeriod)
		else
			Data:Update(player, function()
				order.DialStarted = 0
			end)
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
			session.ReleaseAt = now + 1.1
			World.Release(session.Plot)
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
		targetPart = plot.OpenParts[2]
	else
		local body = plot.Active:FindFirstChild("Корпус")
		targetPart = if body and body:IsA("Part") then body else nil
	end
	if
		not targetPart
		or (position - targetPart.Position).Magnitude > (if kind == "cargo" or kind == "crate" then 8 else 11)
	then
		return false, false
	end
	local opened = false
	if kind == "safe" then
		if physical and not argument then
			order.DialStarted = Workspace:GetServerTimeNow()
			interface:FireClient(
				player,
				"dial",
				order.Id,
				order.DialStarted,
				order.Target,
				Economy.DialPeriod,
				Economy.DialTolerance
			)
			return true, false
		elseif not physical and argument == order.Id and order.DialStarted > 0 then
			local elapsed = Workspace:GetServerTimeNow() - order.DialStarted
			local phase = (elapsed % Economy.DialPeriod) / Economy.DialPeriod
			order.DialStarted = 0
			opened = elapsed > 0.3 and elapsed <= 20 and math.abs(phase - order.Target) <= Economy.DialTolerance
			if not opened then
				World.RotateDial(plot, 0)
				tell(player, "Ручка вне сектора. Попробуйте ещё раз.")
			end
		else
			return false, false
		end
	elseif not physical then
		return false, false
	elseif kind == "box" or kind == "secret" then
		order.Progress += 1
		opened = order.Progress >= (if kind == "box" then 4 else 5)
	elseif kind == "crate" or kind == "cargo" then
		if argument == "doors" then
			if kind ~= "cargo" or order.Progress ~= 3 then
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
			opened = kind == "crate" and order.Progress == 15
		end
	end
	if opened then
		Economy.open(order)
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
		if not stand or not slotKey or not displayed or not World.Near(player, stand, 9) then
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
		return false
	end
	local item = data.Inventory[itemIndex]
	if action == "sell" and World.Near(player, plot.Stations.inventory, 11) then
		local total = Economy.price(data, item)
		Economy.credit(data, total)
		tell(player, `Продано · +{total} монет`)
	elseif
		action == "collection"
		and World.Near(player, plot.Stations.collections, 11)
		and Economy.collectible(item.Kind)
	then
		data.Collections[item.Kind] = item
		tell(player, "Экземпляр внесён в коллекцию.")
	elseif action == "display" and slotKey then
		local stand = standPart(plot, slotKey)
		local index = member(slotKey, #Catalog.DisplaySizes)
		if not stand or not index or data.Displays[slotKey] or not World.Near(player, stand, 9) then
			return false
		end
		if Catalog.Items[item.Kind].Size ~= Catalog.DisplaySizes[index] then
			return false
		end
		data.Displays[slotKey] = item
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
		if #data.Inventory >= Economy.capacity(data) then
			tell(player, "Склад заполнен")
			return false
		end
		for index, loot in order.Loot do
			if loot.Item.Id == itemId then
				table.insert(data.Inventory, loot.Item)
				table.remove(order.Loot, index)
				finishLoot(order)
				return true
			end
		end
	elseif
		(action == "quickSell" or action == "quickCollect")
		and (data.Perks[action] or 0) > 0
		and World.Near(player, plot.Button, 11)
	then
		if action == "quickSell" then
			local total = 0
			for _, loot in order.Loot do
				total += Economy.price(data, loot.Item)
			end
			table.clear(order.Loot)
			Economy.credit(data, total)
			tell(player, `Быстрая продажа · +{total} монет`)
		else
			local count = math.min(#order.Loot, Economy.capacity(data) - #data.Inventory)
			for _ = 1, count do
				local loot = table.remove(order.Loot, 1)
				if loot then
					table.insert(data.Inventory, loot.Item)
				end
			end
			if #order.Loot > 0 then
				tell(player, "Склад заполнен")
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
	if now - session.LastAction < 0.14 then
		return
	end
	session.LastAction = now
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
		if action == "buy" and World.Near(player, plot.Stations.terminal, 11) then
			if #data.Orders >= 1 + (data.Perks.orders or 0) then
				tell(player, "Все слоты заказов заняты.")
			elseif data.Coins < Config.OrderPrice then
				tell(player, "Недостаточно монет.")
			else
				data.Coins -= Config.OrderPrice
				table.insert(data.Orders, Economy.newOrder(data, false))
				updated = true
			end
		elseif action == "open" and order then
			updated, scatter = openOrder(player, plot, order, argument, physical)
		elseif action == "perk" and argument then
			local perk = perks[argument]
			local level = data.Perks[argument] or 0
			local cost = perk and perk.Costs[level + 1]
			if not cost or (perk.Parent and (data.Perks[perk.Parent] or 0) < (perk.Required or 1)) then
				return
			end
			if data.Coins < cost then
				tell(player, "Недостаточно монет.")
			else
				data.Coins -= cost
				data.Perks[argument] = level + 1
				updated = true
			end
		elseif action == "daily" then
			local day = math.floor(now / 86400)
			if now >= session.ReadyAt and data.DailyClaim < day then
				data.DailyClaim = day
				Economy.credit(data, Economy.DailyReward)
				updated = true
				tell(player, `Ежедневная награда · +{Economy.DailyReward} монет`)
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

local function boardText(title: string, entries: { { Name: string, Score: number } }): string
	local lines = { title }
	for index, entry in entries do
		table.insert(lines, `{index}. {entry.Name}  ·  {entry.Score}`)
	end
	if #entries == 0 then
		table.insert(lines, "Пока пусто")
	end
	return table.concat(lines, "\n")
end

local function startRankings(): ()
	World.Board("global", "ОБЩИЙ РЕЙТИНГ\nНет данных")
	task.spawn(function()
		local names: { [string]: string } = {}
		while true do
			local rank = Data:GetRanking()
			if rank then
				local entries = {}
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
				World.Board("global", boardText("ОБЩИЙ · ЗАРАБОТАНО МОНЕТ", entries))
			end
			task.wait(90)
		end
	end)
	task.spawn(function()
		while true do
			local entries = {}
			for player in sessions do
				local data = Data:Get(player)
				if data then
					table.insert(entries, { Name = player.DisplayName, Score = data.Earned })
				end
			end
			table.sort(entries, function(first, second)
				if first.Score == second.Score then
					return first.Name < second.Name
				end
				return first.Score > second.Score
			end)
			World.Board("localLobby", boardText("ЛОББИ · ЗАРАБОТАНО МОНЕТ", entries))
			task.wait(3)
		end
	end)
end

function SimulatorService:Start(): ()
	changed = Remotes.event(Remotes.Events.DataChanged)
	interface = Remotes.event(Remotes.Events.Interface)
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
		local session = sessions[player]
		if session then
			World.Clear(session.Plot)
			World.UpdateDisplays(session.Plot, {})
			World.UpdateStorage(session.Plot, 15)
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
			tickPlayer(player, session, now)
		end
		task.wait(0.1)
	end
end

return SimulatorService
