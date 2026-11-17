---
name: studio-mcp
description: Работа с открытым Roblox Studio через встроенный MCP-сервер Roblox_Studio — осмотр иерархии места, выполнение Luau, плейтест, чтение Output, имитация ввода игрока, генерация ассетов. Использовать, когда нужно проверить изменение в реальном Studio, найти объект в Workspace или отладить ошибку из Output.
---

# Roblox Studio через MCP

Сервер — встроенный в Studio (`Roblox_Studio`). Настройка — `docs/MCP.md`.
Условия: Studio открыт, в Assistant включено «Enable Studio as MCP server», Rojo подключён (`rojo serve`).

## Главное правило
**Источник истины для кода — файлы в `src/`, а не Studio.**
Скрипты меняются только в репозитории, Rojo синхронизирует их в Studio.
Код, изменённый прямо в Studio, при следующей синхронизации будет перезаписан и не попадёт в Git.

## Начало работы
1. `list_roblox_studios` → взять `studio_id` нужного места (он нужен в каждом вызове).
2. `get_studio_state` → убедиться, что не идёт плейтест, прежде чем что-то запускать.

## Разрешено
| Задача | Инструменты |
|---|---|
| Осмотр места | `search_game_tree`, `inspect_instance`, `subagent` |
| Чтение скриптов (сверить, что Rojo синхронизировал) | `script_read`, `script_search`, `script_grep` |
| Временная диагностика (вывести состояние, проверить гипотезу) | `execute_luau` |
| Плейтест и логи | `start_stop_play`, `get_console_output`, `screen_capture` |
| Проверка геймплея как игрок | `character_navigation`, `user_keyboard_input`, `user_mouse_input` |
| Справка по API | `http_get` (create.roblox.com/docs), `skill` |

## Только по явной просьбе человека
- `generate_*`, `insert_asset`, `search_asset`, `upload_image`, `store_image` — меняют место или тратят ресурсы аккаунта. Toolbox-модели проверять на скрипты.
- Изменения Workspace (карта, модели) через `execute_luau` — карта живёт в .rbxl, не в Git; после правок сообщить человеку.
- `save_place` — сохраняет место; без просьбы не вызывать.

## Запрещено
- `multi_edit` и `execute_luau` для изменения Script / LocalScript / ModuleScript, которые синхронизирует Rojo (всё в ServerScriptService.Server, StarterPlayerScripts.Client, ReplicatedStorage.Shared).
- Удалять объекты без явной просьбы.
- Публиковать место в Roblox.
- `submit_feedback` от имени команды.

## Цикл проверки правки
1. Изменить файлы в `src/`.
2. `script_read` — убедиться, что Rojo синхронизировал изменения в Studio.
3. `start_stop_play` (запуск) → подождать → `get_console_output`.
4. При необходимости — `character_navigation` / ввод, чтобы пройти сценарий, `screen_capture` для UI.
5. `start_stop_play` (остановка). Отчитаться: что проверено, что в Output.

Если MCP-сервер недоступен — не имитировать результат. Сообщить человеку и дать шаги ручной проверки.
