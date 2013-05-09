# Makefile to build D runtime library phobos64.lib for Win64
# Prerequisites:
#	Microsoft Visual Studio
# Targets:
#	make
#		Same as make unittest
#	make phobos64.lib
#		Build phobos64.lib
#	make clean
#		Delete unneeded files created by build process
#	make unittest
#		Build phobos64.lib, build and run unit tests
#	make cov
#		Build for coverage tests, run coverage tests
#	make html
#		Build documentation

## Memory model (32 or 64)
MODEL=64

## Copy command

CP=cp

## Directory where dmd has been installed

DIR=\dmd2

## Visual C directories
VCDIR=\Program Files (x86)\Microsoft Visual Studio 10.0\VC
SDKDIR=\Program Files (x86)\Microsoft SDKs\Windows\v7.0A

## Flags for VC compiler

#CFLAGS=/Zi /nologo /I"$(VCDIR)\INCLUDE" /I"$(SDKDIR)\Include"
CFLAGS=/O2 /nologo /I"$(VCDIR)\INCLUDE" /I"$(SDKDIR)\Include"

## Flags for dmd D compiler

DFLAGS=-m$(MODEL) -O -release -w -d -property
#DFLAGS=-m$(MODEL) -unittest -g -d
#DFLAGS=-m$(MODEL) -unittest -cov -g -d

## Flags for compiling unittests

UDFLAGS=-g -m$(MODEL) -O -w -d -property

## C compiler, linker, librarian

CC="$(VCDIR)\bin\amd64\cl"
LD="$(VCDIR)\bin\amd64\link"
AR="$(VCDIR)\bin\amd64\lib"
MAKE=make

## D compiler

DMD=$(DIR)\bin\dmd
#DMD=..\dmd
DMD=dmd

## Location of where to write the html documentation files

DOCSRC = .
STDDOC = $(DOCSRC)/std.ddoc

DOC=..\..\html\d\phobos
#DOC=..\doc\phobos

## Location of druntime tree

DRUNTIME=..\druntime
DRUNTIMELIB=$(DRUNTIME)\lib\druntime64.lib

## Zlib library

ZLIB=etc\c\zlib\zlib$(MODEL).lib

.c.obj:
	$(CC) -c $(CFLAGS) $*.c

.cpp.obj:
	$(CC) -c $(CFLAGS) $*.cpp

.d.obj:
	$(DMD) -c $(DFLAGS) $*

.asm.obj:
	$(CC) -c $*

LIB=phobos$(MODEL).lib

targets : $(LIB)

test : test.exe

test.obj : test.d
	$(DMD) -c -m$(MODEL) test -g -unittest

test.exe : test.obj $(LIB)
	$(DMD) test.obj -m$(MODEL) -g -L/map

#	ti_bit.obj ti_Abit.obj

# The separation is a workaround for bug 4904 (optlink bug 3372).
# SRCS_1 is the heavyweight modules which are most likely to trigger the bug.
# Do not add any more modules to SRCS_1.
SRC_STD_1_HEAVY= std\stdio.d std\stdiobase.d \
	std\string.d std\format.d \
	std\file.d

SRC_STD_2_HEAVY= std\range.d

SRC_STD_2a_HEAVY= std\array.d std\functional.d std\path.d std\outbuffer.d std\utf.d

SRC_STD_math=std\math.d
SRC_STD_3= std\csv.d std\complex.d std\numeric.d std\bigint.d
SRC_STD_3c= std\datetime.d std\metastrings.d std\bitmanip.d std\typecons.d

SRC_STD_3a= std\uni.d std\base64.d std\md5.d std\ascii.d \
    std\demangle.d std\uri.d std\mmfile.d std\getopt.d

SRC_STD_3b= std\signals.d std\typetuple.d std\traits.d \
    std\encoding.d std\xml.d \
    std\random.d \
    std\exception.d \
    std\compiler.d \
    std\system.d std\concurrency.d

