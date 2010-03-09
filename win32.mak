# Makefile to build D runtime library phobos.lib for Win32
# Prerequisites:
#	Digital Mars dmc, lib, and make that are unzipped from Digital Mars C:
#	    http://ftp.digitalmars.com/Digital_Mars_C++/Patch/dm850c.zip
#	and are in the \dm\bin directory.
# Targets:
#	make
#		Same as make unittest
#	make phobos.lib
#		Build phobos.lib
#	make clean
#		Delete unneeded files created by build process
#	make unittest
#		Build phobos.lib, build and run unit tests
#	make cov
#		Build for coverage tests, run coverage tests
#	make html
#		Build documentation
# Notes:
#	minit.obj requires Microsoft MASM386.EXE to build from minit.asm,
#`	or just use the supplied minit.obj

## Copy command

CP=cp

## Directory where dmd has been installed

DIR=\dmd2

## Flags for dmc C compiler

CFLAGS=-mn -6 -r
#CFLAGS=-g -mn -6 -r

## Flags for dmd D compiler

DFLAGS=-O -release -nofloat -w -d
#DFLAGS=-unittest -g -d
#DFLAGS=-unittest -cov -g -d

## Flags for compiling unittests

UDFLAGS=-O -release -nofloat -d

## C compiler

CC=dmc

## D compiler

DMD=$(DIR)\bin\dmd
#DMD=..\dmd
DMD=dmd

## Location of where to write the html documentation files

DOC=..\..\html\d\phobos
#DOC=..\doc\phobos

## Location of druntime tree

DRUNTIME=..\druntime
DRUNTIMELIB=$(DRUNTIME)\lib\druntime.lib

.c.obj:
	$(CC) -c $(CFLAGS) $*

.cpp.obj:
	$(CC) -c $(CFLAGS) $*

.d.obj:
	$(DMD) -c $(DFLAGS) $*

.asm.obj:
	$(CC) -c $*

targets : phobos.lib

test : test.exe

test.obj : test.d
	$(DMD) -c test -g -unittest

test.exe : test.obj phobos.lib
	$(DMD) test.obj -g -L/map

OBJS= Czlib.obj Dzlib.obj \
	oldsyserror.obj \
	c_stdio.obj

#	ti_bit.obj ti_Abit.obj

SRCS= std\math.d std\stdio.d std\dateparse.d std\date.d std\uni.d std\string.d \
	std\atomics.d std\base64.d std\md5.d std\xml.d std\bigint.d std\regexp.d \
	std\compiler.d std\cpuid.d std\format.d std\demangle.d \
	std\path.d std\file.d std\outbuffer.d std\utf.d std\uri.d \
	std\ctype.d std\random.d std\mmfile.d \
	std\algorithm.d std\array.d std\numeric.d std\functional.d \
	std\range.d std\stdiobase.d std\concurrency.d \
	std\metastrings.d std\contracts.d std\getopt.d \
	std\signals.d std\typetuple.d std\traits.d std\bind.d \
	std\bitmanip.d std\typecons.d \
	std\boxer.d \
	std\process.d \
	std\system.d \
	std\iterator.d std\encoding.d std\variant.d \
	std\stream.d std\socket.d std\socketstream.d \
	std\perf.d std\conv.d \
	std\zip.d std\cstream.d std\loader.d \
	std\__fileinit.d \
	std\datebase.d \
	std\regex.d \
	std\stdarg.d \
	std\stdint.d \
	std\json.d \
	crc32.d \
	std\c\process.d \
	std\c\stdarg.d \
	std\c\stddef.d \
	std\c\stdlib.d \
	std\c\string.d \
	std\c\time.d \
	std\c\math.d \
	std\c\windows\com.d \
	std\c\windows\stat.d \
	std\c\windows\windows.d \
	std\c\windows\winsock.d \
	std\windows\charset.d \
	std\windows\iunknown.d \
	std\windows\registry.d \
	std\windows\syserror.d



