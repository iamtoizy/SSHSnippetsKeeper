@echo off
setlocal enabledelayedexpansion
set INPUT=%~dp0sales.csv
set OUTPUT=%~dp0summary.txt
if not exist "%INPUT%" (
    echo csv missing: %INPUT%
    exit /b 2
)
set /a TOTAL=0
set /a ROWS=0
for /f "usebackq skip=1 tokens=1-4 delims=;" %%A in (`"%INPUT%"`) do (
    set /a ROWS+=1
    set /a TOTAL+=%%D
    echo region %%A product %%B qty %%C sum %%D
)
echo rows processed: %ROWS% > "%OUTPUT%"
echo total sum: %TOTAL% >> "%OUTPUT%"
if %TOTAL% GTR 100000 (
    echo high volume month >> "%OUTPUT%"
)
sort "%INPUT%" /o "%INPUT%.sorted"
findstr /b "north" "%INPUT%.sorted" | find /c "north"
set /a QTY_SUM=0
for /f "usebackq skip=1 tokens=3 delims=;" %%Q in (`"%INPUT%"`) do set /a QTY_SUM+=%%Q
echo quantity sum: %QTY_SUM% >> "%OUTPUT%"
del "%INPUT%.sorted" 2>nul
type "%OUTPUT%"
endlocal
