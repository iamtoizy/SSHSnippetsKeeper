@echo off
setlocal enabledelayedexpansion
set LOG_DIR=D:\AppLogs
set DAYS_KEEP=14
if not exist "%LOG_DIR%" (
    echo log dir missing
    exit /b 2
)
echo rotating logs older than %DAYS_KEEP% days
dir "%LOG_DIR%" /b 2>nul | find /c /v ""
forfiles /p "%LOG_DIR%" /m *.log /d -%DAYS_KEEP% /c "cmd /c del @path" >nul 2>&1
if errorlevel 1 (
    echo nothing to rotate or forfiles unavailable
)
echo remaining files:
dir "%LOG_DIR%" /b 2>nul
dir "%LOG_DIR%" /b 2>nul | find /c /v ""
for /d %%D in ("%LOG_DIR%\*") do (
    echo subdir: %%~nxD
    forfiles /p "%%D" /m *.log /d -%DAYS_KEEP% /c "cmd /c del @path" >nul 2>&1
)
for %%F in ("%LOG_DIR%\*.zip") do (
    echo archive kept: %%~nxF
)
echo rotation finished
exit /b 0
