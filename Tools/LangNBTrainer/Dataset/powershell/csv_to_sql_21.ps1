param(
    [string]$CsvPath = "data\employees.csv",
    [string]$TableName = "dbo.Employees",
    [int]$BatchSize = 100
)
if (-not (Test-Path $CsvPath)) {
    Write-Warning "csv not found: $CsvPath"
    exit 1
}
$Rows = Import-Csv -Path $CsvPath
Write-Output "rows loaded: $($Rows.Count)"
$Required = "id", "name", "department"
$Columns = ($Rows | Get-Member -MemberType NoteProperty).Name
foreach ($Col in $Required) {
    if ($Columns -notcontains $Col) {
        Write-Warning "missing required column: $Col"
        exit 2
    }
}
$SqlFile = "data\import_employees.sql"
$Statements = @()
$Counter = 0
foreach ($Row in $Rows) {
    $SafeName = $Row.name -replace "'", "''"
    $Statement = "INSERT INTO $TableName (id, name, department) VALUES ($($Row.id), '$SafeName', '$($Row.department)');"
    $Statements += $Statement
    $Counter++
    if ($Counter -ge $BatchSize) {
        Write-Output "batch ready: $Counter statements"
        $Statements | Out-File $SqlFile -Append -Encoding utf8
        $Statements = @()
        $Counter = 0
    }
}
if ($Statements.Count -gt 0) {
    $Statements | Out-File $SqlFile -Append -Encoding utf8
}
$Duplicates = $Rows | Group-Object id | Where-Object { $_.Count -gt 1 }
if ($Duplicates) {
    Write-Warning "duplicate ids: $($Duplicates.Count)"
    $Duplicates | ForEach-Object { Write-Output "  id $($_.Name) x$($_.Count)" }
}
Write-Output "generated: $SqlFile"
