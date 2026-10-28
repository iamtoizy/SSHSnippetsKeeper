@echo off
setlocal enabledelayedexpansion
set SERVICE_NAME=%~1
if "%SERVICE_NAME%"=="" (
    echo usage: service_manager.cmd ^<service^> ^<start^|stop^|status^>
    exit /b 64
)
set ACTION=%~2
if "%ACTION%"=="" set ACTION=status
sc query "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1060 (
    echo service %SERVICE_NAME% does not exist
    exit /b 2
)
if /i "%ACTION%"=="start" goto :start
if /i "%ACTION%"=="stop" goto :stop
if /i "%ACTION%"=="status" goto :status
echo unknown action: %ACTION%
exit /b 64

:start
sc config "%SERVICE_NAME%" start= auto >nul
net start "%SERVICE_NAME%"
if errorlevel 1 (
    echo failed to start %SERVICE_NAME%
    exit /b 3
)
echo %SERVICE_NAME% started
goto :eof

:stop
net stop "%SERVICE_NAME%"
if errorlevel 1 (
    echo failed to stop %SERVICE_NAME%
    exit /b 3
)
echo %SERVICE_NAME% stopped
goto :eof

:status
for /f "tokens=4" %%S in ('sc query "%SERVICE_NAME%" ^| findstr STATE') do set STATE=%%S
echo %SERVICE_NAME% state: !STATE!
sc qc "%SERVICE_NAME%" | findstr START_TYPE
exit /b 0
