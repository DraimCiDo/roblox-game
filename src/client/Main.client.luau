--!strict
-- Точка входа клиента. Логику сюда не добавлять — только в Controllers/.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)

Loader.load(script.Parent.Controllers)
