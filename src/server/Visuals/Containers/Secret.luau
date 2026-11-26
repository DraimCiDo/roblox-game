--!strict
-- Secret container: model and core charging.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Audio = require(script.Parent.Parent.Parent.Network.Audio)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.World)
local Common = require(script.Parent.Common)
type Build = Common.Build
type Ctx = Common.Ctx
local rng = Common.rng
local swingAll = Common.swingAll
local fade = Common.fade
local sparks = Common.sparks
local shards = Common.shards
local launch = Common.launch
local flash = Common.flash
local setPrompt = Common.setPrompt
local add = Common.add
local addCylinder = Common.addCylinder
local join = Common.join
local hinge = Common.hinge
local light = Common.light

local Secret = {}

local OBSIDIAN = Color3.fromRGB(34, 26, 58)
local VIOLET = Color3.fromRGB(146, 87, 208)
local VIOLET_HOT = Color3.fromRGB(228, 196, 255)

-- ============ Секретный контейнер ============

local SECRET_WIDTH = 6
local SECRET_HEIGHT = 4.2
local SECRET_FLOOR = 0.14
local SECRET_PROMPTS = {
	Texts.secretCharge1,
	Texts.secretCharge2,
	Texts.secretCharge3,
	Texts.secretCharge4,
}

local function buildSecret(b: Build, openParts: { Part }): ()
	local w, h, f = SECRET_WIDTH, SECRET_HEIGHT, SECRET_FLOOR
	local body = add(b, "Корпус", CFrame.new(0, f / 2, 0), Vector3.new(w, f, w), OBSIDIAN, Enum.Material.Slate)
	b.Layout.Named.Body = body
	local function wall(x: number, z: number, sx: number, sz: number, pivot: Vector3, axis: Vector3, angle: number)
		local piece =
			add(b, "Панель", CFrame.new(x, f + h / 2, z), Vector3.new(sx, h, sz), OBSIDIAN, Enum.Material.Slate)
		hinge(b, piece, pivot, axis, angle)
		join(b, "Walls", piece)
		join(b, "Shell", piece)
		b.Kit.Click(piece, b.Use)
	end
	local edge = w / 2 - 0.15
	wall(edge, 0, 0.3, w, Vector3.new(w / 2, f, 0), Vector3.zAxis, -math.pi / 2)
	wall(-edge, 0, 0.3, w, Vector3.new(-w / 2, f, 0), Vector3.zAxis, math.pi / 2)
	wall(0, edge, w - 0.6, 0.3, Vector3.new(0, f, w / 2), Vector3.xAxis, math.pi / 2)
	wall(0, -edge, w - 0.6, 0.3, Vector3.new(0, f, -w / 2), Vector3.xAxis, -math.pi / 2)

	local lid =
		add(b, "Крышка", CFrame.new(0, f + h + 0.15, 0), Vector3.new(w, 0.3, w), OBSIDIAN, Enum.Material.Slate)
	join(b, "Shell", lid)
	b.Layout.Named.Lid = lid
	b.Kit.Click(lid, b.Use)

	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local seam = add(
				b,
				"Шов",
				CFrame.new(x * (w / 2 + 0.02), f + h / 2, z * (w / 2 + 0.02)),
				Vector3.new(0.16, h, 0.16),
				VIOLET,
				Enum.Material.Neon
			)
			join(b, "Seams", seam)
			join(b, "Shell", seam)
		end
	end
	for _, z in { -1, 1 } do
		local band = add(
			b,
			"Шов",
			CFrame.new(0, f + h + 0.32, z * (w / 2)),
			Vector3.new(w + 0.1, 0.12, 0.12),
			VIOLET,
			Enum.Material.Neon
		)
		join(b, "Seams", band)
		join(b, "Shell", band)
	end

	local orb = add(b, "Заряд", CFrame.new(0, f + h + 1.7, 0), Vector3.one * 1.3, VIOLET, Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	orb.CanCollide = false
	table.insert(openParts, orb)
	local glow = light(orb, VIOLET, 14)
	glow.Brightness = 0.5
	b.Layout.Named.Orb = orb
	b.Kit.Click(orb, b.Use)
	for index, tilt in { CFrame.Angles(0.5, 0, 0.2), CFrame.Angles(-0.4, 0, -0.5) } do
		local ring =
			addCylinder(b, "Кольцо", Vector3.zero, "y", 0.08, 2.8 + index * 0.5, VIOLET_HOT, Enum.Material.Neon)
		local frame = CFrame.new(0, f + h + 1.7, 0) * tilt * CFrame.Angles(0, 0, math.pi / 2)
		ring.CFrame = frame
		b.Layout.Rest[ring] = frame
		ring.Transparency = 0.65
		ring.CanCollide = false
		join(b, "Rings", ring)
	end
	b.Kit.Prompt(body, SECRET_PROMPTS[1], b.Model.Name, b.Use, "open", nil, 10)
end

local function secretCharge(ctx: Ctx, step: number, instant: boolean): ()
	local layout = ctx.Layout
	local orb = layout.Named.Orb
	local glow = orb:FindFirstChildWhichIsA("PointLight")
	local mix = step / 5
	local info = TweenInfo.new(if instant then 0 else 0.3)
	if step < 5 then
		local color = VIOLET:Lerp(VIOLET_HOT, mix * 0.7)
		TweenService:Create(orb, info, { Size = Vector3.one * (1.3 + 0.28 * step), Color = color }):Play()
		if glow then
			TweenService:Create(glow, info, { Brightness = 0.5 + 0.9 * step, Range = 14 + 2 * step, Color = color })
				:Play()
		end
		for _, seam in layout.Groups.Seams do
			TweenService:Create(seam, info, { Color = VIOLET:Lerp(VIOLET_HOT, mix * 0.6) }):Play()
		end
		for _, ring in layout.Groups.Rings do
			TweenService:Create(ring, info, { Transparency = 0.65 - 0.11 * step }):Play()
		end
		if not instant then
			sparks(ctx.Model, orb.CFrame, 8 + 4 * step, VIOLET_HOT, 10 + 3 * step, -4)
			Audio.at(orb, "charge", 0.8 + 0.12 * step)
		end
		setPrompt(layout.Named.Body, SECRET_PROMPTS[step + 1] or SECRET_PROMPTS[#SECRET_PROMPTS])
		return
	end
	-- Финал: вспышка ядра, оболочка раскрывается и растворяется.
	for _, ring in layout.Groups.Rings do
		ring.CanCollide = false
		TweenService:Create(ring, info, { Transparency = 1 }):Play()
	end
	if instant then
		orb.Transparency = 1
		fade(layout.Groups.Shell, 0)
		return
	end
	TweenService:Create(orb, TweenInfo.new(0.35), { Size = Vector3.one * 7, Transparency = 1 }):Play()
	if glow then
		flash(glow, 8, 0)
	end
	local center = orb.CFrame
	Audio.at(orb, "boom")
	sparks(ctx.Model, center, 40, VIOLET_HOT, 36, 10)
	sparks(ctx.Model, center, 30, VIOLET, 26, 10)
	launch(ctx.Model, layout.Named.Lid, Vector3.new(0, 30, 0))
	for _, piece in layout.Groups.Walls do
		if rng:NextNumber() < 0.5 then
			shards(ctx.Model, piece, 1, 24)
		end
	end
	swingAll(ctx, layout.Groups.Walls, 0.6, Enum.EasingStyle.Sine)
	fade(layout.Groups.Shell, 0.5)
end

Secret.buildSecret = buildSecret
Secret.secretCharge = secretCharge

return Secret
