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
#	or just use the supplied minit.obj

## Copy command

CP=cp

## Directory where dmd has been installed

DIR=\dmd2

## Flags for dmc C compiler

CFLAGS=-mn -6 -r
#CFLAGS=-g -mn -6 -r

## Flags for dmd D compiler

DFLAGS=-O -release -w -d -property
#DFLAGS=-unittest -g -d
#DFLAGS=-unittest -cov -g -d

## Flags for compiling unittests

UDFLAGS=-O -w -d -property

## C compiler

CC=dmc

## D compiler

DMD=$(DIR)\bin\dmd
#DMD=..\dmd
DMD=dmd

## Location of the svn repository

SVN=\svnproj\phobos\phobos

## Location of where to write the html documentation files

DOCSRC = .
STDDOC = $(DOCSRC)/std.ddoc

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

LIB=phobos.lib

targets : $(LIB)

test : test.exe

test.obj : test.d
	$(DMD) -c test -g -unittest

test.exe : test.obj $(LIB)
	$(DMD) test.obj -g -L/map

#	ti_bit.obj ti_Abit.obj

# The separation is a workaround for bug 4904 (optlink bug 3372).
# SRCS_1 is the heavyweight modules which are most likely to trigger the bug.
# Do not add any more modules to SRCS_1.
SRC_STD_1_HEAVY= std\stdio.d std\stdiobase.d \
	std\string.d std\format.d \
	std\file.d

SRC_STD_2_HEAVY= std\array.d std\functional.d std\range.d \
	std\path.d std\outbuffer.d std\utf.d

SRC_STD_3= std\csv.d std\math.d std\complex.d std\numeric.d std\bigint.d \
    std\datetime.d \
    std\metastrings.d std\bitmanip.d std\typecons.d \
    std\uni.d std\base64.d std\md5.d std\ctype.d std\ascii.d \
    std\demangle.d std\uri.d std\mmfile.d std\getopt.d \
    std\signals.d std\typetuple.d std\traits.d \
    std\encoding.d std\xml.d \
    std\random.d std\regexp.d \
    std\exception.d \
    std\compiler.d std\cpuid.d \
    std\system.d std\concurrency.d

SRC_STD_4= std\uuid.d

SRC_STD_5_HEAVY= std\algorithm.d

SRC_STD_REST= std\variant.d \
	std\syserror.d std\zlib.d \
	std\stream.d std\socket.d std\socketstream.d \
	std\perf.d std\container.d std\conv.d \
	std\zip.d std\cstream.d \
	std\regex.d \
	std\stdint.d \
	std\json.d \
	std\parallelism.d \
	std\mathspecial.d \
	std\process.d

SRC_STD_ALL= $(SRC_STD_1_HEAVY) $(SRC_STD_2_HEAVY) $(SRC_STD_3) $(SRC_STD_4) \
	$(SRC_STD_5_HEAVY) $(SRC_STD_REST)

SRC=	unittest.d crc32.d index.d

SRC_STD= std\zlib.d std\zip.d std\stdint.d std\container.d std\conv.d std\utf.d std\uri.d \
	std\math.d std\string.d std\path.d std\datetime.d \
	std\ctype.d std\csv.d std\file.d std\compiler.d std\system.d \
	std\outbuffer.d std\md5.d std\base64.d \
	std\mmfile.d \
	std\syserror.d \
	std\regexp.d std\random.d std\stream.d std\process.d \
	std\socket.d std\socketstream.d std\format.d \
	std\stdio.d std\perf.d std\uni.d std\uuid.d \
	std\cstream.d std\demangle.d \
	std\signals.d std\cpuid.d std\typetuple.d std\traits.d \
	std\metastrings.d std\getopt.d \
	std\variant.d std\numeric.d std\bitmanip.d std\complex.d std\mathspecial.d \
	std\functional.d std\algorithm.d std\array.d std\typecons.d \
	std\json.d std\xml.d std\encoding.d std\bigint.d std\concurrency.d \
	std\range.d std\stdiobase.d std\parallelism.d \
	std\regex.d \
	std\exception.d std\ascii.d

