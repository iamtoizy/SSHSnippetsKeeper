param(
    [string]$BaseUri = "https://api.example.com/v2/tickets",
    [int]$PageSize = 50,
    [int]$MaxPages = 20
)
$Headers = @{
    Accept        = "application/json"
    Authorization = "Bearer $env:API_TOKEN"
}
$Items = [System.Collections.Generic.List[object]]::new()
$Page = 1
$NextUri = "${BaseUri}?page=1&per_page=$PageSize"
do {
    try {
        $Response = Invoke-RestMethod -Uri $NextUri -Headers $Headers -Method Get -TimeoutSec 20 -ErrorAction Stop
    } catch {
        Write-Warning "page $Page failed: $($_.Exception.Message)"
        break
    }
    foreach ($Item in $Response.data) {
        $Items.Add([PSCustomObject]@{
            Id        = $Item.id
            Subject   = $Item.subject
            Priority  = $Item.priority
            UpdatedAt = [datetime]$Item.updated_at
            AgeHours  = [math]::Round(((Get-Date) - [datetime]$Item.updated_at).TotalHours, 1)
        })
    }
    if (-not $Response.pagination.next) {
        break
    }
    $NextUri = $Response.pagination.next
    $Page++
} while ($Page -le $MaxPages)
$Overdue = $Items | Where-Object { $_.Priority -eq "urgent" -and $_.AgeHours -gt 24 }
$Items | Group-Object Priority | Sort-Object Count -Descending | Select-Object Name, Count | Format-Table -AutoSize
$Overdue | Sort-Object AgeHours -Descending | Select-Object -First 10 Id, Subject, AgeHours | Format-Table -AutoSize
$Payload = @{
    generated = (Get-Date).ToString("s")
    pages     = $Page
    total     = $Items.Count
    overdue   = @($Overdue).Count
} | ConvertTo-Json
Set-Content -Path "$env:TEMP\api_pagination_summary.json" -Value $Payload -Encoding UTF8
Write-Output "items=$($Items.Count) overdue=$(@($Overdue).Count) pages=$Page"
if (@($Overdue).Count -gt 0) {
    exit 1
}
exit 0
