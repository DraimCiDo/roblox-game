--!strict
-- Client side of the mopping job: arms holding the mop, wet traces behind it, spinning markers and the
-- progress bar of the spot being cleaned. Visual only, the server counts the cleaning.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Network.Remotes)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.UI)
local Notices = require(ReplicatedStorage.Shared.Config.Texts.Notices)
local Style = require(script.Parent.Parent.UI.Style)

local MopController = {}

local TRACE_STEP = 0.9
local TRACE_SECONDS = 7
local MAX_TRACES = 90
local WATER = Color3.fromRGB(150, 200, 255)

-- Arm angles holding the handle in front of the body.
local R15_POSE: { [string]: CFrame } = {
	RightShoulder = CFrame.Angles(math.rad(48), 0, math.rad(-14)),
	LeftShoulder = CFrame.Angles(math.rad(62), 0, math.rad(34)),
	RightElbow = CFrame.Angles(math.rad(22), 0, 0),
	LeftElbow = CFrame.Angles(math.rad(26), 0, 0),
}
local R6_POSE: { [string]: CFrame } = {
	["Right Shoulder"] = CFrame.Angles(0, math.rad(-18), math.rad(50)),
	["Left Shoulder"] = CFrame.Angles(0, math.rad(34), math.rad(-64)),
}

local traces: { BasePart } = {}
local lastTrace: { [Model]: Vector3 } = {}
local bar: Frame
local fill: Frame

local function pose(character: Model): ()
	for _, joint in character:GetDescendants() do
		-- Newer avatars use AnimationConstraint joints instead of Motor6D; both have Transform.
		if joint:IsA("Motor6D") or joint.ClassName == "AnimationConstraint" then
			local angle = R15_POSE[joint.Name] or R6_POSE[joint.Name]
			if angle then
				(joint :: any).Transform = angle
			end
		end
	end
end

-- A wet mark under the mop head that dries out.
local function trace(character: Model): ()
	local mop = character:FindFirstChild("Швабра в руках")
	local head = mop and mop:FindFirstChild("Насадка")
	if not head or not head:IsA("BasePart") then
		return
	end
	local floor = head.Position.Y - 0.4
	local at = Vector3.new(head.Position.X, floor, head.Position.Z)
	local previous = lastTrace[character]
	if previous and (at - previous).Magnitude < TRACE_STEP then
		return
	end
	lastTrace[character] = at
	-- Not after a teleport or a respawn: only a continuous movement leaves a trace.
	if not previous or (at - previous).Magnitude > TRACE_STEP * 5 then
		return
	end
	local mark = Instance.new("Part")
	mark.Name = "Мокрый след"
	mark.Size = Vector3.new(1.9, 0.02, (at - previous).Magnitude)
	-- Slightly different heights keep crossing marks from flickering.
	local lift = Vector3.yAxis * (0.025 + math.random() * 0.012)
	mark.CFrame = CFrame.lookAt((at + previous) / 2 + lift, at + lift)
	mark.Color = WATER
	mark.Material = Enum.Material.SmoothPlastic
	mark.Transparency = 0.72
	mark.Reflectance = 0.2
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.CastShadow = false
	mark.Parent = Workspace
	TweenService:Create(mark, TweenInfo.new(TRACE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
		Reflectance = 0,
	}):Play()
	table.insert(traces, mark)
	if #traces > MAX_TRACES then
		(table.remove(traces, 1) :: BasePart):Destroy()
	end
	task.delay(TRACE_SECONDS, function()
		local index = table.find(traces, mark)
		if index then
			table.remove(traces, index)
			mark:Destroy()
		end
	end)
end

local function buildBar(): ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MopProgress"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11
	bar = Style.frame(gui, Style.Ink, 14)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	-- Above the tutorial panel at the bottom and below the balance on low screens.
	bar.Position = UDim2.fromScale(0.5, 0.7)
	bar.Size = UDim2.fromOffset(240, 52)
	bar.Visible = false
	Style.outline(bar, Style.Edge, 3)
	local caption = Style.label(bar, Texts.mopProgress, 16, Style.Text, Style.Display)
	caption.Position = UDim2.fromOffset(0, 4)
	caption.Size = UDim2.new(1, 0, 0, 20)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	local track = Style.frame(bar, Style.Track, 8)
	track.Position = UDim2.fromOffset(12, 28)
	track.Size = UDim2.new(1, -24, 0, 14)
	fill = Style.frame(track, Style.Signal, 8)
	fill.Size = UDim2.fromScale(0, 1)
	-- The same shrinking on low screens as the HUD layer.
	local scale = Instance.new("UIScale")
	local camera = Workspace.CurrentCamera
	if camera then
		scale.Scale = math.clamp(camera.ViewportSize.Y / 760, 0.68, 1)
	end
	scale.Parent = bar
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function progress(share: number?): ()
	if not share then
		bar.Visible = false
		fill.Size = UDim2.fromScale(0, 1)
		return
	end
	bar.Visible = true
	Style.tween(fill, { Size = UDim2.fromScale(math.clamp(share, 0, 1), 1) }, 0.1)
end

function MopController:Start(): ()
	buildBar()
	Remotes.event(Remotes.Events.Interface).OnClientEvent:Connect(function(mode, value)
		if mode == "mop" then
			progress(value)
		end
	end)

	-- The stand offers to put the mop back while this player holds it.
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt.Name == "MopStation" then
			local character = Players.LocalPlayer.Character
			local holding = character and character:GetAttribute("Mopping")
			prompt.ActionText = if holding then Notices.mopPut else Notices.mopTake
		end
	end)

	-- After the animations of the frame, so that the arms keep the mop pose while walking.
	RunService.PreSimulation:Connect(function()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character and character:GetAttribute("Mopping") then
				pose(character)
				trace(character)
			end
		end
		for character in lastTrace do
			if not character.Parent or not character:GetAttribute("Mopping") then
				lastTrace[character] = nil
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, marker in CollectionService:GetTagged("MopMarker") do
			local gem = marker:FindFirstChild("Ромб")
			if gem and gem:IsA("BasePart") then
				local base = gem:GetAttribute("Base")
				if typeof(base) ~= "CFrame" then
					base = gem.CFrame
					gem:SetAttribute("Base", base)
				end
				local lift = Vector3.yAxis * math.sin(now * 3) * 0.35
				gem.CFrame = CFrame.Angles(0, now * 1.8, 0) * (base :: CFrame).Rotation
					+ (base :: CFrame).Position
					+ lift
			end
		end
	end)
end

return MopController
