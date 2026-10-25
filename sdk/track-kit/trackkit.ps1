param([ValidateSet('import-geography','edit-course','dress-scenery','validate','export')][string]$Target='edit-course',[string]$Scene='res://kandy.tscn',[string]$Output='exported')
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $PSScriptRoot
$engine=Join-Path $PSScriptRoot 'engine/Godot_v4.7.2-stable_mono_win64_console.exe'
if(-not (Test-Path -LiteralPath $engine)){throw 'Use the complete offline SDK package with its bundled engine.'}
if($Target -eq 'import-geography'){
 & './author-python/python.exe' './tools/prepare_kandy.py' --world './inputs/world' --output './data/kandy'
 if($LASTEXITCODE -ne 0){throw 'Archived geography validation/import failed'}
 exit
}
& $engine --path $PSScriptRoot --headless --editor --import --quit
if($LASTEXITCODE -ne 0){throw 'Offline authoring resource import failed'}
if($Target -eq 'edit-course'){& $engine --path $PSScriptRoot --editor $Scene;exit}
& $engine --headless --path $PSScriptRoot --script res://bake_elevated.gd -- ("--scene="+$Scene) ("--action="+$Target) ("--output="+[IO.Path]::GetFullPath((Join-Path $PSScriptRoot $Output)))
if($LASTEXITCODE -ne 0){throw 'Course validation/export failed'}
