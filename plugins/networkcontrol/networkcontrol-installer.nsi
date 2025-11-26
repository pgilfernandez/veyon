; NSIS Installer Script for NetworkControl Plugin
; This script creates a standalone installer for the Veyon NetworkControl plugin
;
; Requirements:
;   - NSIS 3.0 or later installed
;   - networkcontrol.dll compiled and present in the same directory
;
; To build the installer:
;   1. Compile the plugin to get networkcontrol.dll
;   2. Place networkcontrol.dll in the same directory as this script
;   3. Run: makensis networkcontrol-installer.nsi
;   4. The installer will be created as VeyonNetworkControl-2.0.0-win64-setup.exe

!define PLUGIN_NAME "NetworkControl"
!define PLUGIN_VERSION "2.0.0"
!define PLUGIN_PUBLISHER "Veyon Community"
!define PLUGIN_DLL "networkcontrol.dll"
!define PRODUCT_NAME "Veyon ${PLUGIN_NAME} Plugin"

; Installer properties
Name "${PRODUCT_NAME} ${PLUGIN_VERSION}"
OutFile "VeyonNetworkControl-${PLUGIN_VERSION}-win64-setup.exe"
InstallDir "$PROGRAMFILES64\Veyon"
InstallDirRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Veyon" "InstallLocation"
RequestExecutionLevel admin

; Include Modern UI
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"

; Version information
VIProductVersion "${PLUGIN_VERSION}.0"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "ProductVersion" "${PLUGIN_VERSION}"
VIAddVersionKey "CompanyName" "${PLUGIN_PUBLISHER}"
VIAddVersionKey "FileDescription" "${PRODUCT_NAME} Installer"
VIAddVersionKey "FileVersion" "${PLUGIN_VERSION}"
VIAddVersionKey "LegalCopyright" "GPL v2"

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install-blue.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Header\nsis-r.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Wizard\win.bmp"

; Welcome page
!define MUI_WELCOMEPAGE_TITLE "Welcome to ${PRODUCT_NAME} Setup"
!define MUI_WELCOMEPAGE_TEXT "This wizard will install the ${PLUGIN_NAME} plugin for Veyon.$\r$\n$\r$\nThis plugin allows you to enable or disable internet access on student computers while keeping the local network functional.$\r$\n$\r$\nClick Next to continue."
!insertmacro MUI_PAGE_WELCOME

; License page (optional - uncomment if you have a license file)
; !insertmacro MUI_PAGE_LICENSE "LICENSE.txt"

; Directory selection page
!define MUI_DIRECTORYPAGE_TEXT_TOP "Setup will install ${PRODUCT_NAME} in the following Veyon installation folder. If Veyon is installed in a different location, please select it below."
!insertmacro MUI_PAGE_DIRECTORY

; Confirmation page with custom message
!define MUI_PAGE_CUSTOMFUNCTION_PRE CheckVeyonInstallation
!insertmacro MUI_PAGE_INSTFILES

; Finish page
!define MUI_FINISHPAGE_TITLE "${PRODUCT_NAME} Installation Complete"
!define MUI_FINISHPAGE_TEXT "${PRODUCT_NAME} has been installed successfully.$\r$\n$\r$\nIMPORTANT: Please restart Veyon Master and Veyon Service to load the new plugin.$\r$\n$\r$\nClick Finish to close this wizard."
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Restart Veyon Service now"
!define MUI_FINISHPAGE_RUN_FUNCTION RestartVeyonService
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

; Languages
!insertmacro MUI_LANGUAGE "English"

; ============================================================================
; Installer Sections
; ============================================================================

