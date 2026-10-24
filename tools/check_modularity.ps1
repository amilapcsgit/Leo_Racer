param([switch]$FullRoster,[switch]$Integration,[switch]$Visual)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
 New-Item -ItemType Directory -Force build/modularity,build/qa-ui | Out-Null
 python tools/content.py stage --profile dev
 if($LASTEXITCODE -ne 0){throw 'Vehicle staging failed'}
 function Check([string]$Name,[string]$Expected,[string[]]$Extra=@()){
  $args=@('--headless','--script',"res://tests/$Name.gd",'--quit-after','18000','--','--drive-test','--track=astra_coast')+$Extra
  $log="build/modularity/check-$Name.log"
  & "$PSScriptRoot/run_godot.ps1" @args *> $log
  if($LASTEXITCODE -ne 0 -or (Select-String -Path $log -Pattern 'SCRIPT ERROR|SHADER ERROR|Assertion failed|"status": ?"FAIL"' -Quiet) -or -not (Select-String -Path $log -Pattern $Expected -Quiet)){throw "Failed $Name; see $log"}
  Write-Host "PASS $Name"
 }
 Check vehicle_codec_test VEHICLE_CODEC_PASS @('--legacy-content')
 Check loose_vehicles_test 'LOOSE_VEHICLES_TEST.*PASS'
 Check local_race_test 'LOCAL_RACE_TEST.*PASS'
 Check local_input_test 'LOCAL_INPUT_TEST.*PASS'
 Check local_ranking_test 'LOCAL_RANKING_TEST.*PASS'
 Check vehicle_workshop_test 'WORKSHOP_TEST.*PASS'
 if($Integration){Check local_integration_test 'LOCAL_INTEGRATION_TEST.*PASS'}
 if($FullRoster){
  python tools/content.py stage --profile full --output build/modularity-full-content/GameAssets
  if($LASTEXITCODE -ne 0){throw 'Full roster staging failed'}
  Check modularity_full_roster 'MODULARITY_FULL_ROSTER.*PASS' @('--vehicles=res://build/modularity-full-content/GameAssets/vehicles')
 }
 if($Visual){
  $log='build/modularity/workshop-visual.log'
  & "$PSScriptRoot/run_godot.ps1" @('--rendering-method','gl_compatibility','--rendering-driver','opengl3','--script','res://tests/vehicle_workshop_test.gd','--quit-after','6000','--','--drive-test','--track=astra_coast') *> $log
  if($LASTEXITCODE -ne 0 -or (Select-String -Path $log -Pattern 'SCRIPT ERROR|SHADER ERROR' -Quiet) -or -not (Select-String -Path $log -Pattern 'WORKSHOP_TEST.*PASS' -Quiet)){throw 'Workshop visual test failed'}
 }
} finally {Pop-Location}
