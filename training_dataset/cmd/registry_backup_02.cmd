@echo off
setlocal
set KEY=HKLM\SOFTWARE\MyApp
set BACKUP_DIR=%~dp0reg_backup
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
set STAMP=%DATE:~-4%%DATE:~3,2%%DATE:~0,2%
set BACKUP_FILE=%BACKUP_DIR%\myapp_%STAMP%.reg
if not exist "%BACKUP_FILE%" (
    reg export "%KEY%" "%BACKUP_FILE%" /y >nul 2>&1
    if errorlevel 1 (
        echo export failed for %KEY%
        exit /b 2
    )
    echo exported to %BACKUP_FILE%
)
reg query "%KEY%" /v InstallPath 2>nul | findstr InstallPath
if errorlevel 1 (
    echo InstallPath missing, writing default
    reg add "%KEY%" /v InstallPath /t REG_SZ /d "C:\Program Files\MyApp" /f >nul
)
reg query "%KEY%" /v Port 2>nul | findstr Port >nul
if errorlevel 1 (
    reg add "%KEY%" /v Port /t REG_DWORD /d 8080 /f >nul
    echo Port created with default 8080
)
for /f "tokens=2*" %%A in ('reg query "%KEY%" /v Port 2^>nul') do set CURRENT_PORT=%%B
echo current port: %CURRENT_PORT%
if "%CURRENT_PORT%"=="8080" (
    reg add "%KEY%" /v Port /t REG_DWORD /d 8443 /f >nul
    echo port upgraded to 8443
)
reg query "%KEY%" /s 2>nul | find /c "REG_"
dir "%BACKUP_DIR%" /b /o-d
echo registry maintenance finished
endlocal
