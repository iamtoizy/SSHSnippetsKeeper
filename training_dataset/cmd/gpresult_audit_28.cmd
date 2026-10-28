@echo off
setlocal
echo refreshing group policy
gpupdate /force >nul 2>&1
if errorlevel 1 (
    echo gpupdate failed
    exit /b 2
)
echo policy refreshed
gpresult /r > "%TEMP%\gp.txt" 2>nul
findstr /i "applied group policy objects" "%TEMP%\gp.txt"
for /f "tokens=* delims=" %%L in ('findstr /i /c:"gpo" "%TEMP%\gp.txt"') do (
    echo %%L
)
set REPORT=%~dp0gp_report.html
gpresult /h "%REPORT%" /f >nul 2>&1
if exist "%REPORT%" (
    echo html report created
    dir "%REPORT%" | findstr /i "gp_report"
)
gpresult /scope computer /r 2>nul | findstr /i "site name domain"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies" /s 2>nul | find /c "REG_"
findstr /i /c:"gpo" "%TEMP%\gp.txt" | find /c "gpo"
del "%TEMP%\gp.txt" 2>nul
echo group policy audit finished
endlocal
