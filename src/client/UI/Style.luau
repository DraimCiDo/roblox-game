--!strict
-- Дизайн-система интерфейса «Лаборатория CORPA»: графит и сталь, неоновые циан и янтарь,
-- тонкие техничные рамки, малые скругления и угловые маркеры, как на экранах оборудования.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Sfx = require(script.Parent.Parent.Audio.Sfx)

export type ButtonTone = "primary" | "neutral" | "reward" | "danger"

local Style = {}

-- Поверхности: от самой тёмной (затемнение) к самой светлой (карточка).
Style.Ink = Color3.fromRGB(6, 9, 14)
Style.Panel = Color3.fromRGB(14, 19, 27)
Style.Card = Color3.fromRGB(22, 30, 41)
Style.Track = Color3.fromRGB(9, 13, 19)
Style.Neutral = Color3.fromRGB(30, 42, 57)
-- Линии и рамки.
Style.Edge = Color3.fromRGB(48, 68, 88)
-- Текст.
Style.Text = Color3.fromRGB(232, 242, 250)
Style.Muted = Color3.fromRGB(134, 154, 175)
-- Акценты.
Style.Cyan = Color3.fromRGB(72, 222, 255)
Style.Amber = Color3.fromRGB(255, 184, 64)
Style.Signal = Color3.fromRGB(74, 232, 152)
Style.Warning = Color3.fromRGB(255, 86, 106)
Style.Violet = Color3.fromRGB(170, 132, 255)

-- Шрифты общие с надписями в мире (Shared/Config/Theme).
Style.Display = Theme.Fonts.Display
Style.Body = Theme.Fonts.Body
Style.Bold = Theme.Fonts.Bold
Style.Mono = Theme.Fonts.Mono

-- Скругления в этом стиле малые: крупные радиусы старой вёрстки сводятся к 2–6 пикселям.
local MAX_RADIUS = 6

local TONES: { [ButtonTone]: { Fill: Color3, Text: Color3, Line: Color3 } } = {
	primary = { Fill = Style.Cyan, Text = Style.Ink, Line = Color3.fromRGB(170, 242, 255) },
	reward = { Fill = Style.Amber, Text = Style.Ink, Line = Color3.fromRGB(255, 222, 150) },
	-- Опасное действие (закрыть, отменить): тёмная плашка с красным контуром, без сплошной заливки.
	danger = { Fill = Color3.fromRGB(46, 18, 26), Text = Style.Warning, Line = Style.Warning },
	neutral = { Fill = Style.Neutral, Text = Style.Text, Line = Color3.fromRGB(70, 110, 140) },
}

function Style.tween(object: Instance, goal: { [string]: any }, duration: number?, easing: Enum.EasingStyle?): Tween
	local info = TweenInfo.new(duration or 0.14, easing or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(object, info, goal)
	tween:Play()
	return tween
end

function Style.round(parent: GuiObject, radius: number): ()
	local corner = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.clamp(math.floor(radius * 0.3 + 0.5), 2, MAX_RADIUS))
	corner.Parent = parent
end

-- Тонкая рамка: толщины старой вёрстки (3–5) сводятся к 1–2 пикселям.
function Style.outline(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local line = Instance.new("UIStroke")
	line.Name = "Рамка"
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Color = color or Style.Edge
	line.Thickness = math.clamp(math.floor((thickness or 2) * 0.5 + 0.5), 1, 2)
	line.Parent = parent
	return line
end

-- Свечение снизу вверх у кнопок и шкал: металлический отлив.
function Style.gloss(parent: GuiObject): ()
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(226, 232, 238)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(176, 186, 196)),
	})
	gradient.Rotation = 90
	gradient.Parent = parent
end

-- Едва заметный градиент для панелей и карточек: сверху светлее, снизу темнее.
function Style.soft(parent: GuiObject, strength: number?): ()
	local gradient = Instance.new("UIGradient")
	local low = 1 - (strength or 0.18)
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(low, low, low))
	gradient.Rotation = 90
	gradient.Parent = parent
end

function Style.frame(parent: Instance, color: Color3?, radius: number?): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	if color then
		frame.BackgroundColor3 = color
	else
		frame.BackgroundTransparency = 1
	end
	if radius then
		Style.round(frame, radius)
	end
	frame.Parent = parent
	return frame
end

