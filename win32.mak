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
#	make html
#		Build documentation
# Notes:
#	This relies on LIB.EXE 8.00 or later, and MAKE.EXE 5.01 or later.

CP=cp

CFLAGS=-mn -6 -r
#CFLAGS=-g -mn -6 -r

DFLAGS=-O -release -nofloat
#DFLAGS=-unittest -g
#DFLAGS=-unittest -cov -g

CC=dmc

DMD=\dmd\bin\dmd
#DMD=..\dmd

DOC=..\..\html\d\phobos
#DOC=..\doc\phobos

.c.obj:
	$(CC) -c $(CFLAGS) $*

.cpp.obj:
	$(CC) -c $(CFLAGS) $*

.d.obj:
	$(DMD) -c $(DFLAGS) $*

.asm.obj:
	$(CC) -c $*

targets : unittest gcstub.obj

unittest : unittest.exe
	unittest

test : test.exe

test.obj : test.d
	$(DMD) -c test -g -unittest

test.exe : test.obj phobos.lib
	$(DMD) test.obj -g -L/map

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
	Czlib.obj Dzlib.obj zip.obj process.obj registry.obj \
	socket.obj socketstream.obj loader.obj stdarg.obj format.obj stdio.obj \
	perf.obj openrj.obj uni.obj winsock.obj oldsyserror.obj \
	errno.obj boxer.obj cstream.obj charset.obj \
	realtest.obj gamma.obj demangle.obj cover.obj bitarray.obj \
	ti_Aa.obj ti_Ag.obj ti_C.obj ti_int.obj ti_char.obj \
	ti_wchar.obj ti_uint.obj ti_short.obj ti_ushort.obj \
	ti_byte.obj ti_ubyte.obj ti_long.obj ti_ulong.obj ti_ptr.obj \
	ti_float.obj ti_double.obj ti_real.obj ti_delegate.obj \
	ti_creal.obj ti_ireal.obj \
	ti_cfloat.obj ti_ifloat.obj \
	ti_cdouble.obj ti_idouble.obj \
	ti_AC.obj ti_Aubyte.obj ti_Aushort.obj ti_Ashort.obj \
	ti_Aint.obj ti_Auint.obj ti_Along.obj ti_Aulong.obj ti_Awchar.obj \
	ti_Afloat.obj ti_Adouble.obj ti_Areal.obj \
	ti_Acfloat.obj ti_Acdouble.obj ti_Acreal.obj \
	ti_dchar.obj ti_Adchar.obj ti_void.obj

#	ti_bit.obj ti_Abit.obj

DOCS=	$(DOC)\std_path.html $(DOC)\std_math.html $(DOC)\std_outbuffer.html \
	$(DOC)\std_stream.html $(DOC)\std_string.html $(DOC)\std_base64.html \
	$(DOC)\object.html $(DOC)\std_compiler.html $(DOC)\std_format.html \
	$(DOC)\std_random.html $(DOC)\std_file.html $(DOC)\std_date.html \
	$(DOC)\std_md5.html $(DOC)\std_zip.html $(DOC)\std_zlib.html \
	$(DOC)\std_bitarray.html \
	$(DOC)\std_conv.html \
	$(DOC)\std_boxer.html \
	$(DOC)\std_cover.html \
	$(DOC)\std_cstream.html \
	$(DOC)\std_ctype.html \
	$(DOC)\std_demangle.html \
	$(DOC)\std_gc.html \
	$(DOC)\std_intrinsic.html \
	$(DOC)\std_mmfile.html \
	$(DOC)\std_openrj.html \
	$(DOC)\std_process.html \
	$(DOC)\std_regexp.html \
	$(DOC)\std_socket.html \
	$(DOC)\std_socketstream.html \
	$(DOC)\std_stdint.html \
	$(DOC)\std_stdio.html \
	$(DOC)\std_system.html \
	$(DOC)\std_thread.html \
	$(DOC)\std_uni.html \
	$(DOC)\std_uri.html \
	$(DOC)\std_utf.html \
	$(DOC)\std_windows_charset.html \
	$(DOC)\std_c_fenv.html \
	$(DOC)\std_c_math.html \
	$(DOC)\std_c_process.html \
	$(DOC)\std_c_stdarg.html \
	$(DOC)\std_c_stddef.html \
	$(DOC)\std_c_stdio.html \
	$(DOC)\std_c_stdlib.html \
	$(DOC)\std_c_string.html \
	$(DOC)\std_c_time.html \
	$(DOC)\std_c_wcharh.html \
	$(DOC)\phobos.html

