
CFLAGS=-g -mn -6 -r -Igc
CC=sc

.c.obj:
	$(CC) -c $(CFLAGS) $*

.cpp.obj:
	$(CC) -c $(CFLAGS) $*

.d.obj:
	..\mars $*

.asm.obj:
	$(CC) -c $*

targets : phobos.lib

test : test.exe

test.exe : test.d phobos.lib ..\mars.exe
	..\mars test -g
	sc -mn test.obj -g

OBJS= assert.obj deh.obj modulo.obj new.obj switch.obj complex.obj \
	critical.obj interface.obj object.obj monitor.obj arraycat.obj invariant.obj \
	dmain2.obj outofmemory.obj achar.obj aaAh4.obj adi.obj file.obj \
	compiler.obj system.obj arraysetlength.obj minit.obj moduleinit.obj \
	cast.obj syserror.obj filename.obj string.obj

HDR=mars.h

SRC= modulo.c new.cpp switch.d complex.c critical.c fpu.d \
	aa.c vaa.c interface.c arraysetlength.cpp minit.asm

SRC2=deh.c object.d gc.d math.d stdio.d stdlib.d time.d monitor.c arraycat.d \
	string.d windows.d filename.d

SRC3=winbase.d windef.d invariant.d assert.d RegExp.d dmain2.d dateparse.d \
	outofmemory.d syserror.d

SRC4=dchar.d ctype.d achar.d aaAh4.d adi.d file.d compiler.d system.d \
	moduleinit.d cast.d

phobos.lib : $(OBJS) gc\dmgc.lib makefile
	del phobos.lib
	lib phobos /c/noi +critical+assert+deh+object+arraysetlength;
	lib phobos /noi +interface+modulo+new+switch+monitor+string;
	lib phobos /noi +arraycat+invariant+dmain2+achar+outofmemory;
	lib phobos /noi +aaAh4+adi+file+compiler+system+syserror;
	lib phobos /noi +minit+moduleinit+cast+filename+gc\dmgc.lib;


aaAh4.obj : aaAh4.d
achar.obj : achar.d
adi.obj : adi.d
arraycat.obj : arraycat.d
assert.obj : assert.d
cast.obj : cast.d
compiler.obj : compiler.d
complex.obj : mars.h complex.c
critical.obj : mars.h critical.c
dassert.obj : mars.h dassert.c
dmain2.obj : dmain2.d
file.obj : file.d
invariant.obj : invariant.d
minit.obj : minit.asm
moduleinit.obj : moduleinit.d
modulo.obj : mars.h modulo.c
monitor.obj : mars.h mars.h monitor.c
outofmemory.obj : outofmemory.d
switch.obj : switch.d
system.obj : system.d

arraysetlength.obj : mars.h arraysetlength.cpp
new.obj : mars.h new.cpp

zip : makefile $(HDR) $(SRC) $(SRC2) $(SRC3) $(SRC4)
	zip32 -u phobos makefile $(HDR)
	zip32 -u phobos $(SRC)
	zip32 -u phobos $(SRC2)
	zip32 -u phobos $(SRC3)
	zip32 -u phobos $(SRC4)

clean:
	del *.obj
