# Makefile for Virtual Nascom

# CC must be an C99 compiler
CC=gcc -std=c99

SOURCES=virtual-nascom.c font.c simz80.c ihex.c
OBJECTS=$(SOURCES:.c=.o)

# full speed or debugging to taste
OPTIMIZE=-O2
#OPTIMIZE=-g
#WARN=-Wmost -Werror
WARN=-Wall -Wno-parentheses
CFLAGS=$(OPTIMIZE) $(WARN) $(shell sdl2-config --cflags)

virtual-nascom: $(OBJECTS)
	$(CC) $(CWARN) $^ -o $@ $(shell sdl2-config --libs)

virtual-nascom.js: $(SOURCES)
	emcc $(SOURCES) $(OPTIMIZE) \
	-s WASM=1 -s USE_SDL=2 \
	-s EXPORTED_FUNCTIONS='["_main", "_reset_nascom", "_load_nascom_string", "_cas_load_input", "_cas_rewind", "_malloc", "_free"]' \
	-s EXPORTED_RUNTIME_METHODS=allocate,intArrayFromString \
	--preload-file basic.nal --preload-file nassys3.nal -o $@

.PHONY : clean clean-js clean-all

clean-all: clean clean-js

clean:
	rm -f $(OBJECTS) virtual-nascom.exe virtual-nascom  *~ core

clean-js:
	rm -f virtual-nascom.js virtual-nascom.wasm virtual-nascom.data