SRC=	errno.c object.d unittest.d crc32.d gcstats.d phobos.d

SRC_STD= std\zlib.d std\zip.d std\stdint.d std\conv.d std\utf.d std\uri.d \
	std\gc.d std\math.d std\string.d std\path.d std\date.d \
	std\ctype.d std\file.d std\compiler.d std\system.d std\moduleinit.d \
	std\outbuffer.d std\math2.d std\thread.d std\md5.d std\base64.d \
	std\asserterror.d std\dateparse.d std\outofmemory.d std\mmfile.d \
	std\intrinsic.d std\array.d std\switcherr.d std\syserror.d \
	std\regexp.d std\random.d std\stream.d std\process.d \
	std\socket.d std\socketstream.d std\loader.d std\stdarg.d std\format.d \
	std\stdio.d std\perf.d std\openrj.d std\uni.d std\boxer.d \
	std\cstream.d std\demangle.d std\cover.d std\bitarray.d

SRC_STD_C= std\c\process.d std\c\stdlib.d std\c\time.d std\c\stdio.d \
	std\c\math.d std\c\stdarg.d std\c\stddef.d std\c\fenv.d std\c\string.d

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
	std\typeinfo\ti_Afloat.d std\typeinfo\ti_Adouble.d \
	std\typeinfo\ti_Areal.d \
	std\typeinfo\ti_Acfloat.d std\typeinfo\ti_Acdouble.d \
	std\typeinfo\ti_Acreal.d \
	std\typeinfo\ti_Awchar.d std\typeinfo\ti_dchar.d \
	std\typeinfo\ti_void.d

#	std\typeinfo\ti_bit.d std\typeinfo\ti_Abit.d

SRC_INT=	\
	internal\switch.d internal\complex.c internal\critical.c \
	internal\minit.asm internal\alloca.d internal\llmath.d internal\deh.c \
	internal\arraycat.d internal\invariant.d internal\monitor.c \
	internal\memset.d internal\arraycast.d internal\aaA.d internal\adi.d \
	internal\dmain2.d internal\cast.d internal\qsort.d internal\deh2.d \
	internal\cmath2.d internal\obj.d internal\mars.h internal\aApply.d \
	internal\object.d internal\trace.d internal\qsort2.d

SRC_STD_WIN= std\windows\registry.d \
	std\windows\iunknown.d std\windows\syserror.d std\windows\charset.d

SRC_STD_C_WIN= std\c\windows\windows.d std\c\windows\com.d \
	std\c\windows\winsock.d

SRC_STD_C_LINUX= std\c\linux\linux.d std\c\linux\linuxextern.d \
	std\c\linux\socket.d

SRC_ETC= etc\gamma.d etc\realtest.d

SRC_ETC_C= etc\c\zlib.d

SRC_ZLIB= etc\c\zlib\trees.h \
	etc\c\zlib\inffixed.h \
	etc\c\zlib\inffast.h \
	etc\c\zlib\crc32.h \
	etc\c\zlib\algorithm.txt \
	etc\c\zlib\uncompr.c \
	etc\c\zlib\compress.c \
	etc\c\zlib\deflate.h \
	etc\c\zlib\inftrees.h \
	etc\c\zlib\infback.c \
	etc\c\zlib\zutil.c \
	etc\c\zlib\crc32.c \
	etc\c\zlib\inflate.h \
	etc\c\zlib\example.c \
	etc\c\zlib\inffast.c \
	etc\c\zlib\trees.c \
	etc\c\zlib\inflate.c \
	etc\c\zlib\gzio.c \
	etc\c\zlib\zconf.h \
	etc\c\zlib\zconf.in.h \
	etc\c\zlib\minigzip.c \
	etc\c\zlib\deflate.c \
	etc\c\zlib\inftrees.c \
	etc\c\zlib\zutil.h \
	etc\c\zlib\zlib.3 \
	etc\c\zlib\zlib.h \
	etc\c\zlib\adler32.c \
	etc\c\zlib\ChangeLog \
	etc\c\zlib\zlib.html \
	etc\c\zlib\README \
	etc\c\zlib\win32.mak \
	etc\c\zlib\linux.mak

