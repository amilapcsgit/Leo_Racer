param([string]$Output='build/Distinct-v3-final/LeoRacer.exe')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$taskProfile=Join-Path $project 'build/distinct/export-profile'
$taskTemp=Join-Path $project 'build/distinct/temp'
New-Item -ItemType Directory -Force -Path $taskProfile,$taskTemp | Out-Null
# Godot's editor, .NET exporter and temporary project.binary all need writable paths.
$env:APPDATA=$taskProfile
$env:LOCALAPPDATA=$taskProfile
$env:TEMP=$taskTemp
$env:TMP=$taskTemp
$env:DOTNET_CLI_TELEMETRY_OPTOUT='1'
& "$PSScriptRoot/build_modular_release.ps1" -DebugExport -DisableEditorPlugins -Output $Output
if($LASTEXITCODE){throw 'Distinct vehicle candidate export failed'}