DOCS=	$(DOC)\object.html \
	$(DOC)\std_algorithm.html \
	$(DOC)\std_array.html \
	$(DOC)\std_base64.html \
	$(DOC)\std_bigint.html \
	$(DOC)\std_bind.html \
	$(DOC)\std_bitmanip.html \
	$(DOC)\std_boxer.html \
	$(DOC)\std_concurrency.html \
	$(DOC)\std_compiler.html \
	$(DOC)\std_complex.html \
	$(DOC)\std_contracts.html \
	$(DOC)\std_conv.html \
	$(DOC)\std_cpuid.html \
	$(DOC)\std_cstream.html \
	$(DOC)\std_ctype.html \
	$(DOC)\std_date.html \
	$(DOC)\std_demangle.html \
	$(DOC)\std_encoding.html \
	$(DOC)\std_file.html \
	$(DOC)\std_format.html \
	$(DOC)\std_functional.html \
	$(DOC)\std_gc.html \
	$(DOC)\std_getopt.html \
	$(DOC)\std_intrinsic.html \
	$(DOC)\std_iterator.html \
	$(DOC)\std_json.html \
	$(DOC)\std_math.html \
	$(DOC)\std_md5.html \
	$(DOC)\std_metastrings.html \
	$(DOC)\std_mmfile.html \
	$(DOC)\std_numeric.html \
	$(DOC)\std_outbuffer.html \
	$(DOC)\std_path.html \
	$(DOC)\std_perf.html \
	$(DOC)\std_process.html \
	$(DOC)\std_random.html \
	$(DOC)\std_range.html \
	$(DOC)\std_regex.html \
	$(DOC)\std_regexp.html \
	$(DOC)\std_signals.html \
	$(DOC)\std_socket.html \
	$(DOC)\std_socketstream.html \
	$(DOC)\std_stdint.html \
	$(DOC)\std_stdio.html \
	$(DOC)\std_stream.html \
	$(DOC)\std_string.html \
	$(DOC)\std_system.html \
	$(DOC)\std_thread.html \
	$(DOC)\std_traits.html \
	$(DOC)\std_typecons.html \
	$(DOC)\std_typetuple.html \
	$(DOC)\std_uni.html \
	$(DOC)\std_uri.html \
	$(DOC)\std_utf.html \
	$(DOC)\std_variant.html \
	$(DOC)\std_xml.html \
	$(DOC)\std_zip.html \
	$(DOC)\std_zlib.html \
	$(DOC)\std_windows_charset.html \
	$(DOC)\std_windows_registry.html \
	$(DOC)\std_c_fenv.html \
	$(DOC)\std_c_locale.html \
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

SRC=	unittest.d crc32.d phobos.d

SRC_STD= std\zlib.d std\zip.d std\stdint.d std\conv.d std\utf.d std\uri.d \
	std\math.d std\string.d std\path.d std\date.d \
	std\ctype.d std\file.d std\compiler.d std\system.d \
	std\outbuffer.d std\md5.d std\atomics.d std\base64.d \
	std\dateparse.d std\mmfile.d \
	std\intrinsic.d std\syserror.d \
	std\regexp.d std\random.d std\stream.d std\process.d \
	std\socket.d std\socketstream.d std\loader.d std\stdarg.d std\format.d \
	std\stdio.d std\perf.d std\uni.d std\boxer.d \
	std\cstream.d std\demangle.d \
	std\signals.d std\cpuid.d std\typetuple.d std\traits.d std\bind.d \
	std\metastrings.d std\contracts.d std\getopt.d \
	std\variant.d std\numeric.d std\bitmanip.d std\complex.d \
	std\functional.d std\algorithm.d std\array.d std\typecons.d std\iterator.d \
	std\json.d std\xml.d std\encoding.d std\bigint.d std\concurrency.d \
	std\range.d std\stdiobase.d \
	std\regex.d std\datebase.d \
	std\__fileinit.d

