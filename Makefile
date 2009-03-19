# Makefile for VirtualNascom

# CC must be an ANSI-C compiler
CC            =gcc

# full speed or debugging to taste
#OPTIMIZE      =-O2
OPTIMIZE      = -g
WARN          = -Wmost -Werror
CFLAGS        =	$(OPTIMIZE) $(WARN)

VIRTUALNASCOM_OBJS = simz80.o nascom.o xvirtualnascom.o

LIBS	      =-lXpm -lXt -lX -lm

###### you should not need to change anything below this line ######
CWARN	      = -ansi -pedantic -Wall -Wshadow \
		-Wpointer-arith -Wnested-externs -Winline

sdl-nascom: sdl-nascom.o simz80.o nascom.o
	$(CC) $(shell sdl-config --libs) $^ -o $@

sdl-nascom.o: sdl-nascom.c
	$(CC) $(CFLAGS) $(shell sdl-config --cflags) -c $< -o $@

ascii-nascom: ascii-nascom.o simz80.o nascom.o
	$(CC) $(CFLAGS) $^ -o $@

all:
		-@echo Use \`make linux\' or \`make solaris\'

linux:		$(VIRTUALNASCOM_OBJS)
		$(CC) $(CFLAGS) $(VIRTUALNASCOM_OBJS) -o xvirtualnascom \
		 -L/usr/X11R6/lib -lXpm -lXt

solaris:	$(VIRTUALNASCOM_OBJS)
		$(CC) $(CFLAGS) $(VIRTUALNASCOM_OBJS) -o xvirtualnascom \
		-lXpm -lXt -lX -lm

simz80.c:	simz80.pl
		rm -f simz80.c
		perl -w simz80.pl >simz80.c
		chmod a-w simz80.c

clean:;		rm -f *.o *~ core

xvirtualnascom.o:	simz80.h xvirtualnascom.h
nascom.o:	simz80.h xvirtualnascom.h
simz80.o:	simz80.c simz80.h
