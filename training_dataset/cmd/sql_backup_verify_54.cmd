@echo off
setlocal enabledelayedexpansion
set BACKUP_DIR=%~1
if "%BACKUP_DIR%"=="" set BACKUP_DIR=D:\SqlBackups
set SERVER=localhost
set LOG=%~dp0verify_log.txt
if not exist "%BACKUP_DIR%" (
    echo backup directory missing: %BACKUP_DIR%
    exit /b 2
)
where sqlcmd >nul 2>&1
if errorlevel 1 (
    echo sqlcmd not available
    exit /b 3
)
if exist "%LOG%" del "%LOG%"
set OK=0
set BAD=0
for %%B in ("%BACKUP_DIR%\*.bak") do (
    echo verifying %%~nxB
    sqlcmd -S %SERVER% -E -b -Q "RESTORE VERIFYONLY FROM DISK='%%~fB' WITH CHECKSUM" >> "%LOG%" 2>&1
    if errorlevel 1 (
        set /a BAD+=1
        echo FAILED %%~nxB>> "%LOG%"
    ) else (
        set /a OK+=1
        echo OK %%~nxB>> "%LOG%"
    )
)
echo verified=%OK% failed=%BAD%
for %%B in ("%BACKUP_DIR%\*.bak") do echo %%~nxB %%~zB bytes
if %BAD% GTR 0 (
    echo verification failures detected
    exit /b 1
)
echo all backups verified
endlocal
exit /b 0
