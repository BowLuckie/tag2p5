default: 
    mkdir -p build
    odin build . -debug -out:build/main
    ./build/main
