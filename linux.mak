# Makefile to build linux D runtime library libphobos.a.
# Targets:
#	make
#		Same as make unittest
#	make libphobos.a
#		Build libphobos.a
#	make clean
#		Delete unneeded files created by build process
#	make unittest
#		Build libphobos.a, build and run unit tests

CFLAGS=-O
#CFLAGS=-g
DFLAGS=-O -release
#DFLAGS=-unittest

CC=gcc
#DMD=/dmd/bin/dmd
DMD=../dmd

.c.o:
	$(CC) -c $(CFLAGS) $*.c

.cpp.o:
	g++ -c $(CFLAGS) $*.cpp

.d.o:
	$(DMD) -c $(DFLAGS) $*.d

.asm.o:
	$(CC) -c $*.asm

targets : unittest

test.o : test.d
	$(DMD) -c test -g

test : test.o libphobos.a
	$(CC) -o $@ test.o libphobos.a -lpthread -g

unittest : unittest.o libphobos.a
	$(CC) -o $@ unittest.o libphobos.a -lpthread -lm -g

unittest.o : unittest.d
	$(DMD) -c unittest

OBJS= assert.o deh2.o switch.o complex.o gcstats.o \
	critical.o object.o monitor.o arraycat.o invariant.o \
	dmain2.o outofmemory.o achar.o aaA.o adi.o file.o \
	compiler.o system.o moduleinit.o \
	cast.o syserror.o path.o string.o memset.o math.o \
	outbuffer.o ctype.o regexp.o random.o linux.o \
	stream.o switcherr.o array.o gc.o \
	qsort.o thread.o obj.o utf.o uri.o \
	crc32.o conv.o arraycast.o errno.o alloca.o cmath2.o \
	ti_wchar.o ti_uint.o ti_short.o ti_ushort.o \
	ti_byte.o ti_ubyte.o ti_long.o ti_ulong.o ti_ptr.o \
	ti_float.o ti_double.o ti_real.o ti_delegate.o \
	ti_creal.o ti_ireal.o ti_cfloat.o ti_ifloat.o \
	ti_cdouble.o ti_idouble.o \
	ti_Aa.o ti_AC.o ti_Ag.o ti_Aubyte.o ti_Aushort.o ti_Ashort.o \
	ti_C.o ti_int.o ti_char.o ti_dchar.o ti_Adchar.o \
	ti_Aint.o ti_Auint.o ti_Along.o ti_Aulong.o ti_Awchar.o \
	date.o dateparse.o llmath.o math2.o

HDR=mars.h

SRC= mars.h switch.d complex.c critical.c minit.asm \
	deh.c object.d gc.d math.d c/stdio.d c/stdlib.d time.d monitor.c \
	arraycat.d string.d windows.d path.d linuxextern.d \
	invariant.d assert.d regexp.d dmain2.d dateparse.d \
	outofmemory.d syserror.d utf.d uri.d \
	ctype.d achar.d aaA.d adi.d file.d compiler.d system.d \
	moduleinit.d cast.d math.d qsort.d \
	outbuffer.d unittest.d stream.d ctype.d random.d adi.d \
	math2.d thread.d obj.d iunknown.d intrinsic.d time.d memset.d \
	array.d switcherr.d arraycast.d errno.c alloca.d cmath2.d \
	ti_wchar.d ti_uint.d ti_short.d ti_ushort.d \
	ti_byte.d ti_ubyte.d ti_long.d ti_ulong.d ti_ptr.d \
	ti_float.d ti_double.d ti_real.d ti_delegate.d \
	ti_creal.d ti_ireal.d ti_cfloat.d ti_ifloat.d \
	ti_cdouble.d ti_idouble.d \
	ti_Aa.d ti_AC.d ti_Ag.d ti_Aubyte.d ti_Aushort.d ti_Ashort.o \
	ti_Aint.d ti_Auint.d ti_Along.d ti_Aulong.d ti_Awchar.d \
	ti_C.d ti_int.d ti_char.d ti_dchar.d ti_Adchar.d \
	crc32.d stdint.d conv.d gcstats.d linux.d deh2.d date.d llmath.d \
	win32.mak linux.mak

