param(
    [int]$RetentionDays = 7,
    [int]$MinFreePercent = 15
)
$Volume = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = 'C:'"
if (-not $Volume) {
    Write-Warning "system volume not found"
    exit 3
}
$FreePercent = [math]::Round(($Volume.FreeSpace / $Volume.Capacity) * 100, 1)
Write-Output "free space on C: $FreePercent%"
if ($FreePercent -lt $MinFreePercent) {
    Write-Warning "free space below $MinFreePercent percent, snapshot skipped"
    exit 2
}
$Existing = @(Get-CimInstance -ClassName Win32_ShadowCopy | Where-Object { $_.VolumeName -eq $Volume.DeviceID })
Write-Output "existing snapshots: $($Existing.Count)"
try {
    $Result = Invoke-CimMethod -ClassName Win32_ShadowCopy -MethodName Create -Arguments @{
        Volume  = $Volume.DeviceID
        Context = "ClientAccessible"
    }
    if ($Result.ReturnValue -ne 0) {
        throw "create returned $($Result.ReturnValue)"
    }
    $Created = Get-CimInstance -ClassName Win32_ShadowCopy -Filter "ID = '$($Result.ShadowID)'"
    Write-Output "created snapshot $($Created.ID) install=$($Created.InstallDate)"
} catch {
    Write-Warning "snapshot failed: $($_.Exception.Message)"
    exit 1
} finally {
    $Total = @(Get-CimInstance -ClassName Win32_ShadowCopy).Count
    Write-Output "snapshot count after run: $Total"
}
$Cutoff = (Get-Date).AddDays(-$RetentionDays)
foreach ($Snapshot in $Existing) {
    if ($Snapshot.InstallDate -lt $Cutoff) {
        Write-Output "removing stale snapshot $($Snapshot.ID)"
        Remove-CimInstance -InputObject $Snapshot -ErrorAction SilentlyContinue
    }
}
$Remaining = @(Get-CimInstance -ClassName Win32_ShadowCopy)
$Remaining | Select-Object ID, InstallDate, VolumeName | Format-Table -AutoSize
Write-Output "retention=${RetentionDays}d remaining=$($Remaining.Count)"
if ($Remaining.Count -eq 0) {
    exit 1
}
exit 0
