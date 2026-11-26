--!strict
-- Cardboard box: model and opening steps.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(script.Parent.Parent.Parent.Network.Audio)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.World)
local Common = require(script.Parent.Common)
type Build = Common.Build
type Ctx = Common.Ctx
local ICE = Common.ICE
local INK = Common.INK
local PAPER = Common.PAPER
local drive = Common.drive
local swingAll = Common.swingAll
local fade = Common.fade
local sparks = Common.sparks
local flash = Common.flash
local setPrompt = Common.setPrompt
local sign = Common.sign
local add = Common.add
local join = Common.join
local hinge = Common.hinge
local light = Common.light

local Box = {}

local KRAFT = Color3.fromRGB(184, 136, 86)
local KRAFT_DARK = Color3.fromRGB(143, 100, 60)
local KRAFT_LIGHT = Color3.fromRGB(214, 168, 112)
local TAPE = Color3.fromRGB(246, 198, 72)

-- ============ Картонная коробка ============

local BOX_WIDTH = 4.6
local BOX_HEIGHT = 2.7
local BOX_FLOOR = 0.14
local BOX_PROMPTS = {
	Texts.boxOpenLeft,
	Texts.boxOpenRight,
	Texts.boxUnfold,
}

local function buildBox(b: Build): ()
	local w, h, f = BOX_WIDTH, BOX_HEIGHT, BOX_FLOOR
	local body = add(b, "Корпус", CFrame.new(0, f / 2, 0), Vector3.new(w, f, w), KRAFT_DARK, Enum.Material.Fabric)
	b.Layout.Named.Body = body
	light(body, Color3.fromRGB(255, 214, 150), 14)

	local function wall(
		x: number,
		z: number,
		sx: number,
		sz: number,
		pivot: Vector3,
		axis: Vector3,
		angle: number
	): Part
		local piece =
			add(b, "Стенка", CFrame.new(x, f + h / 2, z), Vector3.new(sx, h, sz), KRAFT, Enum.Material.Fabric)
		hinge(b, piece, pivot, axis, angle)
		join(b, "Walls", piece)
		b.Kit.Click(piece, b.Use)
		return piece
	end
	local edge = w / 2 - 0.06
	wall(edge, 0, 0.12, w, Vector3.new(w / 2, f, 0), Vector3.zAxis, -math.pi / 2)
	wall(-edge, 0, 0.12, w, Vector3.new(-w / 2, f, 0), Vector3.zAxis, math.pi / 2)
	wall(0, edge, w - 0.24, 0.12, Vector3.new(0, f, w / 2), Vector3.xAxis, math.pi / 2)
	local front = wall(0, -edge, w - 0.24, 0.12, Vector3.new(0, f, -w / 2), Vector3.xAxis, -math.pi / 2)

	-- Этикетка на передней стенке разворачивается вместе с ней.
	local label = add(
		b,
		"Этикетка",
		CFrame.new(-0.9, f + 1.3, -(w / 2 + 0.02)),
		Vector3.new(1.7, 1, 0.04),
		PAPER,
		Enum.Material.SmoothPlastic
	)
	hinge(b, label, Vector3.new(0, f, -w / 2), Vector3.xAxis, -math.pi / 2)
	join(b, "Walls", label)
	sign(label, Enum.NormalId.Front, Texts.boxLabel, INK)
	b.Layout.Named.Front = front

	for _, side in { -1, 1 } do
		local flap = add(
			b,
			"Створка",
			CFrame.new(side * w / 4, f + h + 0.05, 0),
			Vector3.new(w / 2, 0.1, w),
			KRAFT_LIGHT,
			Enum.Material.Fabric
		)
		hinge(b, flap, Vector3.new(side * w / 2, f + h, 0), Vector3.zAxis, -side * 2)
		b.Layout.Named[if side == -1 then "FlapLeft" else "FlapRight"] = flap
		join(b, "Flaps", flap)
		b.Kit.Click(flap, b.Use)
	end

	local tapeColor = if b.Variant then ICE else TAPE
	local strip = add(
		b,
		"Лента",
		CFrame.new(0, f + h + 0.12, 0),
		Vector3.new(0.7, 0.05, w + 0.1),
		tapeColor,
		Enum.Material.SmoothPlastic
	)
	b.Layout.Named.Tape = strip
	join(b, "Tape", strip)
	for _, side in { -1, 1 } do
		local piece = add(
			b,
			"Лента",
			CFrame.new(0, f + h - 0.45, side * (w / 2 + 0.03)),
			Vector3.new(0.7, 0.9, 0.05),
			tapeColor,
			Enum.Material.SmoothPlastic
		)
		join(b, "Tape", piece)
	end
	b.Kit.Prompt(body, Texts.boxTape, b.Model.Name, b.Use, "open", nil, 10)
end

local function boxStep(ctx: Ctx, step: number, instant: boolean): ()
	local layout = ctx.Layout
	local top = ctx.Base * CFrame.new(0, BOX_FLOOR + BOX_HEIGHT + 0.2, 0)
	if step == 1 then
		local strip = layout.Named.Tape
		local rest = layout.Rest[strip]
		local ends = layout.Groups.Tape
		if instant then
			fade(ends, 0)
		else
			fade(ends, 0.12)
			drive(ctx.Model, 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(alpha)
				strip.CFrame = ctx.Base
					* CFrame.new(rest.Position + Vector3.new(0.6 * alpha, 3 * alpha, -4 * alpha))
					* CFrame.Angles(2.4 * alpha, 0.3 * alpha, 0.9 * alpha)
				strip.Transparency = math.clamp((alpha - 0.55) / 0.45, 0, 1)
			end)
			sparks(ctx.Model, top, 10, TAPE, 14)
			Audio.at(ctx.Model, "tape")
		end
	elseif step == 2 or step == 3 then
		local flap = layout.Named[if step == 2 then "FlapLeft" else "FlapRight"]
		swingAll(ctx, { flap }, if instant then 0 else 0.5, Enum.EasingStyle.Sine)
		if not instant then
			Audio.at(ctx.Model, "flap")
			sparks(
				ctx.Model,
				ctx.Base * CFrame.new(if step == 2 then -BOX_WIDTH / 2 else BOX_WIDTH / 2, BOX_FLOOR + BOX_HEIGHT, 0),
				8,
				KRAFT_LIGHT,
				12
			)
		end
	else
		fade(layout.Groups.Flaps, if instant then 0 else 0.3)
		swingAll(ctx, layout.Groups.Walls, if instant then 0 else 0.7, Enum.EasingStyle.Sine)
		if not instant then
			local center = ctx.Base * CFrame.new(0, 1.6, 0)
			Audio.at(ctx.Model, "confetti")
			task.delay(0.45, function()
				if ctx.Model.Parent then
					Audio.at(ctx.Model, "thud")
				end
			end)
			sparks(ctx.Model, center, 26, TAPE, 26, 14)
			sparks(ctx.Model, center, 20, PAPER, 22, 14)
			sparks(ctx.Model, center, 20, ICE, 20, 14)
			local glow = layout.Named.Body:FindFirstChildWhichIsA("PointLight")
			if glow then
				flash(glow, 3, 0)
			end
		end
	end
	if step <= #BOX_PROMPTS then
		setPrompt(layout.Named.Body, BOX_PROMPTS[step])
	end
end

Box.buildBox = buildBox
Box.boxStep = boxStep

return Box
