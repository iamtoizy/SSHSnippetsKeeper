param(
    [int]$Samples = 5,
    [int]$IntervalSec = 2
)
$Counters = @(
    "\Processor(_Total)\% Processor Time",
    "\Memory\Available MBytes",
    "\PhysicalDisk(_Total)\Avg. Disk Queue Length",
    "\System\Processor Queue Length"
)
$History = @()
for ($I = 1; $I -le $Samples; $I++) {
    $Data = Get-Counter -Counter $Counters -SampleInterval $IntervalSec -MaxSamples 1
    $Values = $Data.CounterSamples
    $Snapshot = [PSCustomObject]@{
        Sample    = $I
        CpuPct    = [math]::Round(($Values | Where-Object Path -like "*processor time*").CookedValue, 1)
        AvailMb   = [math]::Round(($Values | Where-Object Path -like "*available*").CookedValue, 0)
        DiskQueue = [math]::Round(($Values | Where-Object Path -like "*disk queue*").CookedValue, 2)
        CpuQueue  = [math]::Round(($Values | Where-Object Path -like "*processor queue*").CookedValue, 2)
    }
    $History += $Snapshot
    Write-Output ("sample {0}: cpu={1}% avail={2}MB diskq={3} cpuq={4}" -f $I, $Snapshot.CpuPct, $Snapshot.AvailMb, $Snapshot.DiskQueue, $Snapshot.CpuQueue)
}
$AvgCpu = [math]::Round(($History | Measure-Object CpuPct -Average).Average, 1)
$MaxDiskQ = ($History | Measure-Object DiskQueue -Maximum).Maximum
if ($AvgCpu -gt 85) {
    Write-Warning "sustained cpu load: $AvgCpu%"
}
if ($MaxDiskQ -gt 2) {
    Write-Warning "disk queue peaked at $MaxDiskQ"
}
$TopProc = Get-Process | Sort-Object CPU -Descending |
    Select-Object -First 5 Name,
        @{N = "CpuSec"; E = { [int]$_.CPU } },
        @{N = "MemMB"; E = { [math]::Round($_.WorkingSet64 / 1MB, 0) } }
$TopProc | Format-Table -AutoSize
