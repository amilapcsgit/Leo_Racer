param([string]$Version='1.5.0')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$sdk=Join-Path $project '.tools/dotnet/dotnet.exe'
if (-not (Test-Path $sdk)) {$sdk=[IO.Path]::GetFullPath((Join-Path $project '../../tools/dotnet/dotnet.exe'))}
$env:DOTNET_ROOT=Split-Path $sdk -Parent
$env:PATH=$env:DOTNET_ROOT+';'+$env:PATH
$env:DOTNET_CLI_HOME=Join-Path $project '.tools/cli-home'
$env:NUGET_PACKAGES=Join-Path $project '.tools/nuget'
& $sdk publish (Join-Path $project 'launcher/LeoRacerLauncher.csproj') -c Release -o (Join-Path $project 'build/launcher') "-p:Version=$Version"
if ($LASTEXITCODE -ne 0) {throw 'Launcher build failed'}
Copy-Item -LiteralPath (Join-Path $project 'build/launcher/Leo Racer Launcher.exe') -Destination (Join-Path $project 'build/ModularGarage/Leo Racer Launcher.exe') -Force
