$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
    python tools/verify_modular_sources.py
    if ($LASTEXITCODE -ne 0) {throw 'Original assets changed'}
    python tools/verify_bigster_assets.py
    if ($LASTEXITCODE -ne 0) {throw 'Bigster export contract failed'}
    $tests=@('local_input_test','local_race_test','local_presentation_test','local_ranking_test','local_driver_test','local_integration_test','bigster_replacement_test','modular_catalog_test','modular_drive_test','modular_presentation_test','bigster_acceptance')
    foreach ($test in $tests) {
        if (-not (Test-Path "tests/$test.gd")) {continue}
        $log="build/local2player-$test.log"
        & "$PSScriptRoot/run_godot.ps1" @('--headless','--script',"res://tests/$test.gd",'--quit-after','18000','--','--drive-test') 2>&1 | Tee-Object -FilePath $log
        if ($LASTEXITCODE -ne 0 -or (Select-String -Path $log -Pattern 'SCRIPT ERROR|^FAIL |"status": "FAIL"|"status":"FAIL"' -Quiet)) {throw "Failed $test"}
    }
} finally {Pop-Location}
