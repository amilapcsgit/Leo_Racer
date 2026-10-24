param([string]$Version='2.0.0',[string]$BuildFolder='build/ModularGarage',[switch]$Development,[switch]$CityAssets,[switch]$ModularContent)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$archive=Join-Path $project '.tools/nsis-3.13.zip'
$compiler=Join-Path $project '.tools/nsis/nsis-3.13/Bin/makensis.exe'
if (-not (Test-Path $compiler)) {
    # SourceForge may return an HTML download page; follow its official refresh.
    Invoke-WebRequest -Uri 'https://downloads.sourceforge.net/project/nsis/NSIS%203/3.13/nsis-3.13.zip' -OutFile $archive
    $bytes=[IO.File]::ReadAllBytes($archive)
    if ($bytes[0] -ne 80 -or $bytes[1] -ne 75) {
        $html=[Text.Encoding]::UTF8.GetString($bytes)
        $match=[regex]::Match($html,'http-equiv="refresh" content="5; url=([^"]+)')
        if (-not $match.Success) {throw 'NSIS download is not an archive'}
        Invoke-WebRequest -Uri ([Net.WebUtility]::HtmlDecode($match.Groups[1].Value)) -OutFile $archive
    }
    if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLower() -ne 'ba63dffc4410ee89193e1cb5a41989991bd77c61068da17e3156d136b7b0b3d8') {throw 'NSIS 3.13 checksum mismatch'}
    Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $project '.tools/nsis') -Force
}
$build=[IO.Path]::GetFullPath((Join-Path $project $BuildFolder))
$owned=@();$payload=@()
if($ModularContent){
 $managed=Get-Content (Join-Path $build '.managed-build.json') -Raw | ConvertFrom-Json
 $files=@($managed.PSObject.Properties.Name | ForEach-Object {
  $candidate=[IO.Path]::GetFullPath((Join-Path $build $_))
  if(-not $candidate.StartsWith($build+[IO.Path]::DirectorySeparatorChar)){throw 'Installer payload escapes build folder'}
  Get-Item -LiteralPath $candidate
 })
}else{$files=@(Get-ChildItem -LiteralPath $build -Recurse -File)}
foreach($file in $files){
 $relative=$file.FullName.Substring($build.Length+1)
 $owned+='Delete "$INSTDIR\'+$relative+'"'
 $parent=Split-Path $relative -Parent
 $payload+='SetOutPath "$INSTDIR'+$(if($parent){'\'+$parent}else{''})+'"'
 $payload+='File "'+$file.FullName+'"'
}
Get-ChildItem -LiteralPath $build -Recurse -Directory | Sort-Object {$_.FullName.Length} -Descending | ForEach-Object {$owned+='RMDir "$INSTDIR\'+$_.FullName.Substring($build.Length+1)+'"'}
[IO.File]::WriteAllLines((Join-Path $project 'installer/owned-files.nsh'),$owned)
[IO.File]::WriteAllLines((Join-Path $project 'installer/payload-files.nsh'),$payload)
Push-Location (Join-Path $project 'installer')
try {
    $flags=@("/DVERSION=$Version","/DCHANNEL=$($Version.Contains('-rc'))","/DBUILD_ROOT=$build")
    if ($Development) {$flags+='/DDEVELOPMENT'}
    if ($CityAssets) {$flags+='/DCITY_ASSETS'}
    if ($ModularContent) {$flags+='/DMODULAR_CONTENT'}
    & $compiler @flags 'LeoRacer.nsi'
    if ($LASTEXITCODE -ne 0) {throw 'NSIS build failed'}
} finally {Pop-Location}
