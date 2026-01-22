TEMPLATE = lib
CONFIG += plugin
QT += widgets network

TARGET = networkcontrol

# Source files
SOURCES += NetworkControlFeaturePlugin.cpp
HEADERS += NetworkControlFeaturePlugin.h

# Resources
RESOURCES = networkcontrol.qrc

# Include Veyon headers from installed app
INCLUDEPATH += /Applications/Veyon/veyon-master.app/Contents/include \
               /Applications/Veyon/veyon-master.app/Contents/Frameworks/qca-qt5.framework/Headers \
               ../../core/include \
               ../../core/src

# Link with Veyon core library and qca
LIBS += -L/Applications/Veyon/veyon-master.app/Contents/lib/veyon \
        -lveyon-core \
        -F/Applications/Veyon/veyon-master.app/Contents/Frameworks \
        -framework qca-qt5

# Use C++17
CONFIG += c++17

# Output directory
DESTDIR = .

# macOS specific
macx {
    QMAKE_MACOSX_DEPLOYMENT_TARGET = 10.15

    # Set RPATH to find Veyon libraries at runtime
    QMAKE_RPATHDIR += @executable_path/../lib
    QMAKE_RPATHDIR += @loader_path

    # Framework paths
    QMAKE_LFLAGS += -F/Applications/Veyon/veyon-master.app/Contents/Frameworks
}
