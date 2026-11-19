--!strict
-- Модели контейнеров и анимации их открытия. Логика открытия (прогресс, проверки) остаётся в SimulatorService.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Audio = require(script.Parent.Audio)
local Types = require(ReplicatedStorage.Shared.Types)

type Use = (Player, string, string?) -> ()
type Axis = "x" | "y" | "z"
type Hinge = { Pivot: Vector3, Axis: Vector3, Angle: number }

export type Kit = {
	Part: (Instance, string, CFrame, Vector3, Color3, Enum.Material?) -> Part,
	Prompt: (BasePart, string, string, Use, string, string?, number?) -> ProximityPrompt,
	Click: (Part, Use) -> (),
}

type Layout = {
	Rest: { [Part]: CFrame },
	Hinges: { [Part]: Hinge },
	Named: { [string]: Part },
	Groups: { [string]: { Part } },
	Center: Vector3,
}

type Build = { Kit: Kit, Model: Model, Layout: Layout, Use: Use, Variant: boolean }
type Ctx = { Model: Model, Layout: Layout, Base: CFrame }

local STEEL = Color3.fromRGB(45, 56, 68)
local ICE = Color3.fromRGB(91, 232, 222)
local AMBER = Color3.fromRGB(255, 181, 86)
local INK = Color3.fromRGB(11, 20, 29)
local PAPER = Color3.fromRGB(240, 238, 228)
local KRAFT = Color3.fromRGB(184, 136, 86)
local KRAFT_DARK = Color3.fromRGB(143, 100, 60)
local KRAFT_LIGHT = Color3.fromRGB(214, 168, 112)
local TAPE = Color3.fromRGB(246, 198, 72)
local WOOD = { Color3.fromRGB(158, 110, 68), Color3.fromRGB(144, 98, 60), Color3.fromRGB(170, 122, 78) }
local WOOD_DARK = Color3.fromRGB(96, 66, 44)
local IRON = Color3.fromRGB(122, 132, 146)
local SAFE_BODY = Color3.fromRGB(82, 96, 112)
local SAFE_DOOR = Color3.fromRGB(108, 124, 142)
local BRASS = Color3.fromRGB(232, 184, 74)
local RED = Color3.fromRGB(255, 70, 80)
local GREEN = Color3.fromRGB(80, 235, 130)
local OBSIDIAN = Color3.fromRGB(34, 26, 58)
local VIOLET = Color3.fromRGB(146, 87, 208)
local VIOLET_HOT = Color3.fromRGB(228, 196, 255)

local rng = Random.new()
local Layouts: { [Model]: Layout } = setmetatable({}, { __mode = "k" }) :: any

local Containers = {}

-- ============ Общие помощники ============

local function rand(low: number, high: number): number
	return rng:NextNumber(low, high)
end

local function swung(rest: CFrame, pivot: Vector3, axis: Vector3, angle: number): CFrame
	return CFrame.new(pivot) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-pivot) * rest
end

-- Плавно прогоняет step(alpha) от 0 до 1; при duration <= 0 сразу ставит конечное состояние.
local function drive(
	model: Model,
	duration: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection?,
	step: (number) -> (),
	done: (() -> ())?
): ()
	if duration <= 0 then
		step(1)
		if done then
			done()
		end
		return
	end
	local value = Instance.new("NumberValue")
	value.Parent = model
	local connection = value.Changed:Connect(function(alpha: number)
		if not model:GetAttribute("Releasing") then
			step(alpha)
		end
	end)
	local tween =
		TweenService:Create(value, TweenInfo.new(duration, style, direction or Enum.EasingDirection.Out), { Value = 1 })
	tween.Completed:Once(function(state: Enum.PlaybackState)
		connection:Disconnect()
		value:Destroy()
		if done and state == Enum.PlaybackState.Completed and not model:GetAttribute("Releasing") then
			done()
		end
	end)
	model.Destroying:Once(function()
		connection:Disconnect()
		tween:Cancel()
	end)
	tween:Play()
