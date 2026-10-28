param(
    [int]$Hours = 24,
    [int]$TopProviders = 5
)
$Since = (Get-Date).AddHours(-$Hours)
$Filter = @{
    LogName   = @("Application", "System")
    Level     = @(1, 2)
    StartTime = $Since
}
$Events = Get-WinEvent -FilterHashtable $Filter -ErrorAction SilentlyContinue
if (-not $Events) {
    Write-Output "no error events in the last $Hours hours"
    exit 0
}
$ByProvider = $Events | Group-Object ProviderName | Sort-Object Count -Descending
$ByProvider | Select-Object -First $TopProviders | ForEach-Object {
    Write-Output ("{0,-40} events={1}" -f $_.Name, $_.Count)
}
$Critical = $Events | Where-Object { $_.Level -le 1 }
foreach ($Event in $Critical | Select-Object -First 5) {
    $Short = $Event.Message.Substring(0, [math]::Min(160, $Event.Message.Length))
    Write-Warning "critical: [$($Event.ProviderName)] $Short"
}
$Ids = $Events | Group-Object Id | Sort-Object Count -Descending | Select-Object -First 10
$Ids | Format-Table @{L = "EventId"; E = { $_.Name } }, Count -AutoSize
$Report = $Events | Select-Object TimeCreated, ProviderName, Id, LevelDisplayName,
    @{N = "Message"; E = { $_.Message.Substring(0, [math]::Min(200, $_.Message.Length)) } }
$Report | Export-Csv "C:\ProgramData\event_errors.csv" -NoTypeInformation
Write-Output "total: $($Events.Count) events since $($Events[0].TimeCreated)"
