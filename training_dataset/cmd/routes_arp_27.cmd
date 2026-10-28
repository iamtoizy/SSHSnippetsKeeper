@echo off
setlocal
set STATIC_NET=192.168.50.0
set STATIC_MASK=255.255.255.0
set STATIC_GW=192.168.1.254
route print -4 | findstr /c:"%STATIC_NET%" >nul
if errorlevel 1 (
    route add %STATIC_NET% mask %STATIC_MASK% %STATIC_GW% metric 1 >nul
    if errorlevel 1 (
        echo route add failed
        exit /b 2
    )
    echo route added for %STATIC_NET%
) else (
    echo static route exists
)
route print -4 | findstr /c:"%STATIC_NET%"
for /f "tokens=1,2,3" %%A in ('route print -4 ^| findstr "%STATIC_NET%"') do (
    echo route: %%A %%B %%C
)
arp -a | find /c /i "dynamic"
arp -d * >nul 2>&1
echo arp cache flushed
ping -n 1 %STATIC_GW% >nul 2>&1
arp -a | findstr "%STATIC_GW%"
route delete %STATIC_NET% >nul 2>&1
echo route removed
route print -4 | findstr /c:"%STATIC_NET%" >nul
if errorlevel 1 (
    echo deletion confirmed
)
endlocal
