param([switch]$WithGameplay)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
 New-Item -ItemType Directory -Force build/colombo-visuals | Out-Null
 python tools/colombo_visual_baseline.py
 if($LASTEXITCODE -ne 0){throw 'Protected visuals baseline changed'}
 foreach($item in @(@('colombo_buildings_test','COLOMBO_BUILDINGS_PASS'),@('colombo_terrain_test','COLOMBO_TERRAIN_PASS'),@('colombo_lighting_test','COLOMBO_LIGHTING_PASS'))){
  $log="build/colombo-visuals/$($item[0]).log"
  & "$PSScriptRoot/run_godot.ps1" @('--headless','--script',"res://tests/$($item[0]).gd",'--quit-after','6000','--','--drive-test') *> $log
  if($LASTEXITCODE -ne 0 -or (Select-String -Path $log -Pattern 'SCRIPT ERROR|SHADER ERROR|Assertion failed' -Quiet) -or -not(Select-String -Path $log -Pattern $item[1] -Quiet)){throw "Failed $($item[0]); see $log"}
  Write-Output "PASS $($item[0])"
 }
 if($WithGameplay){
  & "$PSScriptRoot/check_city.ps1"
  if($LASTEXITCODE -ne 0){throw 'City regression failed'}
  & "$PSScriptRoot/check_ui.ps1"
  if($LASTEXITCODE -ne 0){throw 'Neon UI regression failed'}
 }
} finally {Pop-Location}
