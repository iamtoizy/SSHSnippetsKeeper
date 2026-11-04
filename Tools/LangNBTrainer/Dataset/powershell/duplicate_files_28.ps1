param(
    [string]$SearchPath = "C:\Users\Public\Documents",
    [long]$MinSizeKB = 1024,
    [switch]$DeleteDuplicates
)
$Candidates = Get-ChildItem -Path $SearchPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt ($MinSizeKB * 1KB) } |
    Group-Object Length | Where-Object { $_.Count -gt 1 } |
    ForEach-Object { $_.Group }
Write-Output "size-collision candidates: $($Candidates.Count)"
$HashGroups = $Candidates | Get-FileHash -Algorithm MD5 |
    Group-Object Hash | Where-Object { $_.Count -gt 1 }
$Duplicates = foreach ($Group in $HashGroups) {
    $Ordered = $Group.Group | Sort-Object { $_.Path } | Select-Object -Skip 1
    foreach ($File in $Ordered) {
        [PSCustomObject]@{
            Hash   = $Group.Name.Substring(0, 8)
            Path   = $File.Path
            SizeKB = [math]::Round((Get-Item $File.Path).Length / 1KB, 0)
        }
    }
}
if (-not $Duplicates) {
    Write-Output "no duplicates found"
    exit 0
}
$Duplicates | Format-Table -AutoSize
$WastedMB = [math]::Round((($Duplicates | Measure-Object SizeKB -Sum).Sum) / 1024, 1)
Write-Output "duplicates: $($Duplicates.Count), wasted: $WastedMB MB"
if ($DeleteDuplicates) {
    $Duplicates | ForEach-Object {
        Remove-Item $_.Path -Force
        Write-Output "deleted: $($_.Path)"
    }
} else {
    Write-Output "dry run, pass -DeleteDuplicates to clean"
}
$Duplicates | Export-Csv "C:\ProgramData\duplicates.csv" -NoTypeInformation
