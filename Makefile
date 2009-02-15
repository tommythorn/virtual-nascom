# Makefile for VirtualNascom

# CC must be an ANSI-C compiler
CC            =	gcc

#where you want the binaries and manual page
BINDIR	      = /usr/local/bin
MANDIR	      = /usr/local/man/man1
LIBDIR	      = /usr/local/lib

# full speed or debugging to taste
OPTIMIZE      = -O2
#OPTIMIZE       = -g

# -DUSE_GNU_READLINE for command recall/editing and filename completion
# -DBGii_BUG works around a problem in Backgrounder II
# -DBIOS to build a CP/M bios and monitor program into the emulator
#  (see also VIRTUALNASCOM_OBJS, below)
# -DMMU compiles in support for bank-switched memory
# -DMEMSIZE <val> sets size of memory in KBytes (default 64)
# solaris2 needs -D__EXTENSIONS__
# linux needs -D_POSIX_SOURCE
OPTIONS	      =

VIRTUALNASCOM_OBJS = simz80.o nascom.o xvirtualnascom.o

LIBS	      = -lXpm -lXt -lX -lm

# a bsd-like install program (/usr/ucb/install on Solaris2)
INSTALL	      = install


###### you should not need to change anything below this line ######
CWARN	      = -ansi -pedantic -Wall -Wshadow \
		-Wpointer-arith -Wnested-externs -Winline
CFLAGS        =	$(CWARN) $(OPTIMIZE) $(OPTIONS) -DLIBDIR=\"$(LIBDIR)/\"

DOC	      = README README.yaze COPYING

all:		xvirtualnascom

xvirtualnascom:	$(VIRTUALNASCOM_OBJS)
		$(CC) $(CFLAGS) $(VIRTUALNASCOM_OBJS) $(LIBS) -o $@

simz80.c:	simz80.pl
		rm -f simz80.c
		perl -w simz80.pl >simz80.c
		chmod a-w simz80.c

install:	all
		$(INSTALL) -s -c -m 755 xvirtualnascom $(BINDIR)

clean:;		rm -f *.o *~ core

xvirtualnascom.o:	simz80.h xvirtualnascom.h
nascom.o:	simz80.h xvirtualnascom.h
simz80.o:	simz80.c simz80.h
