---
name: new-module
description: Создание нового серверного сервиса (src/server/Services) или клиентского контроллера (src/client/Controllers) по шаблону проекта. Использовать, когда нужно добавить новую игровую систему, менеджер, UI-контроллер или любой модуль, который должен автоматически загружаться через Loader.
---

# Новый сервис / контроллер

## Куда класть
| Что | Папка | Суффикс имени |
|---|---|---|
| Серверная логика (данные, экономика, бой, матчи) | `src/server/Services/` | `...Service` |
| Клиентская логика (ввод, UI, камера, эффекты) | `src/client/Controllers/` | `...Controller` |
| Общий код без состояния (утилиты, типы, конфиги) | `src/shared/` | без суффикса |

Loader подхватывает **только прямых детей** папок `Services/` и `Controllers/`. Вспомогательные модули сервиса кладите в подпапку `Services/<Имя>Service/` и превращайте сервис в `init.luau` этой папки.

## Шаблон
```lua
--!strict
-- <Одна строка: за что отвечает модуль>
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local ExampleService = {}

-- Приватное состояние — локальные переменные модуля, не поля таблицы.
local state: { [Player]: number } = {}

function ExampleService:Init()
	-- Только подготовка. Без yield, без вызова других сервисов.
end

function ExampleService:Start()
	-- Подписки, циклы, обращение к другим сервисам.
end

-- Публичный API ниже, с типами у всех параметров и возвращаемых значений.

return ExampleService
```

## Обращение к другим сервисам
`require(script.Parent.OtherService)` и вызывать его методы **только в Start()** или позже.
Избегайте циклических require — выносите общее в `src/shared/`.

## Чек-лист
1. `--!strict` первой строкой, у публичных функций есть типы.
2. Очистка по `Players.PlayerRemoving` для всех таблиц, индексированных игроком (иначе утечка памяти).
3. Если нужна сеть — сначала скилл `new-remote`.
4. Если меняются сохраняемые данные — скилл `datastore-change`.
5. Прогнать `scripts/check`.