SRC_STD_C= std\c\process.d std\c\stdlib.d std\c\time.d std\c\stdio.d \
	std\c\math.d std\c\stdarg.d std\c\stddef.d std\c\fenv.d std\c\string.d \
	std\c\locale.d std\c\wcharh.d

SRC_STD_WIN= std\windows\registry.d \
	std\windows\iunknown.d std\windows\syserror.d std\windows\charset.d

SRC_STD_C_WIN= std\c\windows\windows.d std\c\windows\com.d \
	std\c\windows\winsock.d std\c\windows\stat.d

SRC_STD_C_LINUX= std\c\linux\linux.d \
	std\c\linux\socket.d std\c\linux\pthread.d std\c\linux\termios.d \
	std\c\linux\tipc.d
	
SRC_STD_C_OSX= std\c\osx\socket.d

SRC_ETC=

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
	etc\c\zlib\README \
	etc\c\zlib\win32.mak \
	etc\c\zlib\linux.mak \
	etc\c\zlib\osx.mak

phobos.lib : $(OBJS) $(SRCS) \
	etc\c\zlib\zlib.lib $(DRUNTIMELIB) win32.mak
	$(DMD) -lib -ofphobos.lib $(DFLAGS) $(SRCS) $(OBJS) \
		etc\c\zlib\zlib.lib $(DRUNTIMELIB)

unittest : $(SRCS) phobos.lib
	$(DMD) $(UDFLAGS) -L/co -unittest unittest.d $(SRCS) phobos.lib
	unittest

#unittest : unittest.exe
#	unittest
#
#unittest.exe : unittest.d phobos.lib
#	$(DMD) unittest -g
#	dmc unittest.obj -g

cov : $(SRCS) phobos.lib
	$(DMD) -cov -unittest -ofcov.exe unittest.d $(SRCS) phobos.lib
	cov

html : $(DOCS)

######################################################

etc\c\zlib\zlib.lib:
	cd etc\c\zlib
	make -f win32.mak zlib.lib
	cd ..\..\..

### std

algorithm.obj : std\algorithm.d
	$(DMD) -c $(DFLAGS) std\algorithm.d

array.obj : std\array.d
	$(DMD) -c $(DFLAGS) std\array.d

atomics.obj : std\atomics.d
	$(DMD) -c $(DFLAGS) -inline std\atomics.d

base64.obj : std\base64.d
	$(DMD) -c $(DFLAGS) -inline std\base64.d

bind.obj : std\bind.d
	$(DMD) -c $(DFLAGS) -inline std\bind.d

bitmanip.obj : std\bitmanip.d
	$(DMD) -c $(DFLAGS) std\bitmanip.d

boxer.obj : std\boxer.d
	$(DMD) -c $(DFLAGS) std\boxer.d
	
concurrency.obj : std\concurrency.d
	$(DMD) -c $(DFLAGS) std\concurrency.d

compiler.obj : std\compiler.d
	$(DMD) -c $(DFLAGS) std\compiler.d

complex.obj : std\complex.d
	$(DMD) -c $(DFLAGS) std\complex.d

contracts.obj : std\contracts.d
	$(DMD) -c $(DFLAGS) std\contracts.d

conv.obj : std\conv.d
	$(DMD) -c $(DFLAGS) std\conv.d

cpuid.obj : std\cpuid.d
	$(DMD) -c $(DFLAGS) std\cpuid.d -ofcpuid.obj

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

__fileinit.obj : std\__fileinit.d
	$(DMD) -c $(DFLAGS) std\__fileinit.d

format.obj : std\format.d
	$(DMD) -c $(DFLAGS) std\format.d

functional.obj : std\functional.d
	$(DMD) -c $(DFLAGS) std\functional.d

getopt.obj : std\getopt.d
	$(DMD) -c $(DFLAGS) std\getopt.d

iterator.obj : std\iterator.d
	$(DMD) -c $(DFLAGS) std\iterator.d

json.obj : std\json.d
	$(DMD) -c $(DFLAGS) std\json.d

loader.obj : std\loader.d
	$(DMD) -c $(DFLAGS) std\loader.d

