@echo off
setlocal
set TASK_NAME=AppMaintenance
set TASK_RUN=%~dp0maintenance.cmd
if not exist "%TASK_RUN%" (
    echo runner script missing: %TASK_RUN%
    exit /b 2
)
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if errorlevel 1 (
    echo task does not exist, creating
    schtasks /create /tn "%TASK_NAME%" /tr "\"%TASK_RUN%\"" /sc daily /st 03:30 /ru SYSTEM /f >nul
    if errorlevel 1 (
        echo creation failed
        exit /b 3
    )
    echo task created for 03:30 daily
) else (
    echo task already exists
)
schtasks /run /tn "%TASK_NAME%" >nul 2>&1
if errorlevel 1 (
    echo manual run rejected
) else (
    echo manual run triggered
)
timeout /t 3 /nobreak >nul
schtasks /query /tn "%TASK_NAME%" /fo LIST | findstr /i "status last run"
schtasks /change /tn "%TASK_NAME%" /disable >nul
echo task disabled
schtasks /change /tn "%TASK_NAME%" /enable >nul
echo task enabled
schtasks /query /fo csv 2>nul | findstr /i "%TASK_NAME%"
schtasks /delete /tn "%TASK_NAME%" /f >nul
echo task deleted
endlocal
