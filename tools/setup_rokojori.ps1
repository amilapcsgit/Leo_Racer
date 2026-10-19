$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$cache=Join-Path $project '.tools/rokojori-v0.6.zip'
$lock=Get-Content (Join-Path $project 'dependency-lock.json') -Raw | ConvertFrom-Json
$entry=$lock.'rokojori_action_library-v0.6.zip'
New-Item -ItemType Directory -Force (Split-Path $cache -Parent) | Out-Null
if (-not (Test-Path $cache)) {
    # Stable official endpoint, not its expiring signed redirect.
    Invoke-WebRequest -Uri ('https://store.godotengine.org/asset/rokojori/rokojori-action-library/download/1640/?build='+[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -Headers @{'Cache-Control'='no-cache'} -OutFile $cache
}
if ((Get-FileHash $cache -Algorithm SHA256).Hash.ToLower() -ne $entry.sha256) {throw 'Rokojori v0.6 checksum mismatch'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($cache)
try {
    foreach($file in $zip.Entries) {
        if (-not $file.FullName.StartsWith($entry.prefix) -or $file.FullName.EndsWith('/')) {continue}
        $target=[IO.Path]::GetFullPath((Join-Path $project $file.FullName))
        if (-not $target.StartsWith($project+[IO.Path]::DirectorySeparatorChar)) {throw 'Unsafe archive entry'}
        New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($file,$target,$true)
    }
} finally {$zip.Dispose()}
