@echo off
setlocal enabledelayedexpansion
set SRC=%~dp0data
set DST=D:\Backup\data
set LOG=%~dp0robocopy.log
if not exist "%SRC%" (
    echo source folder missing: %SRC%
    exit /b 2
)
robocopy "%SRC%" "%DST%" /MIR /R:2 /W:5 /NP /LOG+:"%LOG%" /XD tmp cache
set RC=%ERRORLEVEL%
if %RC% GEQ 16 (
    echo fatal error, no files copied
    exit /b %RC%
)
if %RC% GEQ 8 (
    echo some files failed to copy
    exit /b %RC%
)
if %RC% GEQ 1 (
    echo files copied or skipped: code %RC%
) else (
    echo source and destination in sync
)
for /f "tokens=1,2,3,4" %%A in ('findstr /c:"Files :" /c:"Dirs :" /c:"Bytes :" "%LOG%"') do (
    echo %%A %%B %%C %%D
)
for /f "delims=" %%L in ('robocopy /L "%SRC%" "%DST%" /MIR /NJH /NJS 2^>nul ^| find /c /v ""') do set PENDING=%%L
echo pending changes: %PENDING%
if exist "%DST%\important.db" (
    echo critical file present in backup
) else (
    echo critical file missing in backup
    exit /b 3
)
type "%LOG%" | findstr /i "started ended"
exit /b 0
