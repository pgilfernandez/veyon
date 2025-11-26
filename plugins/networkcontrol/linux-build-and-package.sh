#!/bin/bash
# Build and Package Script for NetworkControl Plugin - Linux
# Creates DEB or RPM packages depending on the distribution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VEYON_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$VEYON_ROOT/build_networkcontrol_linux"
DIST_DIR="$VEYON_ROOT/veyon-linux-distribution"
PLUGIN_NAME="networkcontrol"
VERSION="1.3.0"

echo "════════════════════════════════════════════════════════"
echo "  NetworkControl Plugin - Linux Build & Package v${VERSION}"
echo "════════════════════════════════════════════════════════"
echo ""

# Detect distribution and package type
if [ -f /etc/debian_version ]; then
    PACKAGE_TYPE="deb"
    DISTRO="Debian/Ubuntu"
elif [ -f /etc/redhat-release ]; then
    PACKAGE_TYPE="rpm"
    DISTRO="RHEL/Fedora/openSUSE"
elif [ -f /etc/arch-release ]; then
    echo "ERROR: Arch Linux is not supported by this script."
    echo "Please use the AUR package or build manually with CMake."
    exit 1
else
    echo "ERROR: Unknown Linux distribution"
    echo "This script supports Debian/Ubuntu and RHEL/Fedora/openSUSE"
    exit 1
fi

echo "→ Detected distribution: $DISTRO ($PACKAGE_TYPE package)"
echo ""

# Check required tools
echo "→ Checking required tools..."
REQUIRED_TOOLS="cmake ninja-build"
if [ "$PACKAGE_TYPE" = "deb" ]; then
    REQUIRED_TOOLS="$REQUIRED_TOOLS dpkg fakeroot"
else
    REQUIRED_TOOLS="$REQUIRED_TOOLS rpm rpmbuild fakeroot"
fi

MISSING_TOOLS=""
for tool in $REQUIRED_TOOLS; do
    if ! command -v $tool &> /dev/null && ! dpkg -l | grep -q "^ii  $tool " 2>/dev/null && ! rpm -q $tool &>/dev/null 2>&1; then
        MISSING_TOOLS="$MISSING_TOOLS $tool"
    fi
done

if [ ! -z "$MISSING_TOOLS" ]; then
    echo "ERROR: Missing required tools:$MISSING_TOOLS"
    echo ""
    if [ "$PACKAGE_TYPE" = "deb" ]; then
        echo "Install with: sudo apt-get install$MISSING_TOOLS"
    else
        echo "Install with: sudo dnf install$MISSING_TOOLS"
    fi
    exit 1
fi

echo "  All required tools are installed"
echo ""

# Step 1: Clean previous build
echo "→ Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 2: Configure with CMake
echo "→ Configuring with CMake..."
cd "$BUILD_DIR"

# Detect Qt version (prefer Qt6, fallback to Qt5)
QT_VERSION=""
if command -v qmake6 &> /dev/null || pkg-config --exists Qt6Core 2>/dev/null; then
    QT_VERSION="-DWITH_QT6=ON"
    echo "  Using Qt6"
elif command -v qmake-qt5 &> /dev/null || pkg-config --exists Qt5Core 2>/dev/null; then
    QT_VERSION="-DWITH_QT6=OFF"
    echo "  Using Qt5"
else
    echo "WARNING: Could not detect Qt version, using default"
fi

cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DWITH_LTO=ON \
    -DWITH_TRANSLATIONS=OFF \
    $QT_VERSION \
    "$VEYON_ROOT"

# Step 3: Build only the networkcontrol plugin
echo "→ Building networkcontrol plugin..."
ninja networkcontrol

# Step 4: Create package structure manually
echo "→ Creating package structure..."
PKG_BUILD="$BUILD_DIR/package-root"
rm -rf "$PKG_BUILD"

# Detect library directory architecture
if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
    VEYON_LIB_DIR="usr/lib/x86_64-linux-gnu/veyon"
elif [ -d "/usr/lib64" ]; then
    VEYON_LIB_DIR="usr/lib64/veyon"
else
    VEYON_LIB_DIR="usr/lib/veyon"
fi

mkdir -p "$PKG_BUILD/$VEYON_LIB_DIR"
mkdir -p "$PKG_BUILD/usr/local/bin"
mkdir -p "$PKG_BUILD/etc/sudoers.d"

# Step 5: Copy files
echo "→ Copying files to package..."
cp "$BUILD_DIR/plugins/networkcontrol/libnew$PLUGIN_NAME.so" "$PKG_BUILD/$VEYON_LIB_DIR/$PLUGIN_NAME.so" 2>/dev/null || \
cp "$BUILD_DIR/plugins/networkcontrol/lib$PLUGIN_NAME.so" "$PKG_BUILD/$VEYON_LIB_DIR/$PLUGIN_NAME.so"

cp "$SCRIPT_DIR/veyon-network-helper.sh" "$PKG_BUILD/usr/local/bin/veyon-network-helper"
cp "$SCRIPT_DIR/veyon-network-control-sudoers" "$PKG_BUILD/etc/sudoers.d/veyon-network-control"

