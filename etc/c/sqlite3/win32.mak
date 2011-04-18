# Makefile for zlib

CC=dmc
LD=link
CFLAGS=-o
LDFLAGS=
O=.obj

# variables
OBJS = sqlite3$(O)

all:  sqlite3.lib

sqlite3.obj: sqlite3.c
	$(CC) -c $(CFLAGS) $*.c

sqlite3.lib: $(OBJS)
	lib -c sqlite3.lib $(OBJS)

clean:
	$(RM) $(OBJS) sqlite3.lib


