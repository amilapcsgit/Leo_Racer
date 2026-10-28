param([ValidateSet('Install','Uninstall')][string]$Mode,[string]$Destination,[string]$Payload,[string]$Version='2.3.0')
$ErrorActionPreference='Stop'
try {
 $root=[IO.Path]::GetFullPath($Destination).TrimEnd('\')
 if($root.Length -lt 5){throw 'Invalid installation directory'}
 function Get-OwnedHash([string]$filePath){
  $hasher=[Security.Cryptography.SHA256]::Create();$stream=[IO.File]::OpenRead($filePath)
  try{return [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-','').ToLowerInvariant()}finally{$stream.Dispose();$hasher.Dispose()}
 }
 function Resolve-Owned([string]$relative){
  if([IO.Path]::IsPathRooted($relative)){throw 'Absolute ownership path rejected'}
  $path=[IO.Path]::GetFullPath((Join-Path $root $relative))
  if(-not $path.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Ownership path escapes installation'}
  return $path
 }
 $ledger=Join-Path $root '.leo-installer-owned.json';$owned=@{}
 if(Test-Path -LiteralPath $ledger){
  $record=Get-Content -LiteralPath $ledger -Raw | ConvertFrom-Json
  if($record.format -ne 1){throw 'Unsupported installer ownership record'}
  foreach($entry in $record.files.PSObject.Properties){$null=Resolve-Owned $entry.Name;$owned[$entry.Name]=[string]$entry.Value}
 }
 if($Mode -eq 'Install'){
  $stage=[IO.Path]::GetFullPath($Payload).TrimEnd('\')
  if(-not (Test-Path -LiteralPath (Join-Path $stage 'LeoRacer.exe'))){throw 'Incomplete selected payload'}
  $requiredIndex=Join-Path $stage 'required-payload.json'
  if(Test-Path -LiteralPath $requiredIndex){
   $required=Get-Content -LiteralPath $requiredIndex -Raw | ConvertFrom-Json
   foreach($entry in $required.files.PSObject.Properties){
    $candidate=[IO.Path]::GetFullPath((Join-Path $stage $entry.Name))
    if(-not $candidate.StartsWith($stage+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Required payload path escapes staging'}
    if(-not (Test-Path -LiteralPath $candidate)){throw 'Incomplete installer extraction. Choose a shorter TEMP folder and try again.'}
    if((Get-OwnedHash $candidate) -ne [string]$entry.Value){throw 'Installer payload verification failed'}
   }
  }
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  $backup=Join-Path $root ('ContentBackups\'+[guid]::NewGuid().ToString('N'))
  $backupIndex=@{}
  # Superseded managed vehicle files must leave discovery before installing API 2.
  # Unknown files and custom packages have no ownership entry and are preserved.
  $incoming=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($file in Get-ChildItem -LiteralPath $stage -Recurse -File){$null=$incoming.Add($file.FullName.Substring($stage.Length+1))}
  foreach($relative in @($owned.Keys)){
   if($relative.Replace('/','\').StartsWith('GameAssets\vehicles\',[StringComparison]::OrdinalIgnoreCase) -and -not $incoming.Contains($relative)){
    $target=Resolve-Owned $relative
    if(Test-Path -LiteralPath $target){
     $archiveRoot=[IO.Path]::GetFullPath((Join-Path $backup 'Superseded'))
     $archived=[IO.Path]::GetFullPath((Join-Path $archiveRoot $relative))
     if(-not $archived.StartsWith($archiveRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Archive path escapes backup'}
     New-Item -ItemType Directory -Force -Path (Split-Path $archived -Parent) | Out-Null
     Move-Item -LiteralPath $target -Destination $archived
     $backupIndex[$relative]=@{file=$archived.Substring($backup.Length+1);modified=((Get-OwnedHash $archived) -ne $owned[$relative])}
    }
    $owned.Remove($relative)
   }
  }
  if($backupIndex.Count){[IO.File]::WriteAllText((Join-Path $backup 'index.json'),($backupIndex | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))}
  foreach($file in Get-ChildItem -LiteralPath $stage -Recurse -File){
   $relative=$file.FullName.Substring($stage.Length+1);$target=Resolve-Owned $relative
   if($target.Length -ge 260){throw 'Choose a shorter installation folder: Windows path length limit reached'}
   $newHash=(Get-OwnedHash $file.FullName)
   if(Test-Path -LiteralPath $target){
    $existing=(Get-OwnedHash $target)
    if($existing -eq $newHash){$owned[$relative]=$newHash;continue}
    if(-not $owned.ContainsKey($relative) -or $existing -ne $owned[$relative]){
     $saved=Join-Path $backup ($existing.Substring(0,16)+'-'+$file.Name);New-Item -ItemType Directory -Force -Path $backup | Out-Null
     Copy-Item -LiteralPath $target -Destination $saved -Force
     $backupIndex[$relative]=[IO.Path]::GetFileName($saved)
     [IO.File]::WriteAllText((Join-Path $backup 'index.json'),($backupIndex | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
    }
   }
   New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
   $temporary=Join-Path (Split-Path $target -Parent) ('.leo-'+[guid]::NewGuid().ToString('N'))
   Copy-Item -LiteralPath $file.FullName -Destination $temporary -Force
   Move-Item -LiteralPath $temporary -Destination $target -Force
   $owned[$relative]=$newHash
  }
  $json=@{format=1;version=$Version;files=$owned} | ConvertTo-Json -Depth 5
  [IO.File]::WriteAllText($ledger+'.new',$json,[Text.UTF8Encoding]::new($false))
  Move-Item -LiteralPath ($ledger+'.new') -Destination $ledger -Force
 }else{
  if(-not (Test-Path -LiteralPath $ledger)){throw 'Ownership record missing; preserving installation'}
  foreach($relative in $owned.Keys){
   $target=Resolve-Owned $relative
   if((Test-Path -LiteralPath $target) -and (Get-OwnedHash $target) -eq $owned[$relative]){Remove-Item -LiteralPath $target}
  }
  Remove-Item -LiteralPath $ledger
  Get-ChildItem -LiteralPath $root -Directory -Recurse | Sort-Object {$_.FullName.Length} -Descending | ForEach-Object {
   if(-not (Get-ChildItem -LiteralPath $_.FullName -Force | Select-Object -First 1)){Remove-Item -LiteralPath $_.FullName}
  }
 }
 Write-Output ('CONTENT_'+$Mode.ToUpper()+'_OK');exit 0
}catch{Write-Output $_.Exception.Message;exit 1}
