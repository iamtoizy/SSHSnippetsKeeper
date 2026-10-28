@echo off
setlocal enabledelayedexpansion
set REPORT=%~dp0sysinfo.txt
echo system report %COMPUTERNAME% %DATE% %TIME% > "%REPORT%"
systeminfo | findstr /i "host os total physical" >> "%REPORT%"
wmic cpu get name,numberofcores,maxclockspeed /format:list 2>nul | findstr "=" >> "%REPORT%"
wmic memorychip get capacity,speed /format:list 2>nul | findstr "=" >> "%REPORT%"
wmic diskdrive get model,size /format:list 2>nul | findstr "=" >> "%REPORT%"
ipconfig | findstr /i "ipv4" >> "%REPORT%"
set /a CORES=0
for /f "tokens=2 delims==" %%C in ('wmic cpu get numberofcores /format:list 2^>nul ^| findstr "="') do set /a CORES+=%%C
echo total cores: %CORES% >> "%REPORT%"
wmic os get lastbootuptime /format:list 2>nul | findstr "=" >> "%REPORT%"
ver | findstr /i "microsoft" >> "%REPORT%"
net statistics workstation 2>nul | findstr /i "since" >> "%REPORT%"
set RAM_GB=
for /f "tokens=2 delims==" %%V in ('wmic computersystem get totalphysicalmemory /format:list 2^>nul ^| findstr "="') do set /a RAM_GB=%%V / 1073741824
echo ram: !RAM_GB! GB >> "%REPORT%"
echo report generated >> "%REPORT%"
type "%REPORT%"
for /f "tokens=3" %%N in ('find /c /v "" ^< "%REPORT%"') do echo lines: %%N
endlocal
