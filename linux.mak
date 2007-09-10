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

CFLAGS=-O -m32
#CFLAGS=-g -m32

DFLAGS=-O -release -w
#DFLAGS=-unittest -w

CC=gcc
#DMD=/dmd/bin/dmd
DMD=dmd

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
	$(CC) -o $@ test.o libphobos.a -lpthread -lm -g

unittest : unittest.o libphobos.a
	$(CC) -o $@ unittest.o libphobos.a -lpthread -lm -g

unittest.o : unittest.d
	$(DMD) -c unittest

OBJS = asserterror.o deh2.o switch.o complex.o gcstats.o \
	critical.o object.o monitor.o arraycat.o invariant.o \
	dmain2.o outofmemory.o aaA.o adi.o aApply.o file.o \
	compiler.o system.o moduleinit.o md5.o base64.o \
	cast.o path.o string.o memset.o math.o mmfile.o \
	outbuffer.o ctype.o regexp.o random.o linux.o linuxsocket.o \
	stream.o cstream.o switcherr.o array.o gc.o \
	qsort.o thread.o obj.o utf.o uri.o \
	Dcrc32.o conv.o arraycast.o errno.o alloca.o cmath2.o \
	process.o syserror.o metastrings.o \
	socket.o socketstream.o stdarg.o stdio.o format.o \
	perf.o openrj.o uni.o trace.o boxer.o \
	demangle.o cover.o bitarray.o bind.o aApplyR.o \
	signals.o cpuid.o traits.o typetuple.o \
	ti_wchar.o ti_uint.o ti_short.o ti_ushort.o \
	ti_byte.o ti_ubyte.o ti_long.o ti_ulong.o ti_ptr.o \
	ti_float.o ti_double.o ti_real.o ti_delegate.o \
	ti_creal.o ti_ireal.o ti_cfloat.o ti_ifloat.o \
	ti_cdouble.o ti_idouble.o \
	ti_AC.o ti_Ag.o ti_Ashort.o \
	ti_C.o ti_int.o ti_char.o ti_dchar.o \
	ti_Aint.o ti_Along.o \
	ti_Afloat.o ti_Adouble.o ti_Areal.o \
	ti_Acfloat.o ti_Acdouble.o ti_Acreal.o \
	ti_void.o \
	date.o dateparse.o llmath.o math2.o Czlib.o Dzlib.o zip.o

ZLIB_OBJS = etc/c/zlib/adler32.o etc/c/zlib/compress.o \
	etc/c/zlib/crc32.o etc/c/zlib/gzio.o \
	etc/c/zlib/uncompr.o etc/c/zlib/deflate.o \
	etc/c/zlib/trees.o etc/c/zlib/zutil.o \
	etc/c/zlib/inflate.o etc/c/zlib/infback.o \
	etc/c/zlib/inftrees.o etc/c/zlib/inffast.o

GC_OBJS= internal/gc/gc.o internal/gc/gcold.o internal/gc/gcx.o \
	internal/gc/gcbits.o internal/gc/gclinux.o

SRC=	errno.c object.d unittest.d crc32.d gcstats.d

SRC_STD= std/zlib.d std/zip.d std/stdint.d std/conv.d std/utf.d std/uri.d \
	std/gc.d std/math.d std/string.d std/path.d std/date.d \
	std/ctype.d std/file.d std/compiler.d std/system.d std/moduleinit.d \
	std/outbuffer.d std/math2.d std/thread.d std/md5.d std/base64.d \
	std/asserterror.d std/dateparse.d std/outofmemory.d std/mmfile.d \
	std/intrinsic.d std/array.d std/switcherr.d std/syserror.d \
	std/regexp.d std/random.d std/stream.d std/process.d \
	std/socket.d std/socketstream.d std/loader.d std/stdarg.d \
	std/stdio.d std/format.d std/perf.d std/openrj.d std/uni.d \
	std/boxer.d std/cstream.d std/demangle.d std/cover.d std/bitarray.d \
	std/signals.d std/cpuid.d std/typetuple.d std/traits.d std/bind.d \
	std/metastrings.d

SRC_STD_C= std/c/process.d std/c/stdlib.d std/c/time.d std/c/stdio.d \
	std/c/math.d std/c/stdarg.d std/c/stddef.d std/c/fenv.d std/c/string.d \
	std/d/locale.d