libphobos.a : $(OBJS) gc2/dmgc.a linux.mak
	ar -r $@ $(OBJS) gc2/gc.o gc2/gcx.o gc2/gcbits.o gc2/gclinux.o

aaA.o : aaA.d
	$(DMD) -c $(DFLAGS) aaA.d

achar.o : achar.d
	$(DMD) -c $(DFLAGS) achar.d

adi.o : adi.d
	$(DMD) -c $(DFLAGS) adi.d

alloca.o : alloca.d
	$(DMD) -c $(DFLAGS) alloca.d

array.o : array.d
	$(DMD) -c $(DFLAGS) array.d

arraycast.o : arraycast.d
	$(DMD) -c $(DFLAGS) arraycast.d

arraycat.o : arraycat.d
	$(DMD) -c $(DFLAGS) arraycat.d

assert.o : assert.d
	$(DMD) -c $(DFLAGS) assert.d

cast.o : cast.d
	$(DMD) -c $(DFLAGS) cast.d

cmath2.o : cmath2.d
	$(DMD) -c $(DFLAGS) cmath2.d

compiler.o : compiler.d
	$(DMD) -c $(DFLAGS) compiler.d

complex.o : mars.h complex.c

conv.o : conv.d
	$(DMD) -c $(DFLAGS) conv.d

crc32.o : crc32.d
	$(DMD) -c $(DFLAGS) crc32.d

critical.o : mars.h critical.c

ctype.o : ctype.d
	$(DMD) -c $(DFLAGS) ctype.d

dassert.o : mars.h dassert.c

date.o : dateparse.d date.d
	$(DMD) -c $(DFLAGS) date.d

dateparse.o : dateparse.d date.d
	$(DMD) -c $(DFLAGS) dateparse.d

deh2.o : deh2.d
	$(DMD) -c $(DFLAGS) -release deh2.d

dmain2.o : dmain2.d
	$(DMD) -c $(DFLAGS) dmain2.d

errno.o : errno.c

file.o : file.d
	$(DMD) -c $(DFLAGS) file.d

gc.o : gc.d
	$(DMD) -c $(DFLAGS) gc.d

gcstats.o : gcstats.d
	$(DMD) -c $(DFLAGS) gcstats.d

invariant.o : invariant.d
	$(DMD) -c $(DFLAGS) invariant.d

linux.o : linux.d
	$(DMD) -c $(DFLAGS) linux.d

llmath.o : llmath.d
	$(DMD) -c $(DFLAGS) llmath.d

math.o : math.d
	$(DMD) -c $(DFLAGS) math.d

math2.o : math2.d
	$(DMD) -c $(DFLAGS) math2.d

memset.o : memset.d
	$(DMD) -c $(DFLAGS) memset.d

moduleinit.o : moduleinit.d
	$(DMD) -c $(DFLAGS) moduleinit.d

monitor.o : mars.h monitor.c

obj.o : obj.d
	$(DMD) -c $(DFLAGS) obj.d

object.o : object.d
	$(DMD) -c $(DFLAGS) object.d

outbuffer.o : outbuffer.d
	$(DMD) -c $(DFLAGS) outbuffer.d

outofmemory.o : outofmemory.d
	$(DMD) -c $(DFLAGS) outofmemory.d

path.o : path.d
	$(DMD) -c $(DFLAGS) path.d

qsort.o : qsort.d
	$(DMD) -c $(DFLAGS) qsort.d

random.o : random.d
	$(DMD) -c $(DFLAGS) random.d

regexp.o : regexp.d
	$(DMD) -c $(DFLAGS) regexp.d

stream.o : stream.d
	$(DMD) -c $(DFLAGS) stream.d

string.o : string.d
	$(DMD) -c $(DFLAGS) string.d

switch.o : switch.d
	$(DMD) -c $(DFLAGS) switch.d

switcherr.o : switcherr.d
	$(DMD) -c $(DFLAGS) switcherr.d

syserror.o : syserror.d
	$(DMD) -c $(DFLAGS) syserror.d

system.o : system.d
	$(DMD) -c $(DFLAGS) system.d

thread.o : thread.d
	$(DMD) -c $(DFLAGS) thread.d

