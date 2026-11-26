--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local Style = require(script.Parent.Style)

-- Подсказка обучения: баннер сверху и подсветка цели в мире (контур, стрелка над целью, луч от персонажа).
local Guide = {}

local localPlayer = Players.LocalPlayer
local banner: Frame
local body: TextLabel
local bannerScale: UIScale
local pulse: (string?) -> ()
local current: Instance?
local highlight: Highlight?
local marker: BillboardGui?
local beam: Beam?
local points: { Attachment } = {}

local function adorneeOf(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	elseif target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function clearWorld(): ()
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if marker then
		marker:Destroy()
		marker = nil
	end
	if beam then
		beam:Destroy()
		beam = nil
	end
	for _, point in points do
		point:Destroy()
	end
	table.clear(points)
end

local function bindBeam(): ()
	if beam then
		beam:Destroy()
		beam = nil
	end
	for _, point in points do
		point:Destroy()
	end
	table.clear(points)
	local target = current
	local part = if target then adorneeOf(target) else nil
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not part or not root or not root:IsA("BasePart") then
		return
	end
	local from = Instance.new("Attachment")
	from.Parent = root
	local to = Instance.new("Attachment")
	to.Parent = part
	points = { from, to }
	local line = Instance.new("Beam")
	line.Attachment0 = from
	line.Attachment1 = to
	line.Width0 = 0.35
	line.Width1 = 0.35
	line.Color = ColorSequence.new(Style.Signal)
	line.Transparency = NumberSequence.new(0.35)
	line.LightEmission = 1
	line.FaceCamera = true
	line.Parent = Workspace
	beam = line
end

local function mark(target: Instance): ()
	local part = adorneeOf(target)
	if not part then
		return
	end
	local glow = Instance.new("Highlight")
	glow.Adornee = target
	glow.FillColor = Style.Signal
	glow.FillTransparency = 0.72
	glow.OutlineColor = Color3.new(1, 1, 1)
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Parent = Workspace
	highlight = glow

	local arrow = Instance.new("BillboardGui")
	arrow.Adornee = part
	arrow.AlwaysOnTop = true
	arrow.Size = UDim2.fromOffset(70, 70)
	arrow.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 2.5, 0)
	arrow.Parent = localPlayer:WaitForChild("PlayerGui")
	local icon = Components.text(arrow, "▼", 56, Style.Signal, true)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.Size = UDim2.fromScale(1, 1)
	Style.textStroke(icon, 3)
	TweenService:Create(icon, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.fromOffset(0, 10),
	}):Play()
	marker = arrow
end

function Guide.build(gui: GuiBase2d, onSkip: () -> (), onPulse: (string?) -> ()): ()
	pulse = onPulse
	banner = Style.frame(gui, Style.Ink, 16)
	banner.Name = "Обучение"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 82)
	banner.AutomaticSize = Enum.AutomaticSize.Y
	banner.Size = UDim2.new(1, -24, 0, 0)
	banner.Visible = false
	Style.outline(banner, Style.Cyan, 4)
	Style.gloss(banner)
	local bounds = Instance.new("UISizeConstraint")
	bounds.MaxSize = Vector2.new(430, math.huge)
	bounds.Parent = banner
	bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = banner
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = banner

	local header = Style.frame(banner)
	header.LayoutOrder = 1
	header.Size = UDim2.new(1, 0, 0, 28)
	local title = Components.text(header, "ОБУЧЕНИЕ", 15, Style.Cyan, true)
	title.Size = UDim2.new(0.6, 0, 1, 0)
	Style.textStroke(title, 2)
	local skip = Style.button(header, "Пропустить", onSkip, true, "neutral")
	skip.TextSize = 13
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.Position = UDim2.new(1, 0, 0.5, 0)
	skip.Size = UDim2.fromOffset(118, 28)

	body = Components.text(banner, "", 17, Style.Text)
	body.FontFace = Style.Bold
	body.LayoutOrder = 2
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Size = UDim2.new(1, 0, 0, 0)

	localPlayer.CharacterAdded:Connect(function()
		task.defer(bindBeam)
	end)
end

function Guide.show(text: string, target: Instance?, pulseKey: string?): ()
	if banner.Visible and body.Text ~= text or not banner.Visible then
		Sfx.play("notice")
	end
	body.Text = text
	banner.Visible = true
	bannerScale.Scale = 0.92
	Style.tween(bannerScale, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
	clearWorld()
	current = target
	if target and target.Parent then
		mark(target)
		bindBeam()
	end
	pulse(pulseKey)
end

function Guide.hide(): ()
	banner.Visible = false
	current = nil
	clearWorld()
	pulse(nil)
end

return Guide
