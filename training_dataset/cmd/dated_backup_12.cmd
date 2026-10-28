@echo off
setlocal enabledelayedexpansion
set SRC=C:\inetpub\wwwroot
set DST=D:\Backups\web
set DAYS_KEEP=10
for /f "tokens=1-3 delims=. " %%A in ("%DATE%") do (
    set D=%%A
    set M=%%B
    set Y=%%C
)
for /f "tokens=1-2 delims=:," %%A in ("%TIME%") do set HHMM=%%A%%B
set TARGET=%DST%\%Y%-%M%-%D%_%HHMM%
echo backing up to %TARGET%
if not exist "%TARGET%" mkdir "%TARGET%"
xcopy "%SRC%\*.*" "%TARGET%\" /s /e /h /y /i >nul
if errorlevel 4 (
    echo xcopy fatal error
    exit /b 2
)
if errorlevel 1 (
    echo files copied with minor issues
) else (
    echo no changes since last backup
)
icacls "%TARGET%" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F" >nul
set /a COUNT=0
for /f "delims=" %%D in ('dir /b /ad /o-n "%DST%"') do (
    set /a COUNT+=1
    if !COUNT! GTR %DAYS_KEEP% (
        echo removing old backup: %%D
        rmdir /s /q "%DST%\%%D"
    )
)
dir "%DST%" /b /ad | sort
robocopy /L "%SRC%" "%TARGET%" /NJH /NJS 2>nul | findstr /c:"Dirs"
echo backup finished
endlocal
