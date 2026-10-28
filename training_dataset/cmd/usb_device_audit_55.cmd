@echo off
setlocal enabledelayedexpansion
set KEY=HKLM\SYSTEM\CurrentControlSet\Enum\USBSTOR
set REPORT=%~dp0usb_devices.csv
echo device_id,service,friendly_name > "%REPORT%"
reg query "%KEY%" >nul 2>&1
if errorlevel 1 (
    echo usbstor key unavailable
    exit /b 2
)
set COUNT=0
for /f "tokens=1 delims= " %%K in ('reg query "%KEY%" /s /v Service 2^>nul ^| findstr /i /b "HKEY"') do (
    set /a COUNT+=1
    set SERVICE=unknown
    set NAME=unknown
    for /f "tokens=3*" %%S in ('reg query "%%K" /v Service 2^>nul ^| findstr /i "Service"') do set SERVICE=%%S
    for /f "tokens=3*" %%F in ('reg query "%%K" /v FriendlyName 2^>nul ^| findstr /i "FriendlyName"') do set NAME=%%F
    echo %%~nxK,!SERVICE!,!NAME!>> "%REPORT%"
    echo device %%~nxK service !SERVICE!
    if /i "!SERVICE!"=="USBSTOR" echo mass storage device attached
)
echo usb devices found: !COUNT!
driverquery /fo csv 2>nul | findstr /i "usbstor"
echo report written to %REPORT%
endlocal
exit /b 0
