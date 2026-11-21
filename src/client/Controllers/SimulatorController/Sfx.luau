--!strict
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

-- Воспроизведение звуков интерфейса (2D) и мира (3D). Если ассет не загрузился, играет встроенный запасной звук.
local Sfx = {}

local random = Random.new()
local failed: { [string]: boolean } = {}
local lastPlayed: { [string]: number } = {}
local MIN_GAP = 0.04
-- Громкость берётся из настроек игрока (0..1): отдельно для интерфейса и для мира.
local volumes = { ui = 0.6, world = 0.6 }
local LIFETIME = 8

local function make(name: string, pitch: number?): Sound?
	local cue = Sounds[name]
	if not cue then
		warn(`[Sfx] Неизвестный звук «{name}»`)
		return nil
	end
	local sound = Instance.new("Sound")
	local speed = cue.Pitch or 1
	if failed[name] and cue.Fallback then
		sound.SoundId = cue.Fallback
		speed *= cue.FallbackPitch or 1
	else
		sound.SoundId = `rbxassetid://{cue.Id}`
	end
	sound.Volume = cue.Volume * (if cue.Range then volumes.world else volumes.ui)
	local jitter = cue.Jitter or 0.08
	sound.PlaybackSpeed = speed * (pitch or 1) * (1 + (random:NextNumber() - 0.5) * jitter)
	return sound
end

local function throttled(name: string): boolean
	local now = os.clock()
	if now - (lastPlayed[name] or -math.huge) < MIN_GAP then
		return true
	end
	lastPlayed[name] = now
	return false
end

-- Задаёт громкость интерфейса и/или мира; nil оставляет значение без изменений.
function Sfx.setVolumes(ui: number?, world: number?): ()
	volumes.ui = math.clamp(ui or volumes.ui, 0, 1)
	volumes.world = math.clamp(world or volumes.world, 0, 1)
end

-- Звук интерфейса без позиции.
function Sfx.play(name: string, pitch: number?): ()
	if throttled(name) then
		return
	end
	local sound = make(name, pitch)
	if not sound then
		return
	end
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, LIFETIME)
end

local function anchorOf(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	elseif target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- Звук мира: затухает с расстоянием от источника.
function Sfx.playAt(name: string, target: Instance?, pitch: number?): ()
	local part = if target then anchorOf(target) else nil
	if not part then
		Sfx.play(name, pitch)
		return
	end
	if throttled(name) then
		return
	end
	local sound = make(name, pitch)
	if not sound then
		return
	end
	local cue = Sounds[name]
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = cue.Range or 70
	sound.Parent = part
	sound:Play()
	Debris:AddItem(sound, LIFETIME)
end

-- Проверяет доступность всех ассетов; недоступные заменяются запасными звуками движка.
function Sfx.preload(): ()
	task.spawn(function()
		for name, cue in Sounds do
			local probe = Instance.new("Sound")
			probe.SoundId = `rbxassetid://{cue.Id}`
			probe.Parent = Workspace
			ContentProvider:PreloadAsync({ probe }, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then
					failed[name] = true
					warn(
						`[Sfx] Звук «{name}» ({cue.Id}) недоступен, используется запасной`
					)
				end
			end)
			probe:Destroy()
		end
	end)
end

return Sfx
