BIN  := build/main
SRCS := $(shell find src -name '*.odin')

COLLECTIONS := -collection:renderer=./src/renderer/ -collection:clay=./src/clay-odin/

.PHONY: default build gdb clean

default: build
	./$(BIN)

build: $(BIN)

$(BIN): $(SRCS)
	mkdir -p build
	odin build src/tag -debug $(COLLECTIONS) -out:$(BIN)

gdb: build
	gdb ./$(BIN)

clean:
	rm -rf build
