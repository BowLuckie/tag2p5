BIN  := build/main
SRCS := $(shell find src -name '*.odin')

COLLECTIONS := -collection:ext=./ext/

.PHONY: default build gdb clean

default: build
	./$(BIN)

build: $(BIN)

$(BIN): $(SRCS)
	mkdir -p build
	odin build src -debug $(COLLECTIONS) -out:$(BIN)

gdb: build
	gdb ./$(BIN)

clean:
	rm -rf build
