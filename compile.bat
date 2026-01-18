@echo off
set "MQL_FILE=%~1"
set "MT5_DATA=C:\Users\abhid\AppData\Roaming\MetaQuotes\Terminal\9B207513987DDC3C65E0F2AC7EE65D70\MQL5"

echo Compiling for Vantage...
echo.

"C:/Program Files/Vantage Australia MT5 Terminal/MetaEditor64.exe" /compile:"%MQL_FILE%" /log:"%~dp0build_log.vantage.txt"
if exist "%~dp0build_log.vantage.txt" (
    type "%~dp0build_log.vantage.txt"
)

echo.
echo Copying to MT5 data folder...

REM Get the compiled .ex5 file path (same as source but with .ex5 extension)
set "EX5_FILE=%~dpn1.ex5"

if exist "%EX5_FILE%" (
    setlocal enabledelayedexpansion

    REM Get the full path
    set "FULL_PATH=%~dp1"
    set "REL_PATH="

    REM Extract path starting from Experts, Indicators, or Scripts using PowerShell
    for /f "delims=" %%a in ('powershell -NoProfile -Command "$p='!FULL_PATH!'; if($p -match '(Experts.*)$'){$matches[1]}elseif($p -match '(Indicators.*)$'){$matches[1]}elseif($p -match '(Scripts.*)$'){$matches[1]}else{''}"') do set "REL_PATH=%%a"

    if "!REL_PATH!"=="" (
        echo ERROR: Could not determine destination folder. File must be in Experts, Indicators, or Scripts folder.
        endlocal
        goto :eof
    )

    set "DEST_DIR=%MT5_DATA%\!REL_PATH!"

    REM Create destination directory if it doesn't exist
    if not exist "!DEST_DIR!" mkdir "!DEST_DIR!"

    REM Copy the .ex5 file
    copy /Y "%EX5_FILE%" "!DEST_DIR!" >nul
    if !errorlevel! == 0 (
        echo SUCCESS: Copied to !DEST_DIR!
        echo.
        echo Refresh Navigator in MT5 to see the EA.
    ) else (
        echo ERROR: Failed to copy file.
    )
    endlocal
) else (
    echo WARNING: No .ex5 file found. Compilation may have failed.
)