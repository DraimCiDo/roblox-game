--!strict
-- Cartoon UI kit: thick dark outlines, rounded corners, bright buttons and bouncy presses.
-- Colors, fonts and sizes come from Config/UiTheme.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Config.UiTheme)
local Sfx = require(script.Parent.Parent.Audio.Sfx)

export type ButtonTone = "primary" | "neutral" | "reward" | "danger"

local Style = {}

Style.Ink = Theme.Colors.Ink
Style.Panel = Theme.Colors.Panel
Style.Card = Theme.Colors.Card
Style.Track = Theme.Colors.Track
Style.Edge = Theme.Colors.Edge
Style.Text = Theme.Colors.Text
Style.Muted = Theme.Colors.Muted
Style.Cyan = Theme.Colors.Blue
Style.Amber = Theme.Colors.Yellow
Style.Signal = Theme.Colors.Green
Style.Warning = Theme.Colors.Red
Style.Violet = Theme.Colors.Purple

Style.Display = Theme.Fonts.Display
Style.Body = Theme.Fonts.Body
Style.Bold = Theme.Fonts.Bold
Style.Mono = Theme.Fonts.Numbers

Style.TouchSize = Theme.TouchSize

local OUTLINE = "Outline"
local TEXT_OUTLINE = "TextOutline"

local TONES: { [ButtonTone]: Color3 } = {
	primary = Theme.Colors.Green,
	reward = Theme.Colors.Orange,
	danger = Theme.Colors.Red,
	neutral = Theme.Colors.Blue,
}

function Style.tween(object: Instance, goal: { [string]: any }, duration: number?, easing: Enum.EasingStyle?): Tween
	local info = TweenInfo.new(duration or 0.14, easing or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(object, info, goal)
	tween:Play()
	return tween
end

-- size is a hint: small chips, cards or large windows.
function Style.round(parent: GuiObject, size: number): ()
	local corner = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	local radius = if size <= 6
		then Theme.Radius.Small
		elseif size <= 14 then Theme.Radius.Medium
		else Theme.Radius.Large
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function Style.outline(parent: GuiObject, color: Color3?, thickness: number?): UIStroke
	local line = Instance.new("UIStroke")
	line.Name = OUTLINE
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Color = color or Style.Edge
	line.Thickness = if (thickness or 2) >= 3 then Theme.Stroke.Thick else Theme.Stroke.Thin
	line.Parent = parent
	return line
end

-- Candy look of buttons and bars: a lighter face and a darker bottom lip.
function Style.gloss(parent: GuiObject): ()
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.72, Color3.fromRGB(232, 232, 238)),
		ColorSequenceKeypoint.new(0.74, Color3.fromRGB(190, 190, 205)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 205)),
	})
	gradient.Rotation = 90
	gradient.Parent = parent
end

-- Gentle top-to-bottom shading of panels and cards.
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

-- Dark outline around letters, for headings, numbers and button captions.
function Style.textStroke(label: GuiObject, thickness: number?, color: Color3?): UIStroke
	local line = Instance.new("UIStroke")
	line.Name = TEXT_OUTLINE
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	line.LineJoinMode = Enum.LineJoinMode.Round
	line.Color = color or Style.Ink
	line.Thickness = if (thickness or 2) >= 3 then 2.5 else 1.8
	line.Parent = label
	return line
end

function Style.setButton(control: TextButton, enabled: boolean, tone: ButtonTone): ()
	control.Interactable = enabled
	control.Selectable = enabled
	control.AutoButtonColor = false
	control:SetAttribute("Tone", tone)
	local letters = control:FindFirstChild(TEXT_OUTLINE) :: UIStroke?
	control.BackgroundColor3 = if enabled then TONES[tone] or TONES.primary else Style.Track
	control.TextColor3 = if enabled then Style.Text else Style.Muted
	if letters then
		letters.Enabled = enabled
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
	local frame = Style.outline(control, Style.Edge, 3)
	Style.textStroke(control, 2)
	Style.setButton(control, enabled ~= false, tone or "primary")
	Style.gloss(control)

	local scale = Instance.new("UIScale")
	scale.Parent = control
	local function highlight(active: boolean): ()
		frame.Color = if active then Style.Text else Style.Edge
	end
	control.MouseEnter:Connect(function()
		if control.Interactable then
			Style.tween(scale, { Scale = 1.05 }, 0.12, Enum.EasingStyle.Back)
			Sfx.play("hover")
		end
	end)
	control.MouseLeave:Connect(function()
		Style.tween(scale, { Scale = 1 }, 0.1)
	end)
	control.SelectionGained:Connect(function()
		highlight(true)
	end)
	control.SelectionLost:Connect(function()
		highlight(false)
	end)
	control.MouseButton1Down:Connect(function()
		if control.Interactable then
			Style.tween(scale, { Scale = 0.92 }, 0.06)
		end
	end)
	control.MouseButton1Up:Connect(function()
		Style.tween(scale, { Scale = 1 }, 0.18, Enum.EasingStyle.Back)
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

-- Progress bar: dark groove and a glossy fill.
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
