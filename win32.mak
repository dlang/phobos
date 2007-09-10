# Makefile to build D runtime library phobos.lib for Win32
# Designed to work with \dm\bin\make.exe
# Targets:
#	make
#		Same as make unittest
#	make phobos.lib
#		Build phobos.lib
#	make clean
#		Delete unneeded files created by build process
#	make unittest
#		Build phobos.lib, build and run unit tests
# Notes:
#	This relies on LIB.EXE 8.00 or later, and MAKE.EXE 5.01 or later.

CFLAGS=-g -mn -6 -r
#DFLAGS=-O -release
DFLAGS=-unittest -g

CC=sc
#DMD=\dmd\bin\dmd
DMD=..\dmd

.c.obj:
	$(CC) -c $(CFLAGS) $*

.cpp.obj:
	$(CC) -c $(CFLAGS) $*

.d.obj:
	$(DMD) -c $(DFLAGS) $*

.asm.obj:
	$(CC) -c $*

targets : unittest

unittest : unittest.exe
	unittest

test : test.exe

test.obj : test.d
	$(DMD) -c test -g

test.exe : test.obj phobos.lib
	$(DMD) test.obj -g

unittest.exe : unittest.d phobos.lib
	$(DMD) unittest -g
	sc unittest.obj -g

OBJS= assert.obj deh.obj switch.obj complex.obj gcstats.obj \
	critical.obj object.obj monitor.obj arraycat.obj invariant.obj \
	dmain2.obj outofmemory.obj achar.obj aaA.obj adi.obj file.obj \
	compiler.obj system.obj moduleinit.obj cmath.obj \
	cast.obj syserror.obj path.obj string.obj memset.obj math.obj \
	outbuffer.obj ctype.obj regexp.obj random.obj windows.obj \
	stream.obj switcherr.obj com.obj array.obj gc.obj adi.obj \
	qsort.obj math2.obj date.obj dateparse.obj thread.obj obj.obj \
	iunknown.obj crc32.obj conv.obj arraycast.obj utf.obj uri.obj \
	ti_Aa.obj ti_Ag.obj ti_C.obj ti_int.obj ti_char.obj \
	ti_wchar.obj ti_uint.obj ti_short.obj ti_ushort.obj \
	ti_byte.obj ti_ubyte.obj ti_long.obj ti_ulong.obj ti_ptr.obj \
	ti_float.obj ti_double.obj ti_real.obj ti_delegate.obj \
	ti_creal.obj ti_ireal.obj \
	ti_cfloat.obj ti_ifloat.obj \
	ti_cdouble.obj ti_idouble.obj

HDR=mars.h

SRC= switch.d complex.c critical.c errno.c alloca.d cmath2.d \
	minit.asm linux.d deh2.d date.d linuxextern.d llmath.d

SRC2=deh.c object.d gc.d math.d c\stdio.d c\stdlib.d time.d monitor.c arraycat.d \
	string.d windows.d path.d

SRC3=invariant.d assert.d RegExp.d dmain2.d dateparse.d \
	outofmemory.d syserror.d

SRC4= ctype.d achar.d aaA.d adi.d file.d compiler.d system.d \
	moduleinit.d cast.d math.d qsort.d

SRC5=outbuffer.d unittest.d stream.d ctype.d regexp.d random.d adi.d \
	ti_Aa.d ti_Ag.d ti_C.d ti_int.d ti_char.d

SRC6=math2.d thread.d obj.d iunknown.d intrinsic.d time.d memset.d \
	array.d switcherr.d arraycast.d

SRC7=ti_wchar.d ti_uint.d ti_short.d ti_ushort.d \
	ti_byte.d ti_ubyte.d ti_long.d ti_ulong.d ti_ptr.d \
	ti_float.d ti_double.d ti_real.d ti_delegate.d \
	ti_creal.d ti_ireal.d ti_cfloat.d ti_ifloat.d \
	ti_cdouble.d ti_idouble.d

SRC8=crc32.d stdint.d conv.d gcstats.d utf.d uri.d cmath.d

phobos.lib : $(OBJS) minit.obj gc2\dmgc.lib win32.mak
	lib -c phobos.lib $(OBJS) minit.obj gc2\dmgc.lib

aaA.obj : aaA.d
achar.obj : achar.d
adi.obj : adi.d
arraycat.obj : arraycat.d
assert.obj : assert.d
cast.obj : cast.d
cmath.obj : cmath.d
compiler.obj : compiler.d
complex.obj : mars.h complex.c
critical.obj : mars.h critical.c
dassert.obj : mars.h dassert.c
date.obj : dateparse.d date.d
dateparse.obj : dateparse.d date.d
deh.obj : mars.h deh.c
dmain2.obj : dmain2.d
file.obj : file.d
gc.obj : gc.d
invariant.obj : invariant.d
math.obj : math.d
math2.obj : math2.d
memset.obj : memset.d
minit.obj : minit.asm
moduleinit.obj : moduleinit.d
monitor.obj : mars.h monitor.c
outofmemory.obj : outofmemory.d
qsort.obj : qsort.d
switch.obj : switch.d
system.obj : system.d
thread.obj : thread.d
ti_Aa.obj : ti_Aa.d
ti_Ag.obj : ti_Ag.d
ti_C.obj : ti_C.d
ti_char.obj : ti_char.d
ti_int.obj : ti_int.d

zip : win32.mak linux.mak $(HDR) $(SRC) $(SRC2) $(SRC3) $(SRC4) $(SRC5) $(SRC6) $(SRC7) \
	$(SRC8)
	zip32 -u phobos win32.mak linux.mak $(HDR)
	zip32 -u phobos $(SRC)
	zip32 -u phobos $(SRC2)
	zip32 -u phobos $(SRC3)
	zip32 -u phobos $(SRC4)
	zip32 -u phobos $(SRC5)
	zip32 -u phobos $(SRC6)
	zip32 -u phobos $(SRC7)
	zip32 -u phobos $(SRC8)

clean:
	del $(OBJS)
