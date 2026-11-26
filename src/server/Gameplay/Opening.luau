--!strict
-- Opening a delivered container: per-type actions and the safe mini-game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.Notices)
local Data = require(script.Parent.Parent.Services.PlayerDataService)
local Economy = require(script.Parent.Parent.Economy.Economy)
local World = require(script.Parent.Parent.World.World)
local Rules = require(script.Parent.Parent.Config.Rules)
local State = require(script.Parent.State)
local Plots = require(script.Parent.Plots)

local Opening = {}

function Opening.open(
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
		local index = Plots.member(argument, 4)
		targetPart = if index then plot.OpenParts[index] else nil
	elseif kind == "cargo" then
		local index = Plots.member(argument, 2)
		targetPart = if index then plot.OpenParts[index * 2] else if argument == "doors" then plot.OpenParts[5] else nil
	elseif kind == "safe" then
		targetPart = plot.OpenParts[3]
	else
		local body = plot.Active:FindFirstChild("Корпус")
		targetPart = if body and body:IsA("Part") then body else nil
	end
	if
		not targetPart
		or (position - targetPart.Position).Magnitude
			> (if kind == "cargo" or kind == "crate" then Rules.Range.CloseOpening else Rules.Range.Station)
	then
		if not physical and kind == "safe" and argument == order.Id then
			State.tell(player, Texts.turnDialAgain)
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
			State.dialStages[player] = 1
			local target, period, tolerance = Economy.dial(order, 1, data.Perks)
			State.interface:FireClient(
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
			local stage = State.dialStages[player] or 1
			local target, period, tolerance = Economy.dial(order, stage, data.Perks)
			local now = Workspace:GetServerTimeNow()
			local elapsed = now - order.DialStarted
			local phase = (elapsed % period) / period
			local distance = math.abs(phase - target)
			local hit = elapsed > 0.3
				and elapsed <= Economy.DialTimeLimit
				and math.min(distance, 1 - distance) <= tolerance
			if hit and stage < Economy.DialStages then
				-- Штифт встал на место: сразу начинается следующий, более быстрый этап.
				State.dialStages[player] = stage + 1
				order.DialStarted = now
				local nextTarget, nextPeriod, nextTolerance = Economy.dial(order, stage + 1, data.Perks)
				State.interface:FireClient(
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
			State.dialStages[player] = nil
			opened = hit
			State.interface:FireClient(player, "dialEnd", hit)
			if not hit then
				World.RotateDial(plot, 0)
				State.warn(player, Texts.dialSlipped)
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
			local index = Plots.member(argument, if kind == "crate" then 4 else 2)
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

-- Turns the safe dial while a cracking round is running and ends it on timeout.
function Opening.tickDial(
	player: Player,
	session: State.Session,
	order: Types.Order,
	data: Types.PlayerData,
	now: number
): ()
	local elapsed = now - order.DialStarted
	if elapsed <= Economy.DialTimeLimit then
		local _, period = Economy.dial(order, State.dialStages[player] or 1, data.Perks)
		World.RotateDial(session.Plot, (elapsed % period) / period)
	else
		Data:Update(player, function()
			order.DialStarted = 0
		end)
		State.dialStages[player] = nil
		World.RotateDial(session.Plot, 0)
	end
end

return Opening