SRC_STD_NET= std\net\isemail.d std\net\curl.d

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

SRC_STD_C_FREEBSD= std\c\freebsd\socket.d

SRC_STD_INTERNAL= std\internal\processinit.d std\internal\uni.d std\internal\uni_tab.d

SRC_STD_INTERNAL_MATH= std\internal\math\biguintcore.d \
	std\internal\math\biguintnoasm.d std\internal\math\biguintx86.d \
    std\internal\math\gammafunction.d std\internal\math\errorfunction.d

SRC_STD_INTERNAL_WINDOWS= std\internal\windows\advapi32.d

SRC_ETC=

SRC_ETC_C= etc\c\zlib.d etc\c\curl.d etc\c\sqlite3.d

SRC_TO_COMPILE_NOT_STD= crc32.d \
	$(SRC_STD_NET) \
	$(SRC_STD_C) \
	$(SRC_STD_WIN) \
	$(SRC_STD_C_WIN) \
	$(SRC_STD_INTERNAL) \
	$(SRC_STD_INTERNAL_MATH) \
	$(SRC_STD_INTERNAL_WINDOWS) \
	$(SRC_ETC) \
	$(SRC_ETC_C)

SRC_TO_COMPILE= $(SRC_STD_ALL) \
	$(SRC_TO_COMPILE_NOT_STD)

SRC_ZLIB= \
	etc\c\zlib\crc32.h \
	etc\c\zlib\deflate.h \
	etc\c\zlib\gzguts.h \
	etc\c\zlib\inffixed.h \
	etc\c\zlib\inffast.h \
	etc\c\zlib\inftrees.h \
	etc\c\zlib\inflate.h \
	etc\c\zlib\trees.h \
	etc\c\zlib\zconf.h \
	etc\c\zlib\zlib.h \
	etc\c\zlib\zutil.h \
	etc\c\zlib\adler32.c \
	etc\c\zlib\compress.c \
	etc\c\zlib\crc32.c \
	etc\c\zlib\deflate.c \
	etc\c\zlib\example.c \
	etc\c\zlib\gzclose.c \
	etc\c\zlib\gzlib.c \
	etc\c\zlib\gzread.c \
	etc\c\zlib\gzwrite.c \
	etc\c\zlib\infback.c \
	etc\c\zlib\inffast.c \
	etc\c\zlib\inflate.c \
	etc\c\zlib\inftrees.c \
	etc\c\zlib\minigzip.c \
	etc\c\zlib\trees.c \
	etc\c\zlib\uncompr.c \
	etc\c\zlib\zutil.c \
	etc\c\zlib\algorithm.txt \
	etc\c\zlib\zlib.3 \
	etc\c\zlib\ChangeLog \
	etc\c\zlib\README \
	etc\c\zlib\win32.mak \
	etc\c\zlib\linux.mak \
	etc\c\zlib\osx.mak


