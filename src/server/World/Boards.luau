--!strict
-- Ranking boards in the hall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Texts = require(ReplicatedStorage.Shared.Config.Texts.World)
local Props = require(script.Parent.Props)
local INK = Props.INK
local PAPER = Props.PAPER
local MUTED = Props.MUTED
local part = Props.part

local Boards = {}

export type RankingEntry = { Name: string, Score: number, Opened: number? }
type RankingRow = { Frame: Frame, Name: TextLabel, Score: TextLabel, Opened: TextLabel? }
type RankingFace = { Rows: { RankingRow }, Status: TextLabel }
local boards: { [string]: { RankingFace } } = {}

local function boardLabel(
	parent: Instance,
	value: string,
	x: number,
	y: number,
	width: number,
	height: number,
	size: number,
	bold: boolean
): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(x, y)
	text.Size = UDim2.fromOffset(width, height)
	text.Text = value
	text.TextColor3 = PAPER
	text.TextSize = size
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.FontFace = if bold then Theme.Fonts.Bold else Theme.Fonts.Body
	text.Parent = parent
	return text
end

local function rankingBoard(
	terminal: Part,
	title: string,
	subtitle: string,
	rowCount: number,
	accent: Color3,
	showOpened: boolean?
): { RankingFace }
	local screen = part(
		terminal,
		"Экран рейтинга",
		terminal.CFrame * CFrame.new(0, terminal.Size.Y / 2 + 3.25, 0),
		Vector3.new(8.8, 6.6, 0.42),
		INK
	)
	local faces = {}
	for _, side in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Face = side
		surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surface.CanvasSize = Vector2.new(640, 480)
		surface.LightInfluence = 0
		surface.MaxDistance = 80
		surface.Parent = screen

		local panel = Instance.new("Frame")
		panel.BorderSizePixel = 0
		panel.BackgroundColor3 = INK
		panel.Size = UDim2.fromScale(1, 1)
		panel.Parent = surface

		local stripe = Instance.new("Frame")
		stripe.BorderSizePixel = 0
		stripe.BackgroundColor3 = accent
		stripe.Size = UDim2.new(1, 0, 0, 6)
		stripe.Parent = panel
		boardLabel(panel, title, 24, 15, 592, 43, 36, true)
		boardLabel(panel, subtitle, 24, 59, 592, 26, 19, false).TextColor3 = MUTED
		boardLabel(panel, Texts.rankPlace, 24, 91, 68, 26, 17, true).TextColor3 = accent
		local coinEdge = if showOpened then 490 else 616
		boardLabel(panel, Texts.rankPlayer, 108, 91, 230, 26, 17, true).TextColor3 = accent
		local coinHeading = boardLabel(panel, Texts.rankCoins, 350, 91, coinEdge - 350, 26, 17, true)
		coinHeading.TextColor3 = accent
		coinHeading.TextXAlignment = Enum.TextXAlignment.Right
		if showOpened then
			local opened = boardLabel(panel, Texts.rankOpened, 505, 91, 111, 26, 17, true)
			opened.TextColor3 = accent
			opened.TextXAlignment = Enum.TextXAlignment.Right
		end

		local rows = {}
		local step = if rowCount <= 6 then 58 else 34
		for index = 1, rowCount do
			local row = Instance.new("Frame")
			row.BackgroundColor3 = if index % 2 == 1 then Color3.fromRGB(26, 42, 49) else Color3.fromRGB(19, 33, 41)
			row.BorderSizePixel = 0
			row.Position = UDim2.fromOffset(16, 122 + (index - 1) * step)
			row.Size = UDim2.fromOffset(608, step - 3)
			row.Visible = false
			row.Parent = panel

			local height = step - 3
			local size = if rowCount <= 6 then 27 else 21
			local rank = boardLabel(row, string.format("%02d", index), 8, 0, 64, height, size, true)
			rank.TextColor3 = if index == 1 then accent else MUTED
			local name = boardLabel(row, "", 92, 0, 230, height, size, true)
			local score = boardLabel(row, "", 334, 0, coinEdge - 350, height, size, true)
			score.TextXAlignment = Enum.TextXAlignment.Right
			local opened = if showOpened then boardLabel(row, "", 489, 0, 111, height, size, true) else nil
			if opened then
				opened.TextXAlignment = Enum.TextXAlignment.Right
			end
			table.insert(rows, { Frame = row, Name = name, Score = score, Opened = opened })
		end
		local status = boardLabel(panel, Texts.rankLoading, 24, 154, 592, 96, 26, false)
		status.TextColor3 = MUTED
		status.TextWrapped = true
		status.TextXAlignment = Enum.TextXAlignment.Center
		table.insert(faces, { Rows = rows, Status = status })
	end
	return faces
end

function Boards.Board(key: string, entries: { RankingEntry }, emptyText: string): ()
	for _, face in boards[key] do
		face.Status.Text = emptyText
		face.Status.Visible = #entries == 0
		for index, row in face.Rows do
			local entry = entries[index]
			row.Frame.Visible = entry ~= nil
			if entry then
				row.Name.Text = entry.Name
				local grouped = string.reverse(string.format("%.0f", entry.Score)):gsub("(%d%d%d)", "%1 ")
				row.Score.Text = string.reverse(grouped):gsub("^ ", "")
				if row.Opened then
					row.Opened.Text = tostring(entry.Opened or 0)
				end
			end
		end
	end
end

Boards.boards = boards
Boards.rankingBoard = rankingBoard

return Boards
