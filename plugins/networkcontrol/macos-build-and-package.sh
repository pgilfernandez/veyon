#!/bin/bash
# Build and Package Script for NetworkControl Plugin
# Compiles the plugin and creates the distribution package in one step

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/Users/pablo/GitHub/veyon/build_networkcontrol"
DIST_DIR="/Users/pablo/GitHub/veyon/veyon-macos-distribution"
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

# Step 7: Create package structure
echo "→ Creating package structure..."
PKG_BUILD="$BUILD_DIR/package-build"
rm -rf "$PKG_BUILD"
mkdir -p "$PKG_BUILD/payload/Applications/Veyon/veyon-master.app/Contents/lib/veyon"
mkdir -p "$PKG_BUILD/payload/Applications/Veyon/veyon-server.app/Contents/lib/veyon"
mkdir -p "$PKG_BUILD/payload/usr/local/bin"
mkdir -p "$PKG_BUILD/payload/etc/sudoers.d"
mkdir -p "$PKG_BUILD/scripts"

# Step 8: Copy files to package
echo "→ Copying files to package..."
cp ${PLUGIN_NAME}.dylib "$PKG_BUILD/payload/Applications/Veyon/veyon-master.app/Contents/lib/veyon/"
cp ${PLUGIN_NAME}.dylib "$PKG_BUILD/payload/Applications/Veyon/veyon-server.app/Contents/lib/veyon/"
cp veyon-network-helper.sh "$PKG_BUILD/payload/usr/local/bin/veyon-network-helper"
cp veyon-network-control-sudoers "$PKG_BUILD/payload/etc/sudoers.d/veyon-network-control"

# Step 9: Create postinstall script
echo "→ Creating postinstall script..."
cat > "$PKG_BUILD/scripts/postinstall" <<'POSTINSTALL'
#!/bin/bash
set -e
chmod 755 /Applications/Veyon/veyon-master.app/Contents/lib/veyon/networkcontrol.dylib
chmod 755 /Applications/Veyon/veyon-server.app/Contents/lib/veyon/networkcontrol.dylib
chmod 755 /usr/local/bin/veyon-network-helper
chmod 440 /etc/sudoers.d/veyon-network-control
chown root:wheel /etc/sudoers.d/veyon-network-control
visudo -c -f /etc/sudoers.d/veyon-network-control >/dev/null 2>&1 || rm -f /etc/sudoers.d/veyon-network-control
if pgrep -x "veyon-master" > /dev/null; then
    echo "⚠️  Veyon Master is running. Please restart it to load the new plugin."
fi
exit 0
POSTINSTALL

chmod +x "$PKG_BUILD/scripts/postinstall"

# Step 10: Build package
echo "→ Building .pkg installer..."
PKG_FILE="VeyonNetworkControl-v${VERSION}.pkg"
pkgbuild --root "$PKG_BUILD/payload" \
         --scripts "$PKG_BUILD/scripts" \
         --identifier io.veyon.networkcontrol \
         --version "$VERSION" \
         --install-location / \
         "$BUILD_DIR/$PKG_FILE"

# Step 11: Move to distribution
echo "→ Moving package to distribution directory..."
mkdir -p "$DIST_DIR"
mv "$BUILD_DIR/$PKG_FILE" "$DIST_DIR/"

# Step 12: Create server-only package structure
echo ""
echo "→ Creating server-only package structure..."
PKG_BUILD_SERVER="$BUILD_DIR/package-build-server-only"
rm -rf "$PKG_BUILD_SERVER"
mkdir -p "$PKG_BUILD_SERVER/payload/Applications/Veyon/veyon-server.app/Contents/lib/veyon"
mkdir -p "$PKG_BUILD_SERVER/payload/usr/local/bin"
mkdir -p "$PKG_BUILD_SERVER/payload/etc/sudoers.d"
mkdir -p "$PKG_BUILD_SERVER/scripts"

# Step 13: Copy files to server-only package
echo "→ Copying files to server-only package..."
cp ${PLUGIN_NAME}.dylib "$PKG_BUILD_SERVER/payload/Applications/Veyon/veyon-server.app/Contents/lib/veyon/"
cp veyon-network-helper.sh "$PKG_BUILD_SERVER/payload/usr/local/bin/veyon-network-helper"
cp veyon-network-control-sudoers "$PKG_BUILD_SERVER/payload/etc/sudoers.d/veyon-network-control"

# Step 14: Create server-only postinstall script
echo "→ Creating server-only postinstall script..."
cat > "$PKG_BUILD_SERVER/scripts/postinstall" <<'POSTINSTALL_SERVER'
#!/bin/bash
set -e
chmod 755 /Applications/Veyon/veyon-server.app/Contents/lib/veyon/networkcontrol.dylib
chmod 755 /usr/local/bin/veyon-network-helper
chmod 440 /etc/sudoers.d/veyon-network-control
chown root:wheel /etc/sudoers.d/veyon-network-control
visudo -c -f /etc/sudoers.d/veyon-network-control >/dev/null 2>&1 || rm -f /etc/sudoers.d/veyon-network-control
if pgrep -x "veyon-server" > /dev/null; then
    echo "⚠️  Veyon Server is running. Please restart it to load the new plugin."
fi
exit 0
POSTINSTALL_SERVER

chmod +x "$PKG_BUILD_SERVER/scripts/postinstall"

# Step 15: Build server-only package
echo "→ Building server-only .pkg installer..."
PKG_FILE_SERVER="VeyonNetworkControl-only-server-v${VERSION}.pkg"
pkgbuild --root "$PKG_BUILD_SERVER/payload" \
         --scripts "$PKG_BUILD_SERVER/scripts" \
         --identifier io.veyon.networkcontrol.serveronly \
         --version "$VERSION" \
         --install-location / \
         "$BUILD_DIR/$PKG_FILE_SERVER"

# Step 16: Move server-only package to distribution
echo "→ Moving server-only package to distribution directory..."
mv "$BUILD_DIR/$PKG_FILE_SERVER" "$DIST_DIR/"

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
echo "Distribution packages:"
echo ""
echo "  1. Full package (master + server):"
echo "     ${DIST_DIR}/${PKG_FILE}"
ls -lh "$DIST_DIR/$PKG_FILE" | awk '{print "     Size: " $5}'
md5 "$DIST_DIR/$PKG_FILE" | sed 's/^/     /'
echo ""
echo "  2. Server-only package:"
echo "     ${DIST_DIR}/${PKG_FILE_SERVER}"
ls -lh "$DIST_DIR/$PKG_FILE_SERVER" | awk '{print "     Size: " $5}'
md5 "$DIST_DIR/$PKG_FILE_SERVER" | sed 's/^/     /'
echo ""
echo "════════════════════════════════════════════════════════"
