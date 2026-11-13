# Roblox Game

Игра для Roblox. Код на Luau хранится в Git и синхронизируется в Roblox Studio через [Rojo](https://rojo.space).

## Быстрый старт

```bash
rokit install          # rojo, selene, stylua, wally (версии из rokit.toml)
wally install          # пакеты (пока пусто)
rojo serve             # затем в Studio: плагин Rojo → Connect
```

Подробная установка с нуля: [docs/SETUP.md](docs/SETUP.md).

## Документация

| Документ | О чём |
|---|---|
| [AGENTS.md](AGENTS.md) | **Правила для ИИ-агентов** (Codex, Claude Code и др.) — и для людей тоже полезно |
| [CLAUDE.md](CLAUDE.md) | Дополнения для Claude Code |
| [docs/SETUP.md](docs/SETUP.md) | Установка окружения |
| [docs/MCP.md](docs/MCP.md) | Подключение Roblox Studio к ИИ через MCP |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Как устроен код |
| [docs/WORKFLOW.md](docs/WORKFLOW.md) | Git, ветки, PR, работа с ИИ |
| [docs/GDD.md](docs/GDD.md) | Дизайн-документ игры (заполняет команда) |
| [docs/decisions/](docs/decisions) | Архитектурные решения (ADR) |

## Проверки

```bash
./scripts/check.sh     # Windows: ./scripts/check.ps1
```
То же самое запускается в GitHub Actions на каждый PR.
