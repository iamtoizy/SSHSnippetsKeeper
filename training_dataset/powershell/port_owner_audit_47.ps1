param(
    [int[]]$AllowedPorts = @(22, 80, 135, 139, 443, 445, 3389, 5985)
)
$Listeners = Get-NetTCPConnection -State Listen -ErrorAction Stop
$Report = foreach ($Conn in $Listeners) {
    $Process = Get-Process -Id $Conn.OwningProcess -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Address = $Conn.LocalAddress
        Port    = $Conn.LocalPort
        Process = if ($Process) { $Process.ProcessName } else { "unknown" }
        PID     = $Conn.OwningProcess
        Path    = if ($Process) { $Process.Path } else { "" }
        Exposed = $Conn.LocalAddress -in @("0.0.0.0", "::")
        Allowed = $AllowedPorts -contains $Conn.LocalPort
    }
}
$Report | Sort-Object Port | Format-Table Address, Port, Process, PID, Allowed -AutoSize
$Report | Group-Object Process | Sort-Object Count -Descending | Select-Object -First 8 Name, Count | Format-Table -AutoSize
$Unexpected = @($Report | Where-Object { -not $_.Allowed -and $_.Exposed })
foreach ($Row in $Unexpected) {
    $Status = "unavailable"
    if ($Row.Path -and (Test-Path $Row.Path)) {
        $Signature = Get-AuthenticodeSignature -FilePath $Row.Path -ErrorAction SilentlyContinue
        if ($Signature) {
            $Status = $Signature.Status
        }
    }
    Write-Warning "unexpected listener $($Row.Address):$($Row.Port) process=$($Row.Process) signature=$Status"
}
$Report | Where-Object { $_.Exposed } | Export-Csv -Path "$env:TEMP\exposed_ports.csv" -NoTypeInformation -Encoding UTF8
$Duplicates = $Report | Group-Object Port | Where-Object { @($_.Group.Address | Select-Object -Unique).Count -gt 1 }
foreach ($Dup in $Duplicates) {
    Write-Output "port $($Dup.Name) bound on multiple addresses: $($Dup.Group.Address -join ', ')"
}
$Exposed = @($Report | Where-Object { $_.Exposed })
Write-Output "listeners=$(@($Report).Count) exposed=$($Exposed.Count) unexpected=$($Unexpected.Count)"
if ($Unexpected.Count -gt 0) {
    exit 2
}
exit 0
