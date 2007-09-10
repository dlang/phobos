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
	dmain2.o outofmemory.o aaA.o adi.o file.o \
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

#SRC= mars.h switch.d complex.c critical.c minit.asm \
#	deh.c object.d gc.d math.d c/stdio.d c/stdlib.d time.d monitor.c \
#	arraycat.d string.d windows.d path.d linuxextern.d \
#	invariant.d assert.d regexp.d dmain2.d dateparse.d \
#	outofmemory.d syserror.d utf.d uri.d \
#	ctype.d aaA.d adi.d file.d compiler.d system.d \
#	moduleinit.d cast.d math.d qsort.d \
#	outbuffer.d unittest.d stream.d ctype.d random.d adi.d \
#	math2.d thread.d obj.d iunknown.d intrinsic.d time.d memset.d \
#	array.d switcherr.d arraycast.d errno.c alloca.d internal/cmath2.d \
#	D/win32/d \
#	ti_wchar.d ti_uint.d ti_short.d ti_ushort.d \
#	ti_byte.d ti_ubyte.d ti_long.d ti_ulong.d ti_ptr.d \
#	ti_float.d ti_double.d ti_real.d ti_delegate.d \
#	ti_creal.d ti_ireal.d ti_cfloat.d ti_ifloat.d \
#	ti_cdouble.d ti_idouble.d \
#	ti_Aa.d ti_AC.d ti_Ag.d ti_Aubyte.d ti_Aushort.d ti_Ashort.o \
#	ti_Aint.d ti_Auint.d ti_Along.d ti_Aulong.d ti_Awchar.d \
#	ti_C.d ti_int.d ti_char.d ti_dchar.d ti_Adchar.d \
#	crc32.d stdint.d conv.d gcstats.d linux.d deh2.d date.d llmath.d \
#	win32.mak linux.mak

SRC=	errno.c object.d unittest.d crc32.d gcstats.d

SRCSTD= std/zlib.d std/zip.d std/stdint.d std/conv.d std/utf.d std/uri.d \
	std/gc.d std/math.d std/string.d std/path.d std/date.d \
	std/ctype.d std/file.d std/compiler.d std/system.d std/moduleinit.d \
	std/outbuffer.d std/math2.d std/thread.d \
	std/assert.d std/dateparse.d std/outofmemory.d \
	std/intrinsic.d std/array.d std/switcherr.d \
	std/regexp.d std/random.d std/stream.d

SRCSTDC= std/c/process.d std/c/stdlib.d std/c/time.d std/c/stdio.d

SRCTI=	\
	std/typeinfo/ti_wchar.d std/typeinfo/ti_uint.d \
	std/typeinfo/ti_short.d std/typeinfo/ti_ushort.d \
	std/typeinfo/ti_byte.d std/typeinfo/ti_ubyte.d \
	std/typeinfo/ti_long.d std/typeinfo/ti_ulong.d \
	std/typeinfo/ti_ptr.d \
	std/typeinfo/ti_float.d std/typeinfo/ti_double.d \
	std/typeinfo/ti_real.d std/typeinfo/ti_delegate.d \
	std/typeinfo/ti_creal.d std/typeinfo/ti_ireal.d \
	std/typeinfo/ti_cfloat.d std/typeinfo/ti_ifloat.d \
	std/typeinfo/ti_cdouble.d std/typeinfo/ti_idouble.d \
	std/typeinfo/ti_Adchar.d std/typeinfo/ti_Aubyte.d \
	std/typeinfo/ti_Aushort.d std/typeinfo/ti_Ashort.d \
	std/typeinfo/ti_Aa.d std/typeinfo/ti_Ag.d \
	std/typeinfo/ti_AC.d std/typeinfo/ti_C.d \
	std/typeinfo/ti_int.d std/typeinfo/ti_char.d \
	std/typeinfo/ti_Aint.d std/typeinfo/ti_Auint.d \
	std/typeinfo/ti_Along.d std/typeinfo/ti_Aulong.d \
	std/typeinfo/ti_Awchar.d std/typeinfo/ti_dchar.d

