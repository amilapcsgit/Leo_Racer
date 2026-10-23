param([switch]$Visual)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
 New-Item -ItemType Directory -Force 'build/qa-ui' | Out-Null
 foreach($test in @('ui_input_test','local_input_test','ui_frontend_test','local_race_test','local_ranking_test','local_presentation_test')){
  $log="build/qa-ui/$test.log"
  & "$PSScriptRoot/run_godot.ps1" @('--headless','--script',"res://tests/$test.gd",'--','--drive-test') 2>&1 | Out-File -Encoding utf8 $log
  if($LASTEXITCODE -ne 0 -or (Select-String -Path $log -Pattern 'SCRIPT ERROR|"status": ?"(FAIL|CHECK)"' -Quiet) -or -not (Select-String -Path $log -Pattern '"status": ?"PASS"' -Quiet)){throw "Failed: $test. See $log"}
  Write-Host "PASS $test"
 }
 if($Visual){
  foreach($renderer in @('gl_compatibility','forward_plus')){
   $visualArguments=@('--rendering-method',$renderer,'--script','res://tests/ui_visual_matrix.gd','--','--drive-test')
   $visualLog="build/qa-ui/visual-$renderer.log"
   & "$PSScriptRoot/run_godot.ps1" @visualArguments 2>&1 | Out-File -Encoding utf8 $visualLog
   if($LASTEXITCODE -ne 0 -or (Select-String -Path $visualLog -Pattern 'SCRIPT ERROR|SHADER ERROR|"status": ?"FAIL"' -Quiet) -or -not (Select-String -Path $visualLog -Pattern '"status": ?"PASS"' -Quiet)){throw "Visual check failed: $renderer"}
  }
 }
} finally {Pop-Location}
