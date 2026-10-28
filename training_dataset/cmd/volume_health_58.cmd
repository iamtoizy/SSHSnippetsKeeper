@echo off
setlocal enabledelayedexpansion
set REPORT=%~dp0volume_health.txt
if exist "%REPORT%" del "%REPORT%"
echo volume health report %DATE% %TIME%>> "%REPORT%"
set BAD=0
for /f "tokens=1,* delims=:" %%A in ('fsutil fsinfo drives 2^>nul ^| findstr ":"') do set DRIVES=%%B
if not defined DRIVES (
    echo cannot enumerate drives
    exit /b 2
)
for %%D in (!DRIVES!) do (
    echo checking %%D
    fsutil fsinfo volumeinfo %%D 2>nul | findstr /i "volume name serial number file system" >> "%REPORT%"
    fsutil volume diskfree %%D 2>nul | findstr /i "total free" >> "%REPORT%"
    fsutil dirty query %%D >nul 2>&1
    if not errorlevel 1 (
        fsutil dirty query %%D | findstr /i "dirty" >nul
        if not errorlevel 1 (
            echo warning: %%D dirty bit set
            echo dirty bit set on %%D>> "%REPORT%"
            set /a BAD+=1
        )
    ) else (
        echo dirty check skipped for %%D, run as administrator
    )
    chkntfs %%D 2>nul | findstr /i "dirty" | findstr /v /i "not" >> "%REPORT%"
)
vol C: 2>nul | findstr /i "volume"
echo issues: !BAD!
type "%REPORT%"
if !BAD! GTR 0 exit /b 1
exit /b 0
