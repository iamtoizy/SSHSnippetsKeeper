$Scopes = Get-DhcpServerv4Scope
$Report = foreach ($Scope in $Scopes) {
    $Stats = Get-DhcpServerv4ScopeStatistics -ScopeId $Scope.ScopeId
    $UsedPct = [math]::Round(100 * $Stats.Used / ($Stats.Used + $Stats.Free), 1)
    [PSCustomObject]@{
        ScopeId  = $Scope.ScopeId
        Name     = $Scope.Name
        UsedPct  = $UsedPct
        State    = $Scope.State
        LeaseHrs = $Scope.LeaseDuration.Hours
    }
}
$Report | Format-Table -AutoSize
$Full = $Report | Where-Object { $_.UsedPct -gt 90 }
foreach ($S in $Full) {
    Write-Warning "scope $($S.ScopeId) is $($_.UsedPct)% full"
}
$Zones = Get-DnsServerZone | Where-Object { -not $_.IsAutoCreated }
$ZoneReport = foreach ($Zone in $Zones) {
    [PSCustomObject]@{
        Zone         = $Zone.ZoneName
        Type         = $Zone.ZoneType
        Records      = $Zone.NumberOfRecords
        DsIntegrated = $Zone.IsDsIntegrated
        AgingEnabled = $Zone.AgingEnabled
    }
}
$ZoneReport | Format-Table -AutoSize
$NoAging = $ZoneReport | Where-Object { -not $_.AgingEnabled }
Write-Output "zones: $($ZoneReport.Count), without aging: $($NoAging.Count)"
$Report | Export-Csv "C:\ProgramData\dhcp_scopes.csv" -NoTypeInformation
$ZoneReport | Export-Csv "C:\ProgramData\dns_zones.csv" -NoTypeInformation
