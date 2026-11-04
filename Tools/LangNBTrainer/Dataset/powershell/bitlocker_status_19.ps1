$Volumes = Get-BitLockerVolume | Where-Object { $_.MountPoint -like "*:" }
$Report = foreach ($Vol in $Volumes) {
    [PSCustomObject]@{
        MountPoint    = $Vol.MountPoint
        VolumeStatus  = $Vol.VolumeStatus
        Protection    = $Vol.ProtectionStatus
        Cipher        = $Vol.EncryptionMethod
        KeyProtectors = ($Vol.KeyProtector | Measure-Object).Count
    }
}
$Report | Format-Table -AutoSize
$Unprotected = $Report | Where-Object { $_.Protection -eq "Off" }
foreach ($Vol in $Unprotected) {
    Write-Warning "$($Vol.MountPoint) is not protected, enabling bitlocker"
    Enable-BitLocker -MountPoint $Vol.MountPoint -EncryptionMethod XtsAes256 -UsedSpaceOnly -SkipHardwareTest -RecoveryPasswordProtector
    $RecoveryKeys = (Get-BitLockerVolume -MountPoint $Vol.MountPoint).KeyProtector |
        Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }
    $RecoveryKeys | ForEach-Object {
        Write-Output "recovery password for $($Vol.MountPoint): $($_.RecoveryPassword)"
    }
}
$ProtectedCount = ($Report | Where-Object { $_.Protection -eq "On" } | Measure-Object).Count
$EncryptedPct = [math]::Round(100 * $ProtectedCount / [math]::Max($Report.Count, 1), 0)
Write-Output "protected volumes: $EncryptedPct%"
$Report | Export-Csv "C:\ProgramData\bitlocker_report.csv" -NoTypeInformation
manage-bde -status C: | Select-String -Pattern "Conversion|Percentage"