SRC_GC= internal\gc\gc.d \
	internal\gc\gcx.d \
	internal\gc\gcstub.d \
	internal\gc\gcbits.d \
	internal\gc\win32.d \
	internal\gc\gclinux.d \
	internal\gc\testgc.d \
	internal\gc\win32.mak \
	internal\gc\linux.mak

phobos.lib : $(OBJS) minit.obj internal\gc\dmgc.lib etc\c\zlib\zlib.lib \
	win32.mak
	lib -c -p32 phobos.lib $(OBJS) minit.obj internal\gc\dmgc.lib \
		etc\c\zlib\zlib.lib

html : $(DOCS)

######################################################

internal\gc\dmgc.lib:
	cd internal\gc
	make -f win32.mak dmgc.lib
	cd ..\..

etc\c\zlib\zlib.lib:
	cd etc\c\zlib
	make -f win32.mak zlib.lib
	cd ..\..\..

errno.obj : errno.c

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

gcstub.obj : internal\gc\gcstub.d
	$(DMD) -c $(DFLAGS) -Iinternal\gc internal\gc\gcstub.d

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

object.obj : internal\object.d
	$(DMD) -c $(DFLAGS) internal\object.d

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

bitarray.obj : std\bitarray.d
	$(DMD) -c $(DFLAGS) -inline std\bitarray.d

boxer.obj : std\boxer.d
	$(DMD) -c $(DFLAGS) std\boxer.d

compiler.obj : std\compiler.d
	$(DMD) -c $(DFLAGS) std\compiler.d

conv.obj : std\conv.d
	$(DMD) -c $(DFLAGS) std\conv.d

cover.obj : std\cover.d
	$(DMD) -c $(DFLAGS) std\cover.d

cstream.obj : std\cstream.d
	$(DMD) -c $(DFLAGS) std\cstream.d

ctype.obj : std\ctype.d
	$(DMD) -c $(DFLAGS) std\ctype.d

date.obj : std\dateparse.d std\date.d
	$(DMD) -c $(DFLAGS) std\date.d

dateparse.obj : std\dateparse.d std\date.d
	$(DMD) -c $(DFLAGS) std\dateparse.d

demangle.obj : std\demangle.d
	$(DMD) -c $(DFLAGS) std\demangle.d

file.obj : std\file.d
	$(DMD) -c $(DFLAGS) std\file.d

format.obj : std\format.d
	$(DMD) -c $(DFLAGS) std\format.d

gc.obj : std\gc.d
	$(DMD) -c $(DFLAGS) std\gc.d

loader.obj : std\loader.d
	$(DMD) -c $(DFLAGS) std\loader.d

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

#object.obj : object.d
#	$(DMD) -c $(DFLAGS) object.d

openrj.obj : std\openrj.d
	$(DMD) -c $(DFLAGS) std\openrj.d

outbuffer.obj : std\outbuffer.d
	$(DMD) -c $(DFLAGS) std\outbuffer.d

outofmemory.obj : std\outofmemory.d
	$(DMD) -c $(DFLAGS) std\outofmemory.d

path.obj : std\path.d
	$(DMD) -c $(DFLAGS) std\path.d

perf.obj : std\perf.d
	$(DMD) -c $(DFLAGS) std\perf.d

process.obj : std\process.d
	$(DMD) -c $(DFLAGS) std\process.d

random.obj : std\random.d
	$(DMD) -c $(DFLAGS) std\random.d

