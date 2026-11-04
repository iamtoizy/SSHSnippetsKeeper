$CriticalServices = @("W32Time", "DNS", "IISADMIN", "MSSQLSERVER")
$MaxRestarts = 3
$StateFile = "C:\ProgramData\watchdog\restarts.xml"
New-Item -Path (Split-Path $StateFile) -ItemType Directory -Force | Out-Null
$State = if (Test-Path $StateFile) { Import-Clixml $StateFile } else { @{} }
foreach ($Name in $CriticalServices) {
    $Svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $Svc) {
        Write-Warning "service $Name not found"
        continue
    }
    if ($Svc.Status -eq "Running") {
        if ($State.ContainsKey($Name)) { $State.Remove($Name) | Out-Null }
        continue
    }
    $Count = 0
    if ($State.ContainsKey($Name)) { $Count = $State[$Name] }
    if ($Count -ge $MaxRestarts) {
        Write-Output "$Name exceeded restart limit ($Count), escalating"
        Write-EventLog -LogName Application -Source "Watchdog" -EventId 9001 -EntryType Error -Message "$Name failed after $Count restarts"
        continue
    }
    Write-Output "$Name is $($Svc.Status), restarting (attempt $($Count + 1))"
    Start-Service -Name $Name -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    $Svc.Refresh()
    if ($Svc.Status -eq "Running") {
        Write-Output "$Name recovered"
    } else {
        $State[$Name] = $Count + 1
        Write-Warning "$Name still $($Svc.Status)"
    }
}
$State | Export-Clixml $StateFile
Get-Service | Where-Object { $_.StartType -eq "Automatic" -and $_.Status -ne "Running" } |
    Select-Object Name, Status | Format-Table -AutoSize
