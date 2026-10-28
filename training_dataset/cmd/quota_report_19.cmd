@echo off
setlocal enabledelayedexpansion
set HOME_ROOT=D:\Users
if not exist "%HOME_ROOT%" (
    echo home root missing
    exit /b 2
)
set QUOTA_MB=500
echo user,mb,over_quota > "%~dp0quota_report.csv"
for /d %%U in ("%HOME_ROOT%\*") do (
    set SIZE_KB=0
    set USER_DIR=%%U
    for /r "!USER_DIR!" %%F in (*.*) do set /a SIZE_KB+=%%~zF / 1024
    set /a SIZE_MB=!SIZE_KB! / 1024
    echo !USER_DIR! !SIZE_MB! MB
    set OVER=no
    if !SIZE_MB! GTR %QUOTA_MB% (
        set OVER=yes
        echo !USER_DIR! exceeds quota
    )
    echo !USER_DIR!,!SIZE_MB!,!OVER! >> "%~dp0quota_report.csv"
)
sort "%~dp0quota_report.csv" /o "%~dp0quota_report.csv"
fsutil quota query D: 2>nul | findstr /i "limit"
type "%~dp0quota_report.csv"
endlocal