regexp.obj : std\regexp.d
	$(DMD) -c $(DFLAGS) std\regexp.d

socket.obj : std\socket.d
	$(DMD) -c $(DFLAGS) std\socket.d -ofsocket.obj

socketstream.obj : std\socketstream.d
	$(DMD) -c $(DFLAGS) std\socketstream.d -ofsocketstream.obj

stdio.obj : std\stdio.d
	$(DMD) -c $(DFLAGS) std\stdio.d

stream.obj : std\stream.d
	$(DMD) -c $(DFLAGS) -d std\stream.d

string.obj : std\string.d
	$(DMD) -c $(DFLAGS) std\string.d

switcherr.obj : std\switcherr.d
	$(DMD) -c $(DFLAGS) std\switcherr.d

oldsyserror.obj : std\syserror.d
	$(DMD) -c $(DFLAGS) std\syserror.d -ofoldsyserror.obj

system.obj : std\system.d
	$(DMD) -c $(DFLAGS) std\system.d

thread.obj : std\thread.d
	$(DMD) -c $(DFLAGS) std\thread.d

uni.obj : std\uni.d
	$(DMD) -c $(DFLAGS) std\uni.d

uri.obj : std\uri.d
	$(DMD) -c $(DFLAGS) std\uri.d

utf.obj : std\utf.d
	$(DMD) -c $(DFLAGS) std\utf.d

Dzlib.obj : std\zlib.d
	$(DMD) -c $(DFLAGS) std\zlib.d -ofDzlib.obj

zip.obj : std\zip.d
	$(DMD) -c $(DFLAGS) std\zip.d

### std\windows

charset.obj : std\windows\charset.d
	$(DMD) -c $(DFLAGS) std\windows\charset.d

iunknown.obj : std\windows\iunknown.d
	$(DMD) -c $(DFLAGS) std\windows\iunknown.d

registry.obj : std\windows\registry.d
	$(DMD) -c $(DFLAGS) std\windows\registry.d

syserror.obj : std\windows\syserror.d
	$(DMD) -c $(DFLAGS) std\windows\syserror.d

### std\c

stdarg.obj : std\c\stdarg.d
	$(DMD) -c $(DFLAGS) std\c\stdarg.d

### etc

gamma.obj : etc\gamma.d
	$(DMD) -c $(DFLAGS) etc\gamma.d

realtest.obj : etc\realtest.d
	$(DMD) -c $(DFLAGS) etc\realtest.d

### etc\c

Czlib.obj : etc\c\zlib.d
	$(DMD) -c $(DFLAGS) etc\c\zlib.d -ofCzlib.obj

### std\c\windows

com.obj : std\c\windows\com.d
	$(DMD) -c $(DFLAGS) std\c\windows\com.d

winsock.obj : std\c\windows\winsock.d
	$(DMD) -c $(DFLAGS) std\c\windows\winsock.d

windows.obj : std\c\windows\windows.d
	$(DMD) -c $(DFLAGS) std\c\windows\windows.d

### std\typeinfo

ti_void.obj : std\typeinfo\ti_void.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_void.d

ti_bit.obj : std\typeinfo\ti_bit.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_bit.d

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

ti_Abit.obj : std\typeinfo\ti_Abit.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Abit.d

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

ti_Afloat.obj : std\typeinfo\ti_Afloat.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Afloat.d

ti_Adouble.obj : std\typeinfo\ti_Adouble.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Adouble.d

ti_Areal.obj : std\typeinfo\ti_Areal.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Areal.d

ti_Acfloat.obj : std\typeinfo\ti_Acfloat.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Acfloat.d

ti_Acdouble.obj : std\typeinfo\ti_Acdouble.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Acdouble.d

ti_Acreal.obj : std\typeinfo\ti_Acreal.d
	$(DMD) -c $(DFLAGS) std\typeinfo\ti_Acreal.d

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


################## DOCS ####################################

$(DOC)\phobos.html : std.ddoc phobos.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\phobos.html std.ddoc phobos.d

$(DOC)\std_base64.html : std.ddoc std\base64.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_base64.html std.ddoc std\base64.d

