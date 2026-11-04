param(
    [string]$ReportPath = "$env:TEMP\gpo_compliance.json",
    [int]$MinPasswordLength = 12
)
Import-Module GroupPolicy -ErrorAction Stop
$Gpos = Get-GPO -All -ErrorAction Stop
$Findings = @()
foreach ($Gpo in $Gpos) {
    try {
        [xml]$Xml = Get-GPOReport -Guid $Gpo.Id -ReportType Xml -ErrorAction Stop
        $Password = $Xml.SelectSingleNode("//SecurityOptions/Account/Password")
        if ($Password) {
            $Length = [int]$Password.MinimumPasswordLength
            if ($Length -gt 0 -and $Length -lt $MinPasswordLength) {
                $Findings += [PSCustomObject]@{
                    Gpo      = $Gpo.DisplayName
                    Setting  = "MinimumPasswordLength"
                    Value    = $Length
                    Severity = "high"
                }
            }
        }
        $Lockout = $Xml.SelectSingleNode("//SecurityOptions/Account/LockoutBadCount")
        if ($Lockout -and [int]$Lockout.LockoutBadCount -eq 0) {
            $Findings += [PSCustomObject]@{
                Gpo      = $Gpo.DisplayName
                Setting  = "LockoutBadCount"
                Value    = 0
                Severity = "medium"
            }
        }
    } catch {
        Write-Warning "cannot parse $($Gpo.DisplayName): $($_.Exception.Message)"
    }
}
$Gpos | Select-Object DisplayName, ModificationTime, GpoStatus | Sort-Object ModificationTime -Descending | Format-Table -AutoSize
$Findings | Format-Table Gpo, Setting, Value, Severity -AutoSize
$Domain = Get-ADDomain -ErrorAction SilentlyContinue
$Payload = @{
    generated = (Get-Date).ToString("s")
    domain    = $Domain.DNSRoot
    total     = @($Gpos).Count
    findings  = @($Findings)
} | ConvertTo-Json -Depth 4
Set-Content -Path $ReportPath -Value $Payload -Encoding UTF8
$Disabled = @($Gpos | Where-Object { $_.GpoStatus -ne "AllSettingsEnabled" })
Write-Output "gpos=$(@($Gpos).Count) disabled=$($Disabled.Count) findings=$(@($Findings).Count) report=$ReportPath"
if (@($Findings).Count -gt 0) { exit 2 }
exit 0
