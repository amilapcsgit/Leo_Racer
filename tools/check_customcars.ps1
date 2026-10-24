param()
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
 ./tools/check_modularity.ps1
 New-Item -ItemType Directory -Force build/customcars | Out-Null
 $checks=@{
  'res://tests/customcars_ui_test.gd'='CUSTOMCARS_UI_TEST.*PASS'
  'res://tests/customcars_boost_test.gd'='CUSTOMCARS_BOOST_TEST.*PASS'
  'res://tests/workshop_converter_test.gd'='WORKSHOP_CONVERTER PASS'
  'res://tools/vehicle_workshop/test_workshop.gd'='CUSTOMCARS_WORKSHOP_UI PASS'
 }
 foreach($entry in $checks.GetEnumerator()){
  $name=[IO.Path]::GetFileNameWithoutExtension($entry.Key)
  $log="build/customcars/$name.log"
  ./tools/run_godot.ps1 @('--headless','--script',$entry.Key,'--quit-after','18000','--','--drive-test','--track=astra_coast') *> $log
  if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|Assertion failed|"status": ?"FAIL"' -Quiet) -or -not(Select-String -LiteralPath $log -Pattern $entry.Value -Quiet)){throw "Custom cars check failed: $name"}
  Write-Host "PASS $name"
 }
} finally {Pop-Location}
