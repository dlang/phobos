# Makefile for zlib

CC=dmc
LD=link
CFLAGS=-o
LDFLAGS=
O=.obj

# variables

OBJS = adler32$(O) compress$(O) crc32$(O) deflate$(O) gzclose$(O) gzlib$(O) gzread$(O) \
	gzwrite$(O) infback$(O) inffast$(O) inflate$(O) inftrees$(O) trees$(O) uncompr$(O) zutil$(O)


all:  zlib.lib example.exe minigzip.exe

adler32.obj: zutil.h zlib.h zconf.h
	$(CC) -c $(CFLAGS) $*.c

zutil.obj: zutil.h zlib.h zconf.h
	$(CC) -c $(CFLAGS) $*.c

gzclose.obj: zlib.h zconf.h gzguts.h
	$(CC) -c $(CFLAGS) $*.c

gzlib.obj: zlib.h zconf.h gzguts.h
	$(CC) -c $(CFLAGS) $*.c

gzread.obj: zlib.h zconf.h gzguts.h
	$(CC) -c $(CFLAGS) $*.c

gzwrite.obj: zlib.h zconf.h gzguts.h
	$(CC) -c $(CFLAGS) $*.c

compress.obj: zlib.h zconf.h
	$(CC) -c $(CFLAGS) $*.c

example.obj: zlib.h zconf.h
	$(CC) -c $(CFLAGS) $*.c

minigzip.obj: zlib.h zconf.h
	$(CC) -c $(CFLAGS) $*.c

uncompr.obj: zlib.h zconf.h
	$(CC) -c $(CFLAGS) $*.c

crc32.obj: zutil.h zlib.h zconf.h crc32.h
	$(CC) -c $(CFLAGS) $*.c

deflate.obj: deflate.h zutil.h zlib.h zconf.h
	$(CC) -c $(CFLAGS) $*.c

infback.obj: zutil.h zlib.h zconf.h inftrees.h inflate.h inffast.h inffixed.h
	$(CC) -c $(CFLAGS) $*.c

inflate.obj: zutil.h zlib.h zconf.h inftrees.h inflate.h inffast.h inffixed.h
	$(CC) -c $(CFLAGS) $*.c

inffast.obj: zutil.h zlib.h zconf.h inftrees.h inflate.h inffast.h
	$(CC) -c $(CFLAGS) $*.c

inftrees.obj: zutil.h zlib.h zconf.h inftrees.h
	$(CC) -c $(CFLAGS) $*.c

trees.obj: deflate.h zutil.h zlib.h zconf.h trees.h
	$(CC) -c $(CFLAGS) $*.c



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
