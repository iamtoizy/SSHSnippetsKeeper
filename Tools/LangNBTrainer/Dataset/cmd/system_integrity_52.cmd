@echo off
setlocal enabledelayedexpansion
set LOG=%~dp0integrity_%DATE:~-4%%DATE:~3,2%%DATE:~0,2%.log
if exist "%LOG%" del "%LOG%"
set ISSUES=0
net session >nul 2>&1
if errorlevel 1 (
    echo elevation required for sfc and dism
    exit /b 3
)
echo integrity check %DATE% %TIME%>> "%LOG%"
where sfc >nul 2>&1
if errorlevel 1 (
    echo sfc not available>> "%LOG%"
    set /a ISSUES+=1
) else (
    echo running sfc scan
    sfc /scannow > "%TEMP%\sfc_out.txt" 2>&1
    type "%TEMP%\sfc_out.txt" >> "%LOG%"
    findstr /i /c:"did not find any integrity violations" "%TEMP%\sfc_out.txt" >nul
    if errorlevel 1 (
        echo sfc reported integrity problems>> "%LOG%"
        set /a ISSUES+=1
    )
)
where dism >nul 2>&1
if errorlevel 1 (
    echo dism not available>> "%LOG%"
    set /a ISSUES+=1
) else (
    echo running dism scanhealth
    dism /online /cleanup-image /scanhealth > "%TEMP%\dism_out.txt" 2>&1
    type "%TEMP%\dism_out.txt" >> "%LOG%"
    findstr /i /c:"no component store corruption detected" "%TEMP%\dism_out.txt" >nul
    if errorlevel 1 (
        echo dism reports component store problems>> "%LOG%"
        set /a ISSUES+=1
    )
)
for %%F in ("%TEMP%\sfc_out.txt" "%TEMP%\dism_out.txt") do if exist "%%~F" del "%%~F"
echo issues=!ISSUES!
echo log=%LOG%
if !ISSUES! GTR 0 exit /b 1
exit /b 0
