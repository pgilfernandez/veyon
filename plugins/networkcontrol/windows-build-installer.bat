@echo off
REM Build NSIS Installer for NetworkControl Plugin
REM
REM Requirements:
REM   - NSIS 3.x installed (https://nsis.sourceforge.io/)
REM   - networkcontrol.dll compiled and present in this directory
REM
REM This script will create: VeyonNetworkControl-2.0.0-win64-setup.exe

echo ============================================================
echo   NetworkControl Plugin - NSIS Installer Builder
echo ============================================================
echo.

REM Check if NSIS is installed
where makensis >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: NSIS is not installed or not in PATH
    echo.
    echo Please download and install NSIS from:
    echo   https://nsis.sourceforge.io/Download
    echo.
    echo After installation, add NSIS to your PATH or run this script
    echo from the NSIS installation directory.
    pause
    exit /b 1
)

echo [*] Found NSIS installation
echo.

REM Check if networkcontrol.dll exists
if not exist "networkcontrol.dll" (
    echo ERROR: networkcontrol.dll not found in current directory
    echo.
    echo Please ensure you have compiled the plugin first.
    echo The DLL should be in the same directory as this script.
    echo.
    echo To compile the plugin:
    echo   1. Use cross-compilation from Linux (recommended)
    echo   2. Run: windows-cross-compile-and-package.sh
    echo   3. Copy the resulting networkcontrol.dll here
    echo.
    pause
    exit /b 1
)

echo [*] Found networkcontrol.dll
echo.

REM Check if NSI script exists
if not exist "networkcontrol-installer.nsi" (
    echo ERROR: networkcontrol-installer.nsi not found
    echo.
    echo This script must be run from the plugin directory
    pause
    exit /b 1
)

echo [*] Building NSIS installer...
echo.

REM Build the installer
makensis networkcontrol-installer.nsi

if %errorLevel% neq 0 (
    echo.
    echo ERROR: NSIS installer build failed
    echo.
    echo Please check the error messages above
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   Build Complete!
echo ============================================================
echo.

REM Find the generated installer
if exist "VeyonNetworkControl-2.0.0-win64-setup.exe" (
    echo Installer created successfully:
    echo   VeyonNetworkControl-2.0.0-win64-setup.exe
    echo.
    for %%A in ("VeyonNetworkControl-2.0.0-win64-setup.exe") do echo   Size: %%~zA bytes
    echo.
    echo You can now distribute this installer to Windows machines.
    echo Users should run it as Administrator.
) else (
    echo WARNING: Installer file not found
    echo Expected: VeyonNetworkControl-2.0.0-win64-setup.exe
)

echo.
echo ============================================================
echo.
pause