SRC_TI=	\
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
	std/typeinfo/ti_Adchar.d \
	std/typeinfo/ti_Ashort.d \
	std/typeinfo/ti_Ag.d \
	std/typeinfo/ti_AC.d std/typeinfo/ti_C.d \
	std/typeinfo/ti_int.d std/typeinfo/ti_char.d \
	std/typeinfo/ti_Aint.d \
	std/typeinfo/ti_Along.d \
	std/typeinfo/ti_Afloat.d std/typeinfo/ti_Adouble.d \
	std/typeinfo/ti_Areal.d \
	std/typeinfo/ti_Acfloat.d std/typeinfo/ti_Acdouble.d \
	std/typeinfo/ti_Acreal.d \
	std/typeinfo/ti_void.d

SRC_INT=	\
	internal/switch.d internal/complex.c internal/critical.c \
	internal/minit.asm internal/alloca.d internal/llmath.d internal/deh.c \
	internal/arraycat.d internal/invariant.d internal/monitor.c \
	internal/memset.d internal/arraycast.d internal/aaA.d internal/adi.d \
	internal/dmain2.d internal/cast.d internal/qsort.d internal/deh2.d \
	internal/cmath2.d internal/obj.d internal/mars.h internal/aApply.d \
	internal/aApplyR.d internal/object.d internal/trace.d internal/qsort2.d

SRC_STD_WIN= std/windows/registry.d \
	std/windows/iunknown.d std/windows/charset.d

SRC_STD_C_WIN= std/c/windows/windows.d std/c/windows/com.d \
	std/c/windows/winsock.d std/c/windows/stat.d

SRC_STD_C_LINUX= std/c/linux/linux.d std/c/linux/linuxextern.d \
	std/c/linux/socket.d std/c/linux/pthread.d

SRC_ETC=  etc/gamma.d

SRC_ETC_C= etc/c/zlib.d

SRC_ZLIB= etc/c/zlib\trees.h \
	etc/c/zlib\inffixed.h \
	etc/c/zlib\inffast.h \
	etc/c/zlib\crc32.h \
	etc/c/zlib\algorithm.txt \
	etc/c/zlib\uncompr.c \
	etc/c/zlib\compress.c \
	etc/c/zlib\deflate.h \
	etc/c/zlib\inftrees.h \
	etc/c/zlib\infback.c \
	etc/c/zlib\zutil.c \
	etc/c/zlib\crc32.c \
	etc/c/zlib\inflate.h \
	etc/c/zlib\example.c \
	etc/c/zlib\inffast.c \
	etc/c/zlib\trees.c \
	etc/c/zlib\inflate.c \
	etc/c/zlib\gzio.c \
	etc/c/zlib\zconf.h \
	etc/c/zlib\zconf.in.h \
	etc/c/zlib\minigzip.c \
	etc/c/zlib\deflate.c \
	etc/c/zlib\inftrees.c \
	etc/c/zlib\zutil.h \
	etc/c/zlib\zlib.3 \
	etc/c/zlib\zlib.h \
	etc/c/zlib\adler32.c \
	etc/c/zlib\ChangeLog \
	etc/c/zlib\README \
	etc/c/zlib\win32.mak \
	etc/c/zlib\linux.mak

SRC_GC= internal/gc/gc.d \
	internal/gc/gcold.d \
	internal/gc/gcx.d \
	internal/gc/gcstub.d \
	internal/gc/gcbits.d \
	internal/gc/win32.d \
	internal/gc/gclinux.d \
	internal/gc/testgc.d \
	internal/gc/win32.mak \
	internal/gc/linux.mak

ALLSRCS = $(SRC) $(SRC_STD) $(SRC_STD_C) $(SRC_TI) $(SRC_INT) $(SRC_STD_WIN) \
	$(SRC_STD_C_WIN) $(SRC_STD_C_LINUX) $(SRC_ETC) $(SRC_ETC_C) \
	$(SRC_ZLIB) $(SRC_GC)


#libphobos.a : $(OBJS) internal/gc/dmgc.a linux.mak
libphobos.a : $(OBJS) internal/gc/dmgc.a $(ZLIB_OBJS) linux.mak
	rm -f libphobos.a
	ar -r $@ $(OBJS) $(ZLIB_OBJS) $(GC_OBJS)

