@echo off
setlocal enabledelayedexpansion
if not exist "%SystemRoot%\System32\inetsrv\appcmd.exe" (
    echo iis appcmd missing
    exit /b 3
)
set REPORT=%~dp0iis_bindings.txt
if exist "%REPORT%" del "%REPORT%"
pushd "%SystemRoot%\System32\inetsrv"
set SITES=0
for /f "delims=" %%S in ('appcmd list sites /text:name 2^>nul') do (
    set SITE=%%S
    set /a SITES+=1
    echo site: !SITE!>> "%REPORT%"
    for /f "delims=" %%T in ('appcmd list site "!SITE!" /text:state 2^>nul') do echo state: %%T>> "%REPORT%"
    for /f "delims=" %%B in ('appcmd list bindings "!SITE!" /text:bindingInformation 2^>nul') do (
        echo binding: %%B>> "%REPORT%"
        for /f "tokens=3 delims=:" %%P in ("%%B") do (
            netstat -ano | findstr ":%%P " >nul
            if errorlevel 1 echo port %%P not listening for !SITE!
        )
    )
)
popd
echo sites: !SITES!
findstr /i "Stopped" "%REPORT%" >nul
if not errorlevel 1 echo warning: stopped sites detected
netstat -ano | findstr ":80 " | find /c /v ""
type "%REPORT%"
endlocal
exit /b 0
