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

CP=cp

CFLAGS=-g -mn -6 -r
DFLAGS=-O -release
#DFLAGS=-unittest -g

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

OBJS= asserterror.obj deh.obj switch.obj complex.obj gcstats.obj \
	critical.obj object.obj monitor.obj arraycat.obj invariant.obj \
	dmain2.obj outofmemory.obj aaA.obj adi.obj aApply.obj file.obj \
	compiler.obj system.obj moduleinit.obj md5.obj base64.obj \
	cast.obj syserror.obj path.obj string.obj memset.obj math.obj \
	outbuffer.obj ctype.obj regexp.obj random.obj windows.obj \
	stream.obj switcherr.obj com.obj array.obj gc.obj mmfile.obj \
	qsort.obj math2.obj date.obj dateparse.obj thread.obj obj.obj \
	iunknown.obj crc32.obj conv.obj arraycast.obj utf.obj uri.obj \
	Czlib.obj Dzlib.obj zip.obj process.obj registry.obj recls.obj \
	ti_Aa.obj ti_Ag.obj ti_C.obj ti_int.obj ti_char.obj \
	ti_wchar.obj ti_uint.obj ti_short.obj ti_ushort.obj \
	ti_byte.obj ti_ubyte.obj ti_long.obj ti_ulong.obj ti_ptr.obj \
	ti_float.obj ti_double.obj ti_real.obj ti_delegate.obj \
	ti_creal.obj ti_ireal.obj \
	ti_cfloat.obj ti_ifloat.obj \
	ti_cdouble.obj ti_idouble.obj \
	ti_AC.obj ti_Aubyte.obj ti_Aushort.obj ti_Ashort.obj \
	ti_Aint.obj ti_Auint.obj ti_Along.obj ti_Aulong.obj ti_Awchar.obj \
	ti_dchar.obj ti_Adchar.obj


SRC=	errno.c object.d unittest.d crc32.d gcstats.d

SRC_STD= std\zlib.d std\zip.d std\stdint.d std\conv.d std\utf.d std\uri.d \
	std\gc.d std\math.d std\string.d std\path.d std\date.d \
	std\ctype.d std\file.d std\compiler.d std\system.d std\moduleinit.d \
	std\outbuffer.d std\math2.d std\thread.d std\md5.d std\base64.d \
	std\asserterror.d std\dateparse.d std\outofmemory.d std\mmfile.d \
	std\intrinsic.d std\array.d std\switcherr.d std\syserror.d \
	std\regexp.d std\random.d std\stream.d std\process.d std\recls.d

SRC_STD_C= std\c\process.d std\c\stdlib.d std\c\time.d std\c\stdio.d std\c\math.d

SRC_TI=	\
	std\typeinfo\ti_wchar.d std\typeinfo\ti_uint.d \
	std\typeinfo\ti_short.d std\typeinfo\ti_ushort.d \
	std\typeinfo\ti_byte.d std\typeinfo\ti_ubyte.d \
	std\typeinfo\ti_long.d std\typeinfo\ti_ulong.d \
	std\typeinfo\ti_ptr.d \
	std\typeinfo\ti_float.d std\typeinfo\ti_double.d \
	std\typeinfo\ti_real.d std\typeinfo\ti_delegate.d \
	std\typeinfo\ti_creal.d std\typeinfo\ti_ireal.d \
	std\typeinfo\ti_cfloat.d std\typeinfo\ti_ifloat.d \
	std\typeinfo\ti_cdouble.d std\typeinfo\ti_idouble.d \
	std\typeinfo\ti_Adchar.d std\typeinfo\ti_Aubyte.d \
	std\typeinfo\ti_Aushort.d std\typeinfo\ti_Ashort.d \
	std\typeinfo\ti_Aa.d std\typeinfo\ti_Ag.d \
	std\typeinfo\ti_AC.d std\typeinfo\ti_C.d \
	std\typeinfo\ti_int.d std\typeinfo\ti_char.d \
	std\typeinfo\ti_Aint.d std\typeinfo\ti_Auint.d \
	std\typeinfo\ti_Along.d std\typeinfo\ti_Aulong.d \
	std\typeinfo\ti_Awchar.d std\typeinfo\ti_dchar.d

