$Threshold = 50
$Queues = Get-Queue
$Report = foreach ($Queue in $Queues) {
    [PSCustomObject]@{
        Identity     = $Queue.Identity
        DeliveryType = $Queue.DeliveryType
        Status       = $Queue.Status
        MessageCount = $Queue.MessageCount
        RetryCount   = $Queue.RetryCount
        NextRetry    = $Queue.NextRetryTime
    }
}
$Report | Format-Table -AutoSize
$Backed = $Report | Where-Object { $_.MessageCount -gt $Threshold }
foreach ($Q in $Backed) {
    Write-Warning "queue $($Q.Identity) holds $($Q.MessageCount) messages (status $($Q.Status))"
    if ($Q.Status -eq "Retry") {
        Retry-Queue -Identity $Q.Identity
        Write-Output "resubmit requested for $($Q.Identity)"
    }
}
$Poison = Get-Message -Queue "Poison" -ErrorAction SilentlyContinue
if ($Poison) {
    Write-Warning "poison queue contains messages"
    $Poison | Select-Object -First 5 Subject, FromAddress | Format-Table -AutoSize
}
$TotalMessages = ($Report | Measure-Object MessageCount -Sum).Sum
Write-Output "total queued: $TotalMessages"
$Shadow = $Report | Where-Object { $_.DeliveryType -eq "ShadowRedundancy" }
Write-Output "shadow queues: $($Shadow.Count)"
$Report | Export-Csv "C:\ProgramData\exchange_queues.csv" -NoTypeInformation
