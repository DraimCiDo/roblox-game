--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Components = require(script.Parent.Parent.Components)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local Style = require(script.Parent.Parent.Style)
local Types = require(ReplicatedStorage.Shared.Types)

-- Настройки: громкость звуков интерфейса и мира. Значение применяется сразу, а на сервер уходит по отпусканию ползунка.
local Settings = {}

local STEP = 0.05
local connections: { RBXScriptConnection } = {}
local dragging = false

local function disconnect(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	dragging = false
end

function Settings.reset(): ()
	disconnect()
end

function Settings.isDragging(): boolean
	return dragging
end

-- Громкость уходит на сервер целым числом процентов («35»): сервер принимает аргумент до 4 знаков, а шаг 0,05
-- даёт дроби вроде 0.6000000000000001 — такие значения отбрасывались, и громкость откатывалась к 60%.
local function percentText(value: number): string
	return tostring(math.clamp(math.round(value * 100), 0, 100))
end

local function pointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function slider(
	title: string,
	hint: string,
	initial: number,
	color: Color3,
	onChange: (number) -> (),
	onCommit: (number) -> ()
): ()
	local card = Components.card(116)
	local name = Components.text(card, title, 19, Style.Text, true)
	Components.place(name, 14, 8, UDim.new(1, -110), 26)
	name.TextWrapped = false
	local percent = Components.text(card, "", 19, color, true)
	percent.AnchorPoint = Vector2.new(1, 0)
	percent.Position = UDim2.new(1, -14, 0, 8)
	percent.Size = UDim2.fromOffset(90, 26)
	percent.TextXAlignment = Enum.TextXAlignment.Right
	local note = Components.text(card, hint, 12, Style.Muted)
	Components.place(note, 14, 36, UDim.new(1, -28), 32)
	note.TextYAlignment = Enum.TextYAlignment.Top

	local track, fill = Style.meter(card, initial, color)
	Components.place(track, 18, 82, UDim.new(1, -36), 18)
	local knob = Style.frame(track, Style.Text, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(30, 30)
	knob.ZIndex = 3
	Style.outline(knob, Style.Edge, 3)

	local value = initial
	-- Перетаскивание — своё у каждого ползунка (общий флаг двигал оба сразу, а сохранялся только один).
	local active = false
	local function show(): ()
		percent.Text = if value <= 0 then "Выкл." else `{math.round(value * 100)}%`
		fill.Size = UDim2.fromScale(value, 1)
		knob.Position = UDim2.fromScale(value, 0.5)
	end
	show()

	local function setFrom(input: InputObject): ()
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local ratio = math.clamp((input.Position.X - track.AbsolutePosition.X) / width, 0, 1)
		local snapped = math.clamp(math.round(ratio / STEP) * STEP, 0, 1)
		if snapped ~= value then
			value = snapped
			show()
			onChange(value)
		end
	end

	-- Нажатие принимает прозрачная кнопка выше полосы: попасть пальцем по тонкой полосе трудно.
	local hit = Instance.new("TextButton")
	hit.Name = "Ползунок"
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.Size = UDim2.new(1, 20, 0, 52)
	hit.ZIndex = 4
	hit.Parent = track
	table.insert(
		connections,
		hit.InputBegan:Connect(function(input)
			if pointer(input) then
				active = true
				dragging = true
				setFrom(input)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input)
			local moving = input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			if active and moving then
				setFrom(input)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if active and pointer(input) then
				active = false
				dragging = false
				onCommit(value)
			end
		end)
	)
end

function Settings.render(data: Types.View): ()
	disconnect()
	Components.paragraph(
		"Звуки можно сделать тише или отключить совсем. Настройки сохраняются в вашем прогрессе."
	)
	slider(
		"Звуки интерфейса",
		"Клики, уведомления, покупки, награды.",
		data.VolumeUi,
		Style.Cyan,
		function(value)
			Sfx.setVolumes(value, nil)
		end,
		function(value)
			Components.send("setVolume", "ui", percentText(value))
			Sfx.play("click")
		end
	)
	slider(
		"Звуки мира",
		"Открытие контейнеров, шлюзы, доставка, сейф.",
		data.VolumeWorld,
		Style.Amber,
		function(value)
			Sfx.setVolumes(nil, value)
		end,
		function(value)
			Components.send("setVolume", "world", percentText(value))
			Sfx.play("thud")
		end
	)
	Settings.renderEffects(data)
end

-- Отпечаток выбранного и купленных эффектов: по нему экран настроек перерисовывается после выбора или покупки.
function Settings.effectsSignature(data: Types.View): string
	local parts = { data.Effect, tostring(data.Coins) }
	for _, effect in Catalog.DropEffects do
		table.insert(parts, if Catalog.effectAvailable(effect, data.Opened, data.Effects) then "1" else "0")
	end
	return table.concat(parts, "|")
end

function Settings.renderEffects(data: Types.View): ()
	Components.heading("Эффекты выпадения")
	Components.paragraph(
		"Выбранный эффект играет, когда из вашего контейнера вылетает добыча. Новые открываются за монеты и достижения."
	)
	for _, effect in Catalog.DropEffects do
		local available = Catalog.effectAvailable(effect, data.Opened, data.Effects)
		local selected = data.Effect == effect.Key
		local caption: string
		local enabled: boolean
		local tone: Style.ButtonTone
		local callback: () -> () = function() end
		if selected then
			caption, enabled, tone = "Выбран", false, "neutral"
		elseif available then
			caption, enabled, tone = "Выбрать", true, "primary"
			callback = function()
				Components.send("effect", effect.Key)
			end
		elseif effect.Price then
			caption = Components.coin(effect.Price)
			enabled, tone = data.Coins >= effect.Price, "reward"
			callback = function()
				Components.send("buyEffect", effect.Key)
			end
		else
			caption, enabled, tone = "Закрыт", false, "neutral"
		end
		Components.row({
			Name = effect.Name,
			Details = effect.Details,
			Tint = effect.Primary,
			Caption = caption,
			Callback = callback,
			Enabled = enabled,
			FocusKey = `Эффект {effect.Key}`,
			Tone = tone,
		})
	end
end

return Settings
