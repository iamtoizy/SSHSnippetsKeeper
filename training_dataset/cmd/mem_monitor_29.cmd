@echo off
setlocal enabledelayedexpansion
set SAMPLES=5
set INTERVAL=3
set THRESHOLD_MB=512
set LOG=%~dp0mem_monitor.log
echo memory monitoring started > "%LOG%"
set /a ITER=0
:loop
for /f "tokens=2 delims==" %%V in ('wmic os get freephysicalmemory /value 2^>nul ^| findstr "="') do set FREE_MB=%%V
set /a FREE_MB=!FREE_MB! / 1024
set /a ITER+=1
echo sample !ITER!: !FREE_MB! MB free >> "%LOG%"
if !FREE_MB! LSS %THRESHOLD_MB% (
    echo pressure detected at sample !ITER! >> "%LOG%"
    wmic os get totalvisiblememorysize,freephysicalmemory /value 2>nul | findstr "="
)
if !ITER! LSS %SAMPLES% (
    timeout /t %INTERVAL% /nobreak >nul
    goto :loop
)
wmic pagefile get allocatedbasesize,currentusage /value 2>nul | findstr "="
systeminfo | findstr /i "virtual memory"
echo monitoring finished >> "%LOG%"
type "%LOG%"
endlocal
