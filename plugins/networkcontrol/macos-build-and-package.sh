#!/bin/bash
# Build and Package Script for NetworkControl Plugin
# Compiles the plugin and creates the distribution package in one step

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VEYON_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$VEYON_ROOT/build_networkcontrol"
DIST_DIR="$VEYON_ROOT/veyon-macos-distribution"
PLUGIN_NAME="networkcontrol"
VERSION="1.3.0"

echo "════════════════════════════════════════════════════════"
echo "  NetworkControl Plugin - Build & Package v${VERSION}"
echo "════════════════════════════════════════════════════════"
echo ""

# Step 1: Clean previous build
echo "→ Cleaning previous build..."
cd "$SCRIPT_DIR"
make clean 2>/dev/null || true
rm -f ${PLUGIN_NAME}.dylib lib${PLUGIN_NAME}.dylib
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 2: Generate Makefile
echo "→ Generating Makefile with qmake..."
/usr/local/opt/qt@5/bin/qmake ${PLUGIN_NAME}.pro

# Step 3: Compile
echo "→ Compiling plugin..."
make -j4

# Step 4: Rename and fix paths
echo "→ Fixing library paths..."
if [ -f "lib${PLUGIN_NAME}.dylib" ]; then
    mv lib${PLUGIN_NAME}.dylib ${PLUGIN_NAME}.dylib
fi

install_name_tool -change "@loader_path/qca-qt5" \
  "@executable_path/../Frameworks/qca-qt5.framework/Versions/2/qca-qt5" \
  ${PLUGIN_NAME}.dylib

# Step 5: Verify
echo "→ Verifying plugin..."
ls -lh ${PLUGIN_NAME}.dylib

echo ""
echo "Dependencies:"
otool -L ${PLUGIN_NAME}.dylib | grep -E "(veyon|qca)" | head -3

ICON_COUNT=$(strings ${PLUGIN_NAME}.dylib | grep "IHDR" | wc -l | tr -d ' ')
echo ""
echo "Embedded PNG icons: ${ICON_COUNT} (expected: 2)"

if [ "$ICON_COUNT" != "2" ]; then
    echo "⚠️  WARNING: Expected 2 icons but found ${ICON_COUNT}"
fi

# Step 6: Move build artifacts
echo ""
echo "→ Moving build artifacts to ${BUILD_DIR}..."
mv *.o moc_* qrc_* Makefile .qmake.stash "$BUILD_DIR/" 2>/dev/null || true

# Step 7: Create component packages (Core, Master, Server, Configurator)
echo "→ Creating component package structures..."

# Component 1: Core (helper script + sudoers) - REQUIRED
PKG_CORE="$BUILD_DIR/package-core"
rm -rf "$PKG_CORE"
mkdir -p "$PKG_CORE/payload/usr/local/bin"
mkdir -p "$PKG_CORE/payload/etc/sudoers.d"
mkdir -p "$PKG_CORE/scripts"

cp veyon-network-helper.sh "$PKG_CORE/payload/usr/local/bin/veyon-network-helper"
cp veyon-network-control-sudoers "$PKG_CORE/payload/etc/sudoers.d/veyon-network-control"

cat > "$PKG_CORE/scripts/postinstall" <<'POSTINSTALL_CORE'
#!/bin/bash
set -e
chmod 755 /usr/local/bin/veyon-network-helper
chmod 440 /etc/sudoers.d/veyon-network-control
chown root:wheel /etc/sudoers.d/veyon-network-control
visudo -c -f /etc/sudoers.d/veyon-network-control >/dev/null 2>&1 || rm -f /etc/sudoers.d/veyon-network-control
exit 0
POSTINSTALL_CORE
chmod +x "$PKG_CORE/scripts/postinstall"

# Component 2: Master - OPTIONAL
PKG_MASTER="$BUILD_DIR/package-master"
rm -rf "$PKG_MASTER"
mkdir -p "$PKG_MASTER/payload/Applications/Veyon/veyon-master.app/Contents/lib/veyon"
mkdir -p "$PKG_MASTER/scripts"

cp ${PLUGIN_NAME}.dylib "$PKG_MASTER/payload/Applications/Veyon/veyon-master.app/Contents/lib/veyon/"

