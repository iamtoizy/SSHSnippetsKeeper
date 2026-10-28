param(
    [string]$InputCsv = "data\contacts_raw.csv",
    [string]$OutputCsv = "data\contacts_clean.csv"
)
$Raw = Import-Csv -Path $InputCsv
Write-Output "raw rows: $($Raw.Count)"
$RequiredColumns = "email", "fullname", "company"
$Header = ($Raw | Get-Member -MemberType NoteProperty).Name
foreach ($Col in $RequiredColumns) {
    if ($Header -notcontains $Col) {
        Write-Warning "missing column: $Col"
        exit 1
    }
}
$Clean = foreach ($Row in $Raw) {
    $Email = "$($Row.email)".Trim().ToLower()
    $Name = "$($Row.fullname)".Trim() -replace "\s+", " "
    if ($Email -notmatch "^[\w\.\-]+@[\w\-]+(\.[\w\-]+)+$") {
        continue
    }
    if ([string]::IsNullOrEmpty($Name)) {
        continue
    }
    [PSCustomObject]@{
        Email   = $Email
        Name    = $Name
        Company = "$($Row.company)".Trim()
        Domain  = $Email.Split("@")[1]
    }
}
$Clean = $Clean | Sort-Object Email -Unique
$Clean | Export-Csv $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Output "clean rows: $($Clean.Count)"
$Removed = $Raw.Count - ($Clean | Measure-Object).Count
Write-Output "removed: $Removed (invalid or duplicate)"
$ByDomain = $Clean | Group-Object Domain | Sort-Object Count -Descending
$ByDomain | Select-Object -First 5 | Format-Table @{L = "Domain"; E = { $_.Name } }, Count -AutoSize
$FreeProviders = $Clean | Where-Object { $_.Domain -match "gmail|yandex|outlook" }
Write-Output "free mail providers: $($FreeProviders.Count)"
$NoCompany = ($Clean | Where-Object { -not $_.Company } | Measure-Object).Count
Write-Output "without company: $NoCompany"
