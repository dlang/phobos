# Makefile for zlib

CC=gcc
LD=link
CFLAGS=-O
LDFLAGS=
O=.o

.c.o:
	$(CC) -c $(CFLAGS) $*

.d.o:
	$(DMD) -c $(DFLAGS) $*

# variables
OBJS = adler32$(O) compress$(O) crc32$(O) gzio$(O) uncompr$(O) deflate$(O) \
       trees$(O) zutil$(O) inflate$(O) infback$(O) inftrees$(O) inffast$(O)

all:  zlib.a example minigzip

adler32.o: adler32.c zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

compress.o: compress.c zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

crc32.o: crc32.c zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

deflate.o: deflate.c deflate.h zutil.h zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

gzio.o: gzio.c zutil.h zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

infback.o: infback.c zlib.h zconf.h inftrees.h inflate.h inffast.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

inflate.o: inflate.c zlib.h zconf.h inftrees.h inflate.h inffast.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

inftrees.o: inftrees.c zlib.h zconf.h inftrees.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

inffast.o: inffast.c zlib.h zconf.h inftrees.h inflate.h inffast.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

trees.o: trees.c deflate.h zutil.h zlib.h zconf.h trees.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

uncompr.o: uncompr.c zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

zutil.o: zutil.c zutil.h zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

example.o: example.c zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

minigzip.o: minigzip.c zlib.h zconf.h
	$(CC) -c $(cvarsdll) $(CFLAGS) $*.c

zlib.a: $(OBJS)
	ar -r $@ $(OBJS)

example: example.o zlib.a
	$(CC) -o $@ example.o zlib.a -g

minigzip: minigzip.o zlib.a
	$(CC) -o $@ minigzip.o zlib.a -g

test: example minigzip
	./example
	echo hello world | minigzip | minigzip -d 

clean:
	rm $(OBJS) zlib.a example minigzip test foo.gz