DOCS=	$(DOC)\object.html \
	$(DOC)\core_atomic.html \
	$(DOC)\core_bitop.html \
	$(DOC)\core_cpuid.html \
	$(DOC)\core_exception.html \
	$(DOC)\core_memory.html \
	$(DOC)\core_runtime.html \
	$(DOC)\core_simd.html \
	$(DOC)\core_time.html \
	$(DOC)\core_thread.html \
	$(DOC)\core_vararg.html \
	$(DOC)\core_sync_barrier.html \
	$(DOC)\core_sync_condition.html \
	$(DOC)\core_sync_config.html \
	$(DOC)\core_sync_exception.html \
	$(DOC)\core_sync_mutex.html \
	$(DOC)\core_sync_rwmutex.html \
	$(DOC)\core_sync_semaphore.html \
	$(DOC)\std_algorithm.html \
	$(DOC)\std_array.html \
	$(DOC)\std_ascii.html \
	$(DOC)\std_base64.html \
	$(DOC)\std_bigint.html \
	$(DOC)\std_bitmanip.html \
	$(DOC)\std_concurrency.html \
	$(DOC)\std_compiler.html \
	$(DOC)\std_complex.html \
	$(DOC)\std_container.html \
	$(DOC)\std_conv.html \
	$(DOC)\std_cpuid.html \
	$(DOC)\std_cstream.html \
	$(DOC)\std_ctype.html \
	$(DOC)\std_csv.html \
	$(DOC)\std_datetime.html \
	$(DOC)\std_demangle.html \
	$(DOC)\std_encoding.html \
	$(DOC)\std_exception.html \
	$(DOC)\std_file.html \
	$(DOC)\std_format.html \
	$(DOC)\std_functional.html \
	$(DOC)\std_gc.html \
	$(DOC)\std_getopt.html \
	$(DOC)\std_json.html \
	$(DOC)\std_math.html \
	$(DOC)\std_mathspecial.html \
	$(DOC)\std_md5.html \
	$(DOC)\std_metastrings.html \
	$(DOC)\std_mmfile.html \
	$(DOC)\std_numeric.html \
	$(DOC)\std_outbuffer.html \
	$(DOC)\std_parallelism.html \
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
	$(DOC)\std_uuid.html \
	$(DOC)\std_variant.html \
	$(DOC)\std_xml.html \
	$(DOC)\std_zip.html \
	$(DOC)\std_zlib.html \
	$(DOC)\std_net_isemail.html \
	$(DOC)\std_net_curl.html \
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
	$(DOC)\etc_c_curl.html \
	$(DOC)\etc_c_sqlite3.html \
	$(DOC)\etc_c_zlib.html \
	$(DOC)\phobos.html

$(LIB) : $(SRC_TO_COMPILE) \
	etc\c\zlib\zlib.lib $(DRUNTIMELIB) win32.mak
	$(DMD) -lib -of$(LIB) -Xfphobos.json $(DFLAGS) $(SRC_TO_COMPILE) \
		etc\c\zlib\zlib.lib $(DRUNTIMELIB)

UNITTEST_OBJS= unittest1.obj unittest2.obj unittest3.obj unittest4.obj \
		unittest5.obj unittest6.obj

unittest : $(LIB)
	$(DMD) $(UDFLAGS) -L/co -c -unittest -ofunittest1.obj $(SRC_STD_1_HEAVY)
	$(DMD) $(UDFLAGS) -L/co -c -unittest -ofunittest2.obj $(SRC_STD_2_HEAVY)
	$(DMD) $(UDFLAGS) -L/co -c -unittest -ofunittest3.obj $(SRC_STD_3)
	$(DMD) $(UDFLAGS) -L/co -c -unittest -ofunittest4.obj $(SRC_STD_4)
	$(DMD) $(UDFLAGS) -L/co -c -unittest -ofunittest5.obj $(SRC_STD_5_HEAVY)
	$(DMD) $(UDFLAGS) -L/co -c -unittest -ofunittest6.obj $(SRC_STD_REST)
	$(DMD) $(UDFLAGS) -L/co -c -unittest -ofunittest7.obj $(SRC_TO_COMPILE_NOT_STD)
	$(DMD) $(UDFLAGS) -L/co -unittest unittest.d $(UNITTEST_OBJS) unittest7.obj \
		etc\c\zlib\zlib.lib $(DRUNTIMELIB)
	unittest

#unittest : unittest.exe
#	unittest
#
#unittest.exe : unittest.d $(LIB)
#	$(DMD) unittest -g
#	dmc unittest.obj -g

cov : $(SRC_TO_COMPILE) $(LIB)
	$(DMD) -cov -unittest -ofcov.exe unittest.d $(SRC_TO_COMPILE) $(LIB)
	cov

html : $(DOCS)

######################################################

etc\c\zlib\zlib.lib: $(SRC_ZLIB)
	cd etc\c\zlib
	make -f win32.mak zlib.lib
	cd ..\..\..

################## DOCS ####################################

DDOCFLAGS=$(DFLAGS) -version=StdDdoc

$(DOC)\object.html : $(STDDOC) $(DRUNTIME)\src\object_.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\object.html $(STDDOC) $(DRUNTIME)\src\object_.d -I$(DRUNTIME)\src\