SRC_INT=	\
	internal\switch.d internal\complex.c internal\critical.c \
	internal\minit.asm internal\alloca.d internal\llmath.d internal\deh.c \
	internal\arraycat.d internal\invariant.d internal\monitor.c \
	internal\memset.d internal\arraycast.d internal\aaA.d internal\adi.d \
	internal\dmain2.d internal\cast.d internal\qsort.d internal\deh2.d \
	internal\cmath2.d internal\obj.d internal\mars.h internal\aApply.d

SRC_STD_WIN= std\windows\registry.d \
	std\windows\iunknown.d

SRC_STD_C_WIN= std\c\windows\windows.d std\c\windows\com.d

SRC_STD_C_LINUX= std\c\linux\linux.d std\c\linux\linuxextern.d

SRC_ETC= etc\c\zlib.d

SRC_ZLIB= etc\c\zlib\algorithm.txt \
	etc\c\zlib\trees.h \
	etc\c\zlib\inffixed.h \
	etc\c\zlib\INDEX \
	etc\c\zlib\zconf.h \
	etc\c\zlib\compress.c \
	etc\c\zlib\adler32.c \
	etc\c\zlib\uncompr.c \
	etc\c\zlib\deflate.h \
	etc\c\zlib\example.c \
	etc\c\zlib\zutil.c \
	etc\c\zlib\gzio.c \
	etc\c\zlib\crc32.c \
	etc\c\zlib\infblock.c \
	etc\c\zlib\infblock.h \
	etc\c\zlib\infcodes.c \
	etc\c\zlib\infcodes.h \
	etc\c\zlib\inffast.c \
	etc\c\zlib\inffast.h \
	etc\c\zlib\zutil.h \
	etc\c\zlib\inflate.c \
	etc\c\zlib\trees.c \
	etc\c\zlib\inftrees.h \
	etc\c\zlib\infutil.c \
	etc\c\zlib\infutil.h \
	etc\c\zlib\minigzip.c \
	etc\c\zlib\inftrees.c \
	etc\c\zlib\zlib.html \
	etc\c\zlib\maketree.c \
	etc\c\zlib\zlib.h \
	etc\c\zlib\zlib.3 \
	etc\c\zlib\FAQ \
	etc\c\zlib\deflate.c \
	etc\c\zlib\ChangeLog \
	etc\c\zlib\win32.mak \
	etc\c\zlib\linux.mak \
	etc\c\zlib\zlib.lib \
	etc\c\zlib\README

SRC_GC= internal\gc\gc.d \
	internal\gc\gcx.d \
	internal\gc\gcbits.d \
	internal\gc\win32.d \
	internal\gc\gclinux.d \
	internal\gc\testgc.d \
	internal\gc\win32.mak \
	internal\gc\linux.mak

SRC_STLSOFT= \
	etc\c\stlsoft\stlsoft_null_mutex.h \
	etc\c\stlsoft\unixstl_string_access.h \
	etc\c\stlsoft\unixstl.h \
	etc\c\stlsoft\winstl_tls_index.h \
	etc\c\stlsoft\unixstl_environment_variable.h \
	etc\c\stlsoft\unixstl_functionals.h \
	etc\c\stlsoft\unixstl_current_directory.h \
	etc\c\stlsoft\unixstl_limits.h \
	etc\c\stlsoft\unixstl_current_directory_scope.h \
	etc\c\stlsoft\unixstl_filesystem_traits.h \
	etc\c\stlsoft\unixstl_findfile_sequence.h \
	etc\c\stlsoft\unixstl_glob_sequence.h \
	etc\c\stlsoft\winstl.h \
	etc\c\stlsoft\winstl_atomic_functions.h \
	etc\c\stlsoft\stlsoft_cccap_gcc.h \
	etc\c\stlsoft\stlsoft_lock_scope.h \
	etc\c\stlsoft\unixstl_thread_mutex.h \
	etc\c\stlsoft\unixstl_spin_mutex.h \
	etc\c\stlsoft\unixstl_process_mutex.h \
	etc\c\stlsoft\stlsoft_null.h \
	etc\c\stlsoft\stlsoft_nulldef.h \
	etc\c\stlsoft\winstl_thread_mutex.h \
	etc\c\stlsoft\winstl_spin_mutex.h \
	etc\c\stlsoft\winstl_system_version.h \
	etc\c\stlsoft\winstl_findfile_sequence.h \
	etc\c\stlsoft\unixstl_readdir_sequence.h \
	etc\c\stlsoft\stlsoft.h \
	etc\c\stlsoft\stlsoft_static_initialisers.h \
	etc\c\stlsoft\stlsoft_iterator.h \
	etc\c\stlsoft\stlsoft_cccap_dmc.h \
	etc\c\stlsoft\winstl_filesystem_traits.h

