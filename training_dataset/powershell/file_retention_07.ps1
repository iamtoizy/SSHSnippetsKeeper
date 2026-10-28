param(
    [string[]]$Targets = @("C:\Windows\Temp", "C:\ProgramData\App\Logs"),
    [int]$OlderThanDays = 30,
    [long]$SizeAlertMB = 500
)
$Cutoff = (Get-Date).AddDays(-$OlderThanDays)
$Summary = @()
foreach ($Target in $Targets) {
    if (-not (Test-Path $Target)) {
        Write-Warning "path missing: $Target"
        continue
    }
    $Old = Get-ChildItem -Path $Target -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $Cutoff }
    $SizeBefore = [math]::Round((($Old | Measure-Object Length -Sum).Sum) / 1MB, 1)
    foreach ($File in $Old) {
        Remove-Item $File.FullName -Force -ErrorAction SilentlyContinue
    }
    $Remaining = Get-ChildItem -Path $Target -Recurse -File -ErrorAction SilentlyContinue
    $SizeAfter = [math]::Round((($Remaining | Measure-Object Length -Sum).Sum) / 1MB, 1)
    $Summary += [PSCustomObject]@{
        Path      = $Target
        Removed   = $Old.Count
        FreedMB   = $SizeBefore
        Remaining = $Remaining.Count
        LeftMB    = $SizeAfter
    }
}
$Summary | Format-Table -AutoSize
$Summary | Export-Csv "C:\ProgramData\cleanup_report.csv" -NoTypeInformation
$Freed = ($Summary | Measure-Object FreedMB -Sum).Sum
Write-Output "freed: $Freed MB"
foreach ($Row in $Summary) {
    if ($Row.LeftMB -gt $SizeAlertMB) {
        Write-Warning "$($Row.Path) still above ${SizeAlertMB}MB"
    }
    $BigFiles = Get-ChildItem -Path $Row.Path -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 100MB }
    $BigFiles | ForEach-Object { Write-Output "oversized: $($_.FullName)" }
}
