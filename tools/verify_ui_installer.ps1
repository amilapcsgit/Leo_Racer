param([string]$Version='2.0.0')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$installer=Join-Path $project ("dist/LeoRacer-Setup-$Version.exe")
$destination=Join-Path $project ('build/ui-installer/'+[guid]::NewGuid().ToString('N')+'/LeoRacer')
New-Item -ItemType Directory -Force (Split-Path $destination -Parent) | Out-Null
$process=Start-Process -FilePath $installer -ArgumentList ('/S /CONTENTTEST /D='+$destination) -WindowStyle Hidden -Wait -PassThru
if($process.ExitCode -ne 0){throw 'Isolated installation failed'}
try {
 & "$PSScriptRoot/verify_ui_package.ps1" -Folder $destination -Archive "dist/LeoRacer-$Version-win64.zip"
 if($LASTEXITCODE -ne 0){throw 'Installed game checks failed'}
} finally {
 $uninstaller=Join-Path $destination 'Uninstall.exe'
 if(Test-Path -LiteralPath $uninstaller){
  $process=Start-Process -FilePath $uninstaller -ArgumentList ('/S /CONTENTTEST _?='+$destination) -WindowStyle Hidden -Wait -PassThru
  if($process.ExitCode -ne 0){throw 'Isolated uninstall failed'}
 }
}
Write-Host 'UI_INSTALLER_TEST PASS / installed, verified offline, uninstalled without changing user installation'