SRC_RECLS= \
	etc\c\recls\recls_compiler.h \
	etc\c\recls\recls_language.h \
	etc\c\recls\recls_unix.h \
	etc\c\recls\recls_retcodes.h \
	etc\c\recls\recls_assert.h \
	etc\c\recls\recls_platform.h \
	etc\c\recls\recls_win32.h \
	etc\c\recls\recls.h \
	etc\c\recls\recls_util.h \
	etc\c\recls\recls_compiler_dmc.h \
	etc\c\recls\recls_compiler_gcc.h \
	etc\c\recls\recls_platform_types.h \
	etc\c\recls\recls_internal.h \
	etc\c\recls\recls_debug.h \
	etc\c\recls\recls_fileinfo_win32.cpp \
	etc\c\recls\recls_api_unix.cpp \
	etc\c\recls\recls_api.cpp \
	etc\c\recls\recls_util_win32.cpp \
	etc\c\recls\recls_util_unix.cpp \
	etc\c\recls\recls_util.cpp \
	etc\c\recls\recls_internal.cpp \
	etc\c\recls\recls_fileinfo.cpp \
	etc\c\recls\recls_defs.h \
	etc\c\recls\recls_fileinfo_unix.cpp \
	etc\c\recls\recls_api_win32.cpp \
	etc\c\recls\win32.mak \
	etc\c\recls\linux.mak \
	etc\c\recls\recls.lib


phobos.lib : $(OBJS) minit.obj internal\gc\dmgc.lib etc\c\zlib\zlib.lib \
	win32.mak etc\c\recls\recls.lib
	lib -c phobos.lib $(OBJS) minit.obj internal\gc\dmgc.lib \
		etc\c\recls\recls.lib etc\c\zlib\zlib.lib

######################################################

### internal

aaA.obj : internal\aaA.d
	$(DMD) -c $(DFLAGS) internal\aaA.d

aApply.obj : internal\aApply.d
	$(DMD) -c $(DFLAGS) internal\aApply.d

adi.obj : internal\adi.d
	$(DMD) -c $(DFLAGS) internal\adi.d

arraycast.obj : internal\arraycast.d
	$(DMD) -c $(DFLAGS) internal\arraycast.d

arraycat.obj : internal\arraycat.d
	$(DMD) -c $(DFLAGS) internal\arraycat.d

cast.obj : internal\cast.d
	$(DMD) -c $(DFLAGS) internal\cast.d

complex.obj : internal\complex.c
	$(CC) -c $(CFLAGS) internal\complex.c

critical.obj : internal\critical.c
	$(CC) -c $(CFLAGS) internal\critical.c

deh.obj : internal\mars.h internal\deh.c
	$(CC) -c $(CFLAGS) internal\deh.c

dmain2.obj : internal\dmain2.d
	$(DMD) -c $(DFLAGS) internal\dmain2.d

invariant.obj : internal\invariant.d
	$(DMD) -c $(DFLAGS) internal\invariant.d

memset.obj : internal\memset.d
	$(DMD) -c $(DFLAGS) internal\memset.d

minit.obj : internal\minit.asm
	$(CC) -c internal\minit.asm

monitor.obj : internal\mars.h internal\monitor.c
	$(CC) -c $(CFLAGS) internal\monitor.c

obj.obj : internal\obj.d
	$(DMD) -c $(DFLAGS) internal\obj.d

qsort.obj : internal\qsort.d
	$(DMD) -c $(DFLAGS) internal\qsort.d

switch.obj : internal\switch.d
	$(DMD) -c $(DFLAGS) internal\switch.d

### std

array.obj : std\array.d
	$(DMD) -c $(DFLAGS) std\array.d

asserterror.obj : std\asserterror.d
	$(DMD) -c $(DFLAGS) std\asserterror.d

base64.obj : std\base64.d
	$(DMD) -c $(DFLAGS) -inline std\base64.d

compiler.obj : std\compiler.d
	$(DMD) -c $(DFLAGS) std\compiler.d

conv.obj : std\conv.d
	$(DMD) -c $(DFLAGS) std\conv.d

