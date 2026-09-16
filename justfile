default: build
    ./build/main

build:
    mkdir -p build
    odin build src -debug -out:build/main

gdb: build
    gdb ./build/main
