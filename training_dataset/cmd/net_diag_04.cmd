@echo off
setlocal
set TARGET=8.8.8.8
set GATEWAY=
for /f "tokens=3" %%G in ('route print 0.0.0.0 ^| findstr "0.0.0.0"') do set GATEWAY=%%G
echo gateway: %GATEWAY%
ping -n 2 %TARGET% >nul 2>&1
if errorlevel 1 (
    echo external host unreachable
    ping -n 2 %GATEWAY% >nul 2>&1
    if errorlevel 1 (
        echo gateway unreachable too, restarting adapter
        netsh interface set interface name="Ethernet" admin=disabled
        timeout /t 5 /nobreak >nul
        netsh interface set interface name="Ethernet" admin=enabled
        ipconfig /renew >nul
    ) else (
        echo gateway ok, problem beyond router
        ipconfig /flushdns >nul
        nslookup example.com 2>nul | findstr /i "address"
    )
) else (
    echo external connectivity ok
)
ipconfig /all | findstr /i "ipv4 gateway dns"
arp -a | find /c /i "dynamic"
for /f "tokens=5" %%A in ('netstat -ano ^| findstr :443 ^| findstr ESTABLISHED') do set CONN_PID=%%A
if defined CONN_PID (
    tasklist /fi "PID eq %CONN_PID%" | findstr /i "pid"
) else (
    echo no established tls connections
)
netstat -e | findstr Bytes
echo network diagnostics finished
endlocal
