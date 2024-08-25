QT       -= core
QT       -= gui

TARGET = awfy
CONFIG   += console
CONFIG   -= app_bundle

QMAKE_CFLAGS += -std=c99 -Wno-unused-parameter

TEMPLATE = app

SOURCES += \
    main.c \
    Benchmark.c \
    Run.c \
    Bounce.c \
    som/Random.c \
    Object.c \
    List.c \
    Mandelbrot.c \
    Permute.c \
    Queens.c \
    Sieve.c \
    Storage.c \
    Towers.c \
    NBody.c \
    Richards.c \
    Json.c \
    som/Vector.c \
    CD.c \
    RedBlackTree.c \
    Havlak.c \
    som/Set.c \
    som/Dictionary.c \
    DeltaBlue.c

HEADERS += \
    Benchmark.h \
    Run.h \
    Bounce.h \
    som/Random.h \
    Object.h \
    List.h \
    Mandelbrot.h \
    Permute.h \
    Queens.h \
    Sieve.h \
    Storage.h \
    Towers.h \
    NBody.h \
    Richards.h \
    Json.h \
    som/Vector.h \
    som/Interfaces.h \
    CD.h \
    RedBlackTree.h \
    Havlak.h \
    som/Dictionary.h \
    som/Set.h \
    DeltaBlue.h


