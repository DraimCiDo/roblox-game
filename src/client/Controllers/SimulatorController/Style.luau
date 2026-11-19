--!strict
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)

export type ButtonTone = "primary" | "neutral" | "reward" | "danger"

local Style = {}

-- Палитра «яркий симулятор»: тёмно-фиолетовые панели и насыщенные акценты.
Style.Ink = Color3.fromRGB(24, 20, 64)
Style.Panel = Color3.fromRGB(47, 53, 118)
Style.Card = Color3.fromRGB(65, 74, 150)
Style.Edge = Color3.fromRGB(16, 12, 46)
Style.Track = Color3.fromRGB(32, 35, 88)
Style.Neutral = Color3.fromRGB(78, 128, 244)
Style.Text = Color3.fromRGB(255, 255, 255)
Style.Muted = Color3.fromRGB(188, 196, 242)
Style.Signal = Color3.fromRGB(76, 224, 124)
Style.Amber = Color3.fromRGB(255, 200, 60)
Style.Warning = Color3.fromRGB(255, 100, 122)
Style.Cyan = Color3.fromRGB(74, 200, 255)
Style.Violet = Color3.fromRGB(178, 120, 255)

Style.Display = Enum.Font.FredokaOne
Style.Body = Enum.Font.GothamMedium
Style.Bold = Enum.Font.GothamBold

function Style.tween(object: Instance, goal: { [string]: any }, duration: number?, easing: Enum.EasingStyle?): Tween
	local info = TweenInfo.new(duration or 0.14, easing or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(object, info, goal)
	tween:Play()
	return tween
end

function Style.round(parent: GuiObject, radius: number): ()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function Style.outline(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local line = Instance.new("UIStroke")
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Color = color or Style.Edge
	line.Thickness = thickness or 2
	line.Parent = parent
	return line
end

-- Мягкий блик сверху вниз: придаёт объём кнопкам и полосам.
function Style.gloss(parent: GuiObject): ()
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 204, 228))
	gradient.Rotation = 90
	gradient.Parent = parent
end

-- Едва заметный градиент для карточек и панелей: сверху светлее, снизу темнее.
function Style.soft(parent: GuiObject, strength: number?): ()
	local gradient = Instance.new("UIGradient")
	local low = 1 - (strength or 0.14)
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

function Style.label(parent: Instance, value: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextColor3 = color or Style.Text
	label.Font = font or Style.Body
	label.TextSize = size
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- Контур вокруг самих букв: белый жирный текст с тёмной обводкой читается на любом цвете, как в симуляторах.
function Style.textStroke(label: GuiObject, thickness: number?, color: Color3?): UIStroke
	local line = Instance.new("UIStroke")
	line.Name = "ТекстОбводка"
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	line.Color = color or Style.Edge
	line.Thickness = thickness or 2
	line.Parent = label
	return line
end

function Style.setButton(control: TextButton, enabled: boolean, tone: ButtonTone): ()
	control.Interactable = enabled
	control.Selectable = enabled
	control.AutoButtonColor = false
	local outline = control:FindFirstChild("ТекстОбводка") :: UIStroke?
	if outline then
		outline.Transparency = if enabled then 0 else 0.6
	end
	if not enabled then
		control.BackgroundColor3 = Style.Track
		control.TextColor3 = Style.Muted
	else
		control.TextColor3 = Style.Text
		if tone == "neutral" then
			control.BackgroundColor3 = Style.Neutral
		elseif tone == "danger" then
			control.BackgroundColor3 = Style.Warning
		else
			control.BackgroundColor3 = if tone == "reward" then Style.Amber else Style.Signal
		end
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
	control.Font = Style.Display
	control.TextSize = 18
	control.TextWrapped = true
	control.Text = caption
	Style.round(control, 12)
	Style.outline(control, Style.Edge, 3)
	Style.textStroke(control, 2)
	Style.setButton(control, enabled ~= false, tone or "primary")
	Style.gloss(control)

	local scale = Instance.new("UIScale")
	scale.Parent = control
	control.MouseEnter:Connect(function()
		if control.Interactable then
			Style.tween(scale, { Scale = 1.03 }, 0.1)
			Sfx.play("hover")
		end
	end)
	control.MouseLeave:Connect(function()
		Style.tween(scale, { Scale = 1 }, 0.1)
	end)
	control.MouseButton1Down:Connect(function()
		if control.Interactable then
			Style.tween(scale, { Scale = 0.94 }, 0.06)
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

function Style.meter(parent: Instance, ratio: number, color: Color3): (Frame, Frame)
	local track = Style.frame(parent, Style.Track, 6)
	Style.outline(track, Style.Edge, 1)
	local fill = Style.frame(track, color, 6)
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	Style.gloss(fill)
	return track, fill
end

function Style.setMeter(fill: Frame, ratio: number): ()
	Style.tween(fill, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) }, 0.25)
end

return Style
