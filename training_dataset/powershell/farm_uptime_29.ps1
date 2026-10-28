param(
    [string[]]$Servers = @("web01", "web02", "db01"),
    [int]$MaxUptimeDays = 30
)
$Results = Invoke-Command -ComputerName $Servers -ScriptBlock {
    $Os = Get-CimInstance Win32_OperatingSystem
    $LastBoot = $Os.LastBootUpTime
    $UptimeDays = [math]::Round(((Get-Date) - $LastBoot).TotalDays, 1)
    $Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID = 'C:'"
    [PSCustomObject]@{
        Server        = $env:COMPUTERNAME
        UptimeDays    = $UptimeDays
        LastBoot      = $LastBoot.ToString("yyyy-MM-dd HH:mm")
        FreeGB        = [math]::Round($Disk.FreeSpace / 1GB, 1)
        PendingReboot = (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending")
    }
} -ErrorAction SilentlyContinue
$Results | Sort-Object UptimeDays -Descending | Format-Table -AutoSize
$LongUptime = $Results | Where-Object { $_.UptimeDays -gt $MaxUptimeDays }
foreach ($R in $LongUptime) {
    Write-Warning "$($R.Server) up for $($R.UptimeDays) days"
}
$Reboot = $Results | Where-Object { $_.PendingReboot }
Write-Output "pending reboot: $($Reboot.Count)"
$LowDisk = $Results | Where-Object { $_.FreeGB -lt 20 }
foreach ($R in $LowDisk) {
    Write-Warning "$($R.Server) low disk: $($R.FreeGB) GB"
}
$Reachable = ($Results | Measure-Object).Count
Write-Output "reachable servers: $Reachable of $($Servers.Count)"
$Results | Export-Csv "C:\ProgramData\farm_uptime.csv" -NoTypeInformation
