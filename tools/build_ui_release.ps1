param([string]$Version='2.0.0',[string]$BuildFolder='build/UIRefresh',[switch]$SkipExport)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
try {
 $folder=$BuildFolder
 $savedEnvironment=@{}
 foreach($name in @('TEMP','TMP','APPDATA','LOCALAPPDATA')){$savedEnvironment[$name]=[Environment]::GetEnvironmentVariable($name)}
 foreach($directory in @('build/ui-temp','build/ui-userdata','build/ui-localdata')){New-Item -ItemType Directory -Force $directory | Out-Null}
 $env:TEMP=Join-Path $project 'build/ui-temp'
 $env:TMP=$env:TEMP
 $env:APPDATA=Join-Path $project 'build/ui-userdata'
 $env:LOCALAPPDATA=Join-Path $project 'build/ui-localdata'
 if(-not $SkipExport){
  & "$PSScriptRoot/build_modular_release.ps1" -Output "$folder/LeoRacer.exe" -DebugExport -DisableEditorPlugins
  if($LASTEXITCODE -ne 0){throw 'UI release export failed'}
 }
 python tools/city_packs.py $folder
 if($LASTEXITCODE -ne 0){throw 'Content pack verification failed'}
 foreach($file in Get-ChildItem -LiteralPath $folder -Recurse -File){
  if($file.Extension -eq '.pdb' -or $file.Name -in @('ui-smoke.json','smoke-test.json','race-test.json') -or $file.Name -like 'libterrain.windows.*.dll'){Remove-Item -LiteralPath $file.FullName}
 }
 @'
LEO RACER - STREET RACING
Run LeoRacer.exe. Keep the whole folder together.
Go Race opens one setup screen. Choose 1 or 2 players, then Start Race.
Auto uses connected mapped controllers first, then keyboard.
Shared keyboard: P1 WASD, Space drift, Left Shift nitro, R recover, H horn.
P2 Arrows, Right Ctrl drift, Right Shift nitro, Backspace recover, Enter horn.
Esc / P pauses both racers. Reconnect and choose Keep Racing to resume.
Spoken cheers are offline synthesized English, adjustable in Settings.
The garage driver carousel has two arrows and no scrollbar.
Loading alternates the original day artwork and current night artwork.
Existing settings and records are retained. No SDK or network is required.
Attribution and licenses: GameAssets/licenses.
'@ | Set-Content -Encoding utf8 "$folder/README.txt"
 @'
@echo off
cd /d "%~dp0"
start "" "LeoRacer.exe" --rendering-method gl_compatibility --rendering-driver opengl3
'@ | Set-Content -Encoding ascii "$folder/Play Compatibility.cmd"
 if($Version.Contains('-dev')){
  "`nColombo visuals development preview: assembled districts, shaped coast and bright tropical midday. Base neon_ui e20c7ed. Public releases are unchanged." | Add-Content -Encoding utf8 "$folder/README.txt"
  $development=@{version=$Version;branch=(& git branch --show-current);source_commit=(& git rev-parse HEAD);base_commit='e20c7ed';public_release=$false;template='Godot 4.7.2 checked/debug'}
  $development | ConvertTo-Json | Set-Content -Encoding utf8 "$folder/development-build.json"
 }
 python tools/package_ui.py --version $Version --folder $folder
 if($LASTEXITCODE -ne 0){throw 'ZIP packaging failed'}
} finally {
 foreach($name in $savedEnvironment.Keys){[Environment]::SetEnvironmentVariable($name,$savedEnvironment[$name])}
 Pop-Location
}
