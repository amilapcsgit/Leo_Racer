param([switch]$Package,[switch]$SkipStage,[string]$ContentArchive='',[string]$Python='python')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
    $qa=Join-Path $project 'build/qa270'
    New-Item -ItemType Directory -Force $qa | Out-Null
    $env:APPDATA=Join-Path $project 'build/ultra-ci-profile'
    $env:LOCALAPPDATA=$env:APPDATA
    $env:TEMP=Join-Path $project 'build/export270-temp';$env:TMP=$env:TEMP
    New-Item -ItemType Directory -Force $env:TEMP | Out-Null
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    if (-not $SkipStage) {
        $stage=@('tools/stage_ultra_content.py')
        if ($ContentArchive) {$stage+=@('--archive',$ContentArchive)}
        & $Python @stage
        if ($LASTEXITCODE -ne 0) {throw 'Content staging failed'}
    }
    $assets=Join-Path $project 'build/content-baseline/GameAssets'
    if (@(Get-ChildItem "$assets/vehicles/*/vehicle.json").Count -ne 21 -or @(Get-ChildItem "$assets/tracks/*/manifest.json").Count -ne 3) {throw 'Stage all 21 cars and three tracks before testing'}
    $env:LEO_ASSET_ROOT=$assets
    $sdk=[IO.Path]::GetFullPath((Join-Path $project '../../tools/dotnet'))
    if (Test-Path '.tools/dotnet/dotnet.exe') {$sdk=Join-Path $project '.tools/dotnet'}
    $env:DOTNET_ROOT=$sdk;$env:PATH=$sdk+';'+$env:PATH
    $env:DOTNET_CLI_HOME=Join-Path $project '.tools/cli-home'
    $env:NUGET_PACKAGES=Join-Path $project '.tools/nuget'
    & "$sdk/dotnet.exe" build LeoRacer.csproj -c Debug -p:RestoreLockedMode=true *> "$qa/dotnet.log"
    if ($LASTEXITCODE -ne 0) {throw '.NET build failed; see qa270/dotnet.log'}
    & "$PSScriptRoot/run_godot.ps1" --headless --editor --import --log-file "$qa/import.log" *> "$qa/import-console.log"
    if ($LASTEXITCODE -ne 0) {throw 'Asset import failed'}
    & $Python tools/test_ultra_legacy.py
    if ($LASTEXITCODE -ne 0) {throw 'Legacy record compatibility failed'}
    New-Item -ItemType Directory -Force build/qa-ui | Out-Null
    foreach ($test in @('local_input_test','ultra_core_test','local_ranking_test','local_race_test')) {
        $log=Join-Path $qa "$test.log"
        & "$PSScriptRoot/run_godot.ps1" @('--headless','--script',"res://tests/$test.gd",'--log-file',$log,'--','--drive-test',"--vehicles=$assets/vehicles","--tracks=$assets/tracks") *> "$qa/$test-console.log"
        if ($LASTEXITCODE -ne 0 -or (Select-String -Path $log -Pattern 'SCRIPT ERROR|^FAIL |"status":\s*"FAIL"' -Quiet)) {throw "Failed $test; see $log"}
    }
    if ($Package) {
        $output=Join-Path $project 'build/Release-2.7.0-Ultra/LeoRacer.exe'
        if (Test-Path $output) {throw 'Preserve previous exports: archive the candidate before rebuilding this destination'}
        New-Item -ItemType Directory -Force (Split-Path $output) | Out-Null
        & "$PSScriptRoot/brand_template.ps1"
        & "$PSScriptRoot/run_godot.ps1" --headless --export-release 'Windows Desktop' $output *> "$qa/export.log"
        if ($LASTEXITCODE -ne 0 -or (Select-String -Path "$qa/export.log" -Pattern 'SCRIPT ERROR|Export .NET Project: Failed|Safe save failed|Can.t open file from path' -Quiet)) {throw 'Export failed'}
        & "$PSScriptRoot/run_godot.ps1" @('--headless','--script','res://tools/build_workshop_pack.gd','--',"--output=$project/build/Release-2.7.0-Ultra/Tools/VehicleWorkshop")
        if ($LASTEXITCODE -ne 0) {throw 'Workshop package failed'}
        & $Python tools/package_ultra.py
        if ($LASTEXITCODE -ne 0) {throw 'Packaging failed'}
        & $Python tools/verify_ultra_delivery.py
        if ($LASTEXITCODE -ne 0) {throw 'Native delivery verification failed'}
        & $Python tools/package_ultra.py package
        if ($LASTEXITCODE -ne 0) {throw 'Evidence packaging failed'}
    }
} finally {Pop-Location}