math.obj : std\math.d
	$(DMD) -c $(DFLAGS) std\math.d

md5.obj : std\md5.d
	$(DMD) -c $(DFLAGS) -inline std\md5.d

metastrings.obj : std\metastrings.d
	$(DMD) -c $(DFLAGS) -inline std\metastrings.d

mmfile.obj : std\mmfile.d
	$(DMD) -c $(DFLAGS) std\mmfile.d

numeric.obj : std\numeric.d
	$(DMD) -c $(DFLAGS) std\numeric.d

outbuffer.obj : std\outbuffer.d
	$(DMD) -c $(DFLAGS) std\outbuffer.d

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

signals.obj : std\signals.d
	$(DMD) -c $(DFLAGS) std\signals.d -ofsignals.obj

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

oldsyserror.obj : std\syserror.d
	$(DMD) -c $(DFLAGS) std\syserror.d -ofoldsyserror.obj

system.obj : std\system.d
	$(DMD) -c $(DFLAGS) std\system.d

traits.obj : std\traits.d
	$(DMD) -c $(DFLAGS) std\traits.d -oftraits.obj

typecons.obj : std\typecons.d
	$(DMD) -c $(DFLAGS) std\typecons.d -oftypecons.obj

typetuple.obj : std\typetuple.d
	$(DMD) -c $(DFLAGS) std\typetuple.d -oftypetuple.obj

uni.obj : std\uni.d
	$(DMD) -c $(DFLAGS) std\uni.d

uri.obj : std\uri.d
	$(DMD) -c $(DFLAGS) std\uri.d

utf.obj : std\utf.d
	$(DMD) -c $(DFLAGS) std\utf.d

variant.obj : std\variant.d
	$(DMD) -c $(DFLAGS) std\variant.d

xml.obj : std\xml.d
	$(DMD) -c $(DFLAGS) std\xml.d

encoding.obj : std\encoding.d
	$(DMD) -c $(DFLAGS) std\encoding.d

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

c_stdio.obj : std\c\stdio.d
	$(DMD) -c $(DFLAGS) std\c\stdio.d -ofc_stdio.obj

### etc

### etc\c

Czlib.obj : etc\c\zlib.d
	$(DMD) -c $(DFLAGS) etc\c\zlib.d -ofCzlib.obj

### std\c\windows

com.obj : std\c\windows\com.d
	$(DMD) -c $(DFLAGS) std\c\windows\com.d

stat.obj : std\c\windows\stat.d
	$(DMD) -c $(DFLAGS) std\c\windows\stat.d

winsock.obj : std\c\windows\winsock.d
	$(DMD) -c $(DFLAGS) std\c\windows\winsock.d

windows.obj : std\c\windows\windows.d
	$(DMD) -c $(DFLAGS) std\c\windows\windows.d

################## DOCS ####################################

$(DOC)\object.html : std.ddoc $(DRUNTIME)\src\object_.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\object.html std.ddoc $(DRUNTIME)\src\object_.d -I$(DRUNTIME)\src\

$(DOC)\phobos.html : std.ddoc phobos.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\phobos.html std.ddoc phobos.d

$(DOC)\std_algorithm.html : std.ddoc std\algorithm.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_algorithm.html std.ddoc std\algorithm.d

$(DOC)\std_array.html : std.ddoc std\array.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_array.html std.ddoc std\array.d

$(DOC)\std_atomics.html : std.ddoc std\atomics.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_atomics.html std.ddoc std\atomics.d

$(DOC)\std_base64.html : std.ddoc std\base64.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_base64.html std.ddoc std\base64.d

$(DOC)\std_bigint.html : std.ddoc std\bigint.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_bigint.html std.ddoc std\bigint.d

$(DOC)\std_bind.html : std.ddoc std\bind.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_bind.html std.ddoc std\bind.d

$(DOC)\std_bitmanip.html : std.ddoc std\bitmanip.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_bitmanip.html std.ddoc std\bitmanip.d

