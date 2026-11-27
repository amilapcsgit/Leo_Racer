param(
    [Parameter(Mandatory=$true)][int]$RunnerId,
    [Parameter(Mandatory=$true)][string]$CandidatePath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][string]$ProfileRoot
)
$ErrorActionPreference = 'Stop'
$gamePath = Join-Path ([IO.Path]::GetFullPath($CandidatePath)) 'LeoRacer.exe'
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
while (Get-Process -Id $RunnerId -ErrorAction SilentlyContinue) {
    foreach ($gameProcess in @(Get-Process -Name LeoRacer -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $gamePath })) {
        $completed = @{}
        foreach ($renderer in @('forward','compatibility')) {
            $report = Join-Path $ProfileRoot "$renderer/profile.json"
            if (Test-Path -LiteralPath $report) {
                try { $completed[$renderer] = @((Get-Content -LiteralPath $report -Raw | ConvertFrom-Json).cases).Count } catch {}
            }
        }
        @{unix_ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();pid=$gameProcess.Id;
          working_set_bytes=$gameProcess.WorkingSet64;peak_working_set_bytes=$gameProcess.PeakWorkingSet64;
          completed_rows=$completed} | ConvertTo-Json -Compress -Depth 4 | Add-Content -LiteralPath $OutputPath
    }
    Start-Sleep -Seconds 2
}
