# Makefile for zlib

MODEL=32
CC=gcc
LD=link
CFLAGS=-O -m$(MODEL)
LDFLAGS=
O=.o

.c.o:
	$(CC) -c $(CFLAGS) $*

.d.o:
	$(DMD) -c $(DFLAGS) $*

# variables
OBJS = sqlite3$(O)

all:  sqlite3.a

sqlite3.o: sqlite3.c
	$(CC) -c $(CFLAGS) $*.c

sqlite3.a: $(OBJS)
	ar -r $@ $(OBJS)

clean:
	$(RM) $(OBJS) sqlite3.a


