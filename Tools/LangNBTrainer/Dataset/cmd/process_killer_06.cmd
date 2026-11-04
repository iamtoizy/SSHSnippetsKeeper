@echo off
setlocal enabledelayedexpansion
set PROCESS_NAME=%~1
if "%PROCESS_NAME%"=="" (
    echo usage: process_killer.cmd ^<name^> [cpu_limit]
    exit /b 64
)
set CPU_LIMIT=%~2
if "%CPU_LIMIT%"=="" set CPU_LIMIT=90
echo looking for %PROCESS_NAME%, memory limit %CPU_LIMIT%%% ram
wmic path win32_process where "name='%PROCESS_NAME%'" get processid 2>nul | findstr [0-9] >nul
if errorlevel 1 (
    echo process not found
    exit /b 1
)
for /f "tokens=2 delims=," %%P in ('wmic path win32_process where "name='%PROCESS_NAME%'" get processid /format:csv 2^>nul ^| findstr [0-9]') do (
    set CURRENT_PID=%%P
    tasklist /fi "PID eq !CURRENT_PID!" 2>nul | findstr /i "%PROCESS_NAME%" >nul
    if not errorlevel 1 (
        echo killing pid !CURRENT_PID!
        taskkill /pid !CURRENT_PID! /f >nul 2>&1
        if errorlevel 1 (
            echo failed to kill !CURRENT_PID!
        ) else (
            echo killed !CURRENT_PID!
        )
    )
)
tasklist | find /i /c "%PROCESS_NAME%"
wmic path win32_process where "name='%PROCESS_NAME%'" get processid 2>nul | findstr [0-9] >nul
if errorlevel 1 (
    echo all instances terminated
    exit /b 0
)
echo some instances still running
exit /b 3