###########################################################

internal/gc/dmgc.a:
#	cd internal/gc
#	make -f linux.mak dmgc.a
#	cd ../..
	make -C ./internal/gc -f linux.mak dmgc.a

$(ZLIB_OBJS):
#	cd etc/c/zlib
#	make -f linux.mak
#	cd ../../..
	make -C ./etc/c/zlib -f linux.mak

###

Dcrc32.o : crc32.d
	$(DMD) -c $(DFLAGS) crc32.d -ofDcrc32.o

errno.o : errno.c

gcstats.o : gcstats.d
	$(DMD) -c $(DFLAGS) gcstats.d

### internal

aaA.o : internal/aaA.d
	$(DMD) -c $(DFLAGS) internal/aaA.d

aApply.o : internal/aApply.d
	$(DMD) -c $(DFLAGS) internal/aApply.d

aApplyR.o : internal/aApplyR.d
	$(DMD) -c $(DFLAGS) internal/aApplyR.d

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

object.o : internal/object.d
	$(DMD) -c $(DFLAGS) internal/object.d

qsort.o : internal/qsort.d
	$(DMD) -c $(DFLAGS) internal/qsort.d

switch.o : internal/switch.d
	$(DMD) -c $(DFLAGS) internal/switch.d

trace.o : internal/trace.d
	$(DMD) -c $(DFLAGS) internal/trace.d

### std

array.o : std/array.d
	$(DMD) -c $(DFLAGS) std/array.d

asserterror.o : std/asserterror.d
	$(DMD) -c $(DFLAGS) std/asserterror.d

base64.o : std/base64.d
	$(DMD) -c $(DFLAGS) std/base64.d

bind.o : std/bind.d
	$(DMD) -c $(DFLAGS) std/bind.d

bitarray.o : std/bitarray.d
	$(DMD) -c $(DFLAGS) std/bitarray.d

boxer.o : std/boxer.d
	$(DMD) -c $(DFLAGS) std/boxer.d

compiler.o : std/compiler.d
	$(DMD) -c $(DFLAGS) std/compiler.d

conv.o : std/conv.d
	$(DMD) -c $(DFLAGS) std/conv.d

cover.o : std/cover.d
	$(DMD) -c $(DFLAGS) std/cover.d

cpuid.o : std/cpuid.d
	$(DMD) -c $(DFLAGS) std/cpuid.d

cstream.o : std/cstream.d
	$(DMD) -c $(DFLAGS) std/cstream.d

ctype.o : std/ctype.d
	$(DMD) -c $(DFLAGS) std/ctype.d

date.o : std/dateparse.d std/date.d
	$(DMD) -c $(DFLAGS) std/date.d

dateparse.o : std/dateparse.d std/date.d
	$(DMD) -c $(DFLAGS) std/dateparse.d

demangle.o : std/demangle.d
	$(DMD) -c $(DFLAGS) std/demangle.d

file.o : std/file.d
	$(DMD) -c $(DFLAGS) std/file.d

format.o : std/format.d
	$(DMD) -c $(DFLAGS) std/format.d

gc.o : std/gc.d
	$(DMD) -c $(DFLAGS) std/gc.d

math.o : std/math.d
	$(DMD) -c $(DFLAGS) std/math.d

math2.o : std/math2.d
	$(DMD) -c $(DFLAGS) std/math2.d

md5.o : std/md5.d
	$(DMD) -c $(DFLAGS) std/md5.d

metastrings.o : std/metastrings.d
	$(DMD) -c $(DFLAGS) std/metastrings.d

mmfile.o : std/mmfile.d
	$(DMD) -c $(DFLAGS) std/mmfile.d

moduleinit.o : std/moduleinit.d
	$(DMD) -c $(DFLAGS) std/moduleinit.d

openrj.o : std/openrj.d
	$(DMD) -c $(DFLAGS) std/openrj.d

outbuffer.o : std/outbuffer.d
	$(DMD) -c $(DFLAGS) std/outbuffer.d

outofmemory.o : std/outofmemory.d
	$(DMD) -c $(DFLAGS) std/outofmemory.d

path.o : std/path.d
	$(DMD) -c $(DFLAGS) std/path.d

perf.o : std/perf.d
	$(DMD) -c $(DFLAGS) std/perf.d

