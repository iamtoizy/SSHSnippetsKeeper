param(
    [string]$ServerInstance = "localhost",
    [string[]]$Databases = @("AppDb", "BillingDb"),
    [string]$BackupRoot = "D:\Backups"
)
$Stamp = Get-Date -Format "yyyyMMdd_HHmm"
foreach ($Db in $Databases) {
    $Dir = Join-Path $BackupRoot $Db
    if (-not (Test-Path $Dir)) {
        New-Item -Path $Dir -ItemType Directory -Force | Out-Null
    }
    $File = Join-Path $Dir "$($Db)_$Stamp.bak"
    try {
        Backup-SqlDatabase -ServerInstance $ServerInstance -Database $Db -BackupFile $File -CompressionOption On -ErrorAction Stop
        $SizeMB = [math]::Round((Get-Item $File).Length / 1MB, 1)
        Write-Output "backup ok: $Db -> $SizeMB MB"
    } catch {
        Write-Warning "backup failed for $Db : $($_.Exception.Message)"
        continue
    }
}
$Cutoff = (Get-Date).AddDays(-14)
Get-ChildItem -Path $BackupRoot -Recurse -Filter "*.bak" |
    Where-Object { $_.LastWriteTime -lt $Cutoff } |
    ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Output "removed old backup: $($_.Name)"
    }
$Report = Get-ChildItem -Path $BackupRoot -Recurse -Filter "*.bak" |
    Select-Object Name, @{N = "SizeMB"; E = { [math]::Round($_.Length / 1MB, 1) } }, LastWriteTime
$Report | Sort-Object LastWriteTime -Descending | Format-Table -AutoSize
$TotalGB = [math]::Round(($Report | Measure-Object SizeMB -Sum).Sum / 1024, 2)
Write-Output "backup storage: $TotalGB GB"
$Verify = Get-ChildItem -Path $BackupRoot -Recurse -Filter "*.bak" | Select-Object -First 1
if ($Verify) {
    Restore-SqlDatabase -ServerInstance $ServerInstance -Database "VerifyOnly" -BackupFile $Verify.FullName -VerifyOnly -ErrorAction SilentlyContinue
}