ctype.obj : std\ctype.d
	$(DMD) -c $(DFLAGS) std\ctype.d

date.obj : std\dateparse.d std\date.d
	$(DMD) -c $(DFLAGS) std\date.d

dateparse.obj : std\dateparse.d std\date.d
	$(DMD) -c $(DFLAGS) std\dateparse.d

file.obj : std\file.d
	$(DMD) -c $(DFLAGS) std\file.d

gc.obj : std\gc.d
	$(DMD) -c $(DFLAGS) std\gc.d

math.obj : std\math.d
	$(DMD) -c $(DFLAGS) std\math.d

math2.obj : std\math2.d
	$(DMD) -c $(DFLAGS) std\math2.d

md5.obj : std\md5.d
	$(DMD) -c $(DFLAGS) -inline std\md5.d

mmfile.obj : std\mmfile.d
	$(DMD) -c $(DFLAGS) std\mmfile.d

moduleinit.obj : std\moduleinit.d
	$(DMD) -c $(DFLAGS) std\moduleinit.d

object.obj : object.d
	$(DMD) -c $(DFLAGS) object.d

outbuffer.obj : std\outbuffer.d
	$(DMD) -c $(DFLAGS) std\outbuffer.d

outofmemory.obj : std\outofmemory.d
	$(DMD) -c $(DFLAGS) std\outofmemory.d

path.obj : std\path.d
	$(DMD) -c $(DFLAGS) std\path.d

process.obj : std\process.d
	$(DMD) -c $(DFLAGS) std\process.d

random.obj : std\random.d
	$(DMD) -c $(DFLAGS) std\random.d

recls.obj : std\recls.d
	$(DMD) -c $(DFLAGS) std\recls.d

regexp.obj : std\regexp.d
	$(DMD) -c $(DFLAGS) std\regexp.d

stream.obj : std\stream.d
	$(DMD) -c $(DFLAGS) std\stream.d

string.obj : std\string.d
	$(DMD) -c $(DFLAGS) std\string.d

switcherr.obj : std\switcherr.d
	$(DMD) -c $(DFLAGS) std\switcherr.d

syserror.obj : std\syserror.d
	$(DMD) -c $(DFLAGS) std\syserror.d

system.obj : std\system.d
	$(DMD) -c $(DFLAGS) std\system.d

thread.obj : std\thread.d
	$(DMD) -c $(DFLAGS) std\thread.d

uri.obj : std\uri.d
	$(DMD) -c $(DFLAGS) std\uri.d

utf.obj : std\utf.d
	$(DMD) -c $(DFLAGS) std\utf.d

Dzlib.obj : std\zlib.d
	$(DMD) -c $(DFLAGS) std\zlib.d -ofDzlib.obj

zip.obj : std\zip.d
	$(DMD) -c $(DFLAGS) std\zip.d

### std\windows

iunknown.obj : std\windows\iunknown.d
	$(DMD) -c $(DFLAGS) std\windows\iunknown.d

registry.obj : std\windows\registry.d
	$(DMD) -c $(DFLAGS) std\windows\registry.d

### etc\c

Czlib.obj : etc\c\zlib.d
	$(DMD) -c $(DFLAGS) etc\c\zlib.d -ofCzlib.obj

### std\c\windows

com.obj : std\c\windows\com.d
	$(DMD) -c $(DFLAGS) std\c\windows\com.d

windows.obj : std\c\windows\windows.d
	$(DMD) -c $(DFLAGS) std\c\windows\windows.d

### std\typeinfo

ti_wchar.obj : std\typeinfo\ti_wchar.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_wchar.d

ti_dchar.obj : std\typeinfo\ti_dchar.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_dchar.d

ti_uint.obj : std\typeinfo\ti_uint.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_uint.d

ti_short.obj : std\typeinfo\ti_short.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_short.d

ti_ushort.obj : std\typeinfo\ti_ushort.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_ushort.d

ti_byte.obj : std\typeinfo\ti_byte.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_byte.d

ti_ubyte.obj : std\typeinfo\ti_ubyte.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_ubyte.d

ti_long.obj : std\typeinfo\ti_long.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_long.d

ti_ulong.obj : std\typeinfo\ti_ulong.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_ulong.d

ti_ptr.obj : std\typeinfo\ti_ptr.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_ptr.d

ti_float.obj : std\typeinfo\ti_float.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_float.d

