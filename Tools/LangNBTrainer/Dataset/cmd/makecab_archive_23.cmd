@echo off
setlocal enabledelayedexpansion
set SRC=%~dp0logs
set ARC=%~dp0cabs
if not exist "%ARC%" mkdir "%ARC%"
set /a COUNT=0
for %%F in ("%SRC%\*.log") do (
    set NAME=%%~nF
    if not exist "%ARC%\!NAME!.cab" (
        makecab /D CompressionType=LZX /L "%ARC%" "%%F" >nul
        if errorlevel 1 (
            echo cab failed for %%F
        ) else (
            echo packed: !NAME!.cab
            set /a COUNT+=1
        )
    )
)
echo new archives: %COUNT%
for %%C in ("%ARC%\*.cab") do (
    expand "%%C" -F:* "%TEMP%\cabtest" >nul 2>&1
    if errorlevel 1 (
        echo corrupt archive: %%~nxC
    ) else (
        echo verified: %%~nxC
    )
)
dir "%ARC%" /b | sort
for /f "tokens=3" %%S in ('dir "%ARC%" 2^>nul ^| findstr "File(s)"') do set TOTAL=%%S
echo archive dir bytes: %TOTAL%
del /q "%TEMP%\cabtest\*.*" 2>nul
echo cab maintenance finished
endlocal