#can't place SRC_STD_DIGEST in SRC_STD_REST because of out-of-memory issues
SRC_STD_DIGEST= std\digest\crc.d std\digest\sha.d std\digest\md.d \
    std\digest\ripemd.d std\digest\digest.d
SRC_STD_4= std\uuid.d $(SRC_STD_DIGEST)

SRC_STD_5_HEAVY= std\algorithm.d

SRC_STD_6a=std\variant.d
SRC_STD_6b=std\syserror.d
SRC_STD_6c=std\zlib.d
SRC_STD_6d=std\stream.d
SRC_STD_6e=std\socket.d
SRC_STD_6f=std\socketstream.d
SRC_STD_6g=std\container.d
SRC_STD_6h=std\conv.d
SRC_STD_6i=std\zip.d
SRC_STD_6j=std\cstream.d
SRC_STD_6k=std\regex.d

SRC_STD_7= \
	std\stdint.d \
	std\json.d \
	std\parallelism.d \
	std\mathspecial.d \
	std\process.d

SRC_STD_ALL= $(SRC_STD_1_HEAVY) $(SRC_STD_2_HEAVY) $(SRC_STD_2a_HEAVY) \
	$(SRC_STD_math) \
	$(SRC_STD_3) $(SRC_STD_3a) $(SRC_STD_3b) $(SRC_STD_3c) $(SRC_STD_4) \
	$(SRC_STD_5_HEAVY) \
	$(SRC_STD_6a) \
	$(SRC_STD_6b) \
	$(SRC_STD_6c) \
	$(SRC_STD_6d) \
	$(SRC_STD_6e) \
	$(SRC_STD_6f) \
	$(SRC_STD_6g) \
	$(SRC_STD_6h) \
	$(SRC_STD_6i) \
	$(SRC_STD_6j) \
	$(SRC_STD_6k) \
	$(SRC_STD_7)

SRC=	unittest.d crc32.d index.d

SRC_STD= std\zlib.d std\zip.d std\stdint.d std\container.d std\conv.d std\utf.d std\uri.d \
	std\math.d std\string.d std\path.d std\datetime.d \
	std\csv.d std\file.d std\compiler.d std\system.d \
	std\outbuffer.d std\md5.d std\base64.d \
	std\mmfile.d \
	std\syserror.d \
	std\random.d std\stream.d std\process.d \
	std\socket.d std\socketstream.d std\format.d \
	std\stdio.d std\uni.d std\uuid.d \
	std\cstream.d std\demangle.d \
	std\signals.d std\typetuple.d std\traits.d \
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

SRC_STD_INTERNAL_DIGEST= std\internal\digest\sha_SSSE3.d

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
	$(SRC_STD_INTERNAL_DIGEST) \
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
	etc\c\zlib\win64.mak \
	etc\c\zlib\linux.mak \
	etc\c\zlib\osx.mak


DOCS=	$(DOC)\object.html \
	$(DOC)\core_atomic.html \
	$(DOC)\core_bitop.html \
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
	$(DOC)\std_digest_crc.html \
	$(DOC)\std_digest_sha.html \
	$(DOC)\std_digest_md.html \
	$(DOC)\std_digest_ripemd.html \
	$(DOC)\std_digest_digest.html \
	$(DOC)\std_cstream.html \
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
	$(DOC)\std_process.html \
	$(DOC)\std_random.html \
	$(DOC)\std_range.html \
	$(DOC)\std_regex.html \
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
	$(ZLIB) $(DRUNTIMELIB) win32.mak win64.mak
	$(DMD) -lib -of$(LIB) -Xfphobos.json $(DFLAGS) $(SRC_TO_COMPILE) \
		$(ZLIB) $(DRUNTIMELIB)

