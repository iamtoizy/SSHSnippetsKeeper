$Services = Get-CimInstance -ClassName Win32_Service |
    Where-Object { $_.StartMode -eq "Auto" }
$Report = foreach ($Svc in $Services) {
    [PSCustomObject]@{
        Name        = $Svc.Name
        DisplayName = $Svc.DisplayName
        State       = $Svc.State
        Account     = $Svc.StartName
        ProcessId   = $Svc.ProcessId
        Delayed     = $Svc.DelayedAutoStart
    }
}
$Stopped = $Report | Where-Object { $_.State -ne "Running" }
Write-Output "auto services: $($Report.Count), stopped: $($Stopped.Count)"
$Stopped | Format-Table Name, Account, State -AutoSize
$CustomAccounts = $Report | Where-Object { $_.Account -notmatch "LocalSystem|LocalService|NetworkService" }
Write-Output "services under custom accounts: $($CustomAccounts.Count)"
$CustomAccounts | Format-Table Name, Account, State -AutoSize
foreach ($Svc in $Stopped) {
    if (-not $Svc.Delayed) {
        Write-Output "recovery candidate: $($Svc.Name)"
        Set-Service -Name $Svc.Name -StartupType Automatic -ErrorAction SilentlyContinue -WhatIf
    }
}
$Delayed = ($Report | Where-Object { $_.Delayed } | Measure-Object).Count
Write-Output "delayed autostart: $Delayed"
$Report | Export-Csv "C:\ProgramData\services_audit.csv" -NoTypeInformation
