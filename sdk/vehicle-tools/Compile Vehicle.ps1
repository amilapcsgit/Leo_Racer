param([Parameter(Mandatory=$true)][string]$VehicleFolder,[Parameter(Mandatory=$true)][string]$Output,[string]$Godot='godot')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$source=[IO.Path]::GetFullPath($VehicleFolder)
$destination=[IO.Path]::GetFullPath($Output)
if($destination -eq $source -or $destination.StartsWith($source+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Use a separate output directory to preserve the source'}
& $Godot --headless --path (Join-Path $project 'vehicle-tools') --editor --import --quit
if($LASTEXITCODE){throw 'SDK import failed'}
& $Godot --headless --path (Join-Path $project 'vehicle-tools') --script res://compile_vehicle260.gd -- "--source=$source" "--destination=$destination"
if($LASTEXITCODE){throw 'Vehicle compilation failed'}
$manifest=Get-Content -LiteralPath (Join-Path $source 'vehicle.json') -Raw | ConvertFrom-Json
foreach($file in Get-ChildItem -LiteralPath $source -Recurse -File){
 if($file.Extension -in @('.glb','.blend','.pck','.scn') -or $file.Name -eq 'vehicle.json'){continue}
 $relative=$file.FullName.Substring($source.Length+1);$target=Join-Path $destination $relative
 New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
 Copy-Item -LiteralPath $file.FullName -Destination $target
}
Write-Output 'VEHICLE_API_2_READY'
