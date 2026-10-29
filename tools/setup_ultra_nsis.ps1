$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$archive=Join-Path $project '.tools/nsis-3.13.zip'
if (-not (Test-Path $archive)) {Invoke-WebRequest -Uri 'https://downloads.sourceforge.net/project/nsis/NSIS%203/3.13/nsis-3.13.zip' -OutFile $archive}
$bytes=[IO.File]::ReadAllBytes($archive)
if ($bytes.Length -lt 2 -or $bytes[0] -ne 80 -or $bytes[1] -ne 75) {
    $html=[Text.Encoding]::UTF8.GetString($bytes)
    $match=[regex]::Match($html,'http-equiv="refresh" content="5; url=([^"]+)')
    if (-not $match.Success) {throw 'NSIS download is not an archive'}
    $download=[Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
    if ($download -notmatch '^https://[^/]*sourceforge\.net/') {throw 'Unexpected NSIS download host'}
    Invoke-WebRequest -Uri $download -OutFile $archive
}
if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLower() -ne 'ba63dffc4410ee89193e1cb5a41989991bd77c61068da17e3156d136b7b0b3d8') {throw 'NSIS 3.13 checksum mismatch'}
Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $project '.tools/nsis') -Force
