param([switch]$SkipBuild)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
$previousAppData=$env:APPDATA;$previousLocalAppData=$env:LOCALAPPDATA;$previousTemp=$env:TEMP;$previousTmp=$env:TMP;$previousDotnet=$env:DOTNET_ROOT
try {
    if (-not $SkipBuild) {
        & "$PSScriptRoot/build_modular_release.ps1" -Output 'build/Local2Player/Leo Racer.exe'
        if ($LASTEXITCODE -ne 0) {throw 'Development export failed'}
    }
    Copy-Item licenses build/Local2Player/licenses -Recurse -Force
    Copy-Item docs/LOCAL2PLAYER_README.txt build/Local2Player/README.txt -Force
    $archive=Join-Path $project 'build/LeoRacer-local2player-development.zip'
    Compress-Archive -LiteralPath build/Local2Player -DestinationPath $archive -Force
    # Unique extraction means the offline test cannot pass with stale DLLs.
    $extract=Join-Path $project ('build/local2player-offline-'+[guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $archive -DestinationPath $extract
    $user=Join-Path $extract 'test-user'
    $env:APPDATA=Join-Path $user 'AppData';$env:LOCALAPPDATA=$env:APPDATA;$env:TEMP=Join-Path $user 'Temp';$env:TMP=$env:TEMP
    New-Item -ItemType Directory -Force $env:APPDATA,$env:TEMP | Out-Null
    Remove-Item Env:DOTNET_ROOT -ErrorAction SilentlyContinue
    $log=Join-Path $project 'build/local2player-extracted-smoke.log'
    & "$extract/Local2Player/Leo Racer.console.exe" --headless -- --smoke-test 2>&1 | Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0 -or (Select-String $log -Pattern 'SCRIPT ERROR|^FAIL |Assemblies not found' -Quiet)) {throw 'Extracted offline smoke failed'}
    $result=Get-Content "$extract/Local2Player/smoke-test.json" -Raw | ConvertFrom-Json
    if ($result.status -ne 'PASS') {throw 'Offline smoke did not pass'}
    $report=[ordered]@{status='PASS';archive='LeoRacer-local2player-development.zip';sha256=(Get-FileHash $archive -Algorithm SHA256).Hash.ToLower();bytes=(Get-Item $archive).Length;extracted_offline_smoke=$result;native_sqlite_bundled=(Test-Path "$extract/Local2Player/data_LeoRacer_windows_x86_64/e_sqlite3.dll");stable_release_unchanged=$true}
    $report | ConvertTo-Json -Depth 6 | Set-Content docs/qa-local2player/offline-package.json -Encoding UTF8
    Write-Host 'Extracted offline development package validated.'
} finally {
    $env:APPDATA=$previousAppData;$env:LOCALAPPDATA=$previousLocalAppData;$env:TEMP=$previousTemp;$env:TMP=$previousTmp;$env:DOTNET_ROOT=$previousDotnet
    Pop-Location
}
