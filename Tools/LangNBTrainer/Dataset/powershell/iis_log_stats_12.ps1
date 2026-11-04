param(
    [string]$LogPath = "C:\inetpub\logs\LogFiles\W3SVC1",
    [int]$TopUrls = 10
)
$Files = Get-ChildItem -Path $LogPath -Filter "*.log" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $Files) {
    Write-Warning "no iis logs found"
    exit 1
}
$Lines = Get-Content $Files.FullName | Where-Object { $_ -match "^20\d\d-" }
$Entries = $Lines | ForEach-Object {
    $Parts = $_ -split " "
    [PSCustomObject]@{
        Time   = $Parts[1]
        Method = $Parts[3]
        Url    = $Parts[4]
        Status = [int]$Parts[5]
        Bytes  = [int]$Parts[7]
        Ms     = [int]$Parts[13]
    }
}
Write-Output "parsed entries: $($Entries.Count)"
$ByStatus = $Entries | Group-Object Status | Sort-Object Count -Descending
$ByStatus | Select-Object -First 8 | Format-Table @{L = "Status"; E = { $_.Name } }, Count -AutoSize
$Slow = $Entries | Where-Object { $_.Ms -gt 2000 } | Sort-Object Ms -Descending | Select-Object -First 5
$Slow | Format-Table Url, Ms -AutoSize
$Top = $Entries | Group-Object Url | Sort-Object Count -Descending | Select-Object -First $TopUrls
$Top | Format-Table @{L = "Url"; E = { $_.Name } }, Count -AutoSize
$ErrorCount = ($Entries | Where-Object { $_.Status -ge 500 } | Measure-Object).Count
$ErrorRate = [math]::Round(100 * $ErrorCount / [math]::Max($Entries.Count, 1), 2)
Write-Output "5xx rate: $ErrorRate%"
$AvgMs = [math]::Round(($Entries | Measure-Object Ms -Average).Average, 0)
Write-Output "avg response: $AvgMs ms"
if ($ErrorRate -gt 5) {
    Write-Warning "error rate above threshold"
    $ByStatus | Select-Object -First 3 | Export-Csv "C:\ProgramData\iis_alert.csv" -NoTypeInformation
}
