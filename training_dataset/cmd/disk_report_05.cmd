@echo off
setlocal enabledelayedexpansion
set REPORT=%~dp0disk_report.txt
echo disk report %DATE% %TIME% > "%REPORT%"
for /f "skip=1 tokens=1 delims=," %%A in ('wmic logicaldisk get caption ^| findstr ":"') do (
    set DRIVE=%%A
    set FREE=
    for /f "tokens=2 delims==" %%F in ('wmic logicaldisk where "DeviceID='!DRIVE!'" get freespace /value ^| findstr "="') do set FREE=%%F
    if defined FREE (
        set /a FREE_GB=!FREE! / 1073741824
        echo !DRIVE! free !FREE_GB! GB
        echo !DRIVE! free !FREE_GB! GB >> "%REPORT%"
        if !FREE_GB! LSS 20 (
            echo !DRIVE! low disk space >> "%REPORT%"
        )
    )
)
dir C:\ /a:-d 2>nul | findstr "File(s)"
for /f "tokens=3" %%A in ('dir C:\ /a:-d 2^>nul ^| findstr "bytes free"') do set FREE_BYTES=%%A
echo free bytes on C: %FREE_BYTES%
defrag C: /A 2>nul | findstr /i "fragmentation"
chkntfs C: 2>nul
echo report saved: %REPORT%
type "%REPORT%"
endlocal
