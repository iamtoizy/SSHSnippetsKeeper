param(
    [string]$GroupName = "Administrators"
)
$Group = Get-LocalGroup -Name $GroupName
$Members = Get-LocalGroupMember -Group $Group
$Report = foreach ($Member in $Members) {
    [PSCustomObject]@{
        Name      = $Member.Name
        Principal = $Member.PrincipalSource
        Type      = $Member.ObjectClass
        Service   = $Member.Name -like "*`$"
    }
}
$Report | Format-Table -AutoSize
$Users = $Report | Where-Object { $_.Type -eq "User" }
$Groups = $Report | Where-Object { $_.Type -eq "Group" }
Write-Output "group $GroupName : $($Report.Count) members (users: $($Users.Count), nested: $($Groups.Count))"
$ServiceAccounts = $Report | Where-Object { $_.Service }
foreach ($M in $ServiceAccounts) {
    Write-Warning "service account inside $GroupName : $($M.Name)"
}
$LocalUsers = Get-LocalUser | Where-Object { $_.Enabled }
$Orphans = foreach ($U in $LocalUsers) {
    $InGroup = $Report | Where-Object { $_.Name -like "*$($U.Name)" }
    if (-not $InGroup -and $U.Description -match "admin") {
        $U.Name
    }
}
if ($Orphans) {
    Write-Warning "admin-like users outside the group:"
    $Orphans | ForEach-Object { Write-Output "  $_" }
}
$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
Write-Output "running as: $($CurrentIdentity.Name)"
$Report | Export-Csv "C:\ProgramData\local_admins.csv" -NoTypeInformation
