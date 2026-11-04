$Session = New-Object -ComObject Microsoft.Update.Session
$Searcher = $Session.CreateUpdateSearcher()
$Result = $Searcher.Search("IsInstalled = 0 and Type = 'Software'")
$Updates = $Result.Updates
Write-Output "missing updates: $($Updates.Count)"
foreach ($Update in $Updates) {
    $SizeMB = [math]::Round($Update.MaxDownloadSize / 1MB, 1)
    Write-Output (" - {0} ({1} MB)" -f $Update.Title, $SizeMB)
}
$HotFixes = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5
$HotFixes | Format-Table HotFixID, Description, InstalledOn -AutoSize
$LastPatch = ($HotFixes | Measure-Object InstalledOn -Maximum).Maximum
$PatchAgeDays = ((Get-Date) - $LastPatch).Days
Write-Output "last patch applied $PatchAgeDays days ago"
if ($PatchAgeDays -gt 60) {
    Write-Warning "patch level is stale"
}
$RebootPending = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
if ($RebootPending) {
    Write-Warning "reboot pending after previous updates"
}
$Downloader = $Session.CreateUpdateDownloader()
foreach ($Update in $Updates) {
    $Coll = New-Object -ComObject Microsoft.Update.UpdateColl
    $Coll.Add($Update) | Out-Null
    $Downloader.Updates = $Coll
    $DownloadResult = $Downloader.Download()
    Write-Output "download result: $($DownloadResult.ResultCode) for $($Update.Title)"
}
