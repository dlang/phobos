# Makefile for zlib

CC=dmc
LD=link
CFLAGS=-o
LDFLAGS=
O=.obj

# variables
OBJS = adler32$(O) compress$(O) crc32$(O) gzio$(O) uncompr$(O) deflate$(O) \
       trees$(O) zutil$(O) inflate$(O) infback$(O) inftrees$(O) inffast$(O)

all:  zlib.lib example.exe minigzip.exe

adler32.obj: adler32.c zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

compress.obj: compress.c zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

crc32.obj: crc32.c zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

deflate.obj: deflate.c deflate.h zutil.h zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

gzio.obj: gzio.c zutil.h zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

infback.obj: infback.c zlib.h zconf.h inftrees.h inflate.h inffast.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

inflate.obj: inflate.c zlib.h zconf.h inftrees.h inflate.h inffast.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

inftrees.obj: inftrees.c zlib.h zconf.h inftrees.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

inffast.obj: inffast.c zlib.h zconf.h inftrees.h inflate.h inffast.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

trees.obj: trees.c deflate.h zutil.h zlib.h zconf.h trees.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

uncompr.obj: uncompr.c zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

zutil.obj: zutil.c zutil.h zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

example.obj: example.c zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

minigzip.obj: minigzip.c zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

zlib.lib: $(OBJS)
	lib -c zlib.lib $(OBJS)

example.exe: example.obj zlib.lib
	$(LD) $(LDFLAGS) example.obj zlib.lib

minigzip.exe: minigzip.obj zlib.lib
	$(LD) $(LDFLAGS) minigzip.obj zlib.lib

test: example.exe minigzip.exe
	example
	echo hello world | minigzip | minigzip -d 

clean:
	del *.obj
	del *.exe
	del *.dll
	del *.lib
	del *.lst
	del foo.gz
