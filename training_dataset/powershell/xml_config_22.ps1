param(
    [string]$ConfigPath = "C:\App\service.config.xml",
    [hashtable]$Settings = @{
        "WorkerThreads" = "8"
        "LogLevel"      = "Warning"
        "ApiTimeout"    = "30"
    }
)
if (-not (Test-Path $ConfigPath)) {
    Write-Warning "config not found: $ConfigPath"
    exit 1
}
$Backup = "$ConfigPath.bak"
Copy-Item $ConfigPath $Backup -Force
Write-Output "backup created: $Backup"
[xml]$Config = Get-Content $ConfigPath
$AppSettings = $Config.configuration.appSettings
foreach ($Key in $Settings.Keys) {
    $Node = $AppSettings.add | Where-Object { $_.key -eq $Key }
    if ($Node) {
        Write-Output "update: $Key = $($Node.value) -> $($Settings[$Key])"
        $Node.value = $Settings[$Key]
    } else {
        Write-Output "add: $Key = $($Settings[$Key])"
        $NewNode = $Config.CreateElement("add")
        $NewNode.SetAttribute("key", $Key)
        $NewNode.SetAttribute("value", $Settings[$Key])
        $AppSettings.AppendChild($NewNode) | Out-Null
    }
}
$Config.Save($ConfigPath)
[xml]$Verify = Get-Content $ConfigPath
foreach ($Key in $Settings.Keys) {
    $Check = $Verify.configuration.appSettings.add | Where-Object { $_.key -eq $Key }
    if ($Check.value -ne $Settings[$Key]) {
        Write-Warning "verification failed for $Key, rolling back"
        Copy-Item $Backup $ConfigPath -Force
        exit 3
    }
}
Write-Output "config updated and verified"