# Set permissions
chmod 755 "$PKG_BUILD/$VEYON_LIB_DIR/$PLUGIN_NAME.so"
chmod 755 "$PKG_BUILD/usr/local/bin/veyon-network-helper"
chmod 440 "$PKG_BUILD/etc/sudoers.d/veyon-network-control"

# Step 6: Create control files
echo "→ Creating package metadata..."
mkdir -p "$PKG_BUILD/DEBIAN" 2>/dev/null || mkdir -p "$PKG_BUILD/RPM" 2>/dev/null

if [ "$PACKAGE_TYPE" = "deb" ]; then
    # Create DEBIAN/control file
    cat > "$PKG_BUILD/DEBIAN/control" <<EOF
Package: veyon-plugin-networkcontrol
Version: $VERSION
Section: education
Priority: optional
Architecture: amd64
Depends: veyon
Maintainer: Pablo <pablo@veyon.local>
Description: Network Control Plugin for Veyon
 Allows teachers to enable/disable internet access on student computers
 by manipulating network routing tables.
EOF

    # Create postinst script
    cat > "$PKG_BUILD/DEBIAN/postinst" <<'POSTINST'
#!/bin/bash
set -e

# Validate sudoers file
visudo -c -f /etc/sudoers.d/veyon-network-control >/dev/null 2>&1 || {
    echo "ERROR: Invalid sudoers configuration, removing file"
    rm -f /etc/sudoers.d/veyon-network-control
    exit 1
}

# Check if Veyon is running
if pgrep -x "veyon-server" > /dev/null || pgrep -x "veyon-master" > /dev/null; then
    echo "⚠️  Veyon is running. Please restart it to load the new plugin."
fi

exit 0
POSTINST

    chmod 755 "$PKG_BUILD/DEBIAN/postinst"

    # Build DEB package
    echo "→ Building DEB package..."
    PKG_FILE="veyon-plugin-networkcontrol_${VERSION}_amd64.deb"
    dpkg-deb --build "$PKG_BUILD" "$BUILD_DIR/$PKG_FILE"

    # Show package info
    echo ""
    echo "Package contents:"
    dpkg -c "$BUILD_DIR/$PKG_FILE"
    echo ""
    echo "Package information:"
    dpkg -I "$BUILD_DIR/$PKG_FILE"

else  # RPM
    # Create RPM spec file
    mkdir -p "$HOME/rpmbuild/"{BUILD,RPMS,SOURCES,SPECS,SRPMS}

    cat > "$HOME/rpmbuild/SPECS/veyon-plugin-networkcontrol.spec" <<EOF
Name:           veyon-plugin-networkcontrol
Version:        $VERSION
Release:        1%{?dist}
Summary:        Network Control Plugin for Veyon
License:        GPLv2
BuildArch:      x86_64
Requires:       veyon

%description
Allows teachers to enable/disable internet access on student computers
by manipulating network routing tables.

%install
mkdir -p %{buildroot}
cp -r $PKG_BUILD/* %{buildroot}/

%files
/$VEYON_LIB_DIR/$PLUGIN_NAME.so
/usr/local/bin/veyon-network-helper
/etc/sudoers.d/veyon-network-control

%post
visudo -c -f /etc/sudoers.d/veyon-network-control >/dev/null 2>&1 || {
    echo "ERROR: Invalid sudoers configuration, removing file"
    rm -f /etc/sudoers.d/veyon-network-control
    exit 1
}

if pgrep -x "veyon-server" > /dev/null || pgrep -x "veyon-master" > /dev/null; then
    echo "⚠️  Veyon is running. Please restart it to load the new plugin."
fi
EOF

    # Build RPM package
    echo "→ Building RPM package..."
    rpmbuild -bb "$HOME/rpmbuild/SPECS/veyon-plugin-networkcontrol.spec"

    PKG_FILE=$(find "$HOME/rpmbuild/RPMS" -name "veyon-plugin-networkcontrol-*.rpm" | head -1)
    cp "$PKG_FILE" "$BUILD_DIR/"
    PKG_FILE=$(basename "$PKG_FILE")

    # Show package info
    echo ""
    echo "Package contents:"
    rpm -qlp "$BUILD_DIR/$PKG_FILE"
    echo ""
    echo "Package dependencies:"
    rpm -qpR "$BUILD_DIR/$PKG_FILE"
fi

# Step 7: Move to distribution
echo ""
echo "→ Moving package to distribution directory..."
mkdir -p "$DIST_DIR"
mv "$BUILD_DIR/$PKG_FILE" "$DIST_DIR/"

# Summary
echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✓ Build & Package Complete"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Package created:"
echo "  $DIST_DIR/$PKG_FILE"
ls -lh "$DIST_DIR/$PKG_FILE" | awk '{print "  Size: " $5}'
echo ""
if [ "$PACKAGE_TYPE" = "deb" ]; then
    echo "Install with:"
    echo "  sudo dpkg -i $DIST_DIR/$PKG_FILE"
    echo "  sudo apt-get install -f  # Fix dependencies if needed"
else
    echo "Install with:"
    echo "  sudo rpm -i $DIST_DIR/$PKG_FILE"
    echo "  # or"
    echo "  sudo dnf install $DIST_DIR/$PKG_FILE"
fi
echo ""
echo "════════════════════════════════════════════════════════"
