--!strict
-- Точка входа сервера. Логику сюда не добавлять — только в Services/.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)
local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)

Remotes.init()
Loader.load(script.Parent.Services)
