@echo off
setlocal enabledelayedexpansion
wmic userprofile get localpath,loaded 2>nul | findstr /v "^$"
for /f "skip=1 tokens=2-3 delims=," %%A in ('wmic userprofile get localpath^,loaded /format:csv 2^>nul ^| findstr ":"') do (
    set PROFILE_PATH=%%A
    set LOADED=%%B
    for %%D in ("!PROFILE_PATH!") do set PROFILE_NAME=%%~nxD
    echo profile: !PROFILE_NAME! loaded=!LOADED!
    if /i "!LOADED!"=="FALSE" if exist "!PROFILE_PATH!\NTUSER.DAT" (
        echo !PROFILE_NAME! has registry hive
    )
)
dir "%SystemDrive%\Users" /b /ad 2>nul
dir "%SystemDrive%\Users" /b /ad 2>nul | find /c /v ""
wmic useraccount get name,sid,status 2>nul | findstr /v "^$"
for /f "tokens=2 delims==" %%S in ('wmic os get localdatetime /value 2^>nul ^| findstr "="') do set NOW=%%S
echo date: !NOW:~0,8!
net user | find /c /v ""
echo profile audit finished
endlocal
