default: build
    ./build/main

build:
    mkdir -p build
    odin build src/tag -debug -out:build/main

gdb: build
    gdb ./build/main