$(DOC)\phobos.html : $(STDDOC) index.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\phobos.html $(STDDOC) index.d

$(DOC)\core_atomic.html : $(STDDOC) $(DRUNTIME)\src\core\atomic.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_atomic.html $(STDDOC) $(DRUNTIME)\src\core\atomic.d -I$(DRUNTIME)\src\

$(DOC)\core_bitop.html : $(STDDOC) $(DRUNTIME)\src\core\bitop.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_bitop.html $(STDDOC) $(DRUNTIME)\src\core\bitop.d -I$(DRUNTIME)\src\

$(DOC)\core_cpuid.html : $(STDDOC) $(DRUNTIME)\src\core\cpuid.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_cpuid.html $(STDDOC) $(DRUNTIME)\src\core\cpuid.d -I$(DRUNTIME)\src\

$(DOC)\core_exception.html : $(STDDOC) $(DRUNTIME)\src\core\exception.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_exception.html $(STDDOC) $(DRUNTIME)\src\core\exception.d -I$(DRUNTIME)\src\

$(DOC)\core_memory.html : $(STDDOC) $(DRUNTIME)\src\core\memory.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_memory.html $(STDDOC) $(DRUNTIME)\src\core\memory.d -I$(DRUNTIME)\src\

$(DOC)\core_runtime.html : $(STDDOC) $(DRUNTIME)\src\core\runtime.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_runtime.html $(STDDOC) $(DRUNTIME)\src\core\runtime.d -I$(DRUNTIME)\src\

$(DOC)\core_simd.html : $(STDDOC) $(DRUNTIME)\src\core\simd.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_simd.html $(STDDOC) $(DRUNTIME)\src\core\simd.d -I$(DRUNTIME)\src\

$(DOC)\core_time.html : $(STDDOC) $(DRUNTIME)\src\core\time.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_time.html $(STDDOC) $(DRUNTIME)\src\core\time.d -I$(DRUNTIME)\src\

$(DOC)\core_thread.html : $(STDDOC) $(DRUNTIME)\src\core\thread.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_thread.html $(STDDOC) $(DRUNTIME)\src\core\thread.d -I$(DRUNTIME)\src\

$(DOC)\core_vararg.html : $(STDDOC) $(DRUNTIME)\src\core\vararg.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_vararg.html $(STDDOC) $(DRUNTIME)\src\core\vararg.d -I$(DRUNTIME)\src\

$(DOC)\core_sync_barrier.html : $(STDDOC) $(DRUNTIME)\src\core\sync\barrier.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_sync_barrier.html $(STDDOC) $(DRUNTIME)\src\core\sync\barrier.d -I$(DRUNTIME)\src\

$(DOC)\core_sync_condition.html : $(STDDOC) $(DRUNTIME)\src\core\sync\condition.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_sync_condition.html $(STDDOC) $(DRUNTIME)\src\core\sync\condition.d -I$(DRUNTIME)\src\

$(DOC)\core_sync_config.html : $(STDDOC) $(DRUNTIME)\src\core\sync\config.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_sync_config.html $(STDDOC) $(DRUNTIME)\src\core\sync\config.d -I$(DRUNTIME)\src\

$(DOC)\core_sync_exception.html : $(STDDOC) $(DRUNTIME)\src\core\sync\exception.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_sync_exception.html $(STDDOC) $(DRUNTIME)\src\core\sync\exception.d -I$(DRUNTIME)\src\

$(DOC)\core_sync_mutex.html : $(STDDOC) $(DRUNTIME)\src\core\sync\mutex.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_sync_mutex.html $(STDDOC) $(DRUNTIME)\src\core\sync\mutex.d -I$(DRUNTIME)\src\

$(DOC)\core_sync_rwmutex.html : $(STDDOC) $(DRUNTIME)\src\core\sync\rwmutex.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_sync_rwmutex.html $(STDDOC) $(DRUNTIME)\src\core\sync\rwmutex.d -I$(DRUNTIME)\src\

