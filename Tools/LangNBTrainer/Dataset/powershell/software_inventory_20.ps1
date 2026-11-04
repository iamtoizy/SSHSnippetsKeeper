$UninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$Apps = Get-ItemProperty $UninstallKeys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, EstimatedSize -Unique |
    Sort-Object DisplayName
Write-Output "installed applications: $($Apps.Count)"
$NoPublisher = $Apps | Where-Object { -not $_.Publisher }
Write-Output "without publisher: $($NoPublisher.Count)"
$Biggest = $Apps | Where-Object { $_.EstimatedSize } |
    Sort-Object EstimatedSize -Descending | Select-Object -First 10
$Biggest | Format-Table DisplayName, @{N = "SizeMB"; E = { [math]::Round($_.EstimatedSize / 1024, 0) } } -AutoSize
$WatchList = "java", "openssl", "7-zip", "notepad"
foreach ($Pattern in $WatchList) {
    $Found = $Apps | Where-Object { $_.DisplayName -like "*$Pattern*" }
    if ($Found) {
        $Found | ForEach-Object { Write-Output "watch: $($_.DisplayName) $($_.DisplayVersion)" }
    } else {
        Write-Warning "not installed: $Pattern"
    }
}
$Apps | Export-Csv "C:\ProgramData\software_inventory.csv" -NoTypeInformation -Encoding UTF8
$Cutoff = (Get-Date).AddYears(-3).ToString("yyyyMMdd")
$OldInstalls = $Apps | Where-Object { $_.InstallDate -and $_.InstallDate -lt $Cutoff }
Write-Output "installed more than 3 years ago: $($OldInstalls.Count)"
