param(
    [switch]$ApplyFixes
)
$AuditResults = [ordered]@{}
$RdpKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
$AuditResults.RdpEnabled = (Get-ItemProperty -Path $RdpKey -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections -eq 0
$UacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$AuditResults.UacEnabled = (Get-ItemProperty -Path $UacKey -Name EnableLUA -ErrorAction SilentlyContinue).EnableLUA -eq 1
$AuditResults.LogonBanner = (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\LegalNoticeText")
$FirewallProfiles = Get-NetFirewallProfile
$AuditResults.FirewallEnabled = ($FirewallProfiles | Where-Object { -not $_.Enabled } | Measure-Object).Count -eq 0
foreach ($Property in $AuditResults.Keys) {
    Write-Output ("{0,-16} = {1}" -f $Property, $AuditResults[$Property])
}
$Hardening = @{
    "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"          = @{ Name = "fDenyTSConnections"; Value = 1 }
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" = @{ Name = "EnableLUA"; Value = 1 }
}
if ($ApplyFixes) {
    foreach ($Key in $Hardening.Keys) {
        $Spec = $Hardening[$Key]
        Set-ItemProperty -Path $Key -Name $Spec.Name -Value $Spec.Value -Type DWord
        Write-Output "hardened: $Key -> $($Spec.Name)=$($Spec.Value)"
    }
}
$AuditResults.GetEnumerator() | ForEach-Object {
    "$($_.Key)=$($_.Value)" | Out-File "C:\ProgramData\registry_audit.txt" -Append
}
$smbSigning = Get-SmbServerConfiguration
Write-Output "smb signing required: $($smbSigning.RequireSecuritySignature)"