$(DOC)\core_sync_semaphore.html : $(STDDOC) $(DRUNTIME)\src\core\sync\semaphore.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\core_sync_semaphore.html $(STDDOC) $(DRUNTIME)\src\core\sync\semaphore.d -I$(DRUNTIME)\src\

$(DOC)\std_algorithm.html : $(STDDOC) std\algorithm.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_algorithm.html $(STDDOC) std\algorithm.d

$(DOC)\std_array.html : $(STDDOC) std\array.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_array.html $(STDDOC) std\array.d

$(DOC)\std_ascii.html : $(STDDOC) std\ascii.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_ascii.html $(STDDOC) std\ascii.d

$(DOC)\std_base64.html : $(STDDOC) std\base64.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_base64.html $(STDDOC) std\base64.d

$(DOC)\std_bigint.html : $(STDDOC) std\bigint.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_bigint.html $(STDDOC) std\bigint.d

$(DOC)\std_bitmanip.html : $(STDDOC) std\bitmanip.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_bitmanip.html $(STDDOC) std\bitmanip.d

$(DOC)\std_concurrency.html : $(STDDOC) std\concurrency.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_concurrency.html $(STDDOC) std\concurrency.d

$(DOC)\std_compiler.html : $(STDDOC) std\compiler.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_compiler.html $(STDDOC) std\compiler.d

$(DOC)\std_complex.html : $(STDDOC) std\complex.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_complex.html $(STDDOC) std\complex.d

$(DOC)\std_conv.html : $(STDDOC) std\conv.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_conv.html $(STDDOC) std\conv.d

$(DOC)\std_container.html : $(STDDOC) std\container.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_container.html $(STDDOC) std\container.d

$(DOC)\std_cpuid.html : $(STDDOC) std\cpuid.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_cpuid.html $(STDDOC) std\cpuid.d

$(DOC)\std_cstream.html : $(STDDOC) std\cstream.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_cstream.html $(STDDOC) std\cstream.d

$(DOC)\std_ctype.html : $(STDDOC) std\ctype.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_ctype.html $(STDDOC) std\ctype.d

$(DOC)\std_csv.html : $(STDDOC) std\csv.d
	$(DMD) -c -o- $(DFLAGS) -Df$(DOC)\std_csv.html $(STDDOC) std\csv.d

$(DOC)\std_datetime.html : $(STDDOC) std\datetime.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_datetime.html $(STDDOC) std\datetime.d

$(DOC)\std_demangle.html : $(STDDOC) std\demangle.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_demangle.html $(STDDOC) std\demangle.d

$(DOC)\std_exception.html : $(STDDOC) std\exception.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_exception.html $(STDDOC) std\exception.d

$(DOC)\std_file.html : $(STDDOC) std\file.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_file.html $(STDDOC) std\file.d

$(DOC)\std_format.html : $(STDDOC) std\format.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_format.html $(STDDOC) std\format.d

$(DOC)\std_functional.html : $(STDDOC) std\functional.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_functional.html $(STDDOC) std\functional.d

$(DOC)\std_gc.html : $(STDDOC) $(DRUNTIME)\src\core\memory.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_gc.html $(STDDOC) $(DRUNTIME)\src\core\memory.d

$(DOC)\std_getopt.html : $(STDDOC) std\getopt.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_getopt.html $(STDDOC) std\getopt.d

$(DOC)\std_json.html : $(STDDOC) std\json.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_json.html $(STDDOC) std\json.d

$(DOC)\std_math.html : $(STDDOC) std\math.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_math.html $(STDDOC) std\math.d

$(DOC)\std_mathspecial.html : $(STDDOC) std\mathspecial.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_mathspecial.html $(STDDOC) std\mathspecial.d

$(DOC)\std_md5.html : $(STDDOC) std\md5.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_md5.html $(STDDOC) std\md5.d

$(DOC)\std_metastrings.html : $(STDDOC) std\metastrings.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_metastrings.html $(STDDOC) std\metastrings.d

