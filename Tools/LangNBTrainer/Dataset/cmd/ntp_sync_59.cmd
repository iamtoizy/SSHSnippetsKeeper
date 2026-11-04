@echo off
setlocal enabledelayedexpansion
set MODE=query
if /i "%~1"=="resync" set MODE=resync
w32tm /query /status > "%TEMP%\w32_status.txt" 2>&1
if errorlevel 1 (
    echo time service unavailable
    exit /b 3
)
findstr /i "Source Last" "%TEMP%\w32_status.txt"
for /f "tokens=2 delims=:" %%O in ('findstr /i "Phase Offset" "%TEMP%\w32_status.txt"') do set OFFSET=%%O
if defined OFFSET echo offset raw: !OFFSET!
w32tm /query /configuration 2>nul | findstr /i "Type NtpServer"
if /i "%MODE%"=="resync" (
    echo resyncing with configured peers
    w32tm /resync /force >nul 2>&1
    if errorlevel 1 (
        echo resync failed, restarting service
        net stop w32time >nul 2>&1
        net start w32time >nul 2>&1
        w32tm /resync /force >nul 2>&1
        if errorlevel 1 (
            echo resync still failing
            exit /b 1
        )
    )
    w32tm /query /status | findstr /i "Source"
) else (
    echo dry run only, pass resync argument to force synchronization
)
w32tm /monitor /computers:time.windows.com 2>nul | findstr /i "offset"
echo ntp check finished
endlocal
exit /b 0
