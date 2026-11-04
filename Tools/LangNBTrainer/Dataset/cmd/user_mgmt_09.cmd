@echo off
setlocal
set USERNAME=%~1
if "%USERNAME%"=="" (
    echo usage: user_mgmt.cmd ^<username^>
    exit /b 64
)
net user %USERNAME% >nul 2>&1
if errorlevel 1 (
    echo creating local user %USERNAME%
    net user %USERNAME% "Temp!Pass%RANDOM%" /add /fullname:"Service %USERNAME%" /passwordchg:no >nul
    if errorlevel 1 (
        echo user creation failed
        exit /b 3
    )
    wmic useraccount where "name='%USERNAME%'" set passwordexpires=false >nul
) else (
    echo user %USERNAME% exists
)
net localgroup "Users" %USERNAME% /add >nul 2>&1
net localgroup "Backup Operators" %USERNAME% /add >nul 2>&1
for /f "skip=4 tokens=*" %%L in ('net user %USERNAME%') do echo %%L
net user %USERNAME% | findstr /i "active password"
net localgroup "Backup Operators" | findstr /i "%USERNAME%" >nul
if errorlevel 1 (
    echo membership missing
    exit /b 4
)
echo membership confirmed
net user %USERNAME% /active:yes >nul
echo account activated
wmic useraccount where "name='%USERNAME%'" get sid 2>nul | findstr S-1
net user | find /i /c ""
endlocal
