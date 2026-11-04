param(
    [int]$WarningDays = 14,
    [string]$OutputPath = "$env:TEMP\password_expiry.csv"
)
Import-Module ActiveDirectory -ErrorAction Stop
$Now = Get-Date
$Users = Get-ADUser -Filter { Enabled -eq $true -and PasswordNeverExpires -eq $false } -Properties msDS-UserPasswordExpiryTimeComputed, PasswordLastSet, Department, EmailAddress
$Report = foreach ($User in $Users) {
    $ExpiryTicks = $User.'msDS-UserPasswordExpiryTimeComputed'
    if ($ExpiryTicks -eq [long]::MaxValue -or $ExpiryTicks -le 0) {
        continue
    }
    $Expires = [datetime]::FromFileTime($ExpiryTicks)
    $DaysLeft = [int]($Expires - $Now).TotalDays
    [PSCustomObject]@{
        SamAccountName = $User.SamAccountName
        Department     = $User.Department
        Email          = $User.EmailAddress
        PasswordSet    = $User.PasswordLastSet
        Expires        = $Expires.ToString("yyyy-MM-dd")
        DaysLeft       = $DaysLeft
        Bucket         = if ($DaysLeft -lt 0) { "expired" } elseif ($DaysLeft -le 3) { "critical" } elseif ($DaysLeft -le $WarningDays) { "warning" } else { "ok" }
    }
}
$Report | Sort-Object DaysLeft | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
$Report | Group-Object Bucket | Select-Object Name, Count | Format-Table -AutoSize
$Notify = $Report | Where-Object { $_.Bucket -in @("expired", "critical", "warning") -and $_.Email }
foreach ($Row in $Notify) {
    try {
        Send-MailMessage -To $Row.Email -From "it@example.com" -Subject "password expires in $($Row.DaysLeft) days" -Body "change the password before $($Row.Expires)" -SmtpServer "smtp.example.com" -ErrorAction Stop
    } catch {
        Write-Warning "mail failed for $($Row.SamAccountName): $($_.Exception.Message)"
    }
}
$Expired = @($Report | Where-Object { $_.DaysLeft -lt 0 })
$Critical = @($Report | Where-Object { $_.Bucket -eq "critical" })
Write-Output "users=$(@($Report).Count) notified=$(@($Notify).Count) critical=$($Critical.Count) expired=$($Expired.Count)"
if ($Expired.Count -gt 0) {
    exit 2
}
exit 0
