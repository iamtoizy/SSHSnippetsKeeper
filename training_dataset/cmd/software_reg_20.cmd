@echo off
setlocal enabledelayedexpansion
set UNINSTALL=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
set REPORT=%~dp0software.txt
echo installed software %DATE% > "%REPORT%"
reg query "%UNINSTALL%" /s /v DisplayName 2>nul | findstr DisplayName >> "%REPORT%"
set /a COUNT=0
for /f "tokens=2,* skip=2" %%A in ('reg query "%UNINSTALL%" /s /v DisplayName 2^>nul ^| findstr DisplayName') do set /a COUNT+=1
echo entries: %COUNT%
reg query "%UNINSTALL%" /s /v DisplayName 2>nul | findstr /i "java" >nul
if not errorlevel 1 (
    echo java runtime detected in registry
)
for /f "tokens=*" %%K in ('reg query "%UNINSTALL%" 2^>nul ^| findstr /i "7-zip notepad"') do (
    echo found key: %%K
)
set WATCH=Microsoft Visual C++
reg query "%UNINSTALL%" /s /f "%WATCH%" /d 2>nul | findstr /i "DisplayName" | more
set /a BIG=0
for /f "tokens=2 delims== " %%V in ('reg query "%UNINSTALL%" /s /v EstimatedSize 2^>nul ^| findstr "0x"') do (
    if %%V GEQ 0x1000000 set /a BIG+=1
)
echo large packages: !BIG!
type "%REPORT%" | find /c /v ""
endlocal
