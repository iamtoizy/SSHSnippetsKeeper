@echo off
setlocal enabledelayedexpansion
set OUT_DIR=%TEMP%\wifi_profiles
set KEEP_DAYS=30
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
netsh wlan show interfaces > "%TEMP%\wlan_if.txt" 2>&1
if errorlevel 1 (
    echo wireless service unavailable
    exit /b 3
)
findstr /i "SSID Signal State" "%TEMP%\wlan_if.txt"
findstr /i "connected" "%TEMP%\wlan_if.txt" >nul
if errorlevel 1 (
    echo adapter is not connected
    exit /b 2
)
set COUNT=0
for /f "tokens=2 delims=:" %%P in ('netsh wlan show profiles 2^>nul ^| findstr /i "All User Profile"') do (
    set PROFILE=%%P
    set PROFILE=!PROFILE:~1!
    set /a COUNT+=1
    netsh wlan export profile name="!PROFILE!" folder="%OUT_DIR%" >nul 2>&1
    if errorlevel 1 (
        echo export failed for !PROFILE!
    ) else (
        echo exported !PROFILE!
    )
)
echo profiles exported: !COUNT!
dir /b "%OUT_DIR%\*.xml" 2>nul | find /c /v ""
for /f "tokens=2 delims=:" %%S in ('netsh wlan show interfaces 2^>nul ^| findstr /i "Radio type"') do echo radio: %%S
forfiles /p "%OUT_DIR%" /m *.xml /d -%KEEP_DAYS% /c "cmd /c del @path" >nul 2>&1
echo wifi audit completed
endlocal
exit /b 0