function Style.label(parent: Instance, value: string, size: number, color: Color3?, font: Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextColor3 = color or Style.Text
	label.FontFace = font or Style.Body
	label.TextSize = size
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- Тень у букв: светлый текст отделяется от подсвеченного фона, не превращаясь в «мультяшную» обводку.
function Style.textStroke(label: GuiObject, thickness: number?, color: Color3?): UIStroke
	local line = Instance.new("UIStroke")
	line.Name = "ТекстОбводка"
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	line.Color = color or Style.Ink
	line.Thickness = if (thickness or 2) >= 3 then 1.5 else 1
	line.Transparency = 0.45
	line.Parent = label
	return line
end

-- Угловые маркеры, как на прицеле или экране прибора. size — длина плеча, thickness — толщина линии.
-- Не вешать на кадры с UIListLayout/UIGridLayout: раскладка примет маркеры за элемент списка.
function Style.brackets(parent: GuiObject, color: Color3?, size: number?, thickness: number?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Маркеры"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = parent.ZIndex + 1
	local arm = size or 10
	local width = thickness or 2
	local tint = color or Style.Cyan
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		for _, horizontal in { true, false } do
			local bar = Instance.new("Frame")
			bar.BorderSizePixel = 0
			bar.BackgroundColor3 = tint
			bar.AnchorPoint = corner
			bar.Position = UDim2.fromScale(corner.X, corner.Y)
			bar.Size = if horizontal then UDim2.fromOffset(arm, width) else UDim2.fromOffset(width, arm)
			bar.ZIndex = holder.ZIndex
			bar.Parent = holder
		end
	end
	holder.Parent = parent
	return holder
end

-- Полоса-акцент у края карточки (слева или сверху): знак статуса или категории.
function Style.accent(parent: GuiObject, color: Color3, vertical: boolean?): Frame
	local bar = Instance.new("Frame")
	bar.Name = "Акцент"
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = color
	bar.ZIndex = parent.ZIndex + 1
	if vertical == false then
		bar.Size = UDim2.new(1, 0, 0, 3)
	else
		bar.Size = UDim2.new(0, 3, 1, 0)
	end
	bar.Parent = parent
	return bar
end

function Style.setButton(control: TextButton, enabled: boolean, tone: ButtonTone): ()
	control.Interactable = enabled
	control.Selectable = enabled
	control.AutoButtonColor = false
	control:SetAttribute("Tone", tone)
	local outline = control:FindFirstChild("ТекстОбводка") :: UIStroke?
	local frame = control:FindFirstChild("Рамка") :: UIStroke?
	if not enabled then
		control.BackgroundColor3 = Style.Track
		control.TextColor3 = Style.Muted
		if frame then
			frame.Color = Style.Edge
		end
		if outline then
			outline.Transparency = 1
		end
		return
	end
	local palette = TONES[tone] or TONES.primary
	control.BackgroundColor3 = palette.Fill
	control.TextColor3 = palette.Text
	if frame then
		frame.Color = palette.Line
	end
	if outline then
		-- Тёмный текст на ярком фоне читается без тени.
		outline.Transparency = if tone == "neutral" or tone == "danger" then 0.45 else 1
	end
end

function Style.button(
	parent: Instance,
	caption: string,
	callback: () -> (),
	enabled: boolean?,
	tone: ButtonTone?
): TextButton
	local control = Instance.new("TextButton")
	control.Name = caption
	control.BorderSizePixel = 0
	control.FontFace = Style.Display
	control.TextSize = 18
	control.TextWrapped = true
	control.Text = caption
	Style.round(control, 12)
	local frame = Style.outline(control, Style.Edge, 2)
	Style.textStroke(control, 2)
	Style.setButton(control, enabled ~= false, tone or "primary")
	Style.gloss(control)

	local scale = Instance.new("UIScale")
	scale.Parent = control
	control.MouseEnter:Connect(function()
		if control.Interactable then
			Style.tween(scale, { Scale = 1.03 }, 0.1)
			frame.Thickness = 2
			Sfx.play("hover")
		end
	end)
	control.MouseLeave:Connect(function()
		Style.tween(scale, { Scale = 1 }, 0.1)
		frame.Thickness = 1
	end)
	control.SelectionGained:Connect(function()
		frame.Thickness = 2
	end)
	control.SelectionLost:Connect(function()
		frame.Thickness = 1
	end)
	control.MouseButton1Down:Connect(function()
		if control.Interactable then
			Style.tween(scale, { Scale = 0.96 }, 0.06)
		end
	end)
	control.MouseButton1Up:Connect(function()
		Style.tween(scale, { Scale = 1 }, 0.1)
	end)
	control.Activated:Connect(function()
		if control.Interactable then
			Sfx.play("click")
			callback()
		end
	end)
	control.Parent = parent
	return control
end

-- Шкала: тёмный жёлоб с тонкой рамкой и светящаяся заливка.
function Style.meter(parent: Instance, ratio: number, color: Color3): (Frame, Frame)
	local track = Style.frame(parent, Style.Track, 4)
	Style.outline(track, Style.Edge, 1)
	local fill = Style.frame(track, color, 4)
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	Style.gloss(fill)
	return track, fill
end

function Style.setMeter(fill: Frame, ratio: number): ()
	Style.tween(fill, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) }, 0.25)
end

return Style
