#!/bin/bash
# Cross-compile NetworkControl Plugin for Windows from Linux
# Creates a standalone NSIS installer package

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VEYON_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLUGIN_NAME="networkcontrol"
VERSION="2.0.0"

echo "════════════════════════════════════════════════════════"
echo "  NetworkControl Plugin - Windows Cross-Compilation"
echo "  Version: ${VERSION}"
echo "════════════════════════════════════════════════════════"
echo ""

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "ERROR: This script must be run on Linux"
    echo "Windows builds require MinGW cross-compilation toolchain"
    echo ""
    echo "If you're on macOS or Windows, please use a Linux VM or Docker container"
    exit 1
fi

echo "→ Detected platform: Linux"
echo ""

# Detect architecture (default to 64-bit)
ARCH="${1:-x86_64}"
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "i686" ]; then
    echo "ERROR: Invalid architecture '$ARCH'"
    echo "Usage: $0 [x86_64|i686]"
    echo ""
    echo "  x86_64 - 64-bit Windows (default)"
    echo "  i686   - 32-bit Windows"
    exit 1
fi

if [ "$ARCH" = "x86_64" ]; then
    ARCH_NAME="win64"
    MINGW_PREFIX="x86_64-w64-mingw32"
else
    ARCH_NAME="win32"
    MINGW_PREFIX="i686-w64-mingw32"
fi

echo "→ Target architecture: $ARCH ($ARCH_NAME)"
echo ""

# Check for required tools
echo "→ Checking required tools..."
REQUIRED_TOOLS="cmake ninja-build $MINGW_PREFIX-gcc $MINGW_PREFIX-g++ makensis"
MISSING_TOOLS=""

for tool in cmake ninja-build makensis; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS="$MISSING_TOOLS $tool"
    fi
done

# Check MinGW compiler
if ! command -v $MINGW_PREFIX-gcc &> /dev/null; then
    MISSING_TOOLS="$MISSING_TOOLS mingw-w64"
fi

if [ ! -z "$MISSING_TOOLS" ]; then
    echo "ERROR: Missing required tools:$MISSING_TOOLS"
    echo ""
    echo "Install on Debian/Ubuntu:"
    echo "  sudo apt-get install cmake ninja-build mingw-w64 nsis"
    echo ""
    echo "Install on Fedora/RHEL:"
    echo "  sudo dnf install cmake ninja-build mingw64-gcc mingw64-gcc-c++ nsis"
    exit 1
fi

echo "  All required tools are installed"
echo ""

# Set build directories
BUILD_DIR="$VEYON_ROOT/build_networkcontrol_windows_$ARCH_NAME"
DIST_DIR="$VEYON_ROOT/veyon-windows-distribution"
MINGW_ROOT="/usr/$MINGW_PREFIX"

echo "→ Build directory: $BUILD_DIR"
echo "→ Distribution directory: $DIST_DIR"
echo ""

# Check if Qt is available for MinGW
if [ ! -d "$MINGW_ROOT" ]; then
    echo "ERROR: MinGW installation not found at $MINGW_ROOT"
    echo ""
    echo "Please install MinGW cross-compilation toolchain:"
    echo "  Debian/Ubuntu: sudo apt-get install mingw-w64"
    echo "  Fedora/RHEL: sudo dnf install mingw64-gcc mingw64-gcc-c++"
    exit 1
fi

# Check for qt-cmake
QT_CMAKE=""
if [ -x "$MINGW_ROOT/bin/qt-cmake" ]; then
    QT_CMAKE="$MINGW_ROOT/bin/qt-cmake"
elif [ -x "$MINGW_ROOT/bin/qmake" ]; then
    echo "WARNING: qt-cmake not found, will try to use regular cmake with toolchain file"
else
    echo "ERROR: Qt for MinGW not found"
    echo ""
    echo "Please install Qt for MinGW cross-compilation"
    echo "See: https://doc.qt.io/qt-6/windows-building.html"
    exit 1
fi

# Clean previous build
echo "→ Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake
echo "→ Configuring with CMake..."

if [ ! -z "$QT_CMAKE" ]; then
    # Use Qt's cmake wrapper
    $QT_CMAKE "$VEYON_ROOT" \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DWITH_LTO=ON \
        -DWITH_TRANSLATIONS=OFF
else
    # Create minimal toolchain file
    cat > "$BUILD_DIR/mingw-toolchain.cmake" <<EOF
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_C_COMPILER $MINGW_PREFIX-gcc)
set(CMAKE_CXX_COMPILER $MINGW_PREFIX-g++)
set(CMAKE_RC_COMPILER $MINGW_PREFIX-windres)
set(CMAKE_FIND_ROOT_PATH $MINGW_ROOT)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

    cmake "$VEYON_ROOT" \
        -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$BUILD_DIR/mingw-toolchain.cmake" \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DWITH_LTO=ON \
        -DWITH_TRANSLATIONS=OFF
fi

# Build only the networkcontrol plugin
echo "→ Building networkcontrol plugin..."
ninja networkcontrol

# Find the compiled plugin
PLUGIN_DLL=$(find "$BUILD_DIR/plugins/networkcontrol" -name "*.dll" | head -1)

