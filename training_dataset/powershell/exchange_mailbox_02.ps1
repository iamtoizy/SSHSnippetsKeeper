$QuotaWarningGB = 45
$QuotaLimitGB = 50
$Mailboxes = Get-Mailbox -ResultSize Unlimited
$Report = foreach ($Mbx in $Mailboxes) {
    $Stats = Get-MailboxStatistics -Identity $Mbx.Alias
    $SizeGB = [math]::Round($Stats.TotalItemSize.Value.ToBytes() / 1GB, 2)
    [PSCustomObject]@{
        Alias     = $Mbx.Alias
        Database  = $Mbx.Database
        SizeGB    = $SizeGB
        ItemCount = $Stats.ItemCount
        LastLogon = $Stats.LastLogonTime
        State     = if ($SizeGB -ge $QuotaLimitGB) { "Blocked" } elseif ($SizeGB -ge $QuotaWarningGB) { "Warning" } else { "Normal" }
    }
}
$Report | Export-Csv "reports\mailbox_sizes.csv" -NoTypeInformation
$Blocked = $Report | Where-Object { $_.State -eq "Blocked" }
$Warning = $Report | Where-Object { $_.State -eq "Warning" }
Write-Output "mailboxes: $($Report.Count), warning: $($Warning.Count), blocked: $($Blocked.Count)"
foreach ($M in $Blocked) {
    Write-Warning "$($M.Alias) reached quota, archive recommended"
}
$Biggest = $Report | Sort-Object SizeGB -Descending | Select-Object -First 5
$Biggest | Format-Table Alias, SizeGB, ItemCount -AutoSize
$SumGB = [math]::Round(($Report | Measure-Object SizeGB -Sum).Sum, 1)
$AvgGB = [math]::Round(($Report | Measure-Object SizeGB -Average).Average, 2)
Write-Output "total size: $SumGB GB, average: $AvgGB GB"
$Orphans = $Report | Where-Object { $_.LastLogon -lt (Get-Date).AddDays(-180) }
$Orphans | ForEach-Object { Write-Output "dormant mailbox: $($_.Alias)" }
