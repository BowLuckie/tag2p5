binary_name := "boxt"

default: run

setup:
    mkdir -p build
    cd build && cmake ..
    ln -sf build/compile_commands.json compile_commands.json

build:
    cmake --build build

rebuild: clean setup build

run: build
    ./build/{{binary_name}}

clean:
    rm -rf build compile_commands.json