$(DOC)\std_mmfile.html : $(STDDOC) std\mmfile.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_mmfile.html $(STDDOC) std\mmfile.d

$(DOC)\std_numeric.html : $(STDDOC) std\numeric.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_numeric.html $(STDDOC) std\numeric.d

$(DOC)\std_outbuffer.html : $(STDDOC) std\outbuffer.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_outbuffer.html $(STDDOC) std\outbuffer.d

$(DOC)\std_parallelism.html : $(STDDOC) std\parallelism.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_parallelism.html $(STDDOC) std\parallelism.d

$(DOC)\std_path.html : $(STDDOC) std\path.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_path.html $(STDDOC) std\path.d

$(DOC)\std_perf.html : $(STDDOC) std\perf.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_perf.html $(STDDOC) std\perf.d

$(DOC)\std_process.html : $(STDDOC) std\process.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_process.html $(STDDOC) std\process.d

$(DOC)\std_random.html : $(STDDOC) std\random.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_random.html $(STDDOC) std\random.d

$(DOC)\std_range.html : $(STDDOC) std\range.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_range.html $(STDDOC) std\range.d

$(DOC)\std_regex.html : $(STDDOC) std\regex.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_regex.html $(STDDOC) std\regex.d

$(DOC)\std_regexp.html : $(STDDOC) std\regexp.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_regexp.html $(STDDOC) std\regexp.d

$(DOC)\std_signals.html : $(STDDOC) std\signals.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_signals.html $(STDDOC) std\signals.d

$(DOC)\std_socket.html : $(STDDOC) std\socket.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_socket.html $(STDDOC) std\socket.d

$(DOC)\std_socketstream.html : $(STDDOC) std\socketstream.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_socketstream.html $(STDDOC) std\socketstream.d

$(DOC)\std_stdint.html : $(STDDOC) std\stdint.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_stdint.html $(STDDOC) std\stdint.d

$(DOC)\std_stdio.html : $(STDDOC) std\stdio.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_stdio.html $(STDDOC) std\stdio.d

$(DOC)\std_stream.html : $(STDDOC) std\stream.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_stream.html -d $(STDDOC) std\stream.d

$(DOC)\std_string.html : $(STDDOC) std\string.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_string.html $(STDDOC) std\string.d

$(DOC)\std_system.html : $(STDDOC) std\system.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_system.html $(STDDOC) std\system.d

$(DOC)\std_thread.html : $(STDDOC) $(DRUNTIME)\src\core\thread.d
	$(DMD) -c -o- -d $(DDOCFLAGS) -Df$(DOC)\std_thread.html $(STDDOC) -I$(DRUNTIME)\src $(DRUNTIME)\src\core\thread.d

$(DOC)\std_traits.html : $(STDDOC) std\traits.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_traits.html $(STDDOC) std\traits.d

$(DOC)\std_typecons.html : $(STDDOC) std\typecons.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_typecons.html $(STDDOC) std\typecons.d

$(DOC)\std_typetuple.html : $(STDDOC) std\typetuple.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_typetuple.html $(STDDOC) std\typetuple.d

$(DOC)\std_uni.html : $(STDDOC) std\uni.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_uni.html $(STDDOC) std\uni.d

$(DOC)\std_uri.html : $(STDDOC) std\uri.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_uri.html $(STDDOC) std\uri.d

$(DOC)\std_utf.html : $(STDDOC) std\utf.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_utf.html $(STDDOC) std\utf.d

$(DOC)\std_uuid.html : $(STDDOC) std\uuid.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_uuid.html $(STDDOC) std\uuid.d

$(DOC)\std_variant.html : $(STDDOC) std\variant.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_variant.html $(STDDOC) std\variant.d

$(DOC)\std_xml.html : $(STDDOC) std\xml.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_xml.html $(STDDOC) std\xml.d

$(DOC)\std_encoding.html : $(STDDOC) std\encoding.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_encoding.html $(STDDOC) std\encoding.d

$(DOC)\std_zip.html : $(STDDOC) std\zip.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_zip.html $(STDDOC) std\zip.d

