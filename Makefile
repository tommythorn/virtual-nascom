# Makefile for VirtualNascom

# CC must be an ANSI-C compiler
CC=gcc

# full speed or debugging to taste
OPTIMIZE=-O2
#OPTIMIZE=-g
#WARN=-Wmost -Werror
WARN=-Wall
CFLAGS=$(OPTIMIZE) $(WARN) $(shell sdl-config --cflags)

virtualnascom: virtualnascom.o font.o simz80.o ihex.o
	$(CC) $(CWARN) $(shell sdl-config --libs) $^ -o $@

clean:
	rm -f *.o *~ core
