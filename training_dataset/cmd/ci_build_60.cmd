@echo off
setlocal enabledelayedexpansion
set PROJECT=%~1
if "%PROJECT%"=="" set PROJECT=%CD%
shift
set CONFIG=Release
if not "%~1"=="" set CONFIG=%~1
set ARTIFACTS=%~dp0artifacts
if not exist "%PROJECT%" (
    echo project path missing: %PROJECT%
    exit /b 2
)
where dotnet >nul 2>&1
if errorlevel 1 (
    echo dotnet sdk not available
    exit /b 3
)
pushd "%PROJECT%"
if exist "%ARTIFACTS%" rd /s /q "%ARTIFACTS%"
set STEP=restore
dotnet restore > "%TEMP%\ci_restore.log" 2>&1
if errorlevel 1 goto :failed
set STEP=build
dotnet build --configuration %CONFIG% --no-restore > "%TEMP%\ci_build.log" 2>&1
if errorlevel 1 goto :failed
set STEP=test
dotnet test --configuration %CONFIG% --no-build --logger "console;verbosity=minimal" > "%TEMP%\ci_test.log" 2>&1
if errorlevel 1 goto :failed
set STEP=publish
dotnet publish --configuration %CONFIG% --no-build --output "%ARTIFACTS%" > "%TEMP%\ci_publish.log" 2>&1
if errorlevel 1 goto :failed
popd
echo build succeeded configuration=%CONFIG%
dir /b "%ARTIFACTS%" 2>nul | find /c /v ""
exit /b 0
:failed
popd
echo step %STEP% failed
findstr /i "error" "%TEMP%\ci_%STEP%.log" | findstr /v /i "0 error"
exit /b 1
