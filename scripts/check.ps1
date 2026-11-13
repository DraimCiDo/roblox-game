# Та же проверка, что в CI. Запускать перед каждым коммитом/PR.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "==> StyLua"; stylua --check src; if ($LASTEXITCODE) { exit $LASTEXITCODE }
Write-Host "==> Selene"; selene src;         if ($LASTEXITCODE) { exit $LASTEXITCODE }
Write-Host "==> Rojo";   rojo build default.project.json -o build/check.rbxl; if ($LASTEXITCODE) { exit $LASTEXITCODE }
Write-Host "OK: все проверки пройдены"