$(DOC)\std_zlib.html : $(STDDOC) std\zlib.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_zlib.html $(STDDOC) std\zlib.d

$(DOC)\std_net_isemail.html : $(STDDOC) std\net\isemail.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_net_isemail.html $(STDDOC) std\net\isemail.d

$(DOC)\std_net_curl.html : $(STDDOC) std\net\curl.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_net_curl.html $(STDDOC) std\net\curl.d

$(DOC)\std_windows_charset.html : $(STDDOC) std\windows\charset.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_windows_charset.html $(STDDOC) std\windows\charset.d

$(DOC)\std_windows_registry.html : $(STDDOC) std\windows\registry.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_windows_registry.html $(STDDOC) std\windows\registry.d

$(DOC)\std_c_fenv.html : $(STDDOC) std\c\fenv.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_c_fenv.html $(STDDOC) std\c\fenv.d

$(DOC)\std_c_locale.html : $(STDDOC) std\c\locale.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_c_locale.html $(STDDOC) std\c\locale.d

$(DOC)\std_c_math.html : $(STDDOC) std\c\math.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_c_math.html $(STDDOC) std\c\math.d

$(DOC)\std_c_process.html : $(STDDOC) std\c\process.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_c_process.html $(STDDOC) std\c\process.d

$(DOC)\std_c_stdarg.html : $(STDDOC) std\c\stdarg.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_c_stdarg.html $(STDDOC) std\c\stdarg.d

$(DOC)\std_c_stddef.html : $(STDDOC) std\c\stddef.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_c_stddef.html $(STDDOC) std\c\stddef.d

$(DOC)\std_c_stdio.html : $(STDDOC) std\c\stdio.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_c_stdio.html $(STDDOC) std\c\stdio.d

$(DOC)\std_c_stdlib.html : $(STDDOC) std\c\stdlib.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_c_stdlib.html $(STDDOC) std\c\stdlib.d

$(DOC)\std_c_string.html : $(STDDOC) std\c\string.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_c_string.html $(STDDOC) std\c\string.d

$(DOC)\std_c_time.html : $(STDDOC) std\c\time.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_c_time.html $(STDDOC) std\c\time.d

$(DOC)\std_c_wcharh.html : $(STDDOC) std\c\wcharh.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_c_wcharh.html $(STDDOC) std\c\wcharh.d

$(DOC)\etc_c_curl.html : $(STDDOC) etc\c\curl.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\etc_c_curl.html $(STDDOC) etc\c\curl.d

$(DOC)\etc_c_sqlite3.html : $(STDDOC) etc\c\sqlite3.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\etc_c_sqlite3.html $(STDDOC) etc\c\sqlite3.d

$(DOC)\etc_c_zlib.html : $(STDDOC) etc\c\zlib.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\etc_c_zlib.html $(STDDOC) etc\c\zlib.d


######################################################

zip : win32.mak posix.mak $(STDDOC) $(SRC) \
	$(SRC_STD) $(SRC_STD_C) $(SRC_STD_WIN) \
	$(SRC_STD_C_WIN) $(SRC_STD_C_LINUX) $(SRC_STD_C_OSX) $(SRC_STD_C_FREEBSD) \
	$(SRC_ETC) $(SRC_ETC_C) $(SRC_ZLIB) $(SRC_STD_NET) \
	$(SRC_STD_INTERNAL) $(SRC_STD_INTERNAL_MATH) $(SRC_STD_INTERNAL_WINDOWS)
	del phobos.zip
	zip32 -u phobos win32.mak posix.mak $(STDDOC)
	zip32 -u phobos $(SRC)
	zip32 -u phobos $(SRC_STD)
	zip32 -u phobos $(SRC_STD_C)
	zip32 -u phobos $(SRC_STD_WIN)
	zip32 -u phobos $(SRC_STD_C_WIN)
	zip32 -u phobos $(SRC_STD_C_LINUX)
	zip32 -u phobos $(SRC_STD_C_OSX)
	zip32 -u phobos $(SRC_STD_C_FREEBSD)
	zip32 -u phobos $(SRC_STD_INTERNAL)
	zip32 -u phobos $(SRC_STD_INTERNAL_MATH)
	zip32 -u phobos $(SRC_STD_INTERNAL_WINDOWS)
	zip32 -u phobos $(SRC_ETC) $(SRC_ETC_C)
	zip32 -u phobos $(SRC_ZLIB)
	zip32 -u phobos $(SRC_STD_NET)

