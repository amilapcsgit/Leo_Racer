$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
 $python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
 if(-not (Test-Path -LiteralPath $python)){$python='python'}
 $compiler=Join-Path $project '.tools/nsis/nsis-3.13/Bin/makensis.exe'
 if(-not (Test-Path -LiteralPath $compiler)){throw 'Pinned NSIS 3.13 must be provisioned before this offline build'}
 $env:APPDATA=Join-Path $project 'build/kandy231/release/user-data'
 $env:LOCALAPPDATA=$env:APPDATA
 $env:TEMP=Join-Path $project 'build/kandy231/release/temp';$env:TMP=$env:TEMP
 New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:TEMP | Out-Null
 # Checked template matches the verified game; the unchecked native template
 # failed Colombo shutdown tests and is deliberately not published.
 & "$PSScriptRoot/build_modular_release.ps1" -DebugExport -DisableEditorPlugins -Output 'build/Release-2.3.1/LeoRacer.exe'
 if($LASTEXITCODE){throw 'Core export failed'}
 & $python tools/city_packs.py build/Release-2.3.1 --loose-vehicles
 if($LASTEXITCODE){throw 'Pack partition failed'}
 & $python tools/release_231.py assemble
 if($LASTEXITCODE){throw 'Explicit content assembly failed'}
 & $compiler /V3 installer/SelectableCars231.nsi
 if($LASTEXITCODE){throw 'Selectable installer compilation failed'}
} finally {Pop-Location}
