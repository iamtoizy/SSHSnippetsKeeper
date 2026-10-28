@echo off
setlocal
set RULE_NAME=MyApp-Web
netsh advfirewall firewall show rule name="%RULE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo rule absent, creating
    netsh advfirewall firewall add rule name="%RULE_NAME%" dir=in action=allow protocol=TCP localport=8443 profile=domain,private >nul
    if errorlevel 1 (
        echo rule creation failed
        exit /b 3
    )
    echo rule created for tcp 8443
) else (
    echo rule exists
)
netsh advfirewall firewall show rule name="%RULE_NAME%" | findstr /i "localport action profile"
netsh advfirewall firewall set rule name="%RULE_NAME%" new localport=9443 >nul
echo port changed to 9443
netsh advfirewall firewall show rule name="%RULE_NAME%" | findstr localport
netsh advfirewall show allprofiles state | findstr /i "state"
netsh advfirewall export "%~dp0firewall_policy.wfw" >nul
if exist "%~dp0firewall_policy.wfw" (
    echo policy exported
)
netsh advfirewall firewall delete rule name="%RULE_NAME%" >nul
echo rule removed
netsh advfirewall show currentprofile | findstr /i "domain"
endlocal