ti_wchar.o : ti_wchar.d
	$(DMD) -c $(DFLAGS) ti_wchar.d

ti_dchar.o : ti_dchar.d
	$(DMD) -c $(DFLAGS) ti_dchar.d

ti_uint.o : ti_uint.d
	$(DMD) -c $(DFLAGS) ti_uint.d

ti_short.o : ti_short.d
	$(DMD) -c $(DFLAGS) ti_short.d

ti_ushort.o : ti_ushort.d
	$(DMD) -c $(DFLAGS) ti_ushort.d

ti_byte.o : ti_byte.d
	$(DMD) -c $(DFLAGS) ti_byte.d

ti_ubyte.o : ti_ubyte.d
	$(DMD) -c $(DFLAGS) ti_ubyte.d

ti_long.o : ti_long.d
	$(DMD) -c $(DFLAGS) ti_long.d

ti_ulong.o : ti_ulong.d
	$(DMD) -c $(DFLAGS) ti_ulong.d

ti_ptr.o : ti_ptr.d
	$(DMD) -c $(DFLAGS) ti_ptr.d

ti_float.o : ti_float.d
	$(DMD) -c $(DFLAGS) ti_float.d

ti_double.o : ti_double.d
	$(DMD) -c $(DFLAGS) ti_double.d

ti_real.o : ti_real.d
	$(DMD) -c $(DFLAGS) ti_real.d

ti_delegate.o : ti_delegate.d
	$(DMD) -c $(DFLAGS) ti_delegate.d

ti_creal.o : ti_creal.d
	$(DMD) -c $(DFLAGS) ti_creal.d

ti_ireal.o : ti_ireal.d
	$(DMD) -c $(DFLAGS) ti_ireal.d

ti_cfloat.o : ti_cfloat.d
	$(DMD) -c $(DFLAGS) ti_cfloat.d

ti_ifloat.o : ti_ifloat.d
	$(DMD) -c $(DFLAGS) ti_ifloat.d

ti_cdouble.o : ti_cdouble.d
	$(DMD) -c $(DFLAGS) ti_cdouble.d

ti_idouble.o : ti_idouble.d
	$(DMD) -c $(DFLAGS) ti_idouble.d

ti_Aa.o : ti_Aa.d
	$(DMD) -c $(DFLAGS) ti_Aa.d

ti_AC.o : ti_AC.d
	$(DMD) -c $(DFLAGS) ti_AC.d

ti_Ag.o : ti_Ag.d
	$(DMD) -c $(DFLAGS) ti_Ag.d

ti_Aubyte.o : ti_Aubyte.d
	$(DMD) -c $(DFLAGS) ti_Aubyte.d

ti_Aushort.o : ti_Aushort.d
	$(DMD) -c $(DFLAGS) ti_Aushort.d

ti_Ashort.o : ti_Ashort.d
	$(DMD) -c $(DFLAGS) ti_Ashort.d

ti_Auint.o : ti_Auint.d
	$(DMD) -c $(DFLAGS) ti_Auint.d

ti_Aint.o : ti_Aint.d
	$(DMD) -c $(DFLAGS) ti_Aint.d

ti_Aulong.o : ti_Aulong.d
	$(DMD) -c $(DFLAGS) ti_Aulong.d

ti_Along.o : ti_Along.d
	$(DMD) -c $(DFLAGS) ti_Along.d

ti_Awchar.o : ti_Awchar.d
	$(DMD) -c $(DFLAGS) ti_Awchar.d

ti_Adchar.o : ti_Adchar.d
	$(DMD) -c $(DFLAGS) ti_Adchar.d

ti_C.o : ti_C.d
	$(DMD) -c $(DFLAGS) ti_C.d

ti_char.o : ti_char.d
	$(DMD) -c $(DFLAGS) ti_char.d

ti_int.o : ti_int.d
	$(DMD) -c $(DFLAGS) ti_int.d

uri.o : uri.d
	$(DMD) -c $(DFLAGS) uri.d

utf.o : utf.d
	$(DMD) -c $(DFLAGS) utf.d

zip : $(SRC)
	rm phobos.zip
	zip phobos $(SRC)

clean:
	rm $(OBJS)