$(DOC)\std_boxer.html : std.ddoc std\boxer.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_boxer.html std.ddoc std\boxer.d

$(DOC)\std_concurrency.html : std.ddoc std\concurrency.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_concurrency.html std.ddoc std\concurrency.d

$(DOC)\std_compiler.html : std.ddoc std\compiler.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_compiler.html std.ddoc std\compiler.d

$(DOC)\std_complex.html : std.ddoc std\complex.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_complex.html std.ddoc std\complex.d

$(DOC)\std_contracts.html : std.ddoc std\contracts.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_contracts.html std.ddoc std\contracts.d

$(DOC)\std_conv.html : std.ddoc std\conv.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_conv.html std.ddoc std\conv.d

$(DOC)\std_cpuid.html : std.ddoc std\cpuid.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_cpuid.html std.ddoc std\cpuid.d

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

$(DOC)\std_functional.html : std.ddoc std\functional.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_functional.html std.ddoc std\functional.d

$(DOC)\std_gc.html : std.ddoc $(DRUNTIME)\src\core\memory.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_gc.html std.ddoc $(DRUNTIME)\src\core\memory.d

$(DOC)\std_getopt.html : std.ddoc std\getopt.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_getopt.html std.ddoc std\getopt.d

$(DOC)\std_iterator.html : std.ddoc std\iterator.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_iterator.html std.ddoc std\iterator.d

$(DOC)\std_intrinsic.html : std.ddoc std\intrinsic.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_intrinsic.html std.ddoc std\intrinsic.d

$(DOC)\std_json.html : std.ddoc std\json.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_json.html std.ddoc std\json.d

$(DOC)\std_math.html : std.ddoc std\math.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_math.html std.ddoc std\math.d

$(DOC)\std_md5.html : std.ddoc std\md5.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_md5.html std.ddoc std\md5.d

$(DOC)\std_metastrings.html : std.ddoc std\metastrings.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_metastrings.html std.ddoc std\metastrings.d

$(DOC)\std_mmfile.html : std.ddoc std\mmfile.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_mmfile.html std.ddoc std\mmfile.d

$(DOC)\std_numeric.html : std.ddoc std\numeric.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_numeric.html std.ddoc std\numeric.d

$(DOC)\std_outbuffer.html : std.ddoc std\outbuffer.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_outbuffer.html std.ddoc std\outbuffer.d

$(DOC)\std_path.html : std.ddoc std\path.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_path.html std.ddoc std\path.d

$(DOC)\std_perf.html : std.ddoc std\perf.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_perf.html std.ddoc std\perf.d

$(DOC)\std_process.html : std.ddoc std\process.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_process.html std.ddoc std\process.d

$(DOC)\std_random.html : std.ddoc std\random.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_random.html std.ddoc std\random.d

$(DOC)\std_range.html : std.ddoc std\range.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_range.html std.ddoc std\range.d

$(DOC)\std_regex.html : std.ddoc std\regex.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_regex.html std.ddoc std\regex.d

$(DOC)\std_regexp.html : std.ddoc std\regexp.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_regexp.html std.ddoc std\regexp.d

$(DOC)\std_signals.html : std.ddoc std\signals.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_signals.html std.ddoc std\signals.d

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

$(DOC)\std_thread.html : std.ddoc $(DRUNTIME)\src\core\thread.d
	$(DMD) -c -o- -d $(DFLAGS) -Df$(DOC)\std_thread.html std.ddoc $(DRUNTIME)\src\core\thread.d

$(DOC)\std_traits.html : std.ddoc std\traits.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_traits.html std.ddoc std\traits.d

$(DOC)\std_typecons.html : std.ddoc std\typecons.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_typecons.html std.ddoc std\typecons.d

$(DOC)\std_typetuple.html : std.ddoc std\typetuple.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_typetuple.html std.ddoc std\typetuple.d

$(DOC)\std_uni.html : std.ddoc std\uni.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_uni.html std.ddoc std\uni.d