SRCINT=	\
	internal/switch.d internal/complex.c internal/critical.c \
	internal/minit.asm internal/alloca.d internal/llmath.d internal/deh.c \
	internal/arraycat.d internal/invariant.d internal/monitor.c \
	internal/memset.d internal/arraycast.d internal/aaA.d internal/adi.d \
	internal/dmain2.d internal/cast.d internal/qsort.d internal/deh2.d \
	internal/cmath2.d internal/obj.d internal/mars.h

SRCSTDWIN= std/windows/registry.d std/windows/syserror.d \
	std/windows/iunknown.d

SRCSTDCWIN= std/c/windows/windows.d std/c/windows/com.d

SRCSTDCLINUX= std/c/linux/linux.d std/c/linux/linuxextern.d

SRCETC= etc/c/zlib.d

SRCZLIB= etc/c/zlib\algorithm.txt \
	etc/c/zlib\trees.h \
	etc/c/zlib\inffixed.h \
	etc/c/zlib\INDEX \
	etc/c/zlib\zconf.h \
	etc/c/zlib\compress.c \
	etc/c/zlib\adler32.c \
	etc/c/zlib\uncompr.c \
	etc/c/zlib\deflate.h \
	etc/c/zlib\example.c \
	etc/c/zlib\zutil.c \
	etc/c/zlib\gzio.c \
	etc/c/zlib\crc32.c \
	etc/c/zlib\infblock.c \
	etc/c/zlib\infblock.h \
	etc/c/zlib\infcodes.c \
	etc/c/zlib\infcodes.h \
	etc/c/zlib\inffast.c \
	etc/c/zlib\inffast.h \
	etc/c/zlib\zutil.h \
	etc/c/zlib\inflate.c \
	etc/c/zlib\trees.c \
	etc/c/zlib\inftrees.h \
	etc/c/zlib\infutil.c \
	etc/c/zlib\infutil.h \
	etc/c/zlib\minigzip.c \
	etc/c/zlib\inftrees.c \
	etc/c/zlib\zlib.html \
	etc/c/zlib\maketree.c \
	etc/c/zlib\zlib.h \
	etc/c/zlib\zlib.3 \
	etc/c/zlib\FAQ \
	etc/c/zlib\deflate.c \
	etc/c/zlib\ChangeLog \
	etc/c/zlib\win32.mak \
	etc/c/zlib\linux.mak \
	etc/c/zlib\zlib.lib \
	etc/c/zlib\README

SRCGC= internal/gc/gc.d \
	internal/gc/gcx.d \
	internal/gc/gcbits.d \
	internal/gc/win32.d \
	internal/gc/gclinux.d \
	internal/gc/testgc.d \
	internal/gc/win32.mak \
	internal/gc/linux.mak

ALLSRCS = $(SRC) $(SRCSTD) $(SRCSTDC) $(SRCTI) $(SRCINT) $(SRCSTDWIN) \
	$(SRCSTDCWIN) $(SRCSTDCLINUX) $(SRCETC) $(SRCZLIB) $(SRCGC)


libphobos.a : $(OBJS) internal/gc/dmgc.a linux.mak
	ar -r $@ $(OBJS) internal/gc/gc.o internal/gc/gcx.o \
	internal/gc/gcbits.o internal/gc/gclinux.o

###########################################################

crc32.o : crc32.d
	$(DMD) -c $(DFLAGS) crc32.d

errno.o : errno.c

gcstats.o : gcstats.d
	$(DMD) -c $(DFLAGS) gcstats.d

### internal

aaA.o : internal/aaA.d
	$(DMD) -c $(DFLAGS) internal/aaA.d

adi.o : internal/adi.d
	$(DMD) -c $(DFLAGS) internal/adi.d

