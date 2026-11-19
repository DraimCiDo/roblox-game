--!strict
local Style = {}

Style.Ink = Color3.fromRGB(12, 18, 24)
Style.Panel = Color3.fromRGB(21, 30, 39)
Style.Card = Color3.fromRGB(29, 42, 53)
Style.Edge = Color3.fromRGB(53, 70, 83)
Style.Track = Color3.fromRGB(17, 26, 33)
Style.Text = Color3.fromRGB(231, 241, 244)
Style.Muted = Color3.fromRGB(164, 184, 195)
Style.Signal = Color3.fromRGB(113, 225, 211)
Style.Amber = Color3.fromRGB(248, 185, 96)
Style.Warning = Color3.fromRGB(250, 159, 144)

export type ButtonTone = "primary" | "neutral" | "reward"

function Style.round(parent: GuiObject, radius: number): ()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function Style.outline(parent: GuiObject, color: Color3?): ()
	local line = Instance.new("UIStroke")
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Color = color or Style.Edge
	line.Parent = parent
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
	label.Font = font or Enum.Font.Gotham
	label.TextSize = size
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function Style.setButton(control: TextButton, enabled: boolean, tone: ButtonTone): ()
	control.Interactable = enabled
	control.Selectable = enabled
	control.AutoButtonColor = enabled
	if not enabled then
		control.BackgroundColor3 = Style.Track
		control.TextColor3 = Style.Muted
	elseif tone == "neutral" then
		control.BackgroundColor3 = Style.Card
		control.TextColor3 = Style.Text
	else
		control.BackgroundColor3 = if tone == "reward" then Style.Amber else Style.Signal
		control.TextColor3 = Style.Ink
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
	control.Font = Enum.Font.GothamBold
	control.TextSize = 13
	control.TextWrapped = true
	control.Text = caption
	Style.setButton(control, enabled ~= false, tone or "primary")
	Style.round(control, 7)
	if tone == "neutral" then
		Style.outline(control)
	end
	control.Activated:Connect(function()
		if control.Interactable then
			callback()
		end
	end)
	control.Parent = parent
	return control
end

function Style.meter(parent: Instance, ratio: number, color: Color3): (Frame, Frame)
	local track = Style.frame(parent, Style.Track, 4)
	local fill = Style.frame(track, color, 4)
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	return track, fill
end

return Style
