@echo off
set "MQL_FILE=%~1"

echo Compiling for both terminals...
echo.

echo Compiling for FTMO...
"C:\Program Files\FTMO MetaTrader 5\metaeditor64.exe" /compile:"%MQL_FILE%" /log:"%~dp0build_log.ftmo.txt"
if exist "%~dp0build_log.ftmo.txt" (
    type "%~dp0build_log.ftmo.txt"
)
echo.

echo Compiling for Fusion...
"C:\Users\abhid\AppData\Roaming\Fusion Markets MT5 Terminal\metaeditor64.exe" /compile:"%MQL_FILE%" /log:"%~dp0build_log.fusion.txt"
if exist "%~dp0build_log.fusion.txt" (
    type "%~dp0build_log.fusion.txt"
)