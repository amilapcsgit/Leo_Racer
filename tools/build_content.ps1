param(
 [ValidateSet('core','vehicle','track','distribution','sdk')][string]$Target='distribution',
 [string]$Id='',
 [ValidateSet('dev','full')][string]$Profile='dev',
 [string]$Version='2.2.0-modularity-dev',
 [string]$CoreFolder='build/ModularityCore',
 [string]$Output=''
)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
 if($Target -eq 'core'){
  python tools/content.py registry
  if($LASTEXITCODE -ne 0){throw 'Official content registry failed'}
  python tools/content.py stage --profile dev
  if($LASTEXITCODE -ne 0){throw 'Stage development vehicles first'}
  $saved=@{}
  foreach($name in @('TEMP','TMP','APPDATA','LOCALAPPDATA')){$saved[$name]=[Environment]::GetEnvironmentVariable($name)}
  try {
   foreach($name in @('TEMP','TMP','APPDATA','LOCALAPPDATA')){
    $directory=Join-Path $project ('build/modularity-environment/'+$name);New-Item -ItemType Directory -Force $directory | Out-Null;[Environment]::SetEnvironmentVariable($name,$directory)
   }
   ./tools/build_modular_release.ps1 -Output "$CoreFolder/LeoRacer.exe" -DebugExport -DisableEditorPlugins
   if($LASTEXITCODE -ne 0){throw 'Core export failed'}
   python tools/city_packs.py $CoreFolder --loose-vehicles
   if($LASTEXITCODE -ne 0){throw 'Pack split failed'}
   python tools/content.py core --folder $CoreFolder --version $Version
   if($LASTEXITCODE -ne 0){throw 'Core package failed'}
  } finally {foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name])}}
 } elseif($Target -eq 'vehicle'){
  if(-not $Id){throw '-Id is required'}
  python tools/content.py vehicle $Id --zip
  if($LASTEXITCODE -ne 0){throw 'Vehicle build failed'}
 } elseif($Target -eq 'track'){
  if(-not $Id){throw '-Id is required'}
  if($Id -eq 'community_example'){
   $kit=Join-Path $project 'sdk/track-kit';$destination=Join-Path $project 'build/content-tracks'
   ./tools/run_godot.ps1 @('--headless','--path',$kit,'--script','res://export.gd','--','--drive-test',('--output='+$destination))
  }else{
   ./tools/run_godot.ps1 @('--headless','--script','res://tools/build_track_content.gd','--','--drive-test',('--track-id='+$Id))
  }
  if($LASTEXITCODE -ne 0){throw 'Track export failed'}
  python tools/content.py track $Id
  if($LASTEXITCODE -ne 0){throw 'Track package failed'}
 } elseif($Target -eq 'distribution'){
  if(-not $Output){$Output="build/Modularity-$Profile"}
  python tools/content.py distribution --core $CoreFolder --profile $Profile --output $Output --version $Version
  if($LASTEXITCODE -ne 0){throw 'Distribution assembly failed'}
 } elseif($Target -eq 'sdk'){
  python tools/content.py sdk
  if($LASTEXITCODE -ne 0){throw 'SDK archive failed'}
 }
} finally {Pop-Location}
