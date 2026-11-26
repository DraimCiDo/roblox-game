--!strict
-- Sector assignment: who owns which plot, and lookup of its stations and stands.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.Notices)
local Data = require(script.Parent.Parent.Services.PlayerDataService)
local Economy = require(script.Parent.Parent.Economy.Economy)
local World = require(script.Parent.Parent.World.World)
local State = require(script.Parent.State)
local View = require(script.Parent.View)

local Plots = {}

function Plots.occupy(player: Player, use: (Player, string, string?) -> ()): ()
	if State.sessions[player] then
		return
	end
	local plot: World.Plot?
	for index, candidate in State.plots do
		if not State.occupants[index] then
			plot = candidate
			State.occupants[index] = player
			break
		end
	end
	if not plot then
		player:Kick(Texts.serverFull)
		return
	end
	local owned = plot
	local session: State.Session = {
		Plot = owned,
		ReadyAt = Workspace:GetServerTimeNow() + Config.DailySeconds,
		RemoteAt = -math.huge,
		PhysicalAt = {},
		Initialized = false,
		ReleaseAt = nil,
		Use = function(actingPlayer, action, argument)
			if actingPlayer == player then
				use(player, action, argument)
			end
		end,
	}
	State.sessions[player] = session
	World.Owner(owned, player)
	World.SpawnPlayer(owned, player)
	while player.Parent == Players and State.sessions[player] == session do
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
			View.sync(player, session)
			return
		end
		task.wait(0.15)
	end
end
function Plots.member(value: string?, maximum: number): number?
	local index = if value then tonumber(value) else nil
	if index and index >= 1 and index <= maximum and index % 1 == 0 and tostring(index) == value then
		return index
	end
	return nil
end
function Plots.standPart(plot: World.Plot, key: string?): Part?
	local index = Plots.member(key, #plot.Stands)
	return if index then plot.Stands[index] else nil
end
function Plots.menuPart(plot: World.Plot, key: string): Part?
	return if key == "loot" then plot.Button else plot.Stations[key] or Plots.standPart(plot, key)
end

function Plots.release(player: Player): ()
	State.lastProfileQuery[player] = nil
	State.dialStages[player] = nil
	State.stats[player] = nil
	State.guides[player] = nil
	State.galleryAt[player] = nil
	local session = State.sessions[player]
	if session then
		World.Clear(session.Plot)
		World.UpdateDisplays(session.Plot, {})
		World.UpdateStorage(session.Plot, Catalog.Storage.Base, {})
		World.UpdateCollections(session.Plot, {})
		World.UpdateStatus(session.Plot, nil, nil, 0, 0, Catalog.Storage.Base)
		World.Owner(session.Plot, nil)
		State.occupants[session.Plot.Rank] = nil
		State.sessions[player] = nil
	end
end

return Plots