cat > "$PKG_MASTER/scripts/postinstall" <<'POSTINSTALL_MASTER'
#!/bin/bash
set -e
chmod 755 /Applications/Veyon/veyon-master.app/Contents/lib/veyon/networkcontrol.dylib
if pgrep -x "veyon-master" > /dev/null; then
    echo "⚠️  Veyon Master is running. Please restart it to load the new plugin."
fi
exit 0
POSTINSTALL_MASTER
chmod +x "$PKG_MASTER/scripts/postinstall"

# Component 3: Server - OPTIONAL
PKG_SERVER="$BUILD_DIR/package-server"
rm -rf "$PKG_SERVER"
mkdir -p "$PKG_SERVER/payload/Applications/Veyon/veyon-server.app/Contents/lib/veyon"
mkdir -p "$PKG_SERVER/scripts"

cp ${PLUGIN_NAME}.dylib "$PKG_SERVER/payload/Applications/Veyon/veyon-server.app/Contents/lib/veyon/"

cat > "$PKG_SERVER/scripts/postinstall" <<'POSTINSTALL_SERVER'
#!/bin/bash
set -e
chmod 755 /Applications/Veyon/veyon-server.app/Contents/lib/veyon/networkcontrol.dylib
if pgrep -x "veyon-server" > /dev/null; then
    echo "⚠️  Veyon Server is running. Please restart it to load the new plugin."
fi
exit 0
POSTINSTALL_SERVER
chmod +x "$PKG_SERVER/scripts/postinstall"

# Component 4: Configurator - OPTIONAL
PKG_CONFIGURATOR="$BUILD_DIR/package-configurator"
rm -rf "$PKG_CONFIGURATOR"
mkdir -p "$PKG_CONFIGURATOR/payload/Applications/Veyon/veyon-configurator.app/Contents/lib/veyon"
mkdir -p "$PKG_CONFIGURATOR/scripts"

cp ${PLUGIN_NAME}.dylib "$PKG_CONFIGURATOR/payload/Applications/Veyon/veyon-configurator.app/Contents/lib/veyon/"

cat > "$PKG_CONFIGURATOR/scripts/postinstall" <<'POSTINSTALL_CONFIGURATOR'
#!/bin/bash
set -e
chmod 755 /Applications/Veyon/veyon-configurator.app/Contents/lib/veyon/networkcontrol.dylib
if pgrep -x "veyon-configurator" > /dev/null; then
    echo "⚠️  Veyon Configurator is running. Please restart it to load the new plugin."
fi
exit 0
POSTINSTALL_CONFIGURATOR
chmod +x "$PKG_CONFIGURATOR/scripts/postinstall"

# Step 8: Build component packages
echo "→ Building component packages..."
pkgbuild --root "$PKG_CORE/payload" \
         --scripts "$PKG_CORE/scripts" \
         --identifier io.veyon.networkcontrol.core \
         --version "$VERSION" \
         --install-location / \
         "$BUILD_DIR/NetworkControl-Core.pkg"

pkgbuild --root "$PKG_MASTER/payload" \
         --scripts "$PKG_MASTER/scripts" \
         --identifier io.veyon.networkcontrol.master \
         --version "$VERSION" \
         --install-location / \
         "$BUILD_DIR/NetworkControl-Master.pkg"

pkgbuild --root "$PKG_SERVER/payload" \
         --scripts "$PKG_SERVER/scripts" \
         --identifier io.veyon.networkcontrol.server \
         --version "$VERSION" \
         --install-location / \
         "$BUILD_DIR/NetworkControl-Server.pkg"

pkgbuild --root "$PKG_CONFIGURATOR/payload" \
         --scripts "$PKG_CONFIGURATOR/scripts" \
         --identifier io.veyon.networkcontrol.configurator \
         --version "$VERSION" \
         --install-location / \
         "$BUILD_DIR/NetworkControl-Configurator.pkg"

