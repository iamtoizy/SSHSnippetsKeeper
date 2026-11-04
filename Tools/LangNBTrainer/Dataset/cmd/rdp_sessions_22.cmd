@echo off
setlocal
qwinsta 2>nul | findstr /v "^$"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections 2>nul | findstr fDenyTS
for /f "tokens=3" %%V in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections 2^>nul ^| findstr fDenyTS') do set DENY=%%V
if "%DENY%"=="0x1" (
    echo rdp disabled, enabling
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f >nul
    netsh advfirewall firewall set rule group="remote desktop" new enable=Yes >nul 2>&1
    echo rdp enabled
) else (
    echo rdp already enabled
)
for /f "tokens=1,2,3 skip=1" %%A in ('qwinsta 2^>nul') do (
    if /i "%%C"=="Active" echo active session: %%A id %%B
)
query user 2>nul | findstr /i "rdp-tcp"
for /f "tokens=2" %%I in ('qwinsta ^| findstr /i "rdp-tcp"') do set SESSION_ID=%%I
if defined SESSION_ID (
    echo rdp session id: %SESSION_ID%
)
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber 2>nul | findstr PortNumber
netstat -an | findstr ":3389"
echo rdp check finished
endlocal
