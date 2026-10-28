@echo off
setlocal enabledelayedexpansion
set DP_SCRIPT=%TEMP%\dp_query.txt
echo list disk > "%DP_SCRIPT%"
echo list volume >> "%DP_SCRIPT%"
echo exit >> "%DP_SCRIPT%"
diskpart /s "%DP_SCRIPT%" > "%TEMP%\dp_out.txt" 2>nul
if errorlevel 1 (
    echo diskpart requires elevation
    exit /b 3
)
findstr /i "disk" "%TEMP%\dp_out.txt"
for /f "tokens=2,3,4" %%D in ('findstr /b /c:"Disk 0" "%TEMP%\dp_out.txt"') do (
    echo disk0 info: %%D %%E
)
echo select disk 0 > "%DP_SCRIPT%"
echo detail disk >> "%DP_SCRIPT%"
echo exit >> "%DP_SCRIPT%"
diskpart /s "%DP_SCRIPT%" 2>nul | findstr /i "type status"
echo list volume > "%DP_SCRIPT%"
echo exit >> "%DP_SCRIPT%"
for /f "tokens=1,2,3,4" %%A in ('diskpart /s "%DP_SCRIPT%" 2^>nul ^| findstr /i "volume"') do (
    echo vol %%A %%B %%C %%D
)
wmic diskdrive get index,model,size 2>nul | findstr /v "^$"
del "%DP_SCRIPT%" "%TEMP%\dp_out.txt" 2>nul
echo disk query finished
endlocal