alloca.o : internal/alloca.d
	$(DMD) -c $(DFLAGS) internal/alloca.d

arraycast.o : internal/arraycast.d
	$(DMD) -c $(DFLAGS) internal/arraycast.d

arraycat.o : internal/arraycat.d
	$(DMD) -c $(DFLAGS) internal/arraycat.d

cast.o : internal/cast.d
	$(DMD) -c $(DFLAGS) internal/cast.d

cmath2.o : internal/cmath2.d
	$(DMD) -c $(DFLAGS) internal/cmath2.d

complex.o : internal/complex.c
	$(CC) -c $(CFLAGS) internal/complex.c

critical.o : internal/critical.c
	$(CC) -c $(CFLAGS) internal/critical.c

#deh.o : internal/mars.h internal/deh.cA
#	$(CC) -c $(CFLAGS) internal/deh.c

deh2.o : internal/deh2.d
	$(DMD) -c $(DFLAGS) -release internal/deh2.d

dmain2.o : internal/dmain2.d
	$(DMD) -c $(DFLAGS) internal/dmain2.d

invariant.o : internal/invariant.d
	$(DMD) -c $(DFLAGS) internal/invariant.d

llmath.o : internal/llmath.d
	$(DMD) -c $(DFLAGS) internal/llmath.d

memset.o : internal/memset.d
	$(DMD) -c $(DFLAGS) internal/memset.d

#minit.o : internal/minit.asm
#	$(CC) -c internal/minit.asm

monitor.o : internal/mars.h internal/monitor.c
	$(CC) -c $(CFLAGS) internal/monitor.c

obj.o : internal/obj.d
	$(DMD) -c $(DFLAGS) internal/obj.d

qsort.o : internal/qsort.d
	$(DMD) -c $(DFLAGS) internal/qsort.d

switch.o : internal/switch.d
	$(DMD) -c $(DFLAGS) internal/switch.d

### std

array.o : std/array.d
	$(DMD) -c $(DFLAGS) std/array.d

assert.o : std/assert.d
	$(DMD) -c $(DFLAGS) std/assert.d

compiler.o : std/compiler.d
	$(DMD) -c $(DFLAGS) std/compiler.d

conv.o : std/conv.d
	$(DMD) -c $(DFLAGS) std/conv.d

ctype.o : std/ctype.d
	$(DMD) -c $(DFLAGS) std/ctype.d

date.o : std/dateparse.d std/date.d
	$(DMD) -c $(DFLAGS) std/date.d

dateparse.o : std/dateparse.d std/date.d
	$(DMD) -c $(DFLAGS) std/dateparse.d

file.o : std/file.d
	$(DMD) -c $(DFLAGS) std/file.d

gc.o : std/gc.d
	$(DMD) -c $(DFLAGS) std/gc.d

math.o : std/math.d
	$(DMD) -c $(DFLAGS) std/math.d

math2.o : std/math2.d
	$(DMD) -c $(DFLAGS) std/math2.d

moduleinit.o : std/moduleinit.d
	$(DMD) -c $(DFLAGS) std/moduleinit.d

object.o : object.d
	$(DMD) -c $(DFLAGS) object.d

outbuffer.o : std/outbuffer.d
	$(DMD) -c $(DFLAGS) std/outbuffer.d

outofmemory.o : std/outofmemory.d
	$(DMD) -c $(DFLAGS) std/outofmemory.d

path.o : std/path.d
	$(DMD) -c $(DFLAGS) std/path.d

random.o : std/random.d
	$(DMD) -c $(DFLAGS) std/random.d

regexp.o : std/regexp.d
	$(DMD) -c $(DFLAGS) std/regexp.d

stream.o : std/stream.d
	$(DMD) -c $(DFLAGS) std/stream.d

string.o : std/string.d
	$(DMD) -c $(DFLAGS) std/string.d

