--!strict
-- Cargo container: model, locks and doors.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(script.Parent.Parent.Parent.Network.Audio)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.World)
local Common = require(script.Parent.Common)
type Build = Common.Build
type Ctx = Common.Ctx
local STEEL = Common.STEEL
local ICE = Common.ICE
local AMBER = Common.AMBER
local IRON = Common.IRON
local drive = Common.drive
local swingAll = Common.swingAll
local sparks = Common.sparks
local launch = Common.launch
local sign = Common.sign
local add = Common.add
local addCylinder = Common.addCylinder
local join = Common.join
local hinge = Common.hinge
local light = Common.light

local Cargo = {}

-- ============ Грузовой контейнер ============

local CARGO_HINGE_X = 6.9
local CARGO_FRONT = -7.8

local function buildCargo(b: Build, openParts: { Part }): ()
	local blue = if b.Variant then Color3.fromRGB(85, 108, 148) else Color3.fromRGB(59, 97, 130)
	add(
		b,
		"Пол контейнера",
		CFrame.new(0, 0.15, 0),
		Vector3.new(14, 0.3, 15.9),
		blue,
		Enum.Material.DiamondPlate
	)
	local roof = add(b, "Крыша", CFrame.new(0, 7.1, 0), Vector3.new(14, 0.4, 16), blue, Enum.Material.Metal)
	b.Layout.Named.Roof = roof
	light(roof, Color3.fromRGB(255, 230, 190), 22).Brightness = 0.5
	add(b, "Задняя стенка", CFrame.new(0, 3.6, 7.8), Vector3.new(14, 7, 0.4), blue, Enum.Material.Metal)
	for _, x in { -6.85, 6.85 } do
		for _, y in { 0.35, 6.95 } do
			for _, z in { -7.75, 7.75 } do
				add(
					b,
					"Угловой элемент",
					CFrame.new(x, y, z),
					Vector3.new(0.75, 0.75, 0.75),
					STEEL,
					Enum.Material.Metal
				)
			end
		end
	end
	for _, side in { -1, 1 } do
		add(b, "Борт", CFrame.new(6.8 * side, 3.6, 0), Vector3.new(0.4, 7, 16), blue, Enum.Material.Metal)
		for z = -6, 6, 2 do
			add(b, "Ребро", CFrame.new(7 * side, 3.6, z), Vector3.new(0.34, 6.6, 0.32), STEEL, Enum.Material.Metal)
		end
		local door = add(
			b,
			"Створка",
			CFrame.new(3.45 * side, 3.6, CARGO_FRONT),
			Vector3.new(6.85, 6.9, 0.35),
			blue,
			Enum.Material.Metal
		)
		table.insert(openParts, door)
		join(b, `Door{side}`, door)
		for rib = -2.5, 2.5, 1.25 do
			local piece = add(
				b,
				"Ребро створки",
				CFrame.new(3.45 * side + rib, 3.6, CARGO_FRONT - 0.22),
				Vector3.new(0.3, 6.5, 0.1),
				STEEL,
				Enum.Material.Metal
			)
			join(b, `Door{side}`, piece)
		end
		local rod = addCylinder(
			b,
			"Штанга",
			Vector3.new(0.9 * side, 3.6, CARGO_FRONT - 0.34),
			"y",
			6.5,
			0.2,
			IRON,
			Enum.Material.Metal
		)
		join(b, `Door{side}`, rod)
		for _, piece in b.Layout.Groups[`Door{side}`] do
			hinge(b, piece, Vector3.new(CARGO_HINGE_X * side, 0, CARGO_FRONT), Vector3.yAxis, -1.75 * side)
		end
		if side == -1 then
			sign(door, Enum.NormalId.Front, "CORPA", Color3.fromRGB(235, 245, 250))
		end
		local lock = add(
			b,
			"Фиксатор",
			CFrame.new(2.2 * side, 3.3, CARGO_FRONT - 0.36),
			Vector3.new(0.42, 2.7, 0.36),
			AMBER,
			Enum.Material.Metal
		)
		table.insert(openParts, lock)
		b.Kit.Prompt(lock, Texts.cargoUnlock, b.Model.Name, b.Use, "open", tostring(if side == -1 then 1 else 2), nil)
	end
	local handle = add(
		b,
		"Открыть створки",
		CFrame.new(0, 3.5, CARGO_FRONT - 0.36),
		Vector3.new(0.65, 1, 0.35),
		ICE,
		Enum.Material.Neon
	)
	table.insert(openParts, handle)
	b.Kit.Prompt(handle, Texts.cargoOpen, b.Model.Name, b.Use, "open", "doors", nil)
end

local function cargoUnlock(ctx: Ctx, lock: Part, side: number, instant: boolean): ()
	if not instant then
		launch(ctx.Model, lock, Vector3.new(side * 6, 8, -14))
		sparks(ctx.Model, lock.CFrame, 14, AMBER, 16)
		Audio.at(lock, "latch")
	end
	lock.Transparency = 1
	lock.CanCollide = false
end

local function cargoOpen(ctx: Ctx, handle: Part, instant: boolean): ()
	local layout = ctx.Layout
	handle.CanCollide = false
	if instant then
		handle.Transparency = 1
	else
		local rest = layout.Rest[handle]
		drive(ctx.Model, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(alpha)
			handle.CFrame = ctx.Base * rest * CFrame.Angles(0, 0, math.pi / 2 * alpha)
		end, function()
			handle.Transparency = 1
		end)
	end
	if not instant then
		Audio.at(ctx.Model, "clunk")
	end
	local doors: { Part } = {}
	for _, side in { -1, 1 } do
		for _, piece in layout.Groups[`Door{side}`] do
			piece.CanCollide = false
			table.insert(doors, piece)
		end
	end
	local function swing()
		if ctx.Model:GetAttribute("Releasing") then
			return
		end
		swingAll(ctx, doors, if instant then 0 else 1.15, Enum.EasingStyle.Sine)
		local glow = layout.Named.Roof:FindFirstChildWhichIsA("PointLight")
		if glow then
			glow.Brightness = 2
		end
		if not instant then
			sparks(ctx.Model, ctx.Base * CFrame.new(0, 3.4, CARGO_FRONT - 0.5), 24, ICE, 20, 8)
			Audio.at(ctx.Model, "scrape")
		end
	end
	if instant then
		swing()
	else
		task.delay(0.22, function()
			if ctx.Model.Parent then
				swing()
			end
		end)
	end
end

Cargo.buildCargo = buildCargo
Cargo.cargoUnlock = cargoUnlock
Cargo.cargoOpen = cargoOpen

return Cargo
