# Makefile for VirtualNascom

# CC must be an ANSI-C compiler
CC            = gcc

# full speed or debugging to taste
#OPTIMIZE     = -O2
OPTIMIZE      = -g
WARN          = -Wmost -Werror
CFLAGS        =	$(OPTIMIZE) $(WARN) $(shell sdl-config --cflags)

LIBS	      =-lXpm -lXt -lX -lm

###### you should not need to change anything below this line ######
CWARN	      = -ansi -pedantic -Wall -Wshadow \
		-Wpointer-arith -Wnested-externs -Winline

sdl-nascom: sdl-nascom.o font.o simz80.o
	$(CC) $(shell sdl-config --libs) $^ -o $@

clean:;		rm -f *.o *~ core
