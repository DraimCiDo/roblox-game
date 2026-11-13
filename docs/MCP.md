# MCP: подключение Roblox Studio к ИИ-агентам

Используем **встроенный MCP-сервер Roblox Studio** (официальная документация: https://create.roblox.com/docs/studio/mcp).
Он ставится вместе со Studio — ничего скачивать не нужно. Работает локально, транспорт stdio.

> Старый отдельный сервер `Roblox/studio-rust-mcp-server` заархивирован и **не используется**.

Правила использования для агентов — `.claude/skills/studio-mcp/SKILL.md`.

## 1. Включить сервер в Studio (один раз)
1. Открыть **Assistant**.
2. Меню `…` → **Manage MCP Servers**.
3. Включить **Enable Studio as MCP server**.

Когда клиент подключится, появится зелёный индикатор с числом подключённых клиентов.

## 2. Claude Code
Ничего настраивать не нужно: в репозитории есть `.mcp.json` с сервером `Roblox_Studio`
(`cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`). При первом запуске `claude` в папке проекта одобрите сервер.
Проверка: команда `/mcp` в Claude Code.

Альтернатива — Studio сам добавит клиента: Assistant → Settings → MCP Servers → **Quick connect** → включить Claude Code.

## 3. Codex
Самый простой путь — Assistant → Settings → MCP Servers → **Quick connect** → включить Codex.

Вручную — в `%USERPROFILE%\.codex\config.toml`:
```toml
[mcp_servers.Roblox_Studio]
command = "cmd.exe"
args = ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]
```
Проверка: `codex mcp list`.

## 4. macOS
Путь другой. В `.mcp.json` он не подходит, поэтому добавьте сервер в локальную область (имя то же — локальная настройка перекроет проектную):
```bash
claude mcp add --scope local Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
```
Для Codex: `command = "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"`.

## 5. Что умеет сервер
| Группа | Инструменты |
|---|---|
| Сессии | `list_roblox_studios` — у каждого вызова есть `studio_id`; сначала получить его здесь |
| Иерархия | `search_game_tree`, `inspect_instance`, `subagent` |
| Скрипты | `script_read`, `script_search`, `script_grep`, `multi_edit` |
| Выполнение Luau | `execute_luau` |
| Плейтест | `get_studio_state`, `start_stop_play`, `get_console_output`, `screen_capture` |
| Имитация игрока | `character_navigation`, `user_keyboard_input`, `user_mouse_input` |
| Генерация и ассеты | `generate_mesh`, `generate_material`, `generate_animation`, `generate_procedural_model`, `search_asset`, `insert_asset`, `upload_image`, `store_image`, `wait_job_finished` |
| Прочее | `save_place`, `http_get`, `skill`, `submit_feedback` |

Ограничения по использованию этих инструментов агентами — в скилле `studio-mcp` (например, `multi_edit` нельзя применять к скриптам, которые синхронизирует Rojo).

## 6. GitHub
Отдельный MCP не обязателен — агенты работают с GitHub через `gh` CLI (`gh auth login`).

## Частые проблемы
- **Агент не видит Studio**: Studio не запущен или выключен «Enable Studio as MCP server». Перезапустите Studio и клиента.
- **`mcp.bat` не найден**: обновите Studio — файл создаётся в `%LOCALAPPDATA%\Roblox\`.
- **Изменения скриптов пропадают**: скрипт правили прямо в Studio. Правьте файлы в `src/`, Rojo синхронизирует.
- MCP-клиент может читать и менять открытое место — подключайте только доверенные клиенты.
