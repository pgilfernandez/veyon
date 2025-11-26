@echo off
REM Network Control Plugin - Windows Installation Script
REM This script installs a pre-compiled networkcontrol.dll plugin into Veyon

echo ============================================================
echo   Veyon NetworkControl Plugin - Windows Installer
echo ============================================================
echo.

REM Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges
    echo.
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo [*] Running with Administrator privileges
echo.

REM Set variables
set VEYON_DIR=C:\Program Files\Veyon
set PLUGIN_DIR=%VEYON_DIR%\plugins
set PLUGIN_NAME=networkcontrol.dll
set VERSION=2.0.0

REM Check if Veyon is installed
if not exist "%VEYON_DIR%" (
    echo ERROR: Veyon installation not found at: %VEYON_DIR%
    echo.
    echo Please install Veyon first or specify the correct installation directory
    pause
    exit /b 1
)

echo [*] Found Veyon installation at: %VEYON_DIR%
echo.

REM Check if plugins directory exists
if not exist "%PLUGIN_DIR%" (
    echo ERROR: Plugins directory not found: %PLUGIN_DIR%
    echo.
    echo Creating plugins directory...
    mkdir "%PLUGIN_DIR%"
    if %errorLevel% neq 0 (
        echo ERROR: Failed to create plugins directory
        pause
        exit /b 1
    )
)

REM Check if networkcontrol.dll exists in current directory
if not exist "%PLUGIN_NAME%" (
    echo ERROR: %PLUGIN_NAME% not found in current directory
    echo.
    echo Please ensure you have compiled the plugin and the DLL is in the same
    echo directory as this script.
    echo.
    echo To compile the plugin for Windows, you need to:
    echo   1. Set up a MinGW cross-compilation environment on Linux
    echo   2. Follow the build instructions in README.md
    echo   3. Copy the resulting networkcontrol.dll to this directory
    echo.
    pause
    exit /b 1
)

echo [*] Found %PLUGIN_NAME% in current directory
echo.

REM Stop Veyon Service if running
echo [*] Checking if Veyon Service is running...
sc query VeyonService | find "RUNNING" >nul 2>&1
if %errorLevel% equ 0 (
    echo [*] Stopping Veyon Service...
    net stop VeyonService
    if %errorLevel% neq 0 (
        echo WARNING: Failed to stop Veyon Service
        echo You may need to stop it manually before continuing
        pause
    ) else (
        echo [*] Veyon Service stopped
        set RESTART_SERVICE=1
    )
) else (
    echo [*] Veyon Service is not running
    set RESTART_SERVICE=0
)
echo.

REM Close Veyon Master if running
tasklist /FI "IMAGENAME eq veyon-master.exe" 2>NUL | find /I /N "veyon-master.exe">NUL
if %errorLevel% equ 0 (
    echo [*] Veyon Master is running. Please close it before continuing.
    echo.
    pause
)

REM Backup existing plugin if it exists
if exist "%PLUGIN_DIR%\%PLUGIN_NAME%" (
    echo [*] Backing up existing plugin...
    copy "%PLUGIN_DIR%\%PLUGIN_NAME%" "%PLUGIN_DIR%\%PLUGIN_NAME%.backup" >nul
    if %errorLevel% equ 0 (
        echo [*] Backup created: %PLUGIN_NAME%.backup
    )
)
echo.

REM Copy plugin
echo [*] Installing plugin to: %PLUGIN_DIR%\%PLUGIN_NAME%
copy /Y "%PLUGIN_NAME%" "%PLUGIN_DIR%\%PLUGIN_NAME%"
if %errorLevel% neq 0 (
    echo ERROR: Failed to copy plugin to Veyon directory
    echo.
    echo Please check file permissions and try again
    pause
    exit /b 1
)

echo [*] Plugin installed successfully
echo.

REM Restart Veyon Service if it was running
if "%RESTART_SERVICE%"=="1" (
    echo [*] Restarting Veyon Service...
    net start VeyonService
    if %errorLevel% neq 0 (
        echo WARNING: Failed to restart Veyon Service
        echo Please restart it manually:
        echo   services.msc -^> VeyonService -^> Start
    ) else (
        echo [*] Veyon Service restarted
    )
    echo.
)

REM Display completion message
echo ============================================================
echo   Installation Complete
echo ============================================================
echo.
echo Plugin installed: %PLUGIN_DIR%\%PLUGIN_NAME%
echo Version: %VERSION%
echo.
echo IMPORTANT NOTES:
echo.
echo 1. Network control on Windows works differently than Linux/macOS:
echo    - Uses Windows Firewall rules instead of route manipulation
echo    - Requires the Veyon Service to be running
echo    - May require additional Windows Firewall configuration
echo.
echo 2. If Veyon Master is running, please restart it to load the plugin
echo.
echo 3. The network control feature will appear in the Veyon Master interface
echo    under the "Features" menu
echo.
echo 4. To uninstall, simply delete: %PLUGIN_DIR%\%PLUGIN_NAME%
echo.
echo ============================================================
echo.
pause
