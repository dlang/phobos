# Makefile for zlib64

MODEL=64
VCDIR=\Program Files (x86)\Microsoft Visual Studio 10.0\VC

CC=$(VCDIR)\bin\amd64\cl
LD=$(VCDIR)\bin\amd64\link
LIB=$(VCDIR)\bin\amd64\lib

CFLAGS=/O2 /nologo /I"$(VCDIR)\INCLUDE"
LIBFLAGS=/nologo
LDFLAGS=/nologo
O=.obj

# do not preselect a C runtime (extracted from the line above to make the auto tester happy)
CFLAGS=$(CFLAGS) /Zl /GS-

# variables

OBJS = adler32$(O) compress$(O) crc32$(O) deflate$(O) gzclose$(O) gzlib$(O) gzread$(O) \
	gzwrite$(O) infback$(O) inffast$(O) inflate$(O) inftrees$(O) trees$(O) uncompr$(O) zutil$(O)


all:  zlib64.lib example.exe infcover.exe minigzip.exe

adler32.obj: zutil.h zlib.h zconf.h
	"$(CC)" /c $(CFLAGS) $*.c

zutil.obj: zutil.h zlib.h zconf.h
	"$(CC)" /c $(CFLAGS) $*.c

gzclose.obj: zlib.h zconf.h gzguts.h
	"$(CC)" /c $(CFLAGS) $*.c

gzlib.obj: zlib.h zconf.h gzguts.h
	"$(CC)" /c $(CFLAGS) $*.c

gzread.obj: zlib.h zconf.h gzguts.h
	"$(CC)" /c $(CFLAGS) $*.c

gzwrite.obj: zlib.h zconf.h gzguts.h
	"$(CC)" /c $(CFLAGS) $*.c

compress.obj: zlib.h zconf.h
	"$(CC)" /c $(CFLAGS) $*.c

uncompr.obj: zlib.h zconf.h
	"$(CC)" /c $(CFLAGS) $*.c

crc32.obj: zutil.h zlib.h zconf.h crc32.h
	"$(CC)" /c $(CFLAGS) $*.c

deflate.obj: deflate.h zutil.h zlib.h zconf.h
	"$(CC)" /c $(CFLAGS) $*.c

infback.obj: zutil.h zlib.h zconf.h inftrees.h inflate.h inffast.h inffixed.h
	"$(CC)" /c $(CFLAGS) $*.c

inflate.obj: zutil.h zlib.h zconf.h inftrees.h inflate.h inffast.h inffixed.h
	"$(CC)" /c $(CFLAGS) $*.c

inffast.obj: zutil.h zlib.h zconf.h inftrees.h inflate.h inffast.h
	"$(CC)" /c $(CFLAGS) $*.c

inftrees.obj: zutil.h zlib.h zconf.h inftrees.h
	"$(CC)" /c $(CFLAGS) $*.c

trees.obj: deflate.h zutil.h zlib.h zconf.h trees.h
	"$(CC)" /c $(CFLAGS) $*.c



example.obj: test\example.c zlib.h zconf.h
	"$(CC)" /c $(cvarsdll) $(CFLAGS) test\$*.c

infcover.obj: test\infcover.c zlib.h zconf.h
	"$(CC)" /c $(cvarsdll) $(CFLAGS) test\$*.c

minigzip.obj: test\minigzip.c zlib.h zconf.h
	"$(CC)" /c $(cvarsdll) $(CFLAGS) test\$*.c

zlib$(MODEL).lib: $(OBJS)
	"$(LIB)" $(LIBFLAGS) /OUT:zlib$(MODEL).lib $(OBJS)

example.exe: example.obj zlib$(MODEL).lib
	"$(LD)" $(LDFLAGS) example.obj zlib$(MODEL).lib

infcover.exe: infcover.obj zlib$(MODEL).lib
	"$(LD)" $(LDFLAGS) infcover.obj zlib$(MODEL).lib

minigzip.exe: minigzip.obj zlib$(MODEL).lib
	"$(LD)" $(LDFLAGS) minigzip.obj zlib$(MODEL).lib

test: example.exe infcover.exe minigzip.exe
	example
	infcover
	echo hello world | minigzip | minigzip -d

clean:
	del *.obj
	del *.exe
	del *.dll
	del *.lib
	del *.lst
	del foo.gz
