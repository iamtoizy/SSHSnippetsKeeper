param(
    [string[]]$RootServices = @("W3SVC", "MSSQLSERVER", "DNS"),
    [int]$MaxDepth = 4
)
function Get-ServiceNode {
    param(
        [string]$Name,
        [int]$Depth,
        [string]$Parent,
        [hashtable]$Seen
    )
    if ($Depth -gt $MaxDepth -or $Seen.ContainsKey($Name)) {
        return
    }
    $Seen[$Name] = $true
    $Service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $Service) {
        Write-Warning "missing service $Name at depth $Depth"
        return
    }
    [PSCustomObject]@{
        Name   = $Service.Name
        Status = $Service.Status
        Start  = $Service.StartType
        Depth  = $Depth
        Parent = $Parent
    }
    foreach ($Child in $Service.DependentServices) {
        Get-ServiceNode -Name $Child.Name -Depth ($Depth + 1) -Parent $Service.Name -Seen $Seen
    }
}
$Seen = @{}
$Tree = foreach ($Root in $RootServices) {
    Get-ServiceNode -Name $Root -Depth 0 -Parent "none" -Seen $Seen
}
$Tree | Sort-Object Depth, Name | Format-Table Name, Status, Start, Depth, Parent -AutoSize
$Stopped = @($Tree | Where-Object { $_.Status -ne "Running" -and $_.Start -eq "Automatic" })
foreach ($Node in $Stopped) {
    Write-Warning "automatic service not running: $($Node.Name) at depth $($Node.Depth)"
}
$Tree | Group-Object Depth | Sort-Object Name | Select-Object Name, Count | Format-Table -AutoSize
$Tree | ConvertTo-Json -Depth 3 | Set-Content -Path "$env:TEMP\service_dependencies.json" -Encoding UTF8
Write-Output "nodes=$(@($Tree).Count) stopped=$($Stopped.Count) roots=$(@($RootServices).Count)"
if ($Stopped.Count -gt 0) {
    exit 1
}
exit 0
