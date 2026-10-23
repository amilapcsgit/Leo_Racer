param([string]$Output='build/ModularGarage/Leo Racer.exe',[switch]$DebugExport,[switch]$DisableEditorPlugins)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
Push-Location $project
$originalProject=$null
try {
    if($DisableEditorPlugins){
        $projectFile=Join-Path $project 'project.godot'
        $originalProject=[IO.File]::ReadAllBytes($projectFile)
        $projectText=[Text.Encoding]::UTF8.GetString($originalProject)
        $projectText=[regex]::Replace($projectText,'(?ms)(\[editor_plugins\]\s*)enabled=PackedStringArray\([^\r\n]*\)','$1enabled=PackedStringArray()')
        [IO.File]::WriteAllText($projectFile,$projectText,[Text.UTF8Encoding]::new($false))
    }
    $importArgs=@('--headless','--editor','--import','--quit')
    & "$PSScriptRoot/run_godot.ps1" @importArgs
    if ($LASTEXITCODE -ne 0) {throw 'Asset import failed'}
    & "$PSScriptRoot/run_godot.ps1" --headless --script res://tools/validate_modular_catalog.gd
    if ($LASTEXITCODE -ne 0) {throw 'Unresolved catalog assets: complete setup before export'}
    $sdk=[IO.Path]::GetFullPath((Join-Path $project '../../tools/dotnet'))
    if (Test-Path (Join-Path $project '.tools/dotnet/dotnet.exe')) {$sdk=Join-Path $project '.tools/dotnet'}
    $env:DOTNET_ROOT=$sdk
    $env:PATH=$sdk+';'+$env:PATH
    $env:DOTNET_CLI_HOME=Join-Path $project 'build/dotnet-home'
    $env:NUGET_PACKAGES=Join-Path $project '.tools/nuget'
    $env:MSBUILDDISABLENODEREUSE='1'
    & (Join-Path $sdk 'dotnet.exe') build LeoRacer.csproj -c Debug -p:RestoreLockedMode=true
    if ($LASTEXITCODE -ne 0) {throw '.NET bridge build failed'}
    & "$PSScriptRoot/brand_template.ps1" -DebugTemplate:$DebugExport
    New-Item -ItemType Directory -Force -Path (Split-Path $Output -Parent) | Out-Null
    $exportLog=Join-Path $project 'build/development-export-check.log'
    $mode=if ($DebugExport) {'--export-debug'} else {'--export-release'}
    $exportArgs=@('--headless',$mode,'Windows Desktop',$Output)
    & "$PSScriptRoot/run_godot.ps1" @exportArgs 2>&1 | Tee-Object -FilePath $exportLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -Path $exportLog -Pattern 'Export .NET Project: Failed|SCRIPT ERROR' -Quiet)) {throw 'Windows or .NET export failed'}
    $folder=Split-Path $Output -Parent
    if (-not (Get-ChildItem $folder -Recurse -Filter 'LeoRacer.dll')) {throw 'Export is missing .NET assemblies'}
    if (-not (Get-ChildItem $folder -Recurse -Filter 'e_sqlite3.dll')) {throw 'Export is missing Windows native SQLite'}
} finally {
    if($null -ne $originalProject){[IO.File]::WriteAllBytes((Join-Path $project 'project.godot'),$originalProject)}
    Pop-Location
}
