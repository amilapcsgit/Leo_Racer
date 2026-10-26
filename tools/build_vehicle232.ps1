param([string]$Baseline='build/Release-2.3.1')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
 $python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
 $env:PYTHONUTF8='1'
 $env:APPDATA=Join-Path $project 'build/vehicle232/export-profile';$env:LOCALAPPDATA=$env:APPDATA
 $env:TEMP=Join-Path $project 'build/vehicle232/temp';$env:TMP=$env:TEMP
 New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:TEMP | Out-Null
 & $python tools/author_bigster_features.py --source "$Baseline/GameAssets/vehicles/bigster" --output 'build/vehicle232/vehicles/bigster'
 if($LASTEXITCODE){throw 'Bigster authoring failed'}
 Copy-Item -LiteralPath 'build/vehicle232/vehicles/bigster/model.glb' -Destination 'assets/models/bigster/bigster_232.glb'
 foreach($name in @('vehicle.json','feature-authoring.json')) {
  Copy-Item -LiteralPath "build/vehicle232/vehicles/bigster/$name" -Destination "content/vehicles/bigster/$name"
 }
 & $python tools/candidate_232.py prepare --baseline $Baseline
 if($LASTEXITCODE){throw 'Candidate staging failed'}
 & $python tools/content.py registry
 if($LASTEXITCODE){throw 'Official fingerprint update failed'}
 & "$PSScriptRoot/build_modular_release.ps1" -DebugExport -DisableEditorPlugins -Output 'build/Release-2.3.2/LeoRacer.exe'
 if($LASTEXITCODE){throw 'Windows candidate export failed'}
 & $python tools/city_packs.py build/Release-2.3.2 --loose-vehicles
 if($LASTEXITCODE){throw 'Candidate pack partition failed'}
 & $python tools/candidate_232.py finish --baseline $Baseline
 if($LASTEXITCODE){throw 'Candidate assembly failed'}
} finally {Pop-Location}
