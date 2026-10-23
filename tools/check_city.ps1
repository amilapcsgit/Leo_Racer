$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
    python tools/colombo_baseline.py
    if ($LASTEXITCODE -ne 0) {throw 'Protected geometry changed'}
    python tools/audit_city_course.py
    if ($LASTEXITCODE -ne 0) {throw 'Course geometry audit failed'}
    foreach ($test in @('city_assets_test','city_tracks_test','city_course_test','city_streaming_test','city_full_race_test')) {
        $log="build/$test.log"
        & "$PSScriptRoot/run_godot.ps1" @('--headless','--script',"res://tests/$test.gd",'--quit-after','60000','--','--drive-test') 2>&1 | Tee-Object -FilePath $log
        if ($LASTEXITCODE -ne 0 -or (Select-String -Path $log -Pattern 'SCRIPT ERROR|^FAIL |"status": "FAIL"|"status":"FAIL"' -Quiet) -or -not (Select-String -Path $log -Pattern '"status": "PASS"|"status":"PASS"' -Quiet)) {throw "Failed or incomplete $test"}
    }
    & "$PSScriptRoot/run_godot.ps1" @('--headless','--script','res://tests/city_full_race_test.gd','--quit-after','60000','--','--drive-test','--single-player') 2>&1 | Tee-Object -FilePath build/city-full-race-single.log
    if ($LASTEXITCODE -ne 0 -or -not (Select-String -Path build/city-full-race-single.log -Pattern '"status": "PASS"|"status":"PASS"' -Quiet)) {throw 'Single-player city race failed'}
    & "$PSScriptRoot/check_local2player.ps1"
    if ($LASTEXITCODE -ne 0) {throw 'Single-player or split-screen regression failed'}
} finally {Pop-Location}
