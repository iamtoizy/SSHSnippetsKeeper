@echo off
setlocal enabledelayedexpansion
set REPORT=%~dp0shares.csv
echo share,path,remark > "%REPORT%"
net share >nul 2>&1
if errorlevel 1 (
    echo cannot enumerate shares
    exit /b 2
)
set COUNT=0
for /f "tokens=1,2*" %%A in ('net share 2^>nul ^| findstr /v /c:"Share name" /c:"----" /c:"completed successfully"') do (
    if not "%%B"=="" (
        set /a COUNT+=1
        echo !COUNT!: %%A at %%B
        echo %%A,%%B,%%C>> "%REPORT%"
        net share "%%A" 2>nul | findstr /i "permission" >nul
        if not errorlevel 1 echo permission entries listed for %%A
    )
)
echo total shares: !COUNT!
net session >nul 2>&1
if errorlevel 1 (
    echo no active sessions
) else (
    for /f "tokens=1" %%S in ('net session 2^>nul ^| findstr /r /c:"\\\\"') do echo session host: %%S
)
openfiles /query /fo csv 2>nul | find /c /v ""
net use 2>nul | findstr /i "ok"
for /f "tokens=1" %%U in ('net use 2^>nul ^| findstr /r /c:"\\\\"') do echo mapped: %%U
type "%REPORT%"
endlocal
exit /b 0
