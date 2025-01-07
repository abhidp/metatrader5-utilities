@echo off
echo MT5 Development Environment Setup Script
echo =====================================
echo This script will create symbolic links between your GitHub repository and MT5 directory.
echo Please run this script as Administrator.
echo.

:: Define paths
set "GITHUB_DIR=C:\Users\abhid\Documents\Projects\metatrader5-utilities"
set "MT5_DIR=C:\Users\abhid\AppData\Roaming\MetaQuotes\Terminal\49CDDEAA95A409ED22BD2287BB67CB9C\MQL5"

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Error: This script requires administrator privileges.
    echo Please right-click the script and select "Run as administrator"
    pause
    exit /b 1
)

echo Creating symbolic links...
echo.

:: Backup existing folders if they exist
if exist "%MT5_DIR%\Experts\Abhis_EAs" (
    echo Backing up existing Abhis_EAs folder...
    move "%MT5_DIR%\Experts\Abhis_EAs" "%MT5_DIR%\Experts\Abhis_EAs_backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%"
)

:: Create symbolic links for each folder
echo Creating link for Abhis_EAs...
mklink /D "%MT5_DIR%\Experts\Abhis_EAs" "%GITHUB_DIR%\Experts\Abhis_EAs"

echo Creating link for Common folder...
mklink /D "%MT5_DIR%\Experts\Common" "%GITHUB_DIR%\Experts\Common"

echo Creating link for Include folder...
mklink /D "%MT5_DIR%\Include\Abhis_Include" "%GITHUB_DIR%\Include\Abhis_Include"

echo Creating link for Indicators folder...
mklink /D "%MT5_DIR%\Indicators\Abhis_Indicators" "%GITHUB_DIR%\Indicators\Abhis_Indicators"

echo Creating link for Scripts folder...
mklink /D "%MT5_DIR%\Scripts\Abhis_Scripts" "%GITHUB_DIR%\Scripts\Abhis_Scripts"

echo Creating link for Libraries folder...
mklink /D "%MT5_DIR%\Libraries\Abhis_Lib" "%GITHUB_DIR%\Libraries\Abhis_Lib"

echo.
echo Setup completed!
echo If you didn't see any errors above, your development environment is ready.
echo You can now edit files in your GitHub folder and they will be automatically available in MT5.
echo.
pause