$(DOC)\std_uri.html : std.ddoc std\uri.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_uri.html std.ddoc std\uri.d

$(DOC)\std_utf.html : std.ddoc std\utf.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_utf.html std.ddoc std\utf.d

$(DOC)\std_variant.html : std.ddoc std\variant.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_variant.html std.ddoc std\variant.d

$(DOC)\std_xml.html : std.ddoc std\xml.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_xml.html std.ddoc std\xml.d

$(DOC)\std_encoding.html : std.ddoc std\encoding.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_encoding.html std.ddoc std\encoding.d

$(DOC)\std_zip.html : std.ddoc std\zip.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_zip.html std.ddoc std\zip.d

$(DOC)\std_zlib.html : std.ddoc std\zlib.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_zlib.html std.ddoc std\zlib.d

$(DOC)\std_windows_charset.html : std.ddoc std\windows\charset.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_windows_charset.html std.ddoc std\windows\charset.d

$(DOC)\std_windows_registry.html : std.ddoc std\windows\registry.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_windows_registry.html std.ddoc std\windows\registry.d

$(DOC)\std_c_fenv.html : std.ddoc std\c\fenv.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_c_fenv.html std.ddoc std\c\fenv.d

$(DOC)\std_c_locale.html : std.ddoc std\c\locale.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_c_locale.html std.ddoc std\c\locale.d

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

zip : win32.mak linux.mak osx.mak std.ddoc $(SRC) \
	$(SRC_STD) $(SRC_STD_C) $(SRC_TI) $(SRC_INT) $(SRC_STD_WIN) \
	$(SRC_STD_C_LINUX) $(SRC_STD_C_OSX) $(SRC_ETC) $(SRC_ETC_C) $(SRC_ZLIB) $(SRC_GC)
	del phobos.zip
	zip32 -u phobos win32.mak linux.mak osx.mak std.ddoc
	zip32 -u phobos $(SRC)
	zip32 -u phobos $(SRC_TI)
	zip32 -u phobos $(SRC_INT)
	zip32 -u phobos $(SRC_STD)
	zip32 -u phobos $(SRC_STD_C)
	zip32 -u phobos $(SRC_STD_WIN)
	zip32 -u phobos $(SRC_STD_C_WIN)
	zip32 -u phobos $(SRC_STD_C_LINUX)
	zip32 -u phobos $(SRC_STD_C_OSX)
	zip32 -u phobos $(SRC_ETC)
	zip32 -u phobos $(SRC_ETC_C)
	zip32 -u phobos $(SRC_ZLIB)
	zip32 -u phobos $(SRC_GC)

clean:
	cd etc\c\zlib
	make -f win32.mak clean
	cd ..\..\..
	del $(OBJS)
	del $(DOCS)
	del unittest.obj unittest.map unittest.exe
	del phobos.lib

cleanhtml:
	del $(DOCS)

install:
	$(CP) phobos.lib $(DIR)\windows\lib
	$(CP) $(DRUNTIME)\lib\gcstub.obj $(DIR)\windows\lib
	$(CP) win32.mak linux.mak osx.mak std.ddoc $(DIR)\src\phobos
	$(CP) $(SRC) $(DIR)\src\phobos
	$(CP) $(SRC_STD) $(DIR)\src\phobos\std
	$(CP) $(SRC_STD_C) $(DIR)\src\phobos\std\c
	$(CP) $(SRC_STD_WIN) $(DIR)\src\phobos\std\windows
	$(CP) $(SRC_STD_C_WIN) $(DIR)\src\phobos\std\c\windows
	$(CP) $(SRC_STD_C_LINUX) $(DIR)\src\phobos\std\c\linux
	$(CP) $(SRC_STD_C_OSX) $(DIR)\src\phobos\std\c\osx
	#$(CP) $(SRC_ETC) $(DIR)\src\phobos\etc
	$(CP) $(SRC_ETC_C) $(DIR)\src\phobos\etc\c
	$(CP) $(SRC_ZLIB) $(DIR)\src\phobos\etc\c\zlib
