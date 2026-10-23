param([string]$Output='build/ModularGarage/Leo Racer.exe',[switch]$DebugExport)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
    & "$PSScriptRoot/run_godot.ps1" --headless --editor --import --quit
    if ($LASTEXITCODE -ne 0) {throw 'Asset import failed'}
    & "$PSScriptRoot/run_godot.ps1" --headless --script res://tools/validate_modular_catalog.gd
    if ($LASTEXITCODE -ne 0) {throw 'Unresolved catalog assets: complete setup before export'}
    $sdk=[IO.Path]::GetFullPath((Join-Path $project '../../tools/dotnet'))
    if (Test-Path (Join-Path $project '.tools/dotnet/dotnet.exe')) {$sdk=Join-Path $project '.tools/dotnet'}
    $env:DOTNET_ROOT=$sdk
    $env:PATH=$sdk+';'+$env:PATH
    $env:DOTNET_CLI_HOME=Join-Path $project 'build/dotnet-home'
    $env:NUGET_PACKAGES=Join-Path $project '.tools/nuget'
    $env:MSBUILDDISABLENODEREUSE='1'
    & (Join-Path $sdk 'dotnet.exe') build LeoRacer.csproj -c Debug -p:RestoreLockedMode=true
    if ($LASTEXITCODE -ne 0) {throw '.NET bridge build failed'}
    & "$PSScriptRoot/brand_template.ps1" -DebugTemplate:$DebugExport
    New-Item -ItemType Directory -Force -Path (Split-Path $Output -Parent) | Out-Null
    $exportLog=Join-Path $project 'build/development-export-check.log'
    $mode=if ($DebugExport) {'--export-debug'} else {'--export-release'}
    & "$PSScriptRoot/run_godot.ps1" @('--headless',$mode,'Windows Desktop',$Output) 2>&1 | Tee-Object -FilePath $exportLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -Path $exportLog -Pattern 'Export .NET Project: Failed|SCRIPT ERROR' -Quiet)) {throw 'Windows or .NET export failed'}
    $folder=Split-Path $Output -Parent
    if (-not (Get-ChildItem $folder -Recurse -Filter 'LeoRacer.dll')) {throw 'Export is missing .NET assemblies'}
    if (-not (Get-ChildItem $folder -Recurse -Filter 'e_sqlite3.dll')) {throw 'Export is missing Windows native SQLite'}
} finally {Pop-Location}
