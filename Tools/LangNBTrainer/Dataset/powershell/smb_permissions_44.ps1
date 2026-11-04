param(
    [string]$OutputPath = "$env:TEMP\smb_permissions.csv"
)
Import-Module SmbShare -ErrorAction Stop
$Shares = Get-SmbShare | Where-Object { $_.Special -eq $false }
$Rows = foreach ($Share in $Shares) {
    $Acl = Get-SmbShareAccess -Name $Share.Name
    foreach ($Entry in $Acl) {
        [PSCustomObject]@{
            Share       = $Share.Name
            Path        = $Share.Path
            Account     = $Entry.AccountName
            AccessRight = $Entry.AccessRight
            AccessType  = $Entry.AccessControlType
            Risk        = if ($Entry.AccountName -match "Everyone|Anonymous Logon") { "high" } elseif ($Entry.AccessRight -eq "Full" -and $Entry.AccountName -notmatch "Administrators") { "medium" } else { "low" }
        }
    }
}
$Rows | Sort-Object Share, Account | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
$Rows | Group-Object Risk | Select-Object Name, Count | Format-Table -AutoSize
$Risky = @($Rows | Where-Object { $_.Risk -ne "low" })
foreach ($Row in $Risky) {
    Write-Warning "$($Row.Share) grants $($Row.AccessRight) to $($Row.Account)"
}
$SessionMap = foreach ($Share in $Shares) {
    $Sessions = Get-SmbSession -ScopeName $Share.Name -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Share     = $Share.Name
        Path      = $Share.Path
        Sessions  = @($Sessions).Count
        Encrypted = $Share.EncryptData
    }
}
$SessionMap | Format-Table -AutoSize
$OpenFiles = Get-SmbOpenFile -ErrorAction SilentlyContinue | Group-Object ClientUserName | Sort-Object Count -Descending
$OpenFiles | Select-Object -First 5 Name, Count | Format-Table -AutoSize
Write-Output "shares=$(@($Shares).Count) acl=$(@($Rows).Count) risky=$($Risky.Count)"
if ($Risky.Count -gt 0) {
    exit 2
}
exit 0
