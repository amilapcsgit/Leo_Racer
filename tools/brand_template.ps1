param([switch]$DebugTemplate)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$editor=Join-Path $project '.tools/rcedit-x64.exe'
if (-not (Test-Path $editor)) {Invoke-WebRequest -Uri 'https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe' -OutFile $editor}
if ((Get-FileHash $editor -Algorithm SHA256).Hash.ToLower() -ne '3e7801db1a5edbec91b49a24a094aad776cb4515488ea5a4ca2289c400eade2a') {throw 'Resource editor checksum mismatch'}
# Brand the template BEFORE Godot appends its embedded PCK, preserving offsets.
$template=if ($DebugTemplate) {'windows_debug_x86_64.exe'} else {'windows_release_x86_64.exe'}
& $editor (Join-Path $project ('.tools/templates/'+$template)) --set-icon (Join-Path $project 'assets/art/launcher/leo-road-crest.ico') --set-version-string ProductName 'Leo Racer' --set-file-version ([regex]::Match((Get-Content (Join-Path $project 'export_presets.cfg') -Raw),'application/file_version="([^"]+)"').Groups[1].Value) --set-product-version ([regex]::Match((Get-Content (Join-Path $project 'export_presets.cfg') -Raw),'application/product_version="([^"]+)"').Groups[1].Value)
if ($LASTEXITCODE -ne 0) {throw 'Application icon update failed'}
