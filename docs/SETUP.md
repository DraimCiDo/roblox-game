# Установка окружения (Windows)

## 1. Базовое
- **Roblox Studio** — уже установлен.
- **Git** — https://git-scm.com
- **GitHub CLI** — `winget install GitHub.cli`, затем `gh auth login`.
- **VS Code** — при открытии проекта согласиться установить рекомендованные расширения (`.vscode/extensions.json`): luau-lsp, StyLua, Selene, Rojo.

## 1.1 Клонирование и git-хук (обязательно)
```powershell
gh repo clone DraimCiDo/roblox-game
cd roblox-game
git config core.hooksPath .githooks
```
Хук `.githooks/pre-push` запрещает прямой пуш в `main`. Без него правило держится только на дисциплине: защита веток GitHub для приватного репозитория на бесплатном тарифе недоступна.

## 2. Rokit (менеджер инструментов)
Установка — по инструкции в репозитории https://github.com/rojo-rbx/rokit (раздел Installation, Windows).
Затем в папке проекта:
```powershell
rokit install
```
Проверка: `rojo --version`, `selene --version`, `stylua --version`, `wally --version`.

## 3. Плагин Rojo для Studio
```powershell
rojo plugin install
```
Перезапустить Studio — на вкладке Plugins появится Rojo.

## 4. Первый запуск
1. В Studio создать пустое место (Baseplate) и сохранить его локально, например `place.rbxl` в корне проекта (не коммитится).
2. Game Settings → Security → включить **Enable Studio Access to API Services** (нужно для DataStore).
3. В терминале: `rojo serve`.
4. В Studio: Plugins → Rojo → **Connect**.
5. Нажать Play. В Output не должно быть ошибок; в ReplicatedStorage появится папка `Remotes`.

> Карта (Workspace, освещение, модели) хранится в `.rbxl` / публикуется в Roblox, а не в Git. Скрипты — только в Git.

## 5. ИИ-агенты
- **Claude Code**: `npm install -g @anthropic-ai/claude-code`, затем `claude` в папке проекта. Правила подхватываются из `CLAUDE.md` → `AGENTS.md`, скиллы — из `.claude/skills/`.
- **Codex**: `npm install -g @openai/codex`, затем `codex` в папке проекта. Правила — из `AGENTS.md`.
- **MCP для Studio** — встроен в Studio: Assistant → `…` → Manage MCP Servers → Enable Studio as MCP server. Подробно — [MCP.md](MCP.md).
