@echo off
echo MT5 Watch and Compile Script (All Files)
echo =====================================
echo.

:: Configuration
set "METAEDITOR_PATH=C:\Program Files\FTMO MetaTrader 5\metaeditor64.exe"
set "GITHUB_DIR=C:\Users\abhid\Documents\Projects\metatrader5-utilities"
set "LOG_FILE=%GITHUB_DIR%\build_log.txt"
set "TEMP_FILE=%TEMP%\mt5_files.tmp"

:: Check if MetaEditor exists
if not exist "%METAEDITOR_PATH%" (
    echo Error: MetaEditor not found at %METAEDITOR_PATH%
    pause
    exit /b 1
)

echo MetaEditor found at: %METAEDITOR_PATH%
echo Watching directory: %GITHUB_DIR%
echo Monitoring all .mq5 files in:
echo  - Experts\Abhis_EAs
echo  - Indicators\Abhis_Indicators
echo  - Scripts\Abhis_Scripts
echo.
echo Press Ctrl+C to stop watching...
echo.

:: Create initial state file
dir /s /b "%GITHUB_DIR%\*.mq5" > "%TEMP_FILE%"
for /f "delims=" %%F in ('dir /s /b "%GITHUB_DIR%\*.mq5"') do (
    for %%A in ("%%F") do set "SIZE_%%~nxA=%%~zA"
)

:WATCH_LOOP
:: Check each .mq5 file
for /f "delims=" %%F in ('dir /s /b "%GITHUB_DIR%\*.mq5"') do (
    :: Get current file size
    for %%A in ("%%F") do set "CURRENT_SIZE=%%~zA"
    
    :: Get stored size (if exists)
    call set "LAST_SIZE=%%SIZE_%%~nxF%%"
    
    :: Compare sizes
    if not "!CURRENT_SIZE!"=="!LAST_SIZE!" (
        echo Changes detected in: %%~nxF
        echo Compiling...
        echo.
        
        :: Compile the file
        "%METAEDITOR_PATH%" /compile:"%%F" /log:"%LOG_FILE%"
        
        :: Check result
        if exist "%%~dpnF.ex5" (
            echo.
            echo Compilation successful: %%~nxF
            if exist "%LOG_FILE%" type "%LOG_FILE%"
        ) else (
            echo.
            echo Compilation failed: %%~nxF
            if exist "%LOG_FILE%" type "%LOG_FILE%"
        )
        
        :: Update stored size
        for %%A in ("%%F") do set "SIZE_%%~nxA=%%~zA"
        echo.
        echo Watching for changes...
        echo.
    )
)

:: Check for new files
dir /s /b "%GITHUB_DIR%\*.mq5" > "%TEMP_FILE%.new"
fc "%TEMP_FILE%" "%TEMP_FILE%.new" > nul
if errorlevel 1 (
    :: New file detected, update the list
    copy /y "%TEMP_FILE%.new" "%TEMP_FILE%" > nul
    echo New .mq5 file detected! Adding to watch list...
    echo.
)

:: Wait before next check
timeout /t 2 /nobreak > nul
goto WATCH_LOOP