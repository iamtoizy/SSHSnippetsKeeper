@echo off
setlocal
set MSI=%~dp0packages\appsetup.msi
set LOG=%~dp0msi_install.log
if not exist "%MSI%" (
    echo msi package missing: %MSI%
    exit /b 2
)
msiexec /i "%MSI%" /qn /l* "%LOG%" TARGETDIR="C:\Program Files\MyApp"
set RC=%ERRORLEVEL%
if %RC% EQU 0 (
    echo install succeeded
) else if %RC% EQU 3010 (
    echo install succeeded, reboot required
) else if %RC% EQU 1638 (
    echo another version of this product is already installed
) else (
    echo msiexec failed with code %RC%
    findstr /i "error" "%LOG%" | more
    exit /b %RC%
)
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /s /f "MyApp" /d 2>nul | findstr /i "MyApp"
wmic product where "name like 'MyApp%%'" get name,version 2>nul | findstr /i "MyApp"
del "%LOG%.old" 2>nul
move /y "%LOG%" "%LOG%.old" >nul
echo deployment finished
endlocal
