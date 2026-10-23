param([string]$Archive='dist/LeoRacer-2.0.0-win64.zip',[string]$Folder)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$installedFolder=[bool]$Folder
$originalEnvironment=@{}
foreach($name in @('APPDATA','DOTNET_ROOT','PATH')){$originalEnvironment[$name]=[Environment]::GetEnvironmentVariable($name)}
Push-Location $project
try {
 if($Folder){
  $folder=[IO.Path]::GetFullPath($Folder)
  $destination=Split-Path $folder -Parent
 }else{
 $destination=Join-Path $project ('build/UIRefresh-verify-'+[guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Path $destination | Out-Null
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 [IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $project $Archive),$destination)
 $folder=Join-Path $destination 'LeoRacer'
 }
 New-Item -ItemType Directory -Force 'build/qa-ui' | Out-Null
 if(-not(Get-ChildItem -LiteralPath $folder -Recurse -Filter coreclr.dll)){throw 'Bundled .NET runtime missing'}
 if(-not(Get-ChildItem -LiteralPath $folder -Recurse -Filter e_sqlite3.dll)){throw 'Bundled SQLite missing'}
 $env:APPDATA=Join-Path $destination 'isolated-userdata'
 $env:DOTNET_ROOT=''
 $env:PATH=($env:PATH.Split(';') | Where-Object {$_ -notmatch 'dotnet'}) -join ';'
 $exe=Join-Path $folder 'LeoRacer.console.exe'
 foreach($mode in @('verify-boot-art','verify-content','ui-smoke-test')){
  $log=Join-Path $project ('build/qa-ui/package-'+$mode+'.log')
  & $exe --headless -- ("--"+$mode) 2>&1 | Out-File -Encoding utf8 $log
  if($LASTEXITCODE -ne 0 -or (Select-String -Path $log -Pattern 'SCRIPT ERROR|"status":"FAIL"' -Quiet)){throw "Extracted package failed: $mode"}
  $expected=switch($mode){'verify-boot-art' {'BOOT_ART_VALIDATION.*"status":"PASS"'} 'verify-content' {'CONTENT_VALIDATION_OK'} default {'UI_PACKAGE_SMOKE.*"status":"PASS"'}}
  if(-not(Select-String -Path $log -Pattern $expected -Quiet)){throw "Incomplete package check: $mode"}
 }
 Copy-Item -LiteralPath (Join-Path $folder 'ui-smoke.json') -Destination 'build/qa-ui/package-smoke-final.json'
 $reportName=if($installedFolder){'installer-package.json'}else{'extracted-package.json'}
 $report=@{status='PASS';folder=$folder;sdk_removed=$true;boot_art_exit=0;content_exit=0;smoke_exit=0;archive_sha256=(Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()}
 $report | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path 'build/qa-ui' $reportName)
 Write-Output ($report | ConvertTo-Json)
} finally {
 foreach($name in $originalEnvironment.Keys){[Environment]::SetEnvironmentVariable($name,$originalEnvironment[$name])}
 Pop-Location
}