# Step 9: Create distribution XML
echo "→ Creating distribution definition..."
cat > "$BUILD_DIR/distribution.xml" <<DISTRIBUTION
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>Veyon NetworkControl Plugin</title>
    <organization>io.veyon.networkcontrol</organization>
    <domains enable_localSystem="true"/>
    <options customize="always" require-scripts="false" hostArchitectures="x86_64,arm64"/>

    <welcome file="welcome.html" mime-type="text/html"/>

    <choices-outline>
        <line choice="core"/>
        <line choice="master"/>
        <line choice="server"/>
        <line choice="configurator"/>
    </choices-outline>

    <choice id="core" title="Core Components" description="Required helper scripts and sudoers configuration (required)" enabled="false" selected="true" visible="true">
        <pkg-ref id="io.veyon.networkcontrol.core"/>
    </choice>

    <choice id="master" title="Veyon Master" description="Install plugin for Veyon Master application" start_selected="true" start_enabled="true" start_visible="true">
        <pkg-ref id="io.veyon.networkcontrol.master"/>
    </choice>

    <choice id="server" title="Veyon Server" description="Install plugin for Veyon Server application" start_selected="true" start_enabled="true" start_visible="true">
        <pkg-ref id="io.veyon.networkcontrol.server"/>
    </choice>

    <choice id="configurator" title="Veyon Configurator" description="Install plugin for Veyon Configurator application (enables feature management in settings)" start_selected="true" start_enabled="true" start_visible="true">
        <pkg-ref id="io.veyon.networkcontrol.configurator"/>
    </choice>

    <pkg-ref id="io.veyon.networkcontrol.core" version="$VERSION" onConclusion="none">NetworkControl-Core.pkg</pkg-ref>
    <pkg-ref id="io.veyon.networkcontrol.master" version="$VERSION" onConclusion="none">NetworkControl-Master.pkg</pkg-ref>
    <pkg-ref id="io.veyon.networkcontrol.server" version="$VERSION" onConclusion="none">NetworkControl-Server.pkg</pkg-ref>
    <pkg-ref id="io.veyon.networkcontrol.configurator" version="$VERSION" onConclusion="none">NetworkControl-Configurator.pkg</pkg-ref>
</installer-gui-script>
DISTRIBUTION

# Step 10: Create resources
echo "→ Creating installer resources..."
mkdir -p "$BUILD_DIR/resources"

cat > "$BUILD_DIR/resources/welcome.html" <<'WELCOME'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8"/>
<style>
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
}
</style>
</head>
<body>
<h1>Veyon NetworkControl Plugin</h1>
<p>This installer will install the NetworkControl plugin for Veyon.</p>
<p><strong>Features:</strong></p>
<ul>
<li>Enable/Disable internet access on student computers</li>
<li>Keep local network functional while blocking internet</li>
<li>Visual indicator when internet is disabled</li>
</ul>
<p>Select which Veyon applications should have the plugin installed in the next step.</p>
</body>
</html>
WELCOME

# Step 11: Build distribution package
echo "→ Building distribution package..."
PKG_FILE="VeyonNetworkControl-v${VERSION}.pkg"
productbuild --distribution "$BUILD_DIR/distribution.xml" \
             --resources "$BUILD_DIR/resources" \
             --package-path "$BUILD_DIR" \
             "$BUILD_DIR/$PKG_FILE"

# Step 12: Move to distribution
echo "→ Moving package to distribution directory..."
mkdir -p "$DIST_DIR"
mv "$BUILD_DIR/$PKG_FILE" "$DIST_DIR/"

# Summary
echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✓ Build & Package Complete"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Plugin compiled:"
echo "  ${SCRIPT_DIR}/${PLUGIN_NAME}.dylib"
echo ""
echo "Build artifacts:"
echo "  ${BUILD_DIR}/"
echo ""
echo "Distribution package (with component selection):"
echo "  ${DIST_DIR}/${PKG_FILE}"
ls -lh "$DIST_DIR/$PKG_FILE" | awk '{print "  Size: " $5}'
md5 "$DIST_DIR/$PKG_FILE" | sed 's/^/  /'
echo ""
echo "Installation options:"
echo "  ✓ Core Components (required) - helper script + sudoers"
echo "  ☐ Veyon Master (optional) - selected by default"
echo "  ☐ Veyon Server (optional) - selected by default"
echo "  ☐ Veyon Configurator (optional) - selected by default"
echo ""
echo "The installer will present a customization screen where you can"
echo "select which Veyon applications should have the plugin installed."
echo ""
echo "════════════════════════════════════════════════════════"