clean:
	cd etc\c\zlib
	make -f win32.mak clean
	cd ..\..\..
	del $(DOCS)
	del $(UNITTEST_OBJS) unittest.obj unittest.exe
	del $(LIB)
	del phobos.json

cleanhtml:
	del $(DOCS)

install:
	$(CP) $(LIB) $(DIR)\windows\lib\ 
	$(CP) $(DRUNTIME)\lib\gcstub.obj $(DIR)\windows\lib\ 
	$(CP) win32.mak posix.mak $(STDDOC) $(DIR)\src\phobos\ 
	$(CP) $(SRC) $(DIR)\src\phobos\ 
	$(CP) $(SRC_STD) $(DIR)\src\phobos\std\ 
	$(CP) $(SRC_STD_NET) $(DIR)\src\phobos\std\net\ 
	$(CP) $(SRC_STD_C) $(DIR)\src\phobos\std\c\ 
	$(CP) $(SRC_STD_WIN) $(DIR)\src\phobos\std\windows\ 
	$(CP) $(SRC_STD_C_WIN) $(DIR)\src\phobos\std\c\windows\ 
	$(CP) $(SRC_STD_C_LINUX) $(DIR)\src\phobos\std\c\linux\ 
	$(CP) $(SRC_STD_C_OSX) $(DIR)\src\phobos\std\c\osx\ 
	$(CP) $(SRC_STD_C_FREEBSD) $(DIR)\src\phobos\std\c\freebsd\ 
	$(CP) $(SRC_STD_INTERNAL) $(DIR)\src\phobos\std\internal\ 
	$(CP) $(SRC_STD_INTERNAL_MATH) $(DIR)\src\phobos\std\internal\math\ 
	$(CP) $(SRC_STD_INTERNAL_WINDOWS) $(DIR)\src\phobos\std\internal\windows\ 
	#$(CP) $(SRC_ETC) $(DIR)\src\phobos\etc\ 
	$(CP) $(SRC_ETC_C) $(DIR)\src\phobos\etc\c\ 
	$(CP) $(SRC_ZLIB) $(DIR)\src\phobos\etc\c\zlib\ 
	$(CP) $(DOCS) $(DIR)\html\d\phobos\ 

svn:
	$(CP) win32.mak posix.mak $(STDDOC) $(SVN)\ 
	$(CP) $(SRC) $(SVN)\ 
	$(CP) $(SRC_STD) $(SVN)\std\ 
	$(CP) $(SRC_STD_NET) $(SVN)\std\net\ 
	$(CP) $(SRC_STD_C) $(SVN)\std\c\ 
	$(CP) $(SRC_STD_WIN) $(SVN)\std\windows\ 
	$(CP) $(SRC_STD_C_WIN) $(SVN)\std\c\windows\ 
	$(CP) $(SRC_STD_C_LINUX) $(SVN)\std\c\linux\ 
	$(CP) $(SRC_STD_C_OSX) $(SVN)\std\c\osx\ 
	$(CP) $(SRC_STD_C_FREEBSD) $(SVN)\std\c\freebsd\ 
	$(CP) $(SRC_STD_INTERNAL) $(SVN)\std\internal\ 
	$(CP) $(SRC_STD_INTERNAL_MATH) $(SVN)\std\internal\math\ 
	$(CP) $(SRC_STD_INTERNAL_WINDOWS) $(SVN)\std\internal\windows\ 
	#$(CP) $(SRC_ETC) $(SVN)\etc\ 
	$(CP) $(SRC_ETC_C) $(SVN)\etc\c\ 
	$(CP) $(SRC_ZLIB) $(SVN)\etc\c\zlib\ 