ti_double.obj : std\typeinfo\ti_double.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_double.d

ti_real.obj : std\typeinfo\ti_real.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_real.d

ti_delegate.obj : std\typeinfo\ti_delegate.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_delegate.d

ti_creal.obj : std\typeinfo\ti_creal.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_creal.d

ti_ireal.obj : std\typeinfo\ti_ireal.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_ireal.d

ti_cfloat.obj : std\typeinfo\ti_cfloat.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_cfloat.d

ti_ifloat.obj : std\typeinfo\ti_ifloat.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_ifloat.d

ti_cdouble.obj : std\typeinfo\ti_cdouble.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_cdouble.d

ti_idouble.obj : std\typeinfo\ti_idouble.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_idouble.d

ti_Aa.obj : std\typeinfo\ti_Aa.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Aa.d

ti_AC.obj : std\typeinfo\ti_AC.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_AC.d

ti_Ag.obj : std\typeinfo\ti_Ag.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Ag.d

ti_Aubyte.obj : std\typeinfo\ti_Aubyte.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Aubyte.d

ti_Aushort.obj : std\typeinfo\ti_Aushort.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Aushort.d

ti_Ashort.obj : std\typeinfo\ti_Ashort.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Ashort.d

ti_Auint.obj : std\typeinfo\ti_Auint.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Auint.d

ti_Aint.obj : std\typeinfo\ti_Aint.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Aint.d

ti_Aulong.obj : std\typeinfo\ti_Aulong.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Aulong.d

ti_Along.obj : std\typeinfo\ti_Along.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Along.d

ti_Awchar.obj : std\typeinfo\ti_Awchar.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Awchar.d

ti_Adchar.obj : std\typeinfo\ti_Adchar.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Adchar.d

ti_C.obj : std\typeinfo\ti_C.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_C.d

ti_char.obj : std\typeinfo\ti_char.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_char.d

ti_int.obj : std\typeinfo\ti_int.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_int.d


######################################################

zip : win32.mak linux.mak $(SRC) \
	$(SRC_STD) $(SRC_STD_C) $(SRC_TI) $(SRC_INT) $(SRC_STD_WIN) \
	$(SRC_STDLINUX) $(SRC_ETC) $(SRC_ZLIB) $(SRC_GC)
	del phobos.zip
	zip32 -u phobos win32.mak linux.mak
	zip32 -u phobos $(SRC)
	zip32 -u phobos $(SRC_TI)
	zip32 -u phobos $(SRC_INT)
	zip32 -u phobos $(SRC_STD)
	zip32 -u phobos $(SRC_STD_C)
	zip32 -u phobos $(SRC_STD_WIN)
	zip32 -u phobos $(SRC_STD_C_WIN)
	zip32 -u phobos $(SRC_STD_C_LINUX)
	zip32 -u phobos $(SRC_ETC)
	zip32 -u phobos $(SRC_ZLIB)
	zip32 -u phobos $(SRC_GC)
	zip32 -u phobos $(SRC_RECLS)
	zip32 -u phobos $(SRC_STLSOFT)

clean:
	del $(OBJS)

install:
	$(CP) phobos.lib \dmd\lib
	$(CP) win32.mak linux.mak minit.obj \dmd\src\phobos
	$(CP) $(SRC) \dmd\src\phobos
	$(CP) $(SRC_STD) \dmd\src\phobos\std
	$(CP) $(SRC_STD_C) \dmd\src\phobos\std\c
	$(CP) $(SRC_TI) \dmd\src\phobos\std\typeinfo
	$(CP) $(SRC_INT) \dmd\src\phobos\internal
	$(CP) $(SRC_STD_WIN) \dmd\src\phobos\std\windows
	$(CP) $(SRC_STD_C_WIN) \dmd\src\phobos\std\c\windows
	$(CP) $(SRC_STD_C_LINUX) \dmd\src\phobos\std\c\linux
	$(CP) $(SRC_ETC) \dmd\src\phobos\etc\c
	$(CP) $(SRC_ZLIB) \dmd\src\phobos\etc\c\zlib
	$(CP) $(SRC_GC) \dmd\src\phobos\internal\gc
	$(CP) $(SRC_RECLS) \dmd\src\phobos\etc\c\recls
	$(CP) $(SRC_STLSOFT) \dmd\src\phobos\etc\c\stlsoft