process.o : std/process.d
	$(DMD) -c $(DFLAGS) std/process.d

random.o : std/random.d
	$(DMD) -c $(DFLAGS) std/random.d

regexp.o : std/regexp.d
	$(DMD) -c $(DFLAGS) std/regexp.d

signals.o : std/signals.d
	$(DMD) -c $(DFLAGS) std/signals.d

socket.o : std/socket.d
	$(DMD) -c $(DFLAGS) std/socket.d

socketstream.o : std/socketstream.d
	$(DMD) -c $(DFLAGS) std/socketstream.d

stdio.o : std/stdio.d
	$(DMD) -c $(DFLAGS) std/stdio.d

stream.o : std/stream.d
	$(DMD) -c $(DFLAGS) -d std/stream.d

string.o : std/string.d
	$(DMD) -c $(DFLAGS) std/string.d

switcherr.o : std/switcherr.d
	$(DMD) -c $(DFLAGS) std/switcherr.d

system.o : std/system.d
	$(DMD) -c $(DFLAGS) std/system.d

syserror.o : std/syserror.d
	$(DMD) -c $(DFLAGS) std/syserror.d

thread.o : std/thread.d
	$(DMD) -c $(DFLAGS) std/thread.d

traits.o : std/traits.d
	$(DMD) -c $(DFLAGS) std/traits.d

typetuple.o : std/typetuple.d
	$(DMD) -c $(DFLAGS) std/typetuple.d

uri.o : std/uri.d
	$(DMD) -c $(DFLAGS) std/uri.d

uni.o : std/uni.d
	$(DMD) -c $(DFLAGS) std/uni.d

utf.o : std/utf.d
	$(DMD) -c $(DFLAGS) std/utf.d

Dzlib.o : std/zlib.d
	$(DMD) -c $(DFLAGS) std/zlib.d -ofDzlib.o

zip.o : std/zip.d
	$(DMD) -c $(DFLAGS) std/zip.d

### std/c

stdarg.o : std/c/stdarg.d
	$(DMD) -c $(DFLAGS) std/c/stdarg.d

### std/c/linux

linux.o : std/c/linux/linux.d
	$(DMD) -c $(DFLAGS) std/c/linux/linux.d

linuxsocket.o : std/c/linux/socket.d
	$(DMD) -c $(DFLAGS) std/c/linux/socket.d -oflinuxsocket.o

### etc

### etc/c

Czlib.o : etc/c/zlib.d
	$(DMD) -c $(DFLAGS) etc/c/zlib.d -ofCzlib.o

### std/typeinfo

ti_void.o : std/typeinfo/ti_void.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_void.d

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

ti_AC.o : std/typeinfo/ti_AC.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_AC.d

ti_Ag.o : std/typeinfo/ti_Ag.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Ag.d

ti_Abit.o : std/typeinfo/ti_Abit.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Abit.d

ti_Ashort.o : std/typeinfo/ti_Ashort.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Ashort.d

ti_Aint.o : std/typeinfo/ti_Aint.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Aint.d

ti_Along.o : std/typeinfo/ti_Along.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Along.d

ti_Afloat.o : std/typeinfo/ti_Afloat.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Afloat.d

ti_Adouble.o : std/typeinfo/ti_Adouble.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Adouble.d

ti_Areal.o : std/typeinfo/ti_Areal.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Areal.d

ti_Acfloat.o : std/typeinfo/ti_Acfloat.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Acfloat.d

ti_Acdouble.o : std/typeinfo/ti_Acdouble.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Acdouble.d

ti_Acreal.o : std/typeinfo/ti_Acreal.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_Acreal.d

ti_C.o : std/typeinfo/ti_C.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_C.d

ti_char.o : std/typeinfo/ti_char.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_char.d

ti_int.o : std/typeinfo/ti_int.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_int.d

ti_bit.o : std/typeinfo/ti_bit.d
	$(DMD) -c $(DFLAGS) std/typeinfo/ti_bit.d


##########################################################333

zip : $(ALLSRCS) linux.mak win32.mak phoboslicense.txt
	$(RM) phobos.zip
	zip phobos $(ALLSRCS) linux.mak win32.mak phoboslicense.txt

clean:
	$(RM) libphobos.a $(OBJS) unittest unittest.o
