@echo off
setlocal enabledelayedexpansion
set LOGFILE=%~dp0app.log
set PATTERN=%~1
if "%PATTERN%"=="" set PATTERN=error
if not exist "%LOGFILE%" (
    echo log file missing: %LOGFILE%
    exit /b 2
)
findstr /i /c:"%PATTERN%" "%LOGFILE%" > "%TEMP%\hits.txt"
for /f %%C in ('find /c /v "" ^< "%TEMP%\hits.txt"') do set HITS=%%C
echo pattern "%PATTERN%" hits: %HITS%
if %HITS% EQU 0 (
    echo nothing to report
    exit /b 0
)
set /a IDX=0
for /f "tokens=1* delims=:" %%A in ('findstr /n /i /c:"%PATTERN%" "%LOGFILE%"') do (
    set /a IDX+=1
    if !IDX! LEQ 5 echo line %%A: %%B
)
for /f %%T in ('type "%LOGFILE%" ^| find /c /v ""') do set TOTAL=%%T
echo total lines: %TOTAL%
set /a RATIO=%HITS% * 100 / %TOTAL%
echo error ratio: %RATIO%%%
if %RATIO% GTR 20 (
    echo error rate too high, rotating log
    copy /y "%LOGFILE%" "%LOGFILE%.%RANDOM%" >nul
    break > "%LOGFILE%"
)
findstr /i /c:"warning" "%LOGFILE%" | find /c "warning"
del "%TEMP%\hits.txt" 2>nul
endlocal
