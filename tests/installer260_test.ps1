$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $repo ('build/installer260-'+[guid]::NewGuid().ToString('N'))
$destination=Join-Path $fixture 'installed';$old=Join-Path $fixture 'old';$next=Join-Path $fixture 'next'
function Put([string]$path,[string]$text){New-Item -ItemType Directory -Force (Split-Path $path -Parent) | Out-Null;[IO.File]::WriteAllText($path,$text)}
function Assert([bool]$ok,[string]$message){if(-not $ok){throw $message}}
function Apply([string]$mode,[string]$payload){
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'installer/InstallerContent.ps1') -Mode $mode -Destination $destination -Payload $payload -Version '2.6.0'
 Assert ($LASTEXITCODE -eq 0) ('Installer '+$mode+' failed')
}
Put (Join-Path $old 'LeoRacer.exe') 'old fixture executable'
Put (Join-Path $old 'GameAssets/vehicles/duster/model.glb') 'old managed model'
Put (Join-Path $old 'GameAssets/vehicles/duster/vehicle.json') 'old managed manifest'
Put (Join-Path $old 'GameAssets/vehicles/retired/vehicle.json') 'retired managed manifest'
Apply 'Install' $old
Put (Join-Path $destination 'GameAssets/vehicles/custom/vehicle.json') 'unrelated custom vehicle'
Put (Join-Path $destination 'GameAssets/vehicles/duster/model.glb') 'modified managed model'
Put (Join-Path $next 'LeoRacer.exe') 'new fixture executable'
Put (Join-Path $next 'GameAssets/vehicles/duster/vehicle.json') 'compiled manifest'
Put (Join-Path $next 'GameAssets/vehicles/duster/vehicle.pck') 'compiled pack'
Apply 'Install' $next
Assert (-not (Test-Path (Join-Path $destination 'GameAssets/vehicles/duster/model.glb'))) 'Superseded model remains in discovery'
Assert (-not (Test-Path (Join-Path $destination 'GameAssets/vehicles/retired/vehicle.json'))) 'Retired manifest remains in discovery'
$backups=@(Get-ChildItem -LiteralPath (Join-Path $destination 'ContentBackups') -Recurse -File)
Assert (@($backups | Where-Object { $_.Name -eq 'model.glb' -and [IO.File]::ReadAllText($_.FullName) -eq 'modified managed model' }).Count -eq 1) 'Modified model backup missing'
Apply 'Install' $next
Assert ([IO.File]::ReadAllText((Join-Path $destination 'GameAssets/vehicles/custom/vehicle.json')) -eq 'unrelated custom vehicle') 'Reinstall changed custom content'
Put (Join-Path $destination 'GameAssets/vehicles/duster/vehicle.json') 'user modified compiled manifest'
Apply 'Uninstall' ''
Assert (Test-Path (Join-Path $destination 'GameAssets/vehicles/custom/vehicle.json')) 'Uninstall removed custom vehicle'
Assert ([IO.File]::ReadAllText((Join-Path $destination 'GameAssets/vehicles/duster/vehicle.json')) -eq 'user modified compiled manifest') 'Uninstall removed modified managed file'
Assert (@(Get-ChildItem -LiteralPath (Join-Path $destination 'ContentBackups') -Recurse -File).Count -eq $backups.Count) 'Uninstall removed backups'
$report=@{status='PASS';checks=8;fixture=$fixture}
$report | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $repo 'build/installer260-result.json')
Write-Output 'INSTALLER260_PASS'
