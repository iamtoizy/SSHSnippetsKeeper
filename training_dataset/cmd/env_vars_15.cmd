@echo off
setlocal enabledelayedexpansion
set APP_HOME=C:\Tools\MyApp
echo %PATH% | find /c /v ""
setx APP_HOME "%APP_HOME%" /m >nul 2>&1
if errorlevel 1 (
    echo setx failed, no admin rights
    exit /b 2
)
echo APP_HOME persisted: %APP_HOME%
for /f "skip=2 tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set SYS_PATH=%%B
echo %SYS_PATH% | find /i "%APP_HOME%" >nul
if errorlevel 1 (
    setx /m Path "%SYS_PATH%;%APP_HOME%" >nul
    echo path extended
) else (
    echo path already contains APP_HOME
)
set JAVA_OPTS=-Xms256m -Xmx1024m -Dapp.home=%APP_HOME%
setx JAVA_OPTS "%JAVA_OPTS%" /m >nul
echo java opts: %JAVA_OPTS%
set CLEAN_PATH=%SYS_PATH:;;=;%
echo cleaned path sample: %CLEAN_PATH:~0,80%
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v APP_HOME 2>nul | findstr APP_HOME
wmic environment where "name='APP_HOME'" get variablevalue 2>nul | findstr /i "APP"
echo environment setup finished
endlocal
