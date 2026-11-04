param(
    [string[]]$KeepTags = @("latest", "stable"),
    [int]$MaxAgeDays = 30
)
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Warning "docker cli not available"
    exit 3
}
$Raw = & docker image ls --format "{{json .}}" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "docker daemon unreachable"
    exit 4
}
$Images = foreach ($Line in $Raw) {
    if ([string]::IsNullOrWhiteSpace($Line)) {
        continue
    }
    $Entry = $Line | ConvertFrom-Json
    [PSCustomObject]@{
        Repository = $Entry.Repository
        Tag        = $Entry.Tag
        Id         = $Entry.ID
        Keep       = $KeepTags -contains $Entry.Tag
    }
}
$Dangling = $Images | Where-Object { $_.Repository -eq "<none>" -or $_.Tag -eq "<none>" }
$Candidates = $Images | Where-Object { -not $_.Keep -and $_.Repository -ne "<none>" }
$Table = foreach ($Image in $Candidates) {
    $Inspect = & docker image inspect $Image.Id --format "{{.Created}}" 2>$null
    $Created = if ($Inspect) { [datetime]::Parse($Inspect).ToUniversalTime() } else { $null }
    [PSCustomObject]@{
        Image   = "$($Image.Repository):$($Image.Tag)"
        Created = $Created
        AgeDays = if ($Created) { ((Get-Date).ToUniversalTime() - $Created).Days } else { -1 }
        Remove  = [bool]($Created -and ((Get-Date).ToUniversalTime() - $Created).Days -gt $MaxAgeDays)
    }
}
$Table | Sort-Object AgeDays -Descending | Format-Table -AutoSize
foreach ($Row in $Table | Where-Object { $_.Remove }) {
    Write-Output "pruning $($Row.Image)"
    & docker image rm $Row.Image 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "could not remove $($Row.Image)"
    }
}
Write-Output "images=$(@($Images).Count) dangling=$(@($Dangling).Count) candidates=$(@($Table).Count)"
if (@($Dangling).Count -gt 0) {
    exit 1
}
exit 0
