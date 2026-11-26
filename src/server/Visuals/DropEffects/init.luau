--!strict
-- Эффекты выпадения добычи из контейнера. Какой эффект играть, выбирает владелец сектора; у каждого эффекта
-- своя анимация (Style в Catalog.DropEffects), а не только свой цвет: конфетти — разлетающиеся бумажки,
-- огонь — вспышка и языки пламени, лёд — кристаллы и снег, пустота — воронка, затягивающая и выбрасывающая
-- частицы, золото — дождь из монет.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Common = require(script.Common)
local Sparks = require(script.Sparks)
local Confetti = require(script.Confetti)
local Fire = require(script.Fire)
local Frost = require(script.Frost)
local Void = require(script.Void)
local Gold = require(script.Gold)

local DropEffects = {}

-- Keys match Style in Config/DropEffects.
local STYLES: { [string]: (anchor: Part, at: CFrame, effect: Catalog.DropEffect) -> () } = {
	sparks = Sparks,
	confetti = Confetti,
	fire = Fire,
	frost = Frost,
	void = Void,
	gold = Gold,
}

-- Проигрывает эффект в точке at. delay — пауза до момента вылета добычи.
function DropEffects.play(at: CFrame, key: string, delay: number): ()
	local effect = Catalog.dropEffect(key) or Catalog.dropEffect(Catalog.DefaultEffect)
	if not effect then
		return
	end
	local style = STYLES[effect.Style] or STYLES.sparks
	task.delay(delay, function()
		local anchor = Instance.new("Part")
		anchor.Name = "Эффект выпадения"
		anchor.Size = Vector3.one * 0.4
		anchor.CFrame = at
		anchor.Transparency = 1
		anchor.Anchored = true
		Common.configure(anchor)
		anchor.Parent = Workspace
		style(anchor, at, effect)
		Debris:AddItem(anchor, 3.5)
	end)
end

return DropEffects
