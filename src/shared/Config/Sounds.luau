--!strict
-- Звуки игры: имя события → ассет. Интерфейс озвучен официальным набором Roblox GUI, звуки мира —
-- профессиональной библиотекой ProSoundEffects (бесплатные ассеты Creator Store, IsPublicDomain).
-- Чтобы заменить звук, поменяйте Id; события в коде используют только имя.
-- Fallback — встроенный звук движка на случай, если ассет не загрузился.
-- Громкость итогового звука = Volume × ползунок игрока («Интерфейс» или «Мир», см. Settings).
export type Cue = {
	Id: number,
	Volume: number,
	-- Скорость воспроизведения (высота тона); 1 — без изменений.
	Pitch: number?,
	-- Случайный разброс скорости, чтобы повторяющиеся звуки не звучали одинаково.
	Jitter: number?,
	-- Дальность слышимости в студах. Наличие поля означает звук мира (его громкость задаёт ползунок «Мир»).
	Range: number?,
	Fallback: string?,
	FallbackPitch: number?,
}

local UI_FALLBACK = "rbxasset://sounds/volume_slider.ogg"
local IMPACT_FALLBACK = "rbxasset://sounds/action_jump_land.mp3"
local BOOM_FALLBACK = "rbxasset://sounds/impact_explosion_03.mp3"

local Sounds: { [string]: Cue } = {
	-- Интерфейс (официальные звуки Roblox)
	click = { Id = 15675032796, Volume = 0.4, Fallback = UI_FALLBACK, FallbackPitch = 1.8 },
	hover = { Id = 17208339919, Volume = 0.15, Fallback = UI_FALLBACK, FallbackPitch = 2.4 },
	menuOpen = { Id = 17208405682, Volume = 0.4, Fallback = UI_FALLBACK, FallbackPitch = 1.4 },
	menuClose = { Id = 10066914500, Volume = 0.4, Fallback = UI_FALLBACK, FallbackPitch = 1.1 },
	notice = { Id = 17208361335, Volume = 0.4, Fallback = UI_FALLBACK, FallbackPitch = 2.0 },
	error = { Id = 17208214688, Volume = 0.4, Fallback = UI_FALLBACK, FallbackPitch = 0.7 },
	coin = { Id = 127645268874265, Volume = 0.25, Fallback = UI_FALLBACK, FallbackPitch = 2.6 },
	sell = { Id = 17208380755, Volume = 0.45, Fallback = UI_FALLBACK, FallbackPitch = 2.2 },
	perk = { Id = 17208327798, Volume = 0.45, Fallback = UI_FALLBACK, FallbackPitch = 1.6 },
	claim = { Id = 17208209318, Volume = 0.45, Fallback = UI_FALLBACK, FallbackPitch = 2.1 },
	levelup = { Id = 15675043410, Volume = 0.55, Fallback = UI_FALLBACK, FallbackPitch = 1.9 },
	order = { Id = 10066968815, Volume = 0.4, Fallback = UI_FALLBACK, FallbackPitch = 1.5 },
	deposit = { Id = 15675085146, Volume = 0.45, Fallback = UI_FALLBACK, FallbackPitch = 1.7 },
	place = { Id = 17208323435, Volume = 0.45, Fallback = IMPACT_FALLBACK },
	pickup = { Id = 15675055424, Volume = 0.35, Fallback = UI_FALLBACK, FallbackPitch = 2.3 },
	tick = { Id = 12221976, Volume = 0.3, Jitter = 0.04, Fallback = UI_FALLBACK, FallbackPitch = 2.8 },
	dialOk = { Id = 17208209318, Volume = 0.45, Fallback = UI_FALLBACK, FallbackPitch = 1.9 },
	-- Мир (играют у источника)
	tape = { Id = 9113836687, Volume = 0.6, Range = 70, Fallback = IMPACT_FALLBACK, FallbackPitch = 1.6 },
	flap = { Id = 12222200, Volume = 0.4, Pitch = 1.3, Range = 60, Fallback = IMPACT_FALLBACK, FallbackPitch = 1.4 },
	confetti = { Id = 9113263454, Volume = 0.6, Range = 80, Fallback = BOOM_FALLBACK, FallbackPitch = 1.8 },
	thud = { Id = 9116488438, Volume = 0.65, Range = 90, Fallback = IMPACT_FALLBACK },
	snap = { Id = 9113582284, Volume = 0.6, Range = 70, Fallback = IMPACT_FALLBACK, FallbackPitch = 1.5 },
	woodCrash = { Id = 9120828793, Volume = 0.7, Range = 90, Fallback = BOOM_FALLBACK, FallbackPitch = 1.2 },
	latch = { Id = 9125921369, Volume = 0.55, Range = 60, Fallback = IMPACT_FALLBACK, FallbackPitch = 2.0 },
	clunk = { Id = 9125626478, Volume = 0.6, Range = 80, Fallback = IMPACT_FALLBACK, FallbackPitch = 0.8 },
	scrape = { Id = 9118837996, Volume = 0.5, Pitch = 0.9, Range = 80, Fallback = IMPACT_FALLBACK, FallbackPitch = 0.6 },
	hiss = { Id = 9113052976, Volume = 0.5, Range = 90, Fallback = IMPACT_FALLBACK, FallbackPitch = 0.7 },
	whoosh = { Id = 15675012262, Volume = 0.5, Range = 90, Fallback = IMPACT_FALLBACK, FallbackPitch = 1.2 },
	charge = { Id = 9125973984, Volume = 0.55, Range = 90, Fallback = UI_FALLBACK, FallbackPitch = 0.8 },
	boom = { Id = 9114588782, Volume = 0.7, Range = 120, Fallback = BOOM_FALLBACK },
}

return table.freeze(Sounds)