$(DOC)\std_bitarray.html : std.ddoc std\bitarray.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_bitarray.html std.ddoc std\bitarray.d

$(DOC)\std_boxer.html : std.ddoc std\boxer.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_boxer.html std.ddoc std\boxer.d

$(DOC)\std_compiler.html : std.ddoc std\compiler.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_compiler.html std.ddoc std\compiler.d

$(DOC)\std_conv.html : std.ddoc std\conv.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_conv.html std.ddoc std\conv.d

$(DOC)\std_cover.html : std.ddoc std\cover.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_cover.html std.ddoc std\cover.d

$(DOC)\std_cstream.html : std.ddoc std\cstream.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_cstream.html std.ddoc std\cstream.d

$(DOC)\std_ctype.html : std.ddoc std\ctype.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_ctype.html std.ddoc std\ctype.d

$(DOC)\std_date.html : std.ddoc std\date.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_date.html std.ddoc std\date.d

$(DOC)\std_demangle.html : std.ddoc std\demangle.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_demangle.html std.ddoc std\demangle.d

$(DOC)\std_file.html : std.ddoc std\file.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_file.html std.ddoc std\file.d

$(DOC)\std_format.html : std.ddoc std\format.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_format.html std.ddoc std\format.d

$(DOC)\std_gc.html : std.ddoc std\gc.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_gc.html std.ddoc std\gc.d

$(DOC)\std_intrinsic.html : std.ddoc std\intrinsic.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_intrinsic.html std.ddoc std\intrinsic.d

$(DOC)\std_math.html : std.ddoc std\math.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_math.html std.ddoc std\math.d

$(DOC)\std_md5.html : std.ddoc std\md5.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_md5.html std.ddoc std\md5.d

$(DOC)\std_mmfile.html : std.ddoc std\mmfile.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_mmfile.html std.ddoc std\mmfile.d

$(DOC)\std_openrj.html : std.ddoc std\openrj.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_openrj.html std.ddoc std\openrj.d

$(DOC)\std_outbuffer.html : std.ddoc std\outbuffer.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_outbuffer.html std.ddoc std\outbuffer.d

$(DOC)\std_path.html : std.ddoc std\path.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_path.html std.ddoc std\path.d

$(DOC)\std_process.html : std.ddoc std\process.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_process.html std.ddoc std\process.d

$(DOC)\std_random.html : std.ddoc std\random.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_random.html std.ddoc std\random.d

$(DOC)\std_regexp.html : std.ddoc std\regexp.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_regexp.html std.ddoc std\regexp.d

$(DOC)\std_socket.html : std.ddoc std\socket.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_socket.html std.ddoc std\socket.d

$(DOC)\std_socketstream.html : std.ddoc std\socketstream.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_socketstream.html std.ddoc std\socketstream.d

$(DOC)\std_stdint.html : std.ddoc std\stdint.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_stdint.html std.ddoc std\stdint.d

$(DOC)\std_stdio.html : std.ddoc std\stdio.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_stdio.html std.ddoc std\stdio.d

$(DOC)\std_stream.html : std.ddoc std\stream.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_stream.html -d std.ddoc std\stream.d

$(DOC)\std_string.html : std.ddoc std\string.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_string.html std.ddoc std\string.d

$(DOC)\std_system.html : std.ddoc std\system.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_system.html std.ddoc std\system.d

$(DOC)\std_thread.html : std.ddoc std\thread.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_thread.html std.ddoc std\thread.d

$(DOC)\std_uni.html : std.ddoc std\uni.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_uni.html std.ddoc std\uni.d

$(DOC)\std_uri.html : std.ddoc std\uri.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_uri.html std.ddoc std\uri.d

$(DOC)\std_utf.html : std.ddoc std\utf.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_utf.html std.ddoc std\utf.d

$(DOC)\std_zip.html : std.ddoc std\zip.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_zip.html std.ddoc std\zip.d

$(DOC)\std_zlib.html : std.ddoc std\zlib.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_zlib.html std.ddoc std\zlib.d

