--!strict
-- Leaderboards in the hall: all-time (DataStore) and current server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Texts = require(ReplicatedStorage.Shared.Config.Texts.Notices)
local Data = require(script.Parent.Parent.Services.PlayerDataService)
local World = require(script.Parent.Parent.World.World)
local Rules = require(script.Parent.Parent.Config.Rules)
local State = require(script.Parent.State)

local Rankings = {}

function Rankings.start(): ()
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
				World.Board("global", entries, Texts.rankingEmpty)
				loaded = true
			elseif not loaded then
				World.Board("global", {}, Texts.rankingUnavailable)
			end
			task.wait(Rules.Rankings.GlobalRefresh)
		end
	end)
	task.spawn(function()
		while true do
			local entries: { World.RankingEntry } = {}
			for player in State.sessions do
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
			World.Board("localLobby", entries, Texts.rankingWaiting)
			task.wait(Rules.Rankings.LobbyRefresh)
		end
	end)
end

return Rankings
