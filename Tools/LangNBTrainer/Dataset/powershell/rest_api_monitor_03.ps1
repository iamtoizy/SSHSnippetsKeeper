$Endpoints = @(
    @{ Name = "payments"; Url = "https://api.example.com/payments/health" },
    @{ Name = "orders";   Url = "https://api.example.com/orders/health" },
    @{ Name = "users";    Url = "https://api.example.com/users/health" }
)
$Results = @()
foreach ($Ep in $Endpoints) {
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $Response = Invoke-RestMethod -Uri $Ep.Url -Method Get -TimeoutSec 5
        $Stopwatch.Stop()
        $Results += [PSCustomObject]@{
            Service   = $Ep.Name
            Healthy   = $true
            LatencyMs = $Stopwatch.ElapsedMilliseconds
            Version   = $Response.version
        }
    } catch {
        $Stopwatch.Stop()
        $Results += [PSCustomObject]@{
            Service   = $Ep.Name
            Healthy   = $false
            LatencyMs = $Stopwatch.ElapsedMilliseconds
            Version   = "unknown"
        }
        Write-Warning "service $($Ep.Name) failed: $($_.Exception.Message)"
    }
}
$Results | Format-Table -AutoSize
$Failed = $Results | Where-Object { -not $_.Healthy }
$Slow = $Results | Where-Object { $_.LatencyMs -gt 800 }
if ($Failed.Count -gt 0) {
    $Body = $Results | ConvertTo-Json
    Send-MailMessage -To "ops@example.com" -From "monitor@example.com" -Subject "health check failed" -Body $Body -SmtpServer "smtp.example.com"
    exit 1
}
if ($Slow.Count -gt 0) {
    Write-Warning "slow services detected: $($Slow.Service -join ', ')"
}
$AvgLatency = ($Results | Measure-Object LatencyMs -Average).Average
Write-Output ("average latency: {0:N0} ms" -f $AvgLatency)
exit 0
