@echo off
setlocal
set WU_KEY=HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU
reg add "%WU_KEY%" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f >nul
echo no-auto-reboot policy set
reg add "%WU_KEY%" /v ScheduledInstallTime /t REG_DWORD /d 3 /f >nul
reg add "%WU_KEY%" /v ScheduledInstallDay /t REG_DWORD /d 7 /f >nul
echo install window: sunday 03:00
reg query "%WU_KEY%" | findstr /i "scheduled noauto"
sc query wuauserv | findstr STATE
sc query bits | findstr STATE
net stop wuauserv >nul 2>&1
del /q /f "%WINDIR%\SoftwareDistribution\Download\*.*" 2>nul
echo update cache cleaned
net start wuauserv >nul 2>&1
if errorlevel 1 (
    echo wuauserv failed to start
    exit /b 3
)
echo update service restarted
usoclient StartScan 2>nul
usoclient StartDownload 2>nul
echo scan triggered
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1
if errorlevel 1 (
    echo no reboot pending
) else (
    echo reboot pending
)
wmic qfe get hotfixid,installedon 2>nul | findstr /v "^$"
echo update client maintenance finished
endlocal
