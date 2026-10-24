param([string]$Version='2.2.0-modularity-dev')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$destination=Join-Path $project ('build/modularity-installer/'+[guid]::NewGuid().ToString('N')+'/LeoRacer')
$root=[IO.Path]::GetFullPath((Join-Path $project 'build/modularity-installer'))+[IO.Path]::DirectorySeparatorChar
if(-not [IO.Path]::GetFullPath($destination).StartsWith($root)){throw 'Test installation must stay in build/modularity-installer'}
$custom=Join-Path $destination 'GameAssets/vehicles/my_community_car'
New-Item -ItemType Directory -Force $custom | Out-Null
[IO.File]::WriteAllText((Join-Path $custom 'keep.txt'),'Contributor source must survive install/update/uninstall.')
$markerHash=(Get-FileHash (Join-Path $custom 'keep.txt')).Hash
$oldPack=Join-Path $destination 'GameAssets/vehicles/roster.pck';[IO.File]::WriteAllText($oldPack,'Obsolete stock pack fixture')
$installer=Join-Path $project "dist/LeoRacer-Setup-$Version.exe"
for($pass=0;$pass -lt 2;$pass++){
 $process=Start-Process -FilePath $installer -ArgumentList ('/S /CONTENTTEST /D='+$destination) -WindowStyle Hidden -Wait -PassThru
 if($process.ExitCode -ne 0){throw 'Isolated install/update failed'}
 if((Get-FileHash (Join-Path $custom 'keep.txt')).Hash -ne $markerHash){throw 'Install/update changed custom content'}
 if(Test-Path $oldPack){throw 'Superseded stock roster pack survived upgrade'}
}
$uninstaller=Join-Path $destination 'Uninstall.exe'
try {
 & "$PSScriptRoot/verify_modularity_package.ps1" -Folder $destination
 if($LASTEXITCODE -ne 0){throw 'Installed game checks failed'}
} finally {
 if(Test-Path $uninstaller){
  $process=Start-Process -FilePath $uninstaller -ArgumentList ('/S /CONTENTTEST _?='+$destination) -WindowStyle Hidden -Wait -PassThru
  if($process.ExitCode -ne 0){throw 'Isolated uninstall failed'}
 }
}
if((Get-FileHash (Join-Path $custom 'keep.txt')).Hash -ne $markerHash){throw 'Uninstall removed custom content'}
if(Test-Path (Join-Path $destination 'LeoRacer.exe')){throw 'Uninstall left packaged executable'}
$report=@{status='PASS';isolated_install=$true;update=$true;uninstall=$true;custom_content_preserved=$true;obsolete_roster_removed=$true;stable_installation_unchanged=$true}
$report | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $project 'build/modularity/installer.json')
Write-Host 'MODULARITY_INSTALLER PASS'
