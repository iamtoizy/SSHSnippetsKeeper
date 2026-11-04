param(
    [string]$SourceDir = "C:\ProgramData\Reports",
    [int]$OlderThanDays = 7
)
$Cutoff = (Get-Date).AddDays(-$OlderThanDays)
$ArchiveRoot = "C:\ProgramData\ReportArchive"
New-Item -Path $ArchiveRoot -ItemType Directory -Force | Out-Null
$OldFiles = Get-ChildItem -Path $SourceDir -Filter "*.csv" -File |
    Where-Object { $_.LastWriteTime -lt $Cutoff }
if (-not $OldFiles) {
    Write-Output "nothing to archive"
    exit 0
}
$Stamp = Get-Date -Format "yyyyMMdd"
$ZipPath = Join-Path $ArchiveRoot "reports_$Stamp.zip"
$OldFiles | Compress-Archive -DestinationPath $ZipPath -Force
$Zip = Get-Item $ZipPath
$SourceSize = [math]::Round((($OldFiles | Measure-Object Length -Sum).Sum) / 1MB, 1)
$ZipSize = [math]::Round($Zip.Length / 1MB, 1)
$Ratio = [math]::Round(100 - (100 * $ZipSize / $SourceSize), 0)
Write-Output ("archived {0} files, {1} MB -> {2} MB, ratio {3}%" -f $OldFiles.Count, $SourceSize, $ZipSize, $Ratio)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$ZipArchive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
$EntryCount = $ZipArchive.Entries.Count
$ZipArchive.Dispose()
Write-Output "archive entries: $EntryCount"
if ($EntryCount -ne $OldFiles.Count) {
    Write-Warning "entry count mismatch, aborting cleanup"
    exit 2
}
$OldFiles | Remove-Item -Force
Write-Output "source files removed: $($OldFiles.Count)"
Get-ChildItem $ArchiveRoot -Filter "*.zip" | Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 12 |
    ForEach-Object {
        Remove-Item $_.FullName
        Write-Output "pruned: $($_.Name)"
    }
