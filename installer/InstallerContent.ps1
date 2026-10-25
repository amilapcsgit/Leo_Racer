param([ValidateSet('Install','Uninstall')][string]$Mode,[string]$Destination,[string]$Payload)
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
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  $backup=Join-Path $root ('ContentBackups\'+[guid]::NewGuid().ToString('N'))
  $backupIndex=@{}
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
     [IO.File]::WriteAllText((Join-Path $backup 'index.json'),($backupIndex | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
    }
   }
   New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
   $temporary=Join-Path (Split-Path $target -Parent) ('.leo-'+[guid]::NewGuid().ToString('N'))
   Copy-Item -LiteralPath $file.FullName -Destination $temporary -Force
   Move-Item -LiteralPath $temporary -Destination $target -Force
   $owned[$relative]=$newHash
  }
  $json=@{format=1;version='2.3.0';files=$owned} | ConvertTo-Json -Depth 5
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
