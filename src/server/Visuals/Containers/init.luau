--!strict
-- Модели контейнеров и анимации их открытия. Логика открытия (прогресс, проверки) остаётся в SimulatorService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Types = require(ReplicatedStorage.Shared.Types)
local Box = require(script.Box)
local Cargo = require(script.Cargo)
local Common = require(script.Common)
local Crate = require(script.Crate)
local Safe = require(script.Safe)
local Secret = require(script.Secret)
type Use = Common.Use
type Kit = Common.Kit
type Layout = Common.Layout
local bits = Common.bits
local buildBox = Box.buildBox
local boxStep = Box.boxStep
local buildCrate = Crate.buildCrate
local crateBreak = Crate.crateBreak
local crateCollapse = Crate.crateCollapse
local buildSafe = Safe.buildSafe
local safeOpen = Safe.safeOpen
local buildCargo = Cargo.buildCargo
local cargoUnlock = Cargo.cargoUnlock
local cargoOpen = Cargo.cargoOpen
local buildSecret = Secret.buildSecret
local secretCharge = Secret.secretCharge

local Containers = {}

local Layouts: { [Model]: Layout } = setmetatable({}, { __mode = "k" }) :: any

-- ============ Публичный интерфейс ============

function Containers.build(order: Types.Order, use: Use, kit: Kit): (Model, { Part })
	local model = Instance.new("Model")
	model.Name = if order.Variant then Catalog.Variants[order.Kind] else Catalog.Containers[order.Kind]
	local layout: Layout = { Rest = {}, Hinges = {}, Named = {}, Groups = {}, Center = Vector3.zero }
	local b: Build = { Kit = kit, Model = model, Layout = layout, Use = use, Variant = order.Variant }
	local openParts: { Part } = {}
	if order.Kind == "box" then
		buildBox(b)
	elseif order.Kind == "crate" then
		buildCrate(b, openParts)
	elseif order.Kind == "safe" then
		buildSafe(b, openParts)
	elseif order.Kind == "cargo" then
		buildCargo(b, openParts)
	else
		buildSecret(b, openParts)
	end
	Layouts[model] = layout
	model.WorldPivot = CFrame.new()
	return model, openParts
end

-- Поворачивает метку и спицы ручки сейфа; phase от 0 до 1.
function Containers.prepareRelease(model: Model, duration: number): ()
	model:SetAttribute("Releasing", true)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.CanCollide = false
		end
	end
	local layout = Layouts[model]
	if not layout then
		return
	end
	local base = model:GetPivot()
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad)
	-- Открытые двери грузового контейнера выступают за границы шахты.
	for _, group in { "Door-1", "Door1" } do
		local doors = layout.Groups[group]
		if not doors then
			continue
		end
		for _, piece in doors do
			local closed = base * layout.Rest[piece]
			TweenService:Create(piece, info, { CFrame = closed }):Play()
		end
	end
end

function Containers.rotateDial(model: Model, base: CFrame, phase: number): ()
	local layout = Layouts[model]
	if not layout or not layout.Groups.Spin then
		return
	end
	local center = layout.Center
	local spin = CFrame.new(center) * CFrame.Angles(0, 0, -math.pi * 2 * phase) * CFrame.new(-center)
	for _, piece in layout.Groups.Spin do
		piece.CFrame = base * spin * layout.Rest[piece]
	end
end

-- Приводит визуальное состояние к прогрессу заказа. live = true проигрывает анимации,
-- иначе (восстановление сохранения) состояние ставится сразу. Возвращает задержку до разлёта добычи.
function Containers.update(model: Model, order: Types.Order, base: CFrame, live: boolean, openParts: { Part }): number
	local layout = Layouts[model]
	if not layout then
		return 0
	end
	local ctx: Ctx = { Model = model, Layout = layout, Base = base }
	local instant = not live
	local opened = order.Stage == "open" or order.Stage == "clear"
	local sealed = order.Stage == "sealed"
	local applied = (model:GetAttribute("Applied") :: number?) or 0
	local lead = 0

	if order.Kind == "box" then
		local target = if opened then 4 else order.Progress
		for step = applied + 1, target do
			boxStep(ctx, step, instant)
		end
		model:SetAttribute("Applied", math.max(applied, target))
		lead = 0.2
	elseif order.Kind == "secret" then
		local target = if opened then 5 else order.Progress
		for step = applied + 1, target do
			secretCharge(ctx, step, instant)
		end
		model:SetAttribute("Applied", math.max(applied, target))
		lead = 0.25
	elseif order.Kind == "crate" then
		local mask = order.Progress
		for index = 1, 4 do
			local flag = bit32.lshift(1, index - 1)
			if bit32.btest(mask, flag) and not bit32.btest(applied, flag) then
				applied = bit32.bor(applied, flag)
				crateBreak(ctx, openParts[index], index, bits(applied), instant)
			end
		end
		model:SetAttribute("Applied", applied)
		if opened and not model:GetAttribute("Collapsed") then
			model:SetAttribute("Collapsed", true)
			if instant then
				crateCollapse(ctx, true)
			else
				task.delay(0.3, function()
					if model.Parent then
						crateCollapse(ctx, false)
					end
				end)
			end
		end
		lead = 0.35
	elseif order.Kind == "safe" then
		if opened and not model:GetAttribute("Collapsed") then
			model:SetAttribute("Collapsed", true)
			safeOpen(ctx, instant)
		end
		lead = 1
	else
		for index = 1, 2 do
			local flag = bit32.lshift(1, index - 1)
			local lock = openParts[index * 2]
			if bit32.btest(order.Progress, flag) and not bit32.btest(applied, flag) then
				applied = bit32.bor(applied, flag)
				cargoUnlock(ctx, lock, if index == 1 then -1 else 1, instant)
			end
			local action = lock:FindFirstChildWhichIsA("ProximityPrompt")
			if action then
				action.Enabled = sealed and not bit32.btest(order.Progress, flag)
			end
		end
		model:SetAttribute("Applied", applied)
		local handle = openParts[5]
		local trigger = handle:FindFirstChildWhichIsA("ProximityPrompt")
		if trigger then
			trigger.Enabled = sealed and order.Progress == 3
		end
		if opened and not model:GetAttribute("Collapsed") then
			model:SetAttribute("Collapsed", true)
			cargoOpen(ctx, handle, instant)
		end
	end
	return lead
end

return Containers
