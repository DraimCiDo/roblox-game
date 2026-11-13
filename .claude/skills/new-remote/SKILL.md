---
name: new-remote
description: Добавление сетевого взаимодействия клиент-сервер (RemoteEvent / RemoteFunction) с серверной валидацией и защитой от эксплойтов. Использовать всегда, когда клиент должен что-то сообщить серверу или сервер — клиенту (покупка, атака, действие игрока, обновление UI).
---

# Новый Remote

## Шаги
1. Объявить имя в `src/shared/Remotes.luau` → `Remotes.Events` или `Remotes.Functions`, с комментарием направления (`Клиент -> сервер` / `Сервер -> клиент`).
2. Сервер: `Remotes.event(Remotes.Events.X).OnServerEvent:Connect(handler)` в `Start()` соответствующего сервиса.
3. Клиент: `Remotes.event(Remotes.Events.X):FireServer(...)` в контроллере.
4. Никогда не создавать Remote вручную в Studio или через `Instance.new` в других местах.

## Правила безопасности (обязательно)
Клиент полностью контролируется игроком. Считай каждый аргумент враждебным.

- **Проверяй типы** каждого аргумента: `typeof(x) == "number"`, плюс `x == x` (NaN) и `math.abs(x) ~= math.huge`.
- **Проверяй диапазоны и права**: хватает ли денег, близко ли игрок к объекту (`(a - b).Magnitude <= MAX`), владеет ли он предметом.
- **Не принимай от клиента результат** — только намерение. Плохо: `FireServer("AddCoins", 100)`. Хорошо: `FireServer("CollectCoin", coinId)` — сервер сам решает, сколько дать.
- **Rate limit** для частых действий (минимальный интервал на игрока, таблица `lastCall[player]`, очистка при выходе).
- **RemoteFunction клиенту не вызывать** (`InvokeClient`) — клиент может повесить сервер. Для сервер→клиент только RemoteEvent.
- **Не отправляй лишнего**: клиент получает только то, что ему нужно видеть.

## Шаблон серверного обработчика
```lua
local MIN_INTERVAL = 0.2
local lastCall: { [Player]: number } = {}

Remotes.event(Remotes.Events.UseItem).OnServerEvent:Connect(function(player: Player, itemId: unknown)
	if typeof(itemId) ~= "string" or #itemId > 64 then
		return
	end
	local now = os.clock()
	if now - (lastCall[player] or 0) < MIN_INTERVAL then
		return
	end
	lastCall[player] = now
	-- ... проверка владения и логика
end)

Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)
```

## Проверка
Studio → вкладка Test → Start Server + 2 Players: убедиться, что событие работает и что второй игрок не видит/не влияет на чужое.
