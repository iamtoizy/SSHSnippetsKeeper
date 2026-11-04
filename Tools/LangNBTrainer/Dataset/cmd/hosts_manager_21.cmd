@echo off
setlocal
set HOSTS=%WINDIR%\System32\drivers\etc\hosts
set BACKUP=%~dp0hosts.bak
copy /y "%HOSTS%" "%BACKUP%" >nul
echo hosts backed up
set ENTRY=10.0.0.5 git.internal
findstr /c:"git.internal" "%HOSTS%" >nul
if errorlevel 1 (
    echo %ENTRY% >> "%HOSTS%"
    if errorlevel 1 (
        echo failed to append, hosts may be read-only
        exit /b 3
    )
    echo entry added: %ENTRY%
) else (
    echo entry already present
)
ipconfig /flushdns >nul
ping -n 1 git.internal >nul 2>&1
if errorlevel 1 (
    echo git.internal does not resolve yet
) else (
    echo git.internal resolves
)
for /f "tokens=1,2" %%A in ('findstr /v /b /c:"#" "%HOSTS%" ^| findstr "[a-z]"') do (
    echo host entry: %%A %%B
)
find /c /v "" "%HOSTS%"
type "%HOSTS%" | findstr /i "localhost"
echo hosts maintenance done
endlocal
