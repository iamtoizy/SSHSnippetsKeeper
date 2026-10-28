$WarningPct = 80
$CriticalPct = 90
$MinSizeGB = 5
$Volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.Size -gt ($MinSizeGB * 1GB) }
$Report = foreach ($Vol in $Volumes) {
    $FreePct = [math]::Round(100 * $Vol.SizeRemaining / $Vol.Size, 1)
    [PSCustomObject]@{
        Drive   = $Vol.DriveLetter
        Label   = $Vol.FileSystemLabel
        SizeGB  = [math]::Round($Vol.Size / 1GB, 1)
        FreeGB  = [math]::Round($Vol.SizeRemaining / 1GB, 1)
        FreePct = $FreePct
        Status  = if ($FreePct -lt $CriticalPct) { "Critical" } elseif ($FreePct -lt $WarningPct) { "Warning" } else { "Ok" }
    }
}
$Report | Sort-Object FreePct | Format-Table -AutoSize
$Critical = $Report | Where-Object { $_.Status -eq "Critical" }
$Warning = $Report | Where-Object { $_.Status -eq "Warning" }
foreach ($V in $Critical) {
    Write-Warning "drive $($V.Drive): only $($V.FreeGB) GB free ($($V.FreePct)%)"
}
Write-Output "critical: $($Critical.Count), warning: $($Warning.Count)"
$Report | Export-Csv "C:\ProgramData\disk_report.csv" -NoTypeInformation
$BiggestFiles = Get-ChildItem "C:\Temp" -Recurse -File -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object -First 3 FullName, @{N = "MB"; E = { [math]::Round($_.Length / 1MB, 1) } }
$BiggestFiles | Format-Table -AutoSize
Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 3" |
    Select-Object DeviceID, @{N = "FreeGB"; E = { [math]::Round($_.FreeSpace / 1GB, 1) }} |
    Format-Table -AutoSize