Section "!NetworkControl Plugin" SecMain
    SectionIn RO  ; Read-only (mandatory)

    DetailPrint "Checking Veyon installation..."

    ; Check if Veyon is installed
    IfFileExists "$INSTDIR\veyon-master.exe" VeyonFound
        MessageBox MB_OK|MB_ICONSTOP "Veyon executable not found at:$\n$INSTDIR\veyon-master.exe$\n$\nPlease select the correct Veyon installation directory."
        Abort
    VeyonFound:

    ; Create plugins directory if it doesn't exist
    CreateDirectory "$INSTDIR\plugins"

    DetailPrint "Stopping Veyon Service..."
    ; Try to stop Veyon Service
    IfFileExists "$INSTDIR\veyon-wcli.exe" HasCLI NoCLI
    HasCLI:
        ExecWait '"$INSTDIR\veyon-wcli.exe" service stop' $0
        Sleep 1500
        Goto ServiceStopped
    NoCLI:
        ; Fallback: try net stop
        ExecWait 'net stop VeyonService' $0
        Sleep 1500
    ServiceStopped:

    ; Backup existing plugin if present
    IfFileExists "$INSTDIR\plugins\${PLUGIN_DLL}" 0 NoBackup
        DetailPrint "Backing up existing plugin..."
        Delete "$INSTDIR\plugins\${PLUGIN_DLL}.backup.old"
        Rename "$INSTDIR\plugins\${PLUGIN_DLL}" "$INSTDIR\plugins\${PLUGIN_DLL}.backup"
    NoBackup:

    ; Install plugin
    DetailPrint "Installing NetworkControl plugin..."
    SetOutPath "$INSTDIR\plugins"

    ; Check if source DLL exists
    IfFileExists "${PLUGIN_DLL}" DLLExists
        MessageBox MB_OK|MB_ICONSTOP "ERROR: ${PLUGIN_DLL} not found!$\n$\nPlease ensure the plugin DLL is in the same directory as this installer."
        Abort
    DLLExists:

    File "${PLUGIN_DLL}"

    ; Verify installation
    IfFileExists "$INSTDIR\plugins\${PLUGIN_DLL}" InstallOK
        MessageBox MB_OK|MB_ICONSTOP "ERROR: Failed to copy plugin DLL to installation directory.$\n$\nPlease check file permissions and try again."
        Abort
    InstallOK:

    DetailPrint "Plugin installed successfully"

    ; Write uninstaller
    WriteUninstaller "$INSTDIR\Uninstall-NetworkControl.exe"

    ; Write registry keys for Add/Remove Programs
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                     "DisplayName" "${PRODUCT_NAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                     "DisplayVersion" "${PLUGIN_VERSION}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                     "Publisher" "${PLUGIN_PUBLISHER}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                     "UninstallString" "$\"$INSTDIR\Uninstall-NetworkControl.exe$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                     "InstallLocation" "$INSTDIR"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                     "DisplayIcon" "$INSTDIR\veyon-master.exe,0"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                       "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                       "NoRepair" 1

    ; Calculate installed size
    ${GetSize} "$INSTDIR\plugins" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl" \
                       "EstimatedSize" "$0"

    ; Restart Veyon Service
    DetailPrint "Restarting Veyon Service..."
    IfFileExists "$INSTDIR\veyon-wcli.exe" HasCLI2 NoCLI2
    HasCLI2:
        ExecWait '"$INSTDIR\veyon-wcli.exe" service start' $0
        Goto ServiceStarted
    NoCLI2:
        ExecWait 'net start VeyonService' $0
    ServiceStarted:

    DetailPrint ""
    DetailPrint "═══════════════════════════════════════════════════"
    DetailPrint "Installation Complete!"
    DetailPrint "═══════════════════════════════════════════════════"
    DetailPrint ""
    DetailPrint "The NetworkControl plugin has been installed."
    DetailPrint ""
    DetailPrint "NEXT STEPS:"
    DetailPrint "  • Restart Veyon Master to load the plugin"
    DetailPrint "  • The plugin will appear in the Features menu"
    DetailPrint ""
SectionEnd

; ============================================================================
; Uninstaller Section
; ============================================================================

Section "Uninstall"
    DetailPrint "Uninstalling NetworkControl plugin..."

    ; Stop Veyon Service
    DetailPrint "Stopping Veyon Service..."
    IfFileExists "$INSTDIR\veyon-wcli.exe" HasCLI3 NoCLI3
    HasCLI3:
        ExecWait '"$INSTDIR\veyon-wcli.exe" service stop' $0
        Sleep 1500
        Goto Stopped
    NoCLI3:
        ExecWait 'net stop VeyonService' $0
        Sleep 1500
    Stopped:

    ; Remove plugin files
    Delete "$INSTDIR\plugins\${PLUGIN_DLL}"
    Delete "$INSTDIR\plugins\${PLUGIN_DLL}.backup"
    Delete "$INSTDIR\Uninstall-NetworkControl.exe"

    ; Remove registry keys
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VeyonNetworkControl"

    ; Restart Veyon Service
    DetailPrint "Restarting Veyon Service..."
    IfFileExists "$INSTDIR\veyon-wcli.exe" HasCLI4 NoCLI4
    HasCLI4:
        ExecWait '"$INSTDIR\veyon-wcli.exe" service start' $0
        Goto Done
    NoCLI4:
        ExecWait 'net start VeyonService' $0
    Done:

    DetailPrint "Uninstallation complete"
SectionEnd

; ============================================================================
; Functions
; ============================================================================

Function CheckVeyonInstallation
    ; Check if Veyon is installed before showing instfiles page
    IfFileExists "$INSTDIR\veyon-master.exe" +3
        MessageBox MB_OK|MB_ICONSTOP "Veyon is not installed at the selected location.$\n$\nPlease go back and select the correct Veyon installation directory."
        Abort
FunctionEnd

Function RestartVeyonService
    DetailPrint "Restarting Veyon Service..."
    IfFileExists "$INSTDIR\veyon-wcli.exe" +3
        ExecWait 'net stop VeyonService && net start VeyonService'
        Goto +2
    ExecWait '"$INSTDIR\veyon-wcli.exe" service restart'
FunctionEnd

; Description text for components
LangString DESC_SecMain ${LANG_ENGLISH} "NetworkControl plugin (required)"

; Assign descriptions to sections
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} $(DESC_SecMain)
!insertmacro MUI_FUNCTION_DESCRIPTION_END
