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

OBJS= asserterror.o deh2.o switch.o complex.o gcstats.o \
	critical.o object.o monitor.o arraycat.o invariant.o \
	dmain2.o outofmemory.o aaA.o adi.o file.o \
	compiler.o system.o moduleinit.o md5.o \
	cast.o path.o string.o memset.o math.o \
	outbuffer.o ctype.o regexp.o random.o linux.o \
	stream.o switcherr.o array.o gc.o \
	qsort.o thread.o obj.o utf.o uri.o \
	crc32.o conv.o arraycast.o errno.o alloca.o cmath2.o \
	process.o syserror.o \
	ti_wchar.o ti_uint.o ti_short.o ti_ushort.o \
	ti_byte.o ti_ubyte.o ti_long.o ti_ulong.o ti_ptr.o \
	ti_float.o ti_double.o ti_real.o ti_delegate.o \
	ti_creal.o ti_ireal.o ti_cfloat.o ti_ifloat.o \
	ti_cdouble.o ti_idouble.o \
	ti_Aa.o ti_AC.o ti_Ag.o ti_Aubyte.o ti_Aushort.o ti_Ashort.o \
	ti_C.o ti_int.o ti_char.o ti_dchar.o ti_Adchar.o \
	ti_Aint.o ti_Auint.o ti_Along.o ti_Aulong.o ti_Awchar.o \
	date.o dateparse.o llmath.o math2.o Czlib.o Dzlib.o zip.o recls.o

ZLIB_OBJS= etc/c/zlib/adler32.o etc/c/zlib/compress.o \
	etc/c/zlib/crc32.o etc/c/zlib/gzio.o \
	etc/c/zlib/uncompr.o etc/c/zlib/deflate.o \
	etc/c/zlib/trees.o etc/c/zlib/zutil.o \
	etc/c/zlib/inflate.o etc/c/zlib/infblock.o \
	etc/c/zlib/inftrees.o etc/c/zlib/infcodes.o \
	etc/c/zlib/infutil.o etc/c/zlib/inffast.o

RECLS_OBJS=

GC_OBJS= internal/gc/gc.o internal/gc/gcx.o \
	internal/gc/gcbits.o internal/gc/gclinux.o

SRC=	errno.c object.d unittest.d crc32.d gcstats.d

SRC_STD= std/zlib.d std/zip.d std/stdint.d std/conv.d std/utf.d std/uri.d \
	std/gc.d std/math.d std/string.d std/path.d std/date.d \
	std/ctype.d std/file.d std/compiler.d std/system.d std/moduleinit.d \
	std/outbuffer.d std/math2.d std/thread.d std/md5.d \
	std/asserterror.d std/dateparse.d std/outofmemory.d \
	std/intrinsic.d std/array.d std/switcherr.d std/syserror.d \
	std/regexp.d std/random.d std/stream.d std/process.d std/recls.d

SRC_STD_C= std/c/process.d std/c/stdlib.d std/c/time.d std/c/stdio.d std/c/math.d

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
	std/typeinfo/ti_Adchar.d std/typeinfo/ti_Aubyte.d \
	std/typeinfo/ti_Aushort.d std/typeinfo/ti_Ashort.d \
	std/typeinfo/ti_Aa.d std/typeinfo/ti_Ag.d \
	std/typeinfo/ti_AC.d std/typeinfo/ti_C.d \
	std/typeinfo/ti_int.d std/typeinfo/ti_char.d \
	std/typeinfo/ti_Aint.d std/typeinfo/ti_Auint.d \
	std/typeinfo/ti_Along.d std/typeinfo/ti_Aulong.d \
	std/typeinfo/ti_Awchar.d std/typeinfo/ti_dchar.d

SRC_INT=	\
	internal/switch.d internal/complex.c internal/critical.c \
	internal/minit.asm internal/alloca.d internal/llmath.d internal/deh.c \
	internal/arraycat.d internal/invariant.d internal/monitor.c \
	internal/memset.d internal/arraycast.d internal/aaA.d internal/adi.d \
	internal/dmain2.d internal/cast.d internal/qsort.d internal/deh2.d \
	internal/cmath2.d internal/obj.d internal/mars.h

SRC_STD_WIN= std/windows/registry.d \
	std/windows/iunknown.d

SRC_STD_C_WIN= std/c/windows/windows.d std/c/windows/com.d

SRC_STD_C_LINUX= std/c/linux/linux.d std/c/linux/linuxextern.d

SRC_ETC= etc/c/zlib.d

SRC_ZLIB= etc/c/zlib/algorithm.txt \
	etc/c/zlib/trees.h \
	etc/c/zlib/inffixed.h \
	etc/c/zlib/INDEX \
	etc/c/zlib/zconf.h \
	etc/c/zlib/compress.c \
	etc/c/zlib/adler32.c \
	etc/c/zlib/uncompr.c \
	etc/c/zlib/deflate.h \
	etc/c/zlib/example.c \
	etc/c/zlib/zutil.c \
	etc/c/zlib/gzio.c \
	etc/c/zlib/crc32.c \
	etc/c/zlib/infblock.c \
	etc/c/zlib/infblock.h \
	etc/c/zlib/infcodes.c \
	etc/c/zlib/infcodes.h \
	etc/c/zlib/inffast.c \
	etc/c/zlib/inffast.h \
	etc/c/zlib/zutil.h \
	etc/c/zlib/inflate.c \
	etc/c/zlib/trees.c \
	etc/c/zlib/inftrees.h \
	etc/c/zlib/infutil.c \
	etc/c/zlib/infutil.h \
	etc/c/zlib/minigzip.c \
	etc/c/zlib/inftrees.c \
	etc/c/zlib/zlib.html \
	etc/c/zlib/maketree.c \
	etc/c/zlib/zlib.h \
	etc/c/zlib/zlib.3 \
	etc/c/zlib/FAQ \
	etc/c/zlib/deflate.c \
	etc/c/zlib/ChangeLog \
	etc/c/zlib/win32.mak \
	etc/c/zlib/linux.mak \
	etc/c/zlib/zlib.lib \
	etc/c/zlib/README

