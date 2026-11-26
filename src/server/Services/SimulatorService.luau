--!strict
-- Composition root of the game loop: wires remotes and the world, dispatches player actions to
-- Gameplay modules and ticks every sector.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Rules = require(script.Parent.Parent.Config.Rules)
local Inventory = require(script.Parent.Parent.Gameplay.Inventory)
local Loot = require(script.Parent.Parent.Gameplay.Loot)
local Mop = require(script.Parent.Parent.Gameplay.Mop)
local Opening = require(script.Parent.Parent.Gameplay.Opening)
local Orders = require(script.Parent.Parent.Gameplay.Orders)
local Perks = require(script.Parent.Parent.Gameplay.Perks)
local Plots = require(script.Parent.Parent.Gameplay.Plots)
local Rankings = require(script.Parent.Parent.Gameplay.Rankings)
local Rewards = require(script.Parent.Parent.Gameplay.Rewards)
local Settings = require(script.Parent.Parent.Gameplay.Settings)
local State = require(script.Parent.Parent.Gameplay.State)
local View = require(script.Parent.Parent.Gameplay.View)
local Hall = require(script.Parent.Parent.World.Hall)
local ItemAssets = require(script.Parent.Parent.World.ItemAssets)
local World = require(script.Parent.Parent.World.World)
local Data = require(script.Parent.PlayerDataService)

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
	setVolume = true,
	effect = true,
	buyEffect = true,
}

local SimulatorService = {}

function SimulatorService:Use(player: Player, action: string, argument: string?, physical: boolean, extra: string?): ()
	local session = State.sessions[player]
	if not session or not session.Initialized or not Data:Get(player) or player.Parent ~= Players then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if physical then
		if now - (session.PhysicalAt[action] or -math.huge) < Rules.ActionInterval then
			return
		end
		session.PhysicalAt[action] = now
	else
		if not REMOTE_ACTIONS[action] or now - session.RemoteAt < Rules.ActionInterval then
			return
		end
		session.RemoteAt = now
	end
	local plot = session.Plot
	if action == "menu" then
		if not physical or not argument then
			return
		end
		local station = Plots.menuPart(plot, argument)
		if station and World.Near(player, station, Rules.Range.Station) then
			State.interface:FireClient(player, "menu", argument)
		end
		return
	end
	local updated, scatter = false, false
	Data:Update(player, function(data: Types.PlayerData)
		local order = data.Orders[1]
		if action == "buy" then
			updated = Orders.buy(player, plot, data)
		elseif action == "open" and order then
			updated, scatter = Opening.open(player, plot, data, order, argument, physical)
			if scatter then
				data.Opened += 1
			end
		elseif action == "perk" and argument then
			updated = Perks.buy(player, data, argument)
		elseif action == "setVolume" then
			updated = Settings.setVolume(data, argument, extra)
		elseif action == "effect" or action == "buyEffect" then
			updated = Settings.effect(player, data, action, argument)
		elseif action == "skipTutorial" then
			updated = Settings.skipTutorial(player, data)
		elseif action == "daily" then
			updated = Rewards.claimDaily(player, session, data, now)
		elseif action == "sell" or action == "collection" or action == "display" or action == "removeDisplay" then
			updated = Inventory.act(player, plot, data, action, argument, extra)
		elseif order and (action == "pickup" or action == "quickSell" or action == "quickCollect") then
			updated = Loot.act(player, plot, data, order, action, argument, physical)
		end
	end)
	if updated then
		View.sync(player, session, scatter)
	end
end

function SimulatorService:Start(): ()
	State.changed = Remotes.event(Remotes.Events.DataChanged)
	State.interface = Remotes.event(Remotes.Events.Interface)
	ItemAssets.preload()
	State.plots = World.Build(function(index, player, action, argument)
		local session = State.sessions[player]
		if session and session.Plot.Rank == index then
			SimulatorService:Use(player, action, argument, true, nil)
		end
	end)
	local plots = State.plots
	if #plots > 0 then
		local sum = Vector3.zero
		for _, plot in plots do
			sum += plot.Spawn.Position
		end
		local center = sum / #plots
		-- В центре зала стоит ядро CORPA, поэтому стойка со шваброй — у дорожки к сектору 02.
		local floorY = Mop.Start(center + Rules.Mop.StationOffset, State.tell, View.publish)
		Hall.Decorate(center, floorY)
		Hall.Gate(floorY)
	end
	Remotes.func(Remotes.Functions.GetData).OnServerInvoke = function(player: Player): Types.View?
		local now = os.clock()
		if now - (State.lastProfileQuery[player] or -math.huge) < 0.5 then
			return nil
		end
		State.lastProfileQuery[player] = now
		return View.get(player)
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
	local function occupy(player: Player): ()
		Plots.occupy(player, function(actingPlayer, action, argument)
			SimulatorService:Use(actingPlayer, action, argument, true, nil)
		end)
	end
	Players.PlayerAdded:Connect(occupy)
	Players.PlayerRemoving:Connect(Plots.release)
	for _, player in Players:GetPlayers() do
		task.spawn(occupy, player)
	end
	Rankings.start()
	while true do
		local now = Workspace:GetServerTimeNow()
		for player, session in State.sessions do
			World.RecoverFromShaft(player, plots)
			Orders.tick(player, session, now)
			Rewards.payGallery(player, session, now)
		end
		task.wait(Rules.TickInterval)
	end
end

return SimulatorService
