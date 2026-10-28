param(
    [int]$SnapshotAgeDays = 14
)
$Vms = Get-VM
$Report = foreach ($Vm in $Vms) {
    [PSCustomObject]@{
        Name       = $Vm.Name
        State      = $Vm.State
        CpuUsage   = $Vm.CPUUsage
        MemoryGB   = [math]::Round($Vm.MemoryAssigned / 1GB, 1)
        UptimeHrs  = [math]::Round($Vm.Uptime.TotalHours, 0)
        Checkpoint = $Vm.ParentCheckpointName
    }
}
$Report | Format-Table -AutoSize
$Running = $Report | Where-Object { $_.State -eq "Running" }
$Off = $Report | Where-Object { $_.State -eq "Off" }
Write-Output "vms: $($Report.Count), running: $($Running.Count), off: $($Off.Count)"
$OldSnapshots = Get-VMSnapshot | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$SnapshotAgeDays) }
foreach ($Snap in $OldSnapshots) {
    $Stamp = $Snap.CreationTime.ToString("yyyy-MM-dd")
    Write-Warning "old snapshot: $($Snap.VMName) / $($Snap.Name) from $Stamp"
}
$MemTotalGB = [math]::Round(($Running | Measure-Object MemoryGB -Sum).Sum, 1)
$HostRamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
Write-Output "vmmem: $MemTotalGB GB of host $HostRamGB GB"
foreach ($Vm in $Vms | Where-Object { $_.State -eq "Off" -and $_.AutomaticStartAction -eq "Nothing" }) {
    Write-Warning "$($Vm.Name) is off with no automatic start action"
}
$CpuHot = $Report | Where-Object { $_.CpuUsage -gt 80 }
foreach ($V in $CpuHot) {
    Write-Warning "$($V.Name) cpu load $($V.CpuUsage)%"
}
