#!/usr/bin/env bash
# Та же проверка, что в CI. Запускать перед каждым коммитом/PR.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> StyLua";  stylua --check src
echo "==> Selene";  selene src
echo "==> Rojo";    rojo build default.project.json -o build/check.rbxl
echo "OK: все проверки пройдены"
