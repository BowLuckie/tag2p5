default: 
    mkdir -p build
    odin build src -debug -out:build/main
    ./build/main
