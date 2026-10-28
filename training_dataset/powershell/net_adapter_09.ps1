$Adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
$Report = foreach ($Adapter in $Adapters) {
    $IpConfig = Get-NetIPAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $DnsServers = (Get-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4).ServerAddresses
    $Stats = $Adapter | Get-NetAdapterStatistics
    [PSCustomObject]@{
        Name       = $Adapter.Name
        LinkSpeed  = $Adapter.LinkSpeed
        IpAddress  = ($IpConfig | Select-Object -First 1).IPAddress
        Gateway    = (Get-NetRoute -InterfaceIndex $Adapter.ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop
        DnsServers = $DnsServers -join ";"
        SentGB     = [math]::Round($Stats.SentBytes / 1GB, 2)
        ReceivedGB = [math]::Round($Stats.ReceivedBytes / 1GB, 2)
    }
}
$Report | Format-Table -AutoSize
$NoDns = $Report | Where-Object { [string]::IsNullOrEmpty($_.DnsServers) }
if ($NoDns.Count -gt 0) {
    Write-Warning "adapters without dns: $($NoDns.Name -join ', ')"
}
$BadGateway = $Report | Where-Object { [string]::IsNullOrEmpty($_.Gateway) }
foreach ($A in $BadGateway) {
    Write-Warning "$($A.Name) has no default gateway"
}
$Report | Export-Csv "C:\ProgramData\nic_report.csv" -NoTypeInformation
$Reachable = Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet
if (-not $Reachable) {
    Write-Warning "external connectivity lost"
    Get-NetIPInterface -AddressFamily IPv4 | Format-Table ifIndex, InterfaceAlias, Dhcp -AutoSize
}
