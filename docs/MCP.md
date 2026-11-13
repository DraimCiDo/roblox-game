# MCP: подключение Roblox Studio к ИИ-агентам

MCP (Model Context Protocol) позволяет агенту видеть и управлять открытым Roblox Studio: читать иерархию, выполнять код, запускать плейтест и читать Output.
Правила использования для агентов — `.claude/skills/studio-mcp/SKILL.md`.

## 1. Сервер Roblox Studio MCP
Используем официальный open-source сервер Roblox: https://github.com/Roblox/studio-rust-mcp-server

1. Скачать релиз для Windows со страницы Releases и запустить установщик — он поставит плагин в Studio.
2. Перезапустить Studio. В Plugins появится MCP-плагин; убедиться, что он **включён** (статус «connected» после запуска агента).
3. Запомнить полный путь к `rbx-studio-mcp.exe`.

> Если в вашей версии Studio есть встроенный MCP-сервер (Assistant → MCP), можно использовать его — подставьте его команду запуска вместо пути к exe ниже.

## 2. Claude Code
В репозитории уже есть `.mcp.json`, который берёт путь из переменной окружения. Один раз на каждой машине:
```powershell
setx ROBLOX_STUDIO_MCP "C:\путь\к\rbx-studio-mcp.exe"
```
Перезапустить терминал, запустить `claude` в папке проекта и одобрить сервер `roblox-studio`. Проверка: команда `/mcp` в Claude Code.

Альтернатива без переменной (только для себя):
```powershell
claude mcp add --scope user roblox-studio -- "C:\путь\к\rbx-studio-mcp.exe" --stdio
```

## 3. Codex
Добавить в `%USERPROFILE%\.codex\config.toml`:
```toml
[mcp_servers.roblox-studio]
command = "C:\\путь\\к\\rbx-studio-mcp.exe"
args = ["--stdio"]
```
Проверка: `codex mcp list`.

## 4. GitHub
Отдельный MCP не обязателен — агенты работают с GitHub через `gh` CLI (`gh auth login`).
При желании можно подключить официальный GitHub MCP-сервер (https://github.com/github/github-mcp-server).

## Частые проблемы
- **Агент не видит Studio** — Studio закрыт или MCP-плагин выключен; должен быть открыт ровно один экземпляр Studio.
- **Изменения скриптов пропадают** — правили скрипт прямо в Studio. Правьте файлы в `src/`, Rojo синхронизирует.
