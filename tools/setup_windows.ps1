param([string]$AssetArchives)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$project=Split-Path $PSScriptRoot -Parent
$localTools=Join-Path $project '.tools'
$lock=Get-Content (Join-Path $project 'toolchain-lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Force $localTools | Out-Null

function Get-PinnedArchive([string]$name) {
    $entry=$lock.files | Where-Object {$_.file -eq $name}
    if (-not $entry) {throw "Unpinned dependency: $name"}
    $cache=Join-Path $localTools $name
    if (-not (Test-Path -LiteralPath $cache)) {
        Write-Host "Downloading checksum-pinned $name"
        # HTTP/1.1 avoids the intermittent .NET HTTP/2 EOF seen on hosted Windows.
        $partial=$cache+'.partial'
        & curl.exe --http1.1 --fail --location --silent --show-error --retry 4 --retry-all-errors --connect-timeout 30 --max-time 300 --output $partial $entry.url
        if ($LASTEXITCODE -ne 0) {throw "Download failed: $name"}
        if ((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash.ToLower() -ne $entry.sha256) {throw "Checksum mismatch: $name"}
        Move-Item -LiteralPath $partial -Destination $cache -Force
    }
    if ((Get-FileHash -LiteralPath $cache -Algorithm SHA256).Hash.ToLower() -ne $entry.sha256) {throw "Checksum mismatch: $name"}
    return $cache
}
function Expand-Safe([string]$archive,[string]$destination,[string]$prefix='') {
    $resolved=[IO.Path]::GetFullPath($destination)
    New-Item -ItemType Directory -Force $resolved | Out-Null
    $zip=[IO.Compression.ZipFile]::OpenRead($archive)
    try {
        foreach($entry in $zip.Entries) {
            if (-not $entry.FullName.StartsWith($prefix) -or $entry.FullName.EndsWith('/')) {continue}
            $relative=$entry.FullName.Substring($prefix.Length)
            if ($prefix -eq 'templates/' -and -not ($relative -like 'windows*x86_64*' -or $relative -eq 'version.txt')) {continue}
            $target=[IO.Path]::GetFullPath((Join-Path $resolved $relative))
            if (-not $target.StartsWith($resolved+[IO.Path]::DirectorySeparatorChar)) {throw 'Unsafe ZIP entry'}
            New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$true)
        }
    } finally {$zip.Dispose()}
}

if ($AssetArchives) {
    $addonLock=Get-Content (Join-Path $project 'dependency-lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach($item in $addonLock.PSObject.Properties) {
        $path=Join-Path $AssetArchives $item.Name
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower() -ne $item.Value.sha256) {throw "Addon checksum mismatch: $($item.Name)"}
        # The prefix is retained because it is already relative to the project.
        $zip=[IO.Compression.ZipFile]::OpenRead($path)
        try {
            foreach($entry in $zip.Entries) {
                if (-not $entry.FullName.StartsWith($item.Value.prefix) -or $entry.FullName.EndsWith('/') -or $entry.FullName.EndsWith('.import')) {continue}
                if ($entry.FullName.Contains('/bin/') -and -not $entry.FullName.Contains('.windows.')) {continue}
                $target=[IO.Path]::GetFullPath((Join-Path $project $entry.FullName))
                if (-not $target.StartsWith($project+[IO.Path]::DirectorySeparatorChar)) {throw 'Unsafe addon ZIP entry'}
                New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$true)
            }
        } finally {$zip.Dispose()}
    }
    Get-ChildItem (Join-Path $project 'addons/terrain_3d') -Recurse -Filter '*.gd' | ForEach-Object {
        $text=Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
        [IO.File]::WriteAllText($_.FullName,($text -replace '\bBaker\b','Terrain3DBaker'))
    }
    Get-ChildItem (Join-Path $project 'addons/EZ-Tree-Godot-Port') -Recurse -Filter '*.gd' | ForEach-Object {
        $text=Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
        [IO.File]::WriteAllText($_.FullName,$text.Replace('res://addons/ez-tree-godot-port/','res://addons/EZ-Tree-Godot-Port/'))
    }
}
if (-not (Test-Path (Join-Path $project 'addons/rokojori_action_library/plugin.cfg'))) {
    & "$PSScriptRoot/setup_rokojori.ps1"
    if ($LASTEXITCODE -ne 0) {throw 'Rokojori setup failed'}
}
$sdk=Join-Path $localTools 'dotnet/dotnet.exe'
$sharedSdk=[IO.Path]::GetFullPath((Join-Path $project '../../tools/dotnet/dotnet.exe'))
if (-not (Test-Path $sdk) -and (Test-Path $sharedSdk)) {$sdk=$sharedSdk}
if (-not (Test-Path $sdk)) {Expand-Safe (Get-PinnedArchive 'dotnet-sdk.zip') (Join-Path $localTools 'dotnet')}
$engine=Join-Path $localTools 'godot/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
$sharedEngine=[IO.Path]::GetFullPath((Join-Path $project '../../tools/godot-net/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'))
if (-not (Test-Path $engine) -and (Test-Path $sharedEngine)) {$engine=$sharedEngine}
if (-not (Test-Path $engine)) {Expand-Safe (Get-PinnedArchive 'godot-net.zip') (Join-Path $localTools 'godot')}
if (-not (Test-Path (Join-Path $localTools 'templates/windows_release_x86_64.exe'))) {
    Expand-Safe (Get-PinnedArchive 'godot-net-templates.tpz') (Join-Path $localTools 'templates') 'templates/'
}
$env:DOTNET_ROOT=Split-Path $sdk -Parent
$env:PATH=$env:DOTNET_ROOT+';'+$env:PATH
$env:DOTNET_CLI_HOME=Join-Path $localTools 'cli-home'
$env:NUGET_PACKAGES=Join-Path $localTools 'nuget'
$env:DOTNET_CLI_TELEMETRY_OPTOUT='1'
Push-Location $project
try {
    & $sdk restore LeoRacer.csproj --locked-mode
    if ($LASTEXITCODE -ne 0) {throw 'Locked dependency restore failed'}
    & $sdk build LeoRacer.sln --nologo --no-restore
    if ($LASTEXITCODE -ne 0) {throw 'C# build failed'}
    & $engine --headless --editor --import --quit --path $project
    if ($LASTEXITCODE -ne 0) {throw 'Godot import failed'}
    Write-Host 'Colombo setup complete. Open Colombo in Godot.cmd starts the .NET editor.'
} finally {Pop-Location}
