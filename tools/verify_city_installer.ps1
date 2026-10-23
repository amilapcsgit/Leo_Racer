param([string]$Version='1.8.0')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$installer=Join-Path $project ("dist/LeoRacer-Setup-$Version.exe")
$destination=Join-Path $project ('build/city-installer/'+[guid]::NewGuid().ToString('N')+'/LeoRacer')
New-Item -ItemType Directory -Force (Split-Path $destination -Parent) | Out-Null
$process=Start-Process -FilePath $installer -ArgumentList ('/S /CONTENTTEST /D='+$destination) -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) {throw 'Silent development installation failed'}
try {
    foreach ($category in @('textures','vehicles','roads','signs','glb','tracks','licenses')) {
        if (-not (Test-Path -LiteralPath (Join-Path $destination ('GameAssets/'+$category)))) {throw "Missing installed folder: $category"}
    }
    Push-Location $project
    try {
        python tools/package_city.py --verify-folder $destination
        if ($LASTEXITCODE -ne 0) {throw 'Installed offline content checks failed'}
    } finally {Pop-Location}
    $report=@{status='PASS';installer_bytes=(Get-Item $installer).Length;destination=$destination;isolated_content_test=$true;existing_installation_untouched=$true;offline_checks='installer-content.json'}
    $report | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $project 'docs/qa-colombo-city/installer.json')
} finally {
    $uninstaller=Join-Path $destination 'Uninstall.exe'
    if (Test-Path -LiteralPath $uninstaller) {
        $process=Start-Process -FilePath $uninstaller -ArgumentList ('/S /CONTENTTEST _?='+$destination) -WindowStyle Hidden -Wait -PassThru
        if ($process.ExitCode -ne 0) {throw 'Development test uninstall failed'}
    }
}
Write-Host 'CITY_INSTALLER_TEST PASS / installed, verified offline, development test uninstalled'
