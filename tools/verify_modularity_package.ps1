param([string]$Archive='dist/LeoRacer-2.2.0-modularity-dev-win64.zip',[string]$Folder,[switch]$Extended)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$saved=@{}
foreach($name in @('APPDATA','DOTNET_ROOT','DOTNET_BUNDLE_EXTRACT_BASE_DIR','PATH')){$saved[$name]=[Environment]::GetEnvironmentVariable($name)}
Push-Location $project
try {
 $directory=Join-Path $project ('build/modularity-offline/'+[guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Force $directory | Out-Null
 if($Folder){$game=[IO.Path]::GetFullPath($Folder)}else{
  [IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $project $Archive),$directory)
  $game=Join-Path $directory 'LeoRacer'
 }
 $env:APPDATA=Join-Path $directory 'user-data';New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
 $env:DOTNET_ROOT='';$env:DOTNET_BUNDLE_EXTRACT_BASE_DIR=Join-Path $directory 'launcher-runtime'
 $env:PATH=($env:PATH.Split(';') | Where-Object {$_ -notmatch 'dotnet'}) -join ';'
 $exe=Join-Path $game 'LeoRacer.console.exe'
 $script:index=0;$checks=[Collections.Generic.List[string]]::new()
 function Run([string[]]$Arguments,[string]$Expected,[int]$Exit=0){
  $script:index++;$log=Join-Path $directory ("check-$script:index.log");$err=Join-Path $directory ("check-$script:index.err")
  $command=@('--headless','--quit-after','18000','--','--drive-test')+$Arguments
  $process=Start-Process -FilePath $exe -ArgumentList $command -WorkingDirectory $game -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err -PassThru
  $deadline=[DateTime]::UtcNow.AddMinutes(3)
  while(-not $process.HasExited){if([DateTime]::UtcNow -gt $deadline){$process.Kill($true);throw 'Offline game check timed out'};Start-Sleep -Milliseconds 250}
  $process.WaitForExit()
  # Start-Process flushes its redirected streams asynchronously after exit.
  $text=$null
  for($attempt=0;$attempt -lt 40;$attempt++){
   try{$text=([IO.File]::ReadAllText($log)+[IO.File]::ReadAllText($err));break}catch [IO.IOException]{Start-Sleep -Milliseconds 100}
  }
  if($null -eq $text){throw 'Redirected process output did not close'}
  if($process.ExitCode -ne $Exit -or $text -notmatch $Expected -or $text -match 'SCRIPT ERROR|SHADER ERROR'){throw "Offline check failed: $($Arguments -join ' '); see $log and $err"}
  $checks.Add($Arguments -join ' ');Write-Host "OFFLINE PASS $($Arguments -join ' ')";return $text
 }
 if(-not(Get-ChildItem -LiteralPath $game -Recurse -Filter coreclr.dll) -or -not(Get-ChildItem -LiteralPath $game -Recurse -Filter e_sqlite3.dll)){throw 'Bundled .NET/SQLite missing'}
 $before=@{exe=(Get-FileHash (Join-Path $game 'LeoRacer.exe')).Hash;core=(Get-FileHash (Join-Path $game 'LeoRacer.pck')).Hash}
 $null=Run @('--verify-boot-art') 'BOOT_ART_VALIDATION.*"status":"PASS"'
 $content=Run @('--verify-content') 'CONTENT_VALIDATION_OK'
 if($content -notmatch 'TRACK_VERIFIED astra_coast official=true' -or $content -notmatch 'TRACK_VERIFIED colombo_city official=true'){throw 'Stock tracks unexpectedly excluded from official records'}
 $null=Run @('--verify-content-refresh') 'CONTENT_REFRESH_TEST.*"status":"PASS"'
 $cold=Run @('--validate-vehicles') 'VEHICLE_VALIDATION.*"status":"PASS"'
 if($cold -match '"official":false'){throw 'Stock vehicles unexpectedly unranked'}
 $null=Run @('--validate-vehicles') '"cache_hit":true'
 $null=Run @('--ui-smoke-test') 'UI_PACKAGE_SMOKE.*"status":"PASS"'
 foreach($track in @('astra_coast','colombo_city')){$null=Run @('--smoke-test',('--track='+$track)) 'LEO_TEST_REPORT.*"status":"PASS"'}
 if($Extended){
  $vehicles=Join-Path $game 'GameAssets/vehicles'
  $pending=Join-Path $vehicles 'pending.glb';[IO.File]::WriteAllBytes($pending,[IO.File]::ReadAllBytes((Join-Path $vehicles 'duster/model.glb')))
  try{$null=Run @('--validate-vehicles') '"needs_setup":\["pending.glb"\]'}finally{Remove-Item -LiteralPath $pending}
  $bad=Join-Path $vehicles 'broken_fixture';New-Item -ItemType Directory $bad | Out-Null
  $metadata=Get-Content (Join-Path $vehicles 'duster/vehicle.json') -Raw | ConvertFrom-Json;$metadata.id='broken_fixture'
  [IO.File]::WriteAllText((Join-Path $bad 'vehicle.json'),($metadata | ConvertTo-Json -Depth 30));[IO.File]::WriteAllBytes((Join-Path $bad 'model.glb'),[byte[]](1,2,3))
  try{$null=Run @('--validate-vehicles') 'Damaged GLB header' 2}finally{Remove-Item -LiteralPath (Join-Path $bad 'model.glb'),(Join-Path $bad 'vehicle.json');Remove-Item -LiteralPath $bad}
  $probeSource=Join-Path $project 'build/content-vehicles/pony'
  if(-not(Test-Path (Join-Path $probeSource 'optimized-textures.json'))){throw 'Build/optimize the Pony probe before extended verification'}
  $probe=Join-Path $vehicles 'contributor_probe';Copy-Item -LiteralPath $probeSource -Destination $probe -Recurse
  $metadata=Get-Content (Join-Path $probe 'vehicle.json') -Raw | ConvertFrom-Json;$metadata.id='contributor_probe';$metadata.display_name='Contributor Probe'
  [IO.File]::WriteAllText((Join-Path $probe 'vehicle.json'),($metadata | ConvertTo-Json -Depth 30))
  $validation=Run @('--validate-vehicles') '"id":"contributor_probe"'
  if($validation -notmatch '"compressed_materials":[1-9]'){throw 'Export template failed to use DDS sidecars'}
  $null=Run @('--smoke-test','--vehicle=contributor_probe','--track=astra_coast') 'LEO_TEST_REPORT.*"status":"PASS"'
  $addonSource=Join-Path $project 'build/content-tracks/community_example';$addon=Join-Path $game 'GameAssets/tracks/community_example'
  Copy-Item -LiteralPath $addonSource -Destination $addon -Recurse
  $null=Run @('--smoke-test','--track=community_example') 'LEO_TEST_REPORT.*"status":"PASS"'
  $cacheRoot=Join-Path $env:APPDATA 'Godot/app_userdata'
  $cacheFiles=@(Get-ChildItem -LiteralPath $cacheRoot -Recurse -File | Where-Object {$_.FullName -match '[\\/]content-cache[\\/]vehicles[\\/]'} )
  if($cacheFiles.Count -eq 0){throw 'Expected disposable vehicle cache files'}
  foreach($file in $cacheFiles){Remove-Item -LiteralPath $file.FullName}
  $null=Run @('--validate-vehicles') '"cache_hit":false'
  $readonly=Get-ChildItem -LiteralPath $vehicles -Recurse -File
  try{
   foreach($file in $readonly){$file.IsReadOnly=$true}
   $null=Run @('--validate-vehicles') 'VEHICLE_VALIDATION.*"status":"PASS"'
  } finally {foreach($file in $readonly){$file.IsReadOnly=$false}}
 }
 if((Get-FileHash (Join-Path $game 'LeoRacer.exe')).Hash -ne $before.exe -or (Get-FileHash (Join-Path $game 'LeoRacer.pck')).Hash -ne $before.core){throw 'Content tests changed the executable/core'}
 $report=@{status='PASS';sdk_environment_removed=$true;network_required=$false;checks=$checks.ToArray();extended=[bool]$Extended;exe_and_core_unchanged=$true;folder=$game}
 $report | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 build/modularity/offline-package.json
 Write-Host 'MODULARITY_OFFLINE_PACKAGE PASS'
} finally {foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name])};Pop-Location}
