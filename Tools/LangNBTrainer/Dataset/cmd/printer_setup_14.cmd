@echo off
setlocal
echo current printers:
wmic printer get name,default,portname 2>nul | findstr /v "^$"
for /f "tokens=2 delims==" %%D in ('wmic printer where "default=true" get name /value 2^>nul ^| findstr "="') do set DEFAULT_PRN=%%D
echo default printer: %DEFAULT_PRN%
net stop spooler >nul 2>&1
timeout /t 2 /nobreak >nul
set SPOOL_DIR=%WINDIR%\System32\spool\PRINTERS
if exist "%SPOOL_DIR%" (
    del /q /f "%SPOOL_DIR%\*.*" 2>nul
    echo spool folder cleaned
)
net start spooler >nul
if errorlevel 1 (
    echo spooler failed to start
    exit /b 3
)
echo spooler restarted
wmic printer where "workoffline=true" get name 2>nul | findstr /v "^$"
for /f "tokens=2 delims==" %%N in ('wmic printer where "workoffline=true" get name /value 2^>nul ^| findstr "="') do (
    echo offline printer: %%N
    wmic printer where "name='%%N'" set workoffline=false >nul 2>&1
)
net start spooler | findstr /i "service"
wmic printer get name,status 2>nul | findstr /v "^$"
echo printer maintenance finished
endlocal
