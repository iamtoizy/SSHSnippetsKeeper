param(
    [string]$OutputPath = "$env:TEMP\dsc_drift.json"
)
if (-not (Get-Module -ListAvailable -Name PSDesiredStateConfiguration)) {
    Write-Warning "dsc module missing"
    exit 3
}
$Status = Get-DscConfigurationStatus -All -ErrorAction SilentlyContinue
if (-not $Status) {
    Write-Warning "no dsc runs recorded"
    exit 4
}
$Latest = $Status | Select-Object -First 1
$Drift = foreach ($Resource in @($Latest.ResourcesNotInDesiredState)) {
    [PSCustomObject]@{
        Resource = $Resource.ResourceId
        Module   = $Resource.ModuleName
        State    = $Resource.InDesiredState
        Duration = $Resource.DurationInSeconds
    }
}
$History = foreach ($Run in $Status | Select-Object -First 10) {
    [PSCustomObject]@{
        Started = $Run.StartDate
        Mode    = $Run.Mode
        Status  = $Run.Status
        Reboot  = $Run.RebootRequested
        Failed  = @($Run.ResourcesNotInDesiredState).Count
        Total   = $Run.NumberOfResources
    }
}
$History | Format-Table -AutoSize
$Test = Test-DscConfiguration -Detailed -ErrorAction SilentlyContinue
$InDesired = [bool]($Test -and $Test.InDesiredState)
if ($InDesired) {
    Write-Output "current configuration matches desired state"
} else {
    Write-Warning "drift detected in $(@($Drift).Count) resources"
}
$Report = @{
    checked   = (Get-Date).ToString("s")
    inDesired = $InDesired
    drift     = @($Drift)
    history   = @($History)
}
$Report | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Output "report written to $OutputPath"
if (-not $InDesired) { exit 1 }
exit 0
