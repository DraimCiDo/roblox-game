--!strict
-- Звуки игры: имя события → ассет. Все идентификаторы взяты из бесплатной библиотеки Creator Store
-- (IsPublicDomain). Чтобы заменить звук, поменяйте Id; события в коде используют только имя.
-- Fallback — встроенный звук движка на случай, если ассет не загрузился.
export type Cue = {
	Id: number,
	Volume: number,
	-- Скорость воспроизведения (высота тона); 1 — без изменений.
	Pitch: number?,
	-- Случайный разброс скорости, чтобы повторяющиеся звуки не звучали одинаково.
	Jitter: number?,
	-- Дальность слышимости в студах для звуков мира.
	Range: number?,
	Fallback: string?,
	FallbackPitch: number?,
}

local UI_FALLBACK = "rbxasset://sounds/volume_slider.ogg"
local IMPACT_FALLBACK = "rbxasset://sounds/action_jump_land.mp3"
local BOOM_FALLBACK = "rbxasset://sounds/impact_explosion_03.mp3"

local Sounds: { [string]: Cue } = {
	-- Интерфейс
	click = { Id = 15675059323, Volume = 0.5, Fallback = UI_FALLBACK, FallbackPitch = 1.8 },
	hover = { Id = 91819415770574, Volume = 0.18, Pitch = 1.2, Fallback = UI_FALLBACK, FallbackPitch = 2.4 },
	menuOpen = { Id = 87437544236708, Volume = 0.5, Fallback = UI_FALLBACK, FallbackPitch = 1.4 },
	menuClose = { Id = 110059957735733, Volume = 0.5, Fallback = UI_FALLBACK, FallbackPitch = 1.1 },
	notice = { Id = 136655923047274, Volume = 0.45, Fallback = UI_FALLBACK, FallbackPitch = 2.0 },
	error = { Id = 91501650514390, Volume = 0.5, Fallback = UI_FALLBACK, FallbackPitch = 0.7 },
	coin = { Id = 4612374807, Volume = 0.3, Fallback = UI_FALLBACK, FallbackPitch = 2.6 },
	sell = { Id = 90531793028786, Volume = 0.6, Fallback = UI_FALLBACK, FallbackPitch = 2.2 },
	perk = { Id = 3406813517, Volume = 0.55, Fallback = UI_FALLBACK, FallbackPitch = 1.6 },
	claim = { Id = 117904822279498, Volume = 0.6, Fallback = UI_FALLBACK, FallbackPitch = 2.1 },
	levelup = { Id = 112485797063762, Volume = 0.7, Fallback = UI_FALLBACK, FallbackPitch = 1.9 },
	order = { Id = 88442833509532, Volume = 0.55, Fallback = UI_FALLBACK, FallbackPitch = 1.5 },
	deposit = { Id = 90618709727045, Volume = 0.55, Fallback = UI_FALLBACK, FallbackPitch = 1.7 },
	place = { Id = 117173602660357, Volume = 0.45, Fallback = IMPACT_FALLBACK },
	pickup = { Id = 113730061669739, Volume = 0.4, Fallback = UI_FALLBACK, FallbackPitch = 2.3 },
	tick = { Id = 137872392480008, Volume = 0.3, Jitter = 0.04, Fallback = UI_FALLBACK, FallbackPitch = 2.8 },
	dialOk = { Id = 120005759558278, Volume = 0.55, Fallback = UI_FALLBACK, FallbackPitch = 1.9 },
	-- Мир (играют у источника)
	tape = { Id = 78173353336114, Volume = 0.9, Range = 70, Fallback = IMPACT_FALLBACK, FallbackPitch = 1.6 },
	flap = {
		Id = 138890894929151,
		Volume = 0.5,
		Pitch = 1.4,
		Range = 60,
		Fallback = IMPACT_FALLBACK,
		FallbackPitch = 1.4,
	},
	confetti = { Id = 76586276648178, Volume = 0.9, Range = 80, Fallback = BOOM_FALLBACK, FallbackPitch = 1.8 },
	thud = { Id = 83861863982203, Volume = 1, Range = 90, Fallback = IMPACT_FALLBACK },
	snap = { Id = 9113582284, Volume = 0.9, Range = 70, Fallback = IMPACT_FALLBACK, FallbackPitch = 1.5 },
	woodCrash = { Id = 9120828793, Volume = 1, Range = 90, Fallback = BOOM_FALLBACK, FallbackPitch = 1.2 },
	latch = { Id = 9125921369, Volume = 0.8, Range = 60, Fallback = IMPACT_FALLBACK, FallbackPitch = 2.0 },
	clunk = { Id = 9125626478, Volume = 0.9, Range = 80, Fallback = IMPACT_FALLBACK, FallbackPitch = 0.8 },
	scrape = { Id = 9118837996, Volume = 0.8, Pitch = 0.9, Range = 80, Fallback = IMPACT_FALLBACK, FallbackPitch = 0.6 },
	hiss = { Id = 9113052976, Volume = 0.8, Range = 90, Fallback = IMPACT_FALLBACK, FallbackPitch = 0.7 },
	whoosh = { Id = 138890894929151, Volume = 0.8, Range = 90, Fallback = IMPACT_FALLBACK, FallbackPitch = 1.2 },
	charge = { Id = 120568222164096, Volume = 0.9, Range = 90, Fallback = UI_FALLBACK, FallbackPitch = 0.8 },
	boom = { Id = 75300135616235, Volume = 1, Range = 120, Fallback = BOOM_FALLBACK },
}

return table.freeze(Sounds)