SRC_GC= internal/gc/gc.d \
	internal/gc/gcx.d \
	internal/gc/gcbits.d \
	internal/gc/win32.d \
	internal/gc/gclinux.d \
	internal/gc/testgc.d \
	internal/gc/win32.mak \
	internal/gc/linux.mak

SRC_STLSOFT= \
	etc/c/stlsoft/stlsoft_null_mutex.h \
	etc/c/stlsoft/unixstl_string_access.h \
	etc/c/stlsoft/unixstl.h \
	etc/c/stlsoft/winstl_tls_index.h \
	etc/c/stlsoft/unixstl_environment_variable.h \
	etc/c/stlsoft/unixstl_functionals.h \
	etc/c/stlsoft/unixstl_current_directory.h \
	etc/c/stlsoft/unixstl_limits.h \
	etc/c/stlsoft/unixstl_current_directory_scope.h \
	etc/c/stlsoft/unixstl_filesystem_traits.h \
	etc/c/stlsoft/unixstl_findfile_sequence.h \
	etc/c/stlsoft/unixstl_glob_sequence.h \
	etc/c/stlsoft/winstl.h \
	etc/c/stlsoft/winstl_atomic_functions.h \
	etc/c/stlsoft/stlsoft_cccap_gcc.h \
	etc/c/stlsoft/stlsoft_lock_scope.h \
	etc/c/stlsoft/unixstl_thread_mutex.h \
	etc/c/stlsoft/unixstl_spin_mutex.h \
	etc/c/stlsoft/unixstl_process_mutex.h \
	etc/c/stlsoft/stlsoft_null.h \
	etc/c/stlsoft/stlsoft_nulldef.h \
	etc/c/stlsoft/winstl_thread_mutex.h \
	etc/c/stlsoft/winstl_spin_mutex.h \
	etc/c/stlsoft/winstl_system_version.h \
	etc/c/stlsoft/winstl_findfile_sequence.h \
	etc/c/stlsoft/unixstl_readdir_sequence.h \
	etc/c/stlsoft/stlsoft.h \
	etc/c/stlsoft/stlsoft_static_initialisers.h \
	etc/c/stlsoft/stlsoft_iterator.h \
	etc/c/stlsoft/stlsoft_cccap_dmc.h \
	etc/c/stlsoft/winstl_filesystem_traits.h

SRC_RECLS= \
	etc/c/recls/recls_compiler.h \
	etc/c/recls/recls_language.h \
	etc/c/recls/recls_unix.h \
	etc/c/recls/recls_retcodes.h \
	etc/c/recls/recls_assert.h \
	etc/c/recls/recls_platform.h \
	etc/c/recls/recls_win32.h \
	etc/c/recls/recls.h \
	etc/c/recls/recls_util.h \
	etc/c/recls/recls_compiler_dmc.h \
	etc/c/recls/recls_compiler_gcc.h \
	etc/c/recls/recls_platform_types.h \
	etc/c/recls/recls_internal.h \
	etc/c/recls/recls_debug.h \
	etc/c/recls/recls_fileinfo_win32.cpp \
	etc/c/recls/recls_api_unix.cpp \
	etc/c/recls/recls_api.cpp \
	etc/c/recls/recls_util_win32.cpp \
	etc/c/recls/recls_util_unix.cpp \
	etc/c/recls/recls_util.cpp \
	etc/c/recls/recls_internal.cpp \
	etc/c/recls/recls_fileinfo.cpp \
	etc/c/recls/recls_defs.h \
	etc/c/recls/recls_fileinfo_unix.cpp \
	etc/c/recls/recls_api_win32.cpp \
	etc/c/recls/win32.mak \
	etc/c/recls/linux.mak \
	etc/c/recls/recls.lib

ALLSRCS = $(SRC) $(SRC_STD) $(SRC_STD_C) $(SRC_TI) $(SRC_INT) $(SRC_STD_WIN) \
	$(SRC_STD_C_WIN) $(SRC_STD_C_LINUX) $(SRC_ETC) $(SRC_ZLIB) $(SRC_GC) \
	$(SRC_RECLS) $(SRC_STLSOFT)


libphobos.a : $(OBJS) internal/gc/dmgc.a linux.mak
	ar -r $@ $(OBJS) $(ZLIB_OBJS) $(GC_OBJS) $(RECLS_OBJS)

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

asserterror.o : std/asserterror.d
	$(DMD) -c $(DFLAGS) std/asserterror.d

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

md5.o : std/md5.d
	$(DMD) -c $(DFLAGS) std/md5.d

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

process.o : std/process.d
	$(DMD) -c $(DFLAGS) std/process.d

random.o : std/random.d
	$(DMD) -c $(DFLAGS) std/random.d

recls.o : std/recls.d
	$(DMD) -c $(DFLAGS) std/recls.d

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

syserror.o : std/syserror.d
	$(DMD) -c $(DFLAGS) std/syserror.d

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

zip : $(ALLSRCS) linux.mak win32.mak
	rm phobos.zip
	zip phobos $(ALLSRCS) linux.mak win32.mak

clean:
	rm $(OBJS)