switcherr.o : std/switcherr.d
	$(DMD) -c $(DFLAGS) std/switcherr.d

system.o : std/system.d
	$(DMD) -c $(DFLAGS) std/system.d

thread.o : std/thread.d
	$(DMD) -c $(DFLAGS) std/thread.d

uri.o : std/uri.d
	$(DMD) -c $(DFLAGS) std/uri.d

utf.o : std/utf.d
	$(DMD) -c $(DFLAGS) std/utf.d

Dzlib.o : std/zlib.d
	$(DMD) -c $(DFLAGS) std/zlib.d -ofDzlib.o

zip.o : std/zip.d
	$(DMD) -c $(DFLAGS) std/zip.d

### std/c/linux

linux.o : std/c/linux/linux.d
	$(DMD) -c $(DFLAGS) std/c/linux/linux.d

### etc/c

Czlib.o : etc/c/zlib.d
	$(DMD) -c $(DFLAGS) etc/c/zlib.d -ofCzlib.o

### std/typeinfo

ti_wchar.o : std/typeinfo/ti_wchar.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_wchar.d

ti_dchar.o : std/typeinfo/ti_dchar.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_dchar.d

ti_uint.o : std/typeinfo/ti_uint.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_uint.d

ti_short.o : std/typeinfo/ti_short.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_short.d

ti_ushort.o : std/typeinfo/ti_ushort.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_ushort.d

ti_byte.o : std/typeinfo/ti_byte.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_byte.d

ti_ubyte.o : std/typeinfo/ti_ubyte.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_ubyte.d

ti_long.o : std/typeinfo/ti_long.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_long.d

ti_ulong.o : std/typeinfo/ti_ulong.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_ulong.d

ti_ptr.o : std/typeinfo/ti_ptr.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_ptr.d

ti_float.o : std/typeinfo/ti_float.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_float.d

ti_double.o : std/typeinfo/ti_double.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_double.d

ti_real.o : std/typeinfo/ti_real.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_real.d

ti_delegate.o : std/typeinfo/ti_delegate.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_delegate.d

ti_creal.o : std/typeinfo/ti_creal.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_creal.d

ti_ireal.o : std/typeinfo/ti_ireal.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_ireal.d

ti_cfloat.o : std/typeinfo/ti_cfloat.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_cfloat.d

ti_ifloat.o : std/typeinfo/ti_ifloat.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_ifloat.d

ti_cdouble.o : std/typeinfo/ti_cdouble.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_cdouble.d

ti_idouble.o : std/typeinfo/ti_idouble.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_idouble.d

ti_Aa.o : std/typeinfo/ti_Aa.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Aa.d

ti_AC.o : std/typeinfo/ti_AC.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_AC.d

ti_Ag.o : std/typeinfo/ti_Ag.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Ag.d

ti_Aubyte.o : std/typeinfo/ti_Aubyte.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Aubyte.d

ti_Aushort.o : std/typeinfo/ti_Aushort.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Aushort.d

ti_Ashort.o : std/typeinfo/ti_Ashort.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Ashort.d

ti_Auint.o : std/typeinfo/ti_Auint.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Auint.d

ti_Aint.o : std/typeinfo/ti_Aint.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Aint.d

ti_Aulong.o : std/typeinfo/ti_Aulong.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Aulong.d

ti_Along.o : std/typeinfo/ti_Along.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Along.d

ti_Awchar.o : std/typeinfo/ti_Awchar.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Awchar.d

ti_Adchar.o : std/typeinfo/ti_Adchar.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Adchar.d

ti_C.o : std/typeinfo/ti_C.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_C.d

ti_char.o : std/typeinfo/ti_char.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_char.d

ti_int.o : std/typeinfo/ti_int.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_int.d


##########################################################333

zip : $(ALLSRCS)
	rm phobos.zip
	zip phobos $(ALLSRCS)

clean:
	rm $(OBJS)