end

local function pose(ctx: Ctx, piece: Part, fraction: number): ()
	local hinge = ctx.Layout.Hinges[piece]
	piece.CFrame = ctx.Base * swung(ctx.Layout.Rest[piece], hinge.Pivot, hinge.Axis, hinge.Angle * fraction)
end

local function swingAll(
	ctx: Ctx,
	parts: { Part },
	duration: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection?,
	done: (() -> ())?
): ()
	drive(ctx.Model, duration, style, direction, function(alpha)
		for _, piece in parts do
			pose(ctx, piece, alpha)
		end
	end, done)
end

local function fade(parts: { Part }, duration: number): ()
	for _, piece in parts do
		piece.CanCollide = false
		if duration <= 0 then
			piece.Transparency = 1
		else
			TweenService:Create(piece, TweenInfo.new(duration), { Transparency = 1 }):Play()
		end
	end
end

-- Искры и конфетти: короткий всплеск частиц без внешних текстур.
local function sparks(model: Model, at: CFrame, count: number, color: Color3, speed: number, gravity: number?): ()
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = at
	anchor.Parent = model
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -(gravity or 22), 0)
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.5
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(anchor, 2)
end

-- Осколки и обломки, которые разлетаются по физике и быстро исчезают.
local function shards(model: Model, source: Part, count: number, power: number): ()
	for _ = 1, count do
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(rand(0.2, 0.6), rand(0.1, 0.4), rand(0.2, 0.6))
		shard.Color = source.Color
		shard.Material = source.Material
		local offset = Vector3.new(
			(rng:NextNumber() - 0.5) * source.Size.X,
			(rng:NextNumber() - 0.5) * source.Size.Y,
			(rng:NextNumber() - 0.5) * source.Size.Z
		)
		shard.CFrame = source.CFrame * CFrame.new(offset) * CFrame.Angles(rand(0, 6), rand(0, 6), rand(0, 6))
		shard.CanQuery = false
		shard.CanTouch = false
		shard.Parent = model
		shard.AssemblyLinearVelocity =
			Vector3.new((rng:NextNumber() - 0.5) * power, power * rand(0.5, 1.2), (rng:NextNumber() - 0.5) * power)
		shard.AssemblyAngularVelocity = Vector3.new(rand(-12, 12), rand(-12, 12), rand(-12, 12))
		Debris:AddItem(shard, 1.8)
	end
end

-- Отлетающая копия детали (скоба, доска, крышка): оригинал остаётся на месте и скрывается.
local function launch(model: Model, source: Part, velocity: Vector3): ()
	local piece = Instance.new("Part")
	piece.Size = source.Size
	piece.Color = source.Color
	piece.Material = source.Material
	piece.CFrame = source.CFrame
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CanCollide = false
	piece.Parent = model
	piece.AssemblyLinearVelocity = velocity
	piece.AssemblyAngularVelocity = Vector3.new(rand(-8, 8), rand(-8, 8), rand(-8, 8))
	Debris:AddItem(piece, 1.5)
end

local function flash(light: PointLight, peak: number, rest: number): ()
	TweenService:Create(light, TweenInfo.new(0.12), { Brightness = peak }):Play()
	task.delay(0.14, function()
		if light.Parent then
			TweenService:Create(light, TweenInfo.new(0.5), { Brightness = rest }):Play()
		end
	end)
end

local function setPrompt(owner: Part?, text: string): ()
	local action = if owner then owner:FindFirstChildWhichIsA("ProximityPrompt") else nil
	if action then
		action.ActionText = text
	end
end

local function sign(piece: Part, face: Enum.NormalId, text: string, color: Color3): ()
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = piece
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(1, 1)
	caption.BackgroundTransparency = 1
	caption.Text = text
	caption.TextColor3 = color
	caption.TextScaled = true
	caption.Font = Enum.Font.GothamBlack
	caption.Parent = gui
