$Printers = Get-Printer | Where-Object { -not $_.Name.StartsWith("Microsoft") }
$Report = foreach ($Printer in $Printers) {
    $Jobs = Get-PrintJob -PrinterName $Printer.Name -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Name   = $Printer.Name
        Driver = $Printer.DriverName
        Port   = $Printer.PortName
        Shared = $Printer.Shared
        Jobs   = ($Jobs | Measure-Object).Count
    }
}
$Report | Format-Table -AutoSize
$Stuck = $Report | Where-Object { $_.Jobs -gt 10 }
foreach ($P in $Stuck) {
    Write-Warning "printer $($P.Name) has $($P.Jobs) queued jobs"
    Get-PrintJob -PrinterName $P.Name |
        Where-Object { $_.JobStatus -match "Error|Retained" } |
        ForEach-Object { Remove-PrintJob -InputObject $_ }
}
$Offline = $Report | Where-Object { $_.Port -like "*nul*" }
Write-Output "printers: $($Report.Count), offline ports: $($Offline.Count)"
$Default = (Get-CimInstance Win32_Printer | Where-Object Default).Name
Write-Output "default printer: $Default"
$Drivers = Get-PrinterDriver | Sort-Object Name -Unique
Write-Output "installed drivers: $($Drivers.Count)"
$Report | Export-Csv "C:\ProgramData\printer_inventory.csv" -NoTypeInformation
