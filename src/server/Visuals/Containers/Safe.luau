--!strict
-- Safe: model and door opening.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Audio = require(script.Parent.Parent.Parent.Network.Audio)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.World)
local Common = require(script.Parent.Common)
type Build = Common.Build
type Ctx = Common.Ctx
local STEEL = Common.STEEL
local IRON = Common.IRON
local RED = Common.RED
local GREEN = Common.GREEN
local swingAll = Common.swingAll
local sparks = Common.sparks
local add = Common.add
local addCylinder = Common.addCylinder
local join = Common.join
local hinge = Common.hinge
local light = Common.light

local Safe = {}

local SAFE_BODY = Color3.fromRGB(82, 96, 112)
local SAFE_DOOR = Color3.fromRGB(108, 124, 142)
local BRASS = Color3.fromRGB(232, 184, 74)

-- ============ Сейф ============

local SAFE_FLOOR = 0.3
local SAFE_DOOR_PIVOT = Vector3.new(-2.5, 0, -3.25)

local function buildSafe(b: Build, openParts: { Part }): ()
	local center = Vector3.new(0.8, 2.3, -3.62)
	b.Layout.Center = center
	add(
		b,
		"Цоколь",
		CFrame.new(0, SAFE_FLOOR / 2, 0),
		Vector3.new(6.4, SAFE_FLOOR, 6.4),
		STEEL,
		Enum.Material.DiamondPlate
	)
	add(b, "Корпус", CFrame.new(0, 2.25, 0), Vector3.new(6, 3.9, 6), SAFE_BODY, Enum.Material.Metal)
	for _, rib in { 0.9, 1.5, 2.1 } do
		add(b, "Ребро", CFrame.new(0, 4.22, rib - 0.4), Vector3.new(5.4, 0.1, 0.3), STEEL, Enum.Material.Metal)
	end
	local cavity = add(
		b,
		"Проём",
		CFrame.new(0, 2.25, -3.02),
		Vector3.new(4.9, 3.3, 0.1),
		Color3.fromRGB(14, 18, 24),
		Enum.Material.SmoothPlastic
	)
	b.Layout.Named.Cavity = cavity
	light(cavity, Color3.fromRGB(255, 226, 170), 14)
	add(b, "Обрамление", CFrame.new(0, 4.0, -3.1), Vector3.new(5.5, 0.25, 0.22), STEEL, Enum.Material.Metal)
	add(b, "Обрамление", CFrame.new(0, 0.5, -3.1), Vector3.new(5.5, 0.25, 0.22), STEEL, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		add(
			b,
			"Обрамление",
			CFrame.new(side * 2.675, 2.25, -3.1),
			Vector3.new(0.25, 3.8, 0.22),
			STEEL,
			Enum.Material.Metal
		)
	end
	for _, y in { 1.0, 3.5 } do
		addCylinder(b, "Петля", Vector3.new(-2.55, y, -3.3), "y", 0.7, 0.3, IRON, Enum.Material.Metal)
	end

	local door = add(
		b,
		"Дверца сейфа",
		CFrame.new(0, 2.25, -3.25),
		Vector3.new(4.9, 3.3, 0.4),
		SAFE_DOOR,
		Enum.Material.Metal
	)
	table.insert(openParts, door)
	join(b, "Door", door)
	local panel = add(
		b,
		"Панель двери",
		CFrame.new(0, 2.25, -3.47),
		Vector3.new(4.2, 2.7, 0.06),
		SAFE_BODY,
		Enum.Material.DiamondPlate
	)
	join(b, "Door", panel)

	local marker = add(
		b,
		"Метка ручки",
		CFrame.new(center + Vector3.new(0, 0.55, -0.3)),
		Vector3.new(0.16, 0.34, 0.08),
		RED,
		Enum.Material.Neon
	)
	marker.CanCollide = false
	table.insert(openParts, marker)
	join(b, "Door", marker)
	join(b, "Spin", marker)

	local dial = addCylinder(b, "Ручка", center, "z", 0.3, 1.6, BRASS, Enum.Material.Metal)
	table.insert(openParts, dial)
	join(b, "Door", dial)
	for index = 0, 2 do
		local spoke = add(
			b,
			"Спица",
			CFrame.new(center + Vector3.new(0, 0, -0.25)) * CFrame.Angles(0, 0, index * math.pi / 3),
			Vector3.new(0.14, 1.5, 0.12),
			BRASS,
			Enum.Material.Metal
		)
		join(b, "Door", spoke)
		join(b, "Spin", spoke)
	end
	local hub =
		addCylinder(b, "Втулка", center + Vector3.new(0, 0, -0.32), "z", 0.2, 0.42, STEEL, Enum.Material.Metal)
	join(b, "Door", hub)

	for index, y in { 1.0, 1.9, 2.8 } do
		for _, side in { -1, 1 } do
			local bolt = addCylinder(
				b,
				"Засов",
				Vector3.new(side * 2.5, y + 0.3 * (index - 2), -3.25),
				"x",
				0.4,
				0.28,
				IRON,
				Enum.Material.Metal
			)
			join(b, "Bolts", bolt)
			join(b, "Door", bolt)
		end
	end
	for index = 1, 3 do
		local lamp = add(
			b,
			"Индикатор",
			CFrame.new(-1.6 + index * 0.4, 3.65, -3.48),
			Vector3.new(0.22, 0.22, 0.08),
			RED,
			Enum.Material.Neon
		)
		join(b, "Lamps", lamp)
		join(b, "Door", lamp)
	end
	for _, piece in b.Layout.Groups.Door do
		hinge(b, piece, SAFE_DOOR_PIVOT, Vector3.yAxis, 1.85)
	end
	b.Kit.Prompt(dial, Texts.safeTurn, b.Model.Name, b.Use, "open", nil, 9)
end

local function safeOpen(ctx: Ctx, instant: boolean): ()
	local layout = ctx.Layout
	for _, lamp in layout.Groups.Lamps do
		lamp.Color = GREEN
	end
	-- Засовы уходят в дверь; новое положение запоминаем, чтобы дверь повернулась вместе с ними.
	for _, bolt in layout.Groups.Bolts do
		local rest = layout.Rest[bolt]
		local inward = if rest.Position.X < 0 then 0.45 else -0.45
		layout.Rest[bolt] = rest * CFrame.new(inward, 0, 0)
		if instant then
			bolt.CFrame = ctx.Base * layout.Rest[bolt]
		else
			TweenService:Create(bolt, TweenInfo.new(0.25), { CFrame = ctx.Base * layout.Rest[bolt] }):Play()
		end
	end
	for _, piece in layout.Groups.Door do
		piece.CanCollide = false
	end
	if not instant then
		Audio.at(ctx.Model, "clunk")
	end
	local cavity = layout.Named.Cavity
	local glow = cavity:FindFirstChildWhichIsA("PointLight")
	local function swing()
		swingAll(ctx, layout.Groups.Door, if instant then 0 else 1.0, Enum.EasingStyle.Sine)
		if glow then
			if instant then
				glow.Brightness = 2.5
			else
				TweenService:Create(glow, TweenInfo.new(0.6), { Brightness = 2.5 }):Play()
				sparks(ctx.Model, cavity.CFrame * CFrame.new(0, 0, -0.4), 22, BRASS, 18, 10)
				Audio.at(ctx.Model, "scrape")
			end
		end
	end
	if instant then
		swing()
	else
		task.delay(0.3, function()
			if ctx.Model.Parent then
				swing()
			end
		end)
	end
end

Safe.buildSafe = buildSafe
Safe.safeOpen = safeOpen

return Safe
