# Архитектура

## Слои
```
Клиент (Controllers)  ──Remotes──▶  Сервер (Services)  ──▶  DataStore
        ▲                                  │
        └──────── DataChanged ─────────────┘
              Shared: Types, Config, Util, Remotes, Loader
```

- **Services** (`src/server/Services`) — вся игровая логика и состояние. Сервер решает всё.
- **Controllers** (`src/client/Controllers`) — ввод, UI, камера, эффекты. Отправляют серверу *намерения*, показывают то, что прислал сервер.
- **Shared** (`src/shared`) — код без состояния, общий для обеих сторон. Помнить: реплицируется клиенту.

## Загрузка
`Main.server.luau` → `Remotes.init()` → `Loader.load(Services)`.
`Main.client.luau` → `Loader.load(Controllers)`.
Loader: `require` всех модулей → `Init()` у всех → `Start()` у всех в отдельных потоках.

## Сеть
Все Remotes объявлены в `src/shared/Remotes.luau`. Сервер создаёт их при старте, клиент ждёт через `WaitForChild`.
Получение: `Remotes.event(Remotes.Events.Name)`, `Remotes.func(Remotes.Functions.Name)`.

## Данные игрока
`PlayerDataService` — единственный владелец сохранений:
- загрузка при входе (с повторами; при ошибке игрок кикается, чтобы не затереть сохранение),
- автосохранение каждые `GameConfig.AutosaveInterval` секунд, при выходе и при остановке сервера,
- изменение только через `PlayerDataService:Update(player, fn)` — клиент получает `DataChanged`.

## Что сознательно отложено
- Тесты (TestEZ / Jest-Lua + run-in-roblox или Open Cloud Luau Execution) — когда появится логика, которую стоит покрыть.
- Session locking для DataStore (защита от двойного входа) — перед релизом рассмотреть ProfileStore.
- Сетевая библиотека (ByteNet/Zap и т.п.) — при росте трафика.
- Деплой через Open Cloud из CI — когда будет опубликованное место.

Значимые решения фиксируются в `docs/decisions/` (ADR).
