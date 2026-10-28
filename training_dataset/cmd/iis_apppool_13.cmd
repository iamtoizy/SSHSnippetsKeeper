@echo off
setlocal enabledelayedexpansion
set APPCMD=%WINDIR%\system32\inetsrv\appcmd.exe
if not exist "%APPCMD%" (
    echo iis is not installed
    exit /b 2
)
"%APPCMD%" list apppool /state:Started /text:NAME
for /f "usebackq delims=" %%P in (`"%APPCMD%" list apppool /state:Stopped /text:NAME`) do (
    echo stopped pool: %%P
    "%APPCMD%" start apppool /apppool.name:"%%P" >nul 2>&1
    if errorlevel 1 (
        echo failed to start %%P
    ) else (
        echo started %%P
    )
)
"%APPCMD%" list wp >nul 2>&1
if errorlevel 1 (
    echo no worker processes running
) else (
    "%APPCMD%" list wp /text:processId,apppool.name
)
for /f "usebackq tokens=2 delims=:" %%T in (`"%APPCMD%" list apppool /text:processModel.startMode`) do (
    echo start mode: %%T
)
"%APPCMD%" recycle apppool /apppool.name:"DefaultAppPool" >nul 2>&1
if errorlevel 1 (
    echo recycle skipped
) else (
    echo DefaultAppPool recycled
)
"%APPCMD%" list site /text:name,state
"%APPCMD%" list apppool /text:NAME | find /c /v ""
endlocal
