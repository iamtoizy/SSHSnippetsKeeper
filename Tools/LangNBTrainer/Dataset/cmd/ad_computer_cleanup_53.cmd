@echo off
setlocal enabledelayedexpansion
set INACTIVE_WEEKS=12
set MODE=dryrun
if /i "%~1"=="apply" set MODE=apply
if /i "%~1"=="help" goto :usage
where dsquery >nul 2>&1
if errorlevel 1 (
    echo dsquery not found, install rsat tools
    exit /b 3
)
set LIST=%~dp0stale_computers.txt
if exist "%LIST%" del "%LIST%"
echo scanning computers inactive for %INACTIVE_WEEKS% weeks
dsquery computer -inactive %INACTIVE_WEEKS% -limit 0 > "%LIST%" 2>nul
if errorlevel 1 (
    echo query failed
    exit /b 4
)
set COUNT=0
for /f "usebackq delims=" %%C in ("%LIST%") do (
    set /a COUNT+=1
    echo stale: %%C
    if /i "%MODE%"=="apply" (
        dsmod computer "%%C" -disabled yes >nul 2>&1
        if errorlevel 1 (
            echo disable failed: %%C
        ) else (
            echo disabled: %%C
        )
    )
)
echo found !COUNT! stale computers in %MODE% mode
if /i "%MODE%"=="apply" goto :verify
echo rerun with apply argument to disable listed accounts
exit /b 0
:verify
dsquery computer -disabled -limit 0 | find /c /v ""
exit /b 0
:usage
echo usage: %~nx0 [apply]
exit /b 0
