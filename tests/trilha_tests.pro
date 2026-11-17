QT += core gui quick testlib
CONFIG += c++17 testcase
TARGET = trilha_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += ../src/backend.h ../src/theme.h
SOURCES += trilha_tests.cpp ../src/backend.cpp ../src/theme.cpp
RESOURCES += ../src/resources.qrc