end

local function bits(mask: number): number
	local count = 0
	for index = 0, 7 do
		if bit32.btest(mask, bit32.lshift(1, index)) then
			count += 1
		end
	end
	return count
end

-- ============ Конструктор моделей ============

local function add(b: Build, name: string, frame: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	local piece = b.Kit.Part(b.Model, name, frame, size, color, material)
	b.Layout.Rest[piece] = frame
	return piece
end

local function addCylinder(
	b: Build,
	name: string,
	position: Vector3,
	axis: Axis,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	local turn = if axis == "y"
		then CFrame.Angles(0, 0, math.pi / 2)
		elseif axis == "z" then CFrame.Angles(0, math.pi / 2, 0)
		else CFrame.identity
	local piece = add(b, name, CFrame.new(position) * turn, Vector3.new(length, diameter, diameter), color, material)
	piece.Shape = Enum.PartType.Cylinder
	return piece
end

local function join(b: Build, group: string, piece: Part): ()
	local list = b.Layout.Groups[group]
	if not list then
		list = {}
		b.Layout.Groups[group] = list
	end
	table.insert(list, piece)
end

local function hinge(b: Build, piece: Part, pivot: Vector3, axis: Vector3, angle: number): ()
	b.Layout.Hinges[piece] = { Pivot = pivot, Axis = axis, Angle = angle }
end

local function light(owner: Part, color: Color3, range: number): PointLight
	local result = Instance.new("PointLight")
	result.Color = color
	result.Range = range
	result.Brightness = 0
	result.Parent = owner
	return result
end

-- ============ Картонная коробка ============

local BOX_WIDTH = 4.6
local BOX_HEIGHT = 2.7
local BOX_FLOOR = 0.14
local BOX_PROMPTS = {
	"Открыть левую створку",
	"Открыть правую створку",
	"Раскрыть коробку",
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
	sign(label, Enum.NormalId.Front, "ХРУПКО\n↑ ВЕРХ", INK)
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
	b.Kit.Prompt(body, "Сорвать ленту", b.Model.Name, b.Use, "open", nil, 10)
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
		swingAll(ctx, { flap }, if instant then 0 else 0.38, Enum.EasingStyle.Back)
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
		swingAll(ctx, layout.Groups.Walls, if instant then 0 else 0.55, Enum.EasingStyle.Quad)
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
		local interaction =
			b.Kit.Prompt(band, "Сломать скобу", b.Model.Name, b.Use, "open", tostring(index), 7)
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
	swingAll(ctx, layout.Groups.Walls, if instant then 0 else 0.5, Enum.EasingStyle.Quad)
end

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
	b.Kit.Prompt(dial, "Вращать ручку", b.Model.Name, b.Use, "open", nil, 9)
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
		swingAll(ctx, layout.Groups.Door, if instant then 0 else 0.8, Enum.EasingStyle.Quad)
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
		b.Kit.Prompt(
			lock,
			"Разблокировать",
			b.Model.Name,
			b.Use,
			"open",
			tostring(if side == -1 then 1 else 2),
			nil
		)
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
	b.Kit.Prompt(handle, "Открыть створки", b.Model.Name, b.Use, "open", "doors", nil)
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
		swingAll(ctx, doors, if instant then 0 else 0.95, Enum.EasingStyle.Quad)
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

-- ============ Секретный контейнер ============

local SECRET_WIDTH = 6
local SECRET_HEIGHT = 4.2
local SECRET_FLOOR = 0.14
local SECRET_PROMPTS = {
	"Зарядить ядро",
	"Усилить свечение",
	"Ещё сильнее",
	"Почти готово!",
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
	swingAll(ctx, layout.Groups.Walls, 0.45, Enum.EasingStyle.Quad)
	fade(layout.Groups.Shell, 0.5)
end

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
