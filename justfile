default: 
    mkdir -p build
    odin build . -out:build/main
    ./build/main
