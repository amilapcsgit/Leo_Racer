param([switch]$Editor,[switch]$Compatibility,[Parameter(ValueFromRemainingArguments=$true)][string[]]$GameArguments)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$engine=Join-Path $project '.tools/godot/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
$sdk=Join-Path $project '.tools/dotnet/dotnet.exe'
if (-not (Test-Path $engine)) {$engine=[IO.Path]::GetFullPath((Join-Path $project '../../tools/godot-net/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'))}
if (-not (Test-Path $sdk)) {$sdk=[IO.Path]::GetFullPath((Join-Path $project '../../tools/dotnet/dotnet.exe'))}
if (-not (Test-Path $engine) -or -not (Test-Path $sdk)) {throw 'Run Setup Colombo.cmd first. See docs/COLOMBO_SETUP.md.'}
$env:DOTNET_ROOT=Split-Path $sdk -Parent
$env:PATH=$env:DOTNET_ROOT+';'+$env:PATH
$env:DOTNET_CLI_TELEMETRY_OPTOUT='1'
# PowerShell consumes a literal -- when this script is called directly.
# Recover the documented game-argument boundary for diagnostic invocations.
if (($GameArguments -contains '--drive-test') -and -not ($GameArguments -contains '--')) {
    $boundary=[Array]::IndexOf($GameArguments,'--drive-test')
    $before=@();if($boundary -gt 0){$before=@($GameArguments[0..($boundary-1)])}
    $GameArguments=@($before)+@('--')+@($GameArguments[$boundary..($GameArguments.Length-1)])
}
if ($GameArguments -contains '--drive-test') {
    # Diagnostics must be writable and never share the player's actual profile.
    $env:APPDATA=Join-Path $project 'build/test-userdata'
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
}
$launch=@('--path',$project)
if ($Editor) {$launch+='--editor'}
if ($Compatibility) {$launch+=@('--rendering-method','gl_compatibility','--rendering-driver','opengl3')}
if ($GameArguments) {$launch+=$GameArguments}
& $engine @launch
exit $LASTEXITCODE
