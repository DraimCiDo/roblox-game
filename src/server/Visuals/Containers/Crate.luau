--!strict
-- Wooden crate: model, breaking clamps and collapse.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(script.Parent.Parent.Parent.Network.Audio)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.World)
local Common = require(script.Parent.Common)
type Build = Common.Build
type Ctx = Common.Ctx
local ICE = Common.ICE
local AMBER = Common.AMBER
local IRON = Common.IRON
local rand = Common.rand
local drive = Common.drive
local swingAll = Common.swingAll
local fade = Common.fade
local sparks = Common.sparks
local launch = Common.launch
local add = Common.add
local join = Common.join
local hinge = Common.hinge

local Crate = {}

local WOOD = { Color3.fromRGB(158, 110, 68), Color3.fromRGB(144, 98, 60), Color3.fromRGB(170, 122, 78) }
local WOOD_DARK = Color3.fromRGB(96, 66, 44)

-- ============ Деревянный ящик ============

local CRATE_WIDTH = 6
local CRATE_HEIGHT = 4
local CRATE_FLOOR = 0.14

local function buildCrate(b: Build, openParts: { Part }): ()
	local w, h, f = CRATE_WIDTH, CRATE_HEIGHT, CRATE_FLOOR
	local rows = 5
	local plank = h / rows
	add(b, "Корпус", CFrame.new(0, f / 2, 0), Vector3.new(w, f, w), WOOD_DARK, Enum.Material.WoodPlanks)

	local function wall(
		x: number,
		z: number,
		long: number,
		alongZ: boolean,
		pivot: Vector3,
		axis: Vector3,
		angle: number
	)
		for row = 1, rows do
			local size = if alongZ then Vector3.new(0.3, plank - 0.04, long) else Vector3.new(long, plank - 0.04, 0.3)
			local piece = add(
				b,
				"Доска",
				CFrame.new(x, f + plank * (row - 0.5), z),
				size,
				WOOD[row % 3 + 1],
				Enum.Material.WoodPlanks
			)
			hinge(b, piece, pivot, axis, angle)
			join(b, "Walls", piece)
		end
	end
	local edge = w / 2 - 0.15
	wall(edge, 0, w, true, Vector3.new(w / 2, f, 0), Vector3.zAxis, -math.pi / 2)
	wall(-edge, 0, w, true, Vector3.new(-w / 2, f, 0), Vector3.zAxis, math.pi / 2)
	wall(0, edge, w - 0.6, false, Vector3.new(0, f, w / 2), Vector3.xAxis, math.pi / 2)
	wall(0, -edge, w - 0.6, false, Vector3.new(0, f, -w / 2), Vector3.xAxis, -math.pi / 2)

	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local post = add(
				b,
				"Стойка",
				CFrame.new(x * (w / 2 - 0.3), f + h / 2, z * (w / 2 - 0.3)),
				Vector3.new(0.7, h + 0.04, 0.7),
				WOOD_DARK,
				Enum.Material.Wood
			)
			join(b, "Posts", post)
		end
	end

	for index = 1, 5 do
		local lid = add(
			b,
			"Крышка",
			CFrame.new((index - 3) * 1.2, f + h + 0.08, 0),
			Vector3.new(1.14, 0.16, w),
			WOOD[index % 3 + 1],
			Enum.Material.WoodPlanks
		)
		join(b, "Lid", lid)
	end
	for _, z in { -1.9, 1.9 } do
		local batten = add(
			b,
			"Планка",
			CFrame.new(0, f + h + 0.22, z),
			Vector3.new(w, 0.12, 0.45),
			WOOD_DARK,
			Enum.Material.Wood
		)
		join(b, "Lid", batten)
	end

	local metal = if b.Variant then ICE else IRON
	local spots = { { -1.5, -1 }, { 1.5, -1 }, { -1.5, 1 }, { 1.5, 1 } }
	for index, spot in spots do
		local z = spot[2] * (w / 2 + 0.06)
		local band = add(
			b,
			"Крепление",
			CFrame.new(spot[1], f + h / 2, z),
			Vector3.new(0.5, h - 0.5, 0.1),
			metal,
			Enum.Material.Metal
		)
		table.insert(openParts, band)
		local plate = add(
			b,
			"Замок",
			CFrame.new(spot[1], f + h * 0.62, z + spot[2] * 0.05),
			Vector3.new(0.8, 0.55, 0.16),
			AMBER,
			Enum.Material.Metal
		)
		join(b, `Lock{index}`, plate)
		local interaction = b.Kit.Prompt(band, Texts.crateBreak, b.Model.Name, b.Use, "open", tostring(index), 7)
		interaction.KeyboardKeyCode = if index % 2 == 1 then Enum.KeyCode.E else Enum.KeyCode.F
		interaction.GamepadKeyCode = if index % 2 == 1 then Enum.KeyCode.ButtonX else Enum.KeyCode.ButtonY
	end
end

local function crateBreak(ctx: Ctx, band: Part, index: number, broken: number, instant: boolean): ()
	local lock = ctx.Layout.Groups[`Lock{index}`][1]
	local action = band:FindFirstChildWhichIsA("ProximityPrompt")
	if action then
		action.Enabled = false
	end
	if not instant then
		local outward = if band.Position.Z > ctx.Base.Position.Z then 1 else -1
		Audio.at(band, "snap")
		launch(ctx.Model, band, Vector3.new(rand(-6, 6), 18, outward * 16))
		launch(ctx.Model, lock, Vector3.new(rand(-6, 6), 14, outward * 12))
		sparks(ctx.Model, band.CFrame, 14, WOOD[1], 18)
	end
	band.Transparency = 1
	band.CanCollide = false
	lock.Transparency = 1
	lock.CanCollide = false
	-- Крышка приподнимается всё сильнее по мере ослабления креплений.
	local lift = 0.1 * broken
	drive(ctx.Model, if instant then 0 else 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function(alpha)
		for number, piece in ctx.Layout.Groups.Lid do
			local tilt = (if number % 2 == 0 then 1 else -1) * 0.015 * broken * alpha
			piece.CFrame = ctx.Base
				* CFrame.new(0, lift * alpha, 0)
				* ctx.Layout.Rest[piece]
				* CFrame.Angles(0, 0, tilt)
		end
	end)
end

local function crateCollapse(ctx: Ctx, instant: boolean): ()
	local layout = ctx.Layout
	if not instant then
		for _, piece in layout.Groups.Lid do
			launch(ctx.Model, piece, Vector3.new(rand(-9, 9), rand(16, 26), rand(-9, 9)))
		end
		Audio.at(ctx.Model, "woodCrash")
		sparks(ctx.Model, ctx.Base * CFrame.new(0, CRATE_HEIGHT, 0), 30, WOOD[2], 28)
		sparks(ctx.Model, ctx.Base * CFrame.new(0, 1.5, 0), 16, Color3.fromRGB(210, 190, 160), 16, 6)
	end
	fade(layout.Groups.Lid, 0)
	fade(layout.Groups.Posts, if instant then 0 else 0.25)
	swingAll(ctx, layout.Groups.Walls, if instant then 0 else 0.65, Enum.EasingStyle.Sine)
end

Crate.buildCrate = buildCrate
Crate.crateBreak = crateBreak
Crate.crateCollapse = crateCollapse

return Crate
