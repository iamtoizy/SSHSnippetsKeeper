param(
    [long]$MaxSizeMB = 64,
    [string]$ArchiveRoot = "C:\ProgramData\EventArchive"
)
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Target = Join-Path $ArchiveRoot $Stamp
New-Item -Path $Target -ItemType Directory -Force | Out-Null
$Logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 }
$Candidates = @($Logs | Where-Object { ($_.FileSize / 1MB) -ge $MaxSizeMB })
if ($Candidates.Count -eq 0) {
    Write-Output "no logs above ${MaxSizeMB}MB"
    Remove-Item $Target -Force -Recurse
    exit 0
}
$Results = @()
foreach ($Log in $Candidates) {
    $SafeName = $Log.LogName -replace '[\\/:\*\?"<>|]', "_"
    $File = Join-Path $Target "$SafeName.evtx"
    & wevtutil epl $Log.LogName $File /ow:true
    $Code = $LASTEXITCODE
    $Results += [PSCustomObject]@{
        LogName  = $Log.LogName
        SizeMB   = [math]::Round($Log.FileSize / 1MB, 1)
        Records  = $Log.RecordCount
        Archive  = $File
        ExitCode = $Code
        Success  = [bool]($Code -eq 0 -and (Test-Path $File))
    }
}
$Results | Sort-Object SizeMB -Descending | Format-Table LogName, SizeMB, Records, Success -AutoSize
$Failed = @($Results | Where-Object { -not $_.Success })
foreach ($Row in $Failed) {
    Write-Warning "export failed for $($Row.LogName) code=$($Row.ExitCode)"
}
$Manifest = @{
    created = $Stamp
    host    = $env:COMPUTERNAME
    logs    = $Results
} | ConvertTo-Json -Depth 4
Set-Content -Path (Join-Path $Target "manifest.json") -Value $Manifest -Encoding UTF8
$TotalMB = [math]::Round(($Results | Measure-Object SizeMB -Sum).Sum, 1)
Write-Output "archived=$(@($Results | Where-Object { $_.Success }).Count) total=${TotalMB}MB path=$Target"
if ($Failed.Count -gt 0) {
    exit 1
}
exit 0