UNITTEST_OBJS= unittest1.obj unittest2.obj unittest2a.obj \
	       unittestM.obj \
		unittest3.obj \
		unittest3a.obj \
		unittest3b.obj \
		unittest3c.obj \
		unittest4.obj \
		unittest5.obj \
		unittest6a.obj \
		unittest6b.obj \
		unittest6c.obj \
		unittest6d.obj \
		unittest6e.obj \
		unittest6f.obj \
		unittest6g.obj \
		unittest6h.obj \
		unittest6i.obj \
		unittest6j.obj \
		unittest6k.obj \
		unittest7.obj 

unittest : $(LIB)
	$(DMD) $(UDFLAGS) -c           -ofunittest1.obj $(SRC_STD_1_HEAVY)
	$(DMD) $(UDFLAGS) -c           -ofunittest2.obj $(SRC_STD_2_HEAVY)
	$(DMD) $(UDFLAGS) -c           -ofunittest2a.obj $(SRC_STD_2a_HEAVY)
	$(DMD) $(UDFLAGS) -c           -ofunittestM.obj $(SRC_STD_math)
	$(DMD) $(UDFLAGS) -c           -ofunittest3.obj $(SRC_STD_3)
	$(DMD) $(UDFLAGS) -c -unittest -ofunittest3a.obj $(SRC_STD_3a)
	$(DMD) $(UDFLAGS) -c           -ofunittest3b.obj $(SRC_STD_3b)
	$(DMD) $(UDFLAGS) -c           -ofunittest3c.obj $(SRC_STD_3c)
	$(DMD) $(UDFLAGS) -c           -ofunittest4.obj $(SRC_STD_4)
	$(DMD) $(UDFLAGS) -c           -ofunittest5.obj $(SRC_STD_5_HEAVY)
	$(DMD) $(UDFLAGS) -c           -ofunittest6a.obj $(SRC_STD_6a)
	$(DMD) $(UDFLAGS) -c           -ofunittest6b.obj $(SRC_STD_6b)
	$(DMD) $(UDFLAGS) -c           -ofunittest6c.obj $(SRC_STD_6c)
	$(DMD) $(UDFLAGS) -c           -ofunittest6d.obj $(SRC_STD_6d)
	$(DMD) $(UDFLAGS) -c           -ofunittest6e.obj $(SRC_STD_6e)
	$(DMD) $(UDFLAGS) -c           -ofunittest6h.obj $(SRC_STD_6h)
	$(DMD) $(UDFLAGS) -c           -ofunittest6i.obj $(SRC_STD_6i)
	$(DMD) $(UDFLAGS) -c -unittest -ofunittest6f.obj $(SRC_STD_6f)
	$(DMD) $(UDFLAGS) -c -unittest -ofunittest6g.obj $(SRC_STD_6g)
	$(DMD) $(UDFLAGS) -c -unittest -ofunittest6j.obj $(SRC_STD_6j)
	$(DMD) $(UDFLAGS) -c -unittest -ofunittest6k.obj $(SRC_STD_6k)
	$(DMD) $(UDFLAGS) -c           -ofunittest7.obj $(SRC_STD_7)
	$(DMD) $(UDFLAGS) -c -unittest -ofunittest8.obj $(SRC_TO_COMPILE_NOT_STD)
	$(DMD) $(UDFLAGS)    -unittest unittest.d $(UNITTEST_OBJS) \
	    $(ZLIB) $(DRUNTIMELIB)
	.\unittest.exe

#unittest : unittest.exe
#	unittest
#
#unittest.exe : unittest.d $(LIB)
#	$(DMD) unittest -g
#	dmc unittest.obj -g

cov : $(SRC_TO_COMPILE) $(LIB)
	$(DMD) -m$(MODEL) -cov -unittest -ofcov.exe unittest.d $(SRC_TO_COMPILE) $(LIB)
	cov

html : $(DOCS)

######################################################

$(ZLIB): $(SRC_ZLIB)
	cd etc\c\zlib
	$(MAKE) -f win$(MODEL).mak zlib$(MODEL).lib "CC=\$(CC)"\"" "LIB=\$(AR)"\"" "VCDIR=$(VCDIR)"
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

$(DOC)\std_cstream.html : $(STDDOC) std\cstream.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_cstream.html $(STDDOC) std\cstream.d

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