if [ -z "$PLUGIN_DLL" ] || [ ! -f "$PLUGIN_DLL" ]; then
    echo "ERROR: Plugin DLL not found after build"
    echo "Expected location: $BUILD_DIR/plugins/networkcontrol/"
    ls -la "$BUILD_DIR/plugins/networkcontrol/" 2>/dev/null || echo "Directory does not exist"
    exit 1
fi

echo "  Plugin compiled: $(basename $PLUGIN_DLL)"
echo ""

# Create NSIS installer script
echo "→ Creating NSIS installer script..."

NSIS_SCRIPT="$BUILD_DIR/networkcontrol-installer.nsi"

cat > "$NSIS_SCRIPT" <<'NSIS_EOF'
!define PLUGIN_NAME "NetworkControl"
!define PLUGIN_VERSION "2.0.0"
!define PLUGIN_PUBLISHER "Veyon Community"
!define PLUGIN_DLL "networkcontrol.dll"

Name "${PLUGIN_NAME} Plugin for Veyon"
OutFile "VeyonNetworkControl-${PLUGIN_VERSION}-win64-setup.exe"
InstallDir "$PROGRAMFILES64\Veyon"
InstallDirRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Veyon" "InstallLocation"
RequestExecutionLevel admin

!include "MUI2.nsh"
!include "LogicLib.nsh"

!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "NetworkControl Plugin" SecMain
    SetOutPath "$INSTDIR\plugins"

    # Stop Veyon Service if running
    ExecWait '"$INSTDIR\veyon-wcli.exe" service stop' $0
    Sleep 1000

    # Backup existing plugin if present
    IfFileExists "$INSTDIR\plugins\${PLUGIN_DLL}" 0 +2
        Rename "$INSTDIR\plugins\${PLUGIN_DLL}" "$INSTDIR\plugins\${PLUGIN_DLL}.backup"

    # Install plugin
    File "${PLUGIN_DLL}"

    # Write uninstaller
    WriteUninstaller "$INSTDIR\Uninstall-NetworkControl.exe"

    # Restart Veyon Service
    ExecWait '"$INSTDIR\veyon-wcli.exe" service start' $0

    # Registry information for Add/Remove Programs
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                     "DisplayName" "${PLUGIN_NAME} Plugin for Veyon"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                     "UninstallString" "$INSTDIR\Uninstall-NetworkControl.exe"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                     "DisplayVersion" "${PLUGIN_VERSION}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                     "Publisher" "${PLUGIN_PUBLISHER}"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                       "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                       "NoRepair" 1

    DetailPrint "NetworkControl plugin installed successfully"
    DetailPrint "Please restart Veyon Master to load the plugin"
SectionEnd

Section "Uninstall"
    # Stop Veyon Service
    ExecWait '"$INSTDIR\veyon-wcli.exe" service stop' $0
    Sleep 1000

    # Remove plugin
    Delete "$INSTDIR\plugins\${PLUGIN_DLL}"
    Delete "$INSTDIR\plugins\${PLUGIN_DLL}.backup"
    Delete "$INSTDIR\Uninstall-NetworkControl.exe"

    # Remove registry keys
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl"

    # Restart Veyon Service
    ExecWait '"$INSTDIR\veyon-wcli.exe" service start' $0
SectionEnd

Function .onInit
    # Check if Veyon is installed
    IfFileExists "$INSTDIR\veyon-master.exe" VeyonFound
        MessageBox MB_OK|MB_ICONSTOP "Veyon is not installed at $INSTDIR.$\n$\nPlease install Veyon first."
        Abort
    VeyonFound:
FunctionEnd
NSIS_EOF

# Copy plugin DLL to build directory
cp "$PLUGIN_DLL" "$BUILD_DIR/networkcontrol.dll"

# Create a simple license file
cat > "$BUILD_DIR/LICENSE.txt" <<'LICENSE_EOF'
NetworkControl Plugin for Veyon
Copyright (c) 2025

This plugin is distributed under the same license as Veyon (GPL v2).

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
LICENSE_EOF

# Build NSIS installer
echo "→ Building NSIS installer..."
cd "$BUILD_DIR"
makensis networkcontrol-installer.nsi

if [ $? -ne 0 ]; then
    echo "ERROR: NSIS installer creation failed"
    exit 1
fi

# Find the generated installer
INSTALLER=$(find "$BUILD_DIR" -name "VeyonNetworkControl-*.exe" | head -1)

if [ -z "$INSTALLER" ] || [ ! -f "$INSTALLER" ]; then
    echo "ERROR: Installer executable not found"
    exit 1
fi

# Move to distribution directory
echo ""
echo "→ Moving installer to distribution directory..."
mkdir -p "$DIST_DIR"
mv "$INSTALLER" "$DIST_DIR/"
INSTALLER_NAME=$(basename "$INSTALLER")

# Summary
echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✓ Build & Package Complete"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Plugin compiled:"
echo "  $BUILD_DIR/networkcontrol.dll"
echo ""
echo "Installer created:"
echo "  $DIST_DIR/$INSTALLER_NAME"
ls -lh "$DIST_DIR/$INSTALLER_NAME" | awk '{print "  Size: " $5}'
echo ""
echo "You can now distribute this installer to Windows machines."
echo "Users should run it as Administrator to install the plugin."
echo ""
echo "════════════════════════════════════════════════════════"