$(DOC)\std_windows_charset.html : std.ddoc std\windows\charset.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_windows_charset.html std.ddoc std\windows\charset.d

$(DOC)\object.html : std.ddoc internal\object.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\object.html std.ddoc internal\object.d

$(DOC)\std_c_fenv.html : std.ddoc std\c\fenv.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_c_fenv.html std.ddoc std\c\fenv.d

$(DOC)\std_c_math.html : std.ddoc std\c\math.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_c_math.html std.ddoc std\c\math.d

$(DOC)\std_c_process.html : std.ddoc std\c\process.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_c_process.html std.ddoc std\c\process.d

$(DOC)\std_c_stdarg.html : std.ddoc std\c\stdarg.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_c_stdarg.html std.ddoc std\c\stdarg.d

$(DOC)\std_c_stddef.html : std.ddoc std\c\stddef.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_c_stddef.html std.ddoc std\c\stddef.d

$(DOC)\std_c_stdio.html : std.ddoc std\c\stdio.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_c_stdio.html std.ddoc std\c\stdio.d

$(DOC)\std_c_stdlib.html : std.ddoc std\c\stdlib.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_c_stdlib.html std.ddoc std\c\stdlib.d

$(DOC)\std_c_string.html : std.ddoc std\c\string.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_c_string.html std.ddoc std\c\string.d

$(DOC)\std_c_time.html : std.ddoc std\c\time.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_c_time.html std.ddoc std\c\time.d

$(DOC)\std_c_wcharh.html : std.ddoc std\c\wcharh.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_c_wcharh.html std.ddoc std\c\wcharh.d


######################################################

zip : win32.mak linux.mak phoboslicense.txt std.ddoc $(SRC) \
	$(SRC_STD) $(SRC_STD_C) $(SRC_TI) $(SRC_INT) $(SRC_STD_WIN) \
	$(SRC_STDLINUX) $(SRC_ETC) $(SRC_ETC_C) $(SRC_ZLIB) $(SRC_GC)
	del phobos.zip
	zip32 -u phobos win32.mak linux.mak std.ddoc
	zip32 -u phobos $(SRC)
	zip32 -u phobos $(SRC_TI)
	zip32 -u phobos $(SRC_INT)
	zip32 -u phobos $(SRC_STD)
	zip32 -u phobos $(SRC_STD_C)
	zip32 -u phobos $(SRC_STD_WIN)
	zip32 -u phobos $(SRC_STD_C_WIN)
	zip32 -u phobos $(SRC_STD_C_LINUX)
	zip32 -u phobos $(SRC_ETC)
	zip32 -u phobos $(SRC_ETC_C)
	zip32 -u phobos $(SRC_ZLIB)
	zip32 -u phobos $(SRC_GC)

clean:
	del $(OBJS)
	del $(DOCS)

cleanhtml:
	del $(DOCS)

install:
	$(CP) phobos.lib gcstub.obj \dmd\lib
	$(CP) win32.mak linux.mak phoboslicense.txt minit.obj std.ddoc \dmd\src\phobos
	$(CP) $(SRC) \dmd\src\phobos
	$(CP) $(SRC_STD) \dmd\src\phobos\std
	$(CP) $(SRC_STD_C) \dmd\src\phobos\std\c
	$(CP) $(SRC_TI) \dmd\src\phobos\std\typeinfo
	$(CP) $(SRC_INT) \dmd\src\phobos\internal
	$(CP) $(SRC_STD_WIN) \dmd\src\phobos\std\windows
	$(CP) $(SRC_STD_C_WIN) \dmd\src\phobos\std\c\windows
	$(CP) $(SRC_STD_C_LINUX) \dmd\src\phobos\std\c\linux
	#$(CP) $(SRC_ETC) \dmd\src\phobos\etc
	$(CP) $(SRC_ETC_C) \dmd\src\phobos\etc\c
	$(CP) $(SRC_ZLIB) \dmd\src\phobos\etc\c\zlib
	$(CP) $(SRC_GC) \dmd\src\phobos\internal\gc

