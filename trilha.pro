QT += core gui qml quick quickcontrols2

CONFIG += c++17 release
TARGET = trilha
TEMPLATE = app

HEADERS += \
    src/backend.h \
    src/theme.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/theme.cpp

RESOURCES += src/resources.qrc

# Windows takes its icon from a .ico, macOS from a .icns that CI builds from
# assets/trilha-1024.png (see .github/workflows/build.yml).
win32: RC_ICONS = assets/trilha.ico
macx: exists(assets/trilha.icns): ICON = assets/trilha.icns
macx: QMAKE_TARGET_BUNDLE_PREFIX = io.github.arthur-zt
macx: QMAKE_CXXFLAGS += -include $$PWD/src/macshim.h
