@echo off
setlocal
set SECURE_DIR=D:\SecureData
if not exist "%SECURE_DIR%" (
    echo secure dir missing: %SECURE_DIR%
    exit /b 2
)
cipher /e /s:"%SECURE_DIR%" >nul 2>&1
if errorlevel 1 (
    echo encryption failed, efs may be unavailable
    exit /b 3
)
echo folder encrypted with efs
cipher /c "%SECURE_DIR%" 2>nul | findstr /i "encryption certificate"
attrib +h "%SECURE_DIR%\*.*" /s /d >nul
echo files hidden
for /r "%SECURE_DIR%" %%F in (*.doc *.xls *.txt) do (
    echo protected: %%F
)
icacls "%SECURE_DIR%" /grant:r "Users:(OI)(CI)RX" >nul 2>&1
icacls "%SECURE_DIR%" | findstr /i "users"
compact /q "%SECURE_DIR%" 2>nul | findstr /i "ratio"
attrib -h "%SECURE_DIR%\report.txt" >nul 2>&1
echo security hardening finished
endlocal
