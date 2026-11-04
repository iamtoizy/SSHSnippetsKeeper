$Tasks = Get-ScheduledTask | Where-Object { $_.TaskPath -notlike "\Microsoft*" }
$Report = foreach ($Task in $Tasks) {
    $Info = $Task | Get-ScheduledTaskInfo
    [PSCustomObject]@{
        Name    = $Task.TaskName
        Path    = $Task.TaskPath
        State   = $Task.State
        LastRun = $Info.LastRunTime
        Result  = $Info.LastTaskResult
        NextRun = $Info.NextRunTime
        Failed  = ($Info.LastTaskResult -ne 0 -and $Info.LastTaskResult -ne 267009)
    }
}
$Report | Sort-Object Path | Format-Table Name, State, LastRun, Result -AutoSize
$Failed = $Report | Where-Object { $_.Failed }
if ($Failed.Count -gt 0) {
    Write-Warning "tasks with errors: $($Failed.Count)"
    $Failed | Export-Csv "C:\ProgramData\task_failures.csv" -NoTypeInformation
}
$Disabled = $Report | Where-Object { $_.State -eq "Disabled" }
Write-Output "total custom tasks: $($Report.Count), disabled: $($Disabled.Count)"
$Stale = $Report | Where-Object { $_.LastRun -lt (Get-Date).AddDays(-30) -and $_.State -eq "Ready" }
foreach ($T in $Stale) {
    Write-Output "stale task: $($T.Path)$($T.Name), last run $($T.LastRun)"
    Start-ScheduledTask -TaskPath $T.Path -TaskName $T.Name -WhatIf
}
$NeverRun = $Report | Where-Object { $_.LastRun -eq [datetime]::MinValue }
Write-Output "never started: $($NeverRun.Count)"
