param(
    [int]$DaysInactive = 90,
    [string]$OutputPath = "reports\inactive_users.csv"
)
$Cutoff = (Get-Date).AddDays(-$DaysInactive)
$Users = Get-ADUser -Filter { Enabled -eq $true } -Properties LastLogonDate, PasswordLastSet, Department
$Inactive = $Users | Where-Object {
    ($null -eq $_.LastLogonDate -or $_.LastLogonDate -lt $Cutoff) -and
    ($null -ne $_.PasswordLastSet)
}
$Report = foreach ($User in $Inactive) {
    [PSCustomObject]@{
        SamAccountName = $User.SamAccountName
        DisplayName    = $User.Name
        Department     = $User.Department
        LastLogon      = $User.LastLogonDate
        DaysIdle       = if ($User.LastLogonDate) { ((Get-Date) - $User.LastLogonDate).Days } else { -1 }
    }
}
$Report | Sort-Object DaysIdle -Descending | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
$Total = ($Report | Measure-Object).Count
$Stale = ($Report | Where-Object { $_.DaysIdle -gt 180 } | Measure-Object).Count
Write-Output "inactive users: $Total (older than 180 days: $Stale)"
$StaleUsers = $Report | Where-Object { $_.DaysIdle -gt 180 }
foreach ($U in $StaleUsers) {
    Disable-ADAccount -Identity $U.SamAccountName -WhatIf
    Set-ADUser -Identity $U.SamAccountName -Description "disabled by audit $($DaysInactive)d" -WhatIf
}
$Departments = $Report | Group-Object Department | Sort-Object Count -Descending
$Departments | Select-Object -First 5 | Format-Table Name, Count -AutoSize