$(DOC)\std_process.html : $(STDDOC) std\process.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_process.html $(STDDOC) std\process.d

$(DOC)\std_random.html : $(STDDOC) std\random.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_random.html $(STDDOC) std\random.d

$(DOC)\std_range.html : $(STDDOC) std\range.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_range.html $(STDDOC) std\range.d

$(DOC)\std_regex.html : $(STDDOC) std\regex.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_regex.html $(STDDOC) std\regex.d

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

$(DOC)\std_digest_crc.html : $(STDDOC) std\digest\crc.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_digest_crc.html $(STDDOC) std\digest\crc.d

$(DOC)\std_digest_sha.html : $(STDDOC) std\digest\sha.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_digest_sha.html $(STDDOC) std\digest\sha.d

$(DOC)\std_digest_md.html : $(STDDOC) std\digest\md.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_digest_md.html $(STDDOC) std\digest\md.d

$(DOC)\std_digest_ripemd.html : $(STDDOC) std\digest\ripemd.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_digest_ripemd.html $(STDDOC) std\digest\ripemd.d

$(DOC)\std_digest_digest.html : $(STDDOC) std\digest\digest.d
	$(DMD) -c -o- $(DDOCFLAGS) -Df$(DOC)\std_digest_digest.html $(STDDOC) std\digest\digest.d

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

zip : win32.mak win64.mak posix.mak $(STDDOC) $(SRC) \
	$(SRC_STD) $(SRC_STD_C) $(SRC_STD_WIN) \
	$(SRC_STD_C_WIN) $(SRC_STD_C_LINUX) $(SRC_STD_C_OSX) $(SRC_STD_C_FREEBSD) \
	$(SRC_ETC) $(SRC_ETC_C) $(SRC_ZLIB) $(SRC_STD_NET) $(SRC_STD_DIGEST)\
	$(SRC_STD_INTERNAL) $(SRC_STD_INTERNAL_DIGEST) $(SRC_STD_INTERNAL_MATH) \
	$(SRC_STD_INTERNAL_WINDOWS)
	del phobos.zip
	zip32 -u phobos win32.mak win64.mak posix.mak $(STDDOC)
	zip32 -u phobos $(SRC)
	zip32 -u phobos $(SRC_STD)
	zip32 -u phobos $(SRC_STD_C)
	zip32 -u phobos $(SRC_STD_WIN)
	zip32 -u phobos $(SRC_STD_C_WIN)
	zip32 -u phobos $(SRC_STD_C_LINUX)
	zip32 -u phobos $(SRC_STD_C_OSX)
	zip32 -u phobos $(SRC_STD_C_FREEBSD)
	zip32 -u phobos $(SRC_STD_INTERNAL)
	zip32 -u phobos $(SRC_STD_INTERNAL_DIGEST)
	zip32 -u phobos $(SRC_STD_INTERNAL_MATH)
	zip32 -u phobos $(SRC_STD_INTERNAL_WINDOWS)
	zip32 -u phobos $(SRC_ETC) $(SRC_ETC_C)
	zip32 -u phobos $(SRC_ZLIB)
	zip32 -u phobos $(SRC_STD_NET)
	zip32 -u phobos $(SRC_STD_DIGEST)

phobos.zip : zip

clean:
	cd etc\c\zlib
	$(MAKE) -f win$(MODEL).mak clean
	cd ..\..\..
	del $(DOCS)
	del $(UNITTEST_OBJS) unittest.obj unittest.exe
	del $(LIB)
	del phobos.json

cleanhtml:
	del $(DOCS)

install: phobos.zip
	$(CP) phobos.lib phobos64.lib $(DIR)\windows\lib
	$(CP) $(DRUNTIME)\lib\gcstub.obj $(DRUNTIME)\lib\gcstub64.obj $(DIR)\windows\lib
	+rd/s/q $(DIR)\src\phobos
	unzip -o phobos.zip -d $(DIR)\src\phobos
