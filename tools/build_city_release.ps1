param([switch]$SkipExport)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
    python tools/prepare_city_catalog.py
    if ($LASTEXITCODE -ne 0) {throw 'Catalog generation failed'}
    python tools/colombo_baseline.py
    if ($LASTEXITCODE -ne 0) {throw 'Protected geometry changed'}
    $output='build/ColomboCity/LeoRacer.exe'
    New-Item -ItemType Directory -Force (Split-Path $output -Parent) | Out-Null
    if (-not $SkipExport) {
        & "$PSScriptRoot/build_modular_release.ps1" -Output $output -DebugExport
        if ($LASTEXITCODE -ne 0) {throw 'City export failed'}
    }
    python tools/city_packs.py build/ColomboCity
    if ($LASTEXITCODE -ne 0) {throw 'Category packaging failed'}
} finally {Pop-Location}
