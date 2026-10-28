param(
    [int]$ExpireDays = 30
)
$Store = Get-ChildItem Cert:\LocalMachine\My
$Report = foreach ($Cert in $Store) {
    $DaysLeft = ($Cert.NotAfter - (Get-Date)).Days
    [PSCustomObject]@{
        Subject       = $Cert.Subject
        Thumbprint    = $Cert.Thumbprint
        NotAfter      = $Cert.NotAfter.ToString("yyyy-MM-dd")
        DaysLeft      = $DaysLeft
        HasPrivateKey = $Cert.HasPrivateKey
        SelfSigned    = ($Cert.Subject -eq $Cert.Issuer)
    }
}
$Report | Sort-Object DaysLeft | Format-Table Subject, NotAfter, DaysLeft, SelfSigned -AutoSize
$Expiring = $Report | Where-Object { $_.DaysLeft -lt $ExpireDays }
foreach ($Cert in $Expiring) {
    Write-Warning "certificate expires in $($Cert.DaysLeft) days: $($Cert.Subject)"
}
$SelfSigned = $Report | Where-Object { $_.SelfSigned }
Write-Output "certificates: $($Report.Count), expiring: $($Expiring.Count), self-signed: $($SelfSigned.Count)"
$Expired = $Report | Where-Object { $_.DaysLeft -lt 0 }
if ($Expired) {
    Write-Warning "expired certificates found"
    $Expired | Export-Csv "C:\ProgramData\expired_certs.csv" -NoTypeInformation
}
$Remote = Test-NetConnection -ComputerName "api.example.com" -Port 443 -InformationLevel Quiet
if ($Remote) {
    $TcpClient = New-Object System.Net.Sockets.TcpClient("api.example.com", 443)
    $SslStream = New-Object System.Net.Security.SslStream($TcpClient.GetStream())
    $SslStream.AuthenticateAsClient("api.example.com")
    $RemoteCert = $SslStream.RemoteCertificate
    Write-Output "remote certificate valid until: $($RemoteCert.GetExpirationDateAsString())"
    $SslStream.Dispose()
    $TcpClient.Dispose()
}
