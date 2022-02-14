# Makefile to build D runtime library phobos.lib for Win32 OMF
# MS COFF builds use win64.mak for 32 and 64 bit
#
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
# Notes:
#	minit.obj requires Microsoft MASM386.EXE to build from minit.asm,
#	or just use the supplied minit.obj

# Ignored, only the default value is supported
# MODEL=32omf

## Copy command

CP=cp

## Directory where dmd has been installed

DIR=\dmd2

## Flags for dmc C compiler

CFLAGS=-mn -6 -r
#CFLAGS=-g -mn -6 -r

## Location of druntime tree

DRUNTIME=../druntime
DRUNTIMELIB=$(DRUNTIME)/lib/druntime.lib

## Flags for dmd D compiler

DFLAGS=-m32omf -conf= -O -release -w -de -preview=dip1000 -preview=dtorfields -preview=fieldwise -I$(DRUNTIME)\import
#DFLAGS=-unittest -g
#DFLAGS=-unittest -cov -g

## Flags for compiling unittests

UDFLAGS=-m32omf -unittest -version=StdUnittest -version=CoreUnittest -conf= -O -w -preview=dip1000 -preview=fieldwise -I$(DRUNTIME)\import

## C compiler

CC=dmc
AR=lib
MAKE=make

## D compiler

DMD_DIR=../dmd
BUILD=release
OS=windows
DMD=$(DMD_DIR)/generated/$(OS)/$(BUILD)/32/dmd

## Zlib library

ZLIB=etc\c\zlib\zlib.lib

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
	$(DMD) -conf= -c test -g $(UDFLAGS)

test.exe : test.obj $(LIB)
	$(DMD) -conf= test.obj -g -L/map

#	ti_bit.obj ti_Abit.obj

SRC= \
	unittest.d \
	index.dd

# The separation is a workaround for bug 4904 (optlink bug 3372).
SRC_STD_1= \
	std\stdio.d \
	std\string.d \
	std\file.d

SRC_STD_2a= \
	std\array.d \
	std\functional.d \
	std\path.d \
	std\outbuffer.d \
	std\utf.d

SRC_STD_3= \
	std\csv.d \
	std\complex.d \
	std\numeric.d \
	std\bigint.d \
	std\bitmanip.d \
	std\typecons.d \
	std\base64.d \
	std\ascii.d \
	std\demangle.d \
	std\uri.d \
	std\mmfile.d \
	std\getopt.d

SRC_STD_3a= \
	std\signals.d \
	std\meta.d \
	std\typetuple.d \
	std\traits.d \
	std\encoding.d \
	std\xml.d \
	std\random.d \
	std\exception.d \
	std\compiler.d \
	std\system.d \
	std\concurrency.d

SRC_STD_4= \
	std\uuid.d

SRC_STD_6= \
	std\variant.d \
	std\zlib.d \
	std\socket.d \
	std\conv.d \
	std\zip.d

SRC_STD_7= \
	std\stdint.d \
	std\json.d \
	std\parallelism.d \
	std\mathspecial.d \
	std\process.d \
	std\package.d

SRC_STD_7a= \
	std\sumtype.d

SRC_STD= \
	$(SRC_STD_1) \
	$(SRC_STD_2a) \
	$(SRC_STD_3) \
	$(SRC_STD_3a) \
	$(SRC_STD_4) \
	$(SRC_STD_6) \
	$(SRC_STD_7) \
	$(SRC_STD_7a)

SRC_STD_ALGO= \
	std\algorithm\package.d \
	std\algorithm\comparison.d \
	std\algorithm\iteration.d \
	std\algorithm\mutation.d \
	std\algorithm\searching.d \
	std\algorithm\setops.d \
	std\algorithm\sorting.d \
	std\algorithm\internal.d

SRC_STD_CONTAINER= \
	std\container\array.d \
	std\container\binaryheap.d \
	std\container\dlist.d \
	std\container\rbtree.d \
	std\container\slist.d \
	std\container\util.d \
	std\container\package.d

SRC_STD_DATETIME= \
	std\datetime\date.d \
	std\datetime\interval.d \
	std\datetime\package.d \
	std\datetime\stopwatch.d \
	std\datetime\systime.d \
	std\datetime\timezone.d

SRC_STD_DIGEST= \
	std\digest\crc.d \
	std\digest\sha.d \
	std\digest\md.d \
	std\digest\ripemd.d \
	std\digest\digest.d \
	std\digest\hmac.d \
	std\digest\murmurhash.d \
	std\digest\package.d

SRC_STD_FORMAT= \
    std\format\package.d \
    std\format\read.d \
    std\format\spec.d \
    std\format\write.d \
    std\format\internal\floats.d \
    std\format\internal\read.d \
    std\format\internal\write.d

SRC_STD_MATH= \
    std\math\algebraic.d \
    std\math\constants.d \
    std\math\exponential.d \
    std\math\operations.d \
    std\math\hardware.d \
    std\math\package.d \
    std\math\remainder.d \
    std\math\rounding.d \
    std\math\traits.d \
    std\math\trigonometry.d

SRC_STD_NET= \
	std\net\isemail.d \
	std\net\curl.d

SRC_STD_RANGE= \
	std\range\package.d \
	std\range\primitives.d \
	std\range\interfaces.d

SRC_STD_REGEX= \
	std\regex\internal\ir.d \
	std\regex\package.d \
	std\regex\internal\parser.d \
	std\regex\internal\tests.d \
	std\regex\internal\tests2.d \
	std\regex\internal\backtracking.d \
	std\regex\internal\thompson.d \
	std\regex\internal\kickstart.d \
	std\regex\internal\generator.d

SRC_STD_WIN= \
	std\windows\registry.d \
	std\windows\syserror.d \
	std\windows\charset.d

SRC_STD_INTERNAL= \
	std\internal\cstring.d \
	std\internal\unicode_tables.d \
	std\internal\unicode_comp.d \
	std\internal\unicode_decomp.d \
	std\internal\unicode_grapheme.d \
	std\internal\unicode_norm.d \
	std\internal\scopebuffer.d \
	std\internal\test\dummyrange.d \
	std\internal\test\range.d

SRC_STD_INTERNAL_DIGEST= \
	std\internal\digest\sha_SSSE3.d

SRC_STD_INTERNAL_MATH= \
	std\internal\math\biguintcore.d \
	std\internal\math\biguintnoasm.d \
	std\internal\math\biguintx86.d \
	std\internal\math\gammafunction.d \
	std\internal\math\errorfunction.d

SRC_STD_INTERNAL_WINDOWS= \
	std\internal\windows\advapi32.d

SRC_STD_EXP= \
	std\checkedint.d std\experimental\checkedint.d std\experimental\typecons.d

SRC_STD_UNI = std\uni\package.d \

SRC_STD_EXP_ALLOC_BB= \
	std\experimental\allocator\building_blocks\affix_allocator.d \
	std\experimental\allocator\building_blocks\aligned_block_list.d \
	std\experimental\allocator\building_blocks\allocator_list.d \
	std\experimental\allocator\building_blocks\ascending_page_allocator.d \
	std\experimental\allocator\building_blocks\bitmapped_block.d \
	std\experimental\allocator\building_blocks\bucketizer.d \
	std\experimental\allocator\building_blocks\fallback_allocator.d \
	std\experimental\allocator\building_blocks\free_list.d \
	std\experimental\allocator\building_blocks\free_tree.d \
	std\experimental\allocator\building_blocks\kernighan_ritchie.d \
	std\experimental\allocator\building_blocks\null_allocator.d \
	std\experimental\allocator\building_blocks\quantizer.d \
	std\experimental\allocator\building_blocks\region.d \
	std\experimental\allocator\building_blocks\scoped_allocator.d \
	std\experimental\allocator\building_blocks\segregator.d \
	std\experimental\allocator\building_blocks\stats_collector.d \
	std\experimental\allocator\building_blocks\package.d

SRC_STD_EXP_ALLOC= \
	std\experimental\allocator\common.d \
	std\experimental\allocator\gc_allocator.d \
	std\experimental\allocator\mallocator.d \
	std\experimental\allocator\mmap_allocator.d \
	std\experimental\allocator\showcase.d \
	std\experimental\allocator\typed.d \
	std\experimental\allocator\package.d \
	$(SRC_STD_EXP_ALLOC_BB)

SRC_STD_EXP_LOGGER= \
	std\experimental\logger\core.d \
	std\experimental\logger\filelogger.d \
	std\experimental\logger\multilogger.d \
	std\experimental\logger\nulllogger.d \
	std\experimental\logger\package.d

SRC_ETC=

SRC_ETC_C= \
	etc\c\zlib.d \
	etc\c\curl.d \
	etc\c\sqlite3.d \
	etc\c\odbc\sql.d \
	etc\c\odbc\sqlext.d \
	etc\c\odbc\sqltypes.d \
	etc\c\odbc\sqlucode.d

SRC_TO_COMPILE= \
	$(SRC_STD) \
	$(SRC_STD_ALGO) \
	$(SRC_STD_CONTAINER) \
	$(SRC_STD_DATETIME) \
	$(SRC_STD_DIGEST) \
	$(SRC_STD_FORMAT) \
	$(SRC_STD_MATH) \
	$(SRC_STD_NET) \
	$(SRC_STD_RANGE) \
	$(SRC_STD_REGEX) \
	$(SRC_STD_C) \
	$(SRC_STD_WIN) \
	$(SRC_STD_C_WIN) \
	$(SRC_STD_INTERNAL) \
	$(SRC_STD_INTERNAL_DIGEST) \
	$(SRC_STD_INTERNAL_MATH) \
	$(SRC_STD_INTERNAL_WINDOWS) \
	$(SRC_STD_EXP) \
	$(SRC_STD_UNI) \
	$(SRC_STD_EXP_ALLOC) \
	$(SRC_STD_EXP_LOGGER) \
	$(SRC_ETC) \
	$(SRC_ETC_C)

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
	etc\c\zlib\gzclose.c \
	etc\c\zlib\gzlib.c \
	etc\c\zlib\gzread.c \
	etc\c\zlib\gzwrite.c \
	etc\c\zlib\infback.c \
	etc\c\zlib\inffast.c \
	etc\c\zlib\inflate.c \
	etc\c\zlib\inftrees.c \
	etc\c\zlib\trees.c \
	etc\c\zlib\uncompr.c \
	etc\c\zlib\zutil.c

$(LIB) : $(SRC_TO_COMPILE) \
	$(ZLIB) $(DRUNTIMELIB) win32.mak win64.mak
	$(DMD) -lib -of$(LIB) -Xfphobos.json $(DFLAGS) $(SRC_TO_COMPILE) \
		$(ZLIB) $(DRUNTIMELIB)

UNITTEST_OBJS= \
		unittest1.obj \
		unittest2.obj \
		unittest2a.obj \
		unittest3.obj \
		unittest3a.obj \
		unittest3b.obj \
		unittest4.obj \
		unittest5.obj \
		unittest5a.obj \
		unittest5b.obj \
		unittest6.obj \
		unittest6a.obj \
		unittest6b.obj \
		unittest7.obj \
		unittest7a.obj \
		unittest8a.obj \
		unittest8b.obj \
		unittest8c.obj \
		unittest8d.obj \
		unittest8e.obj \
		unittest8f.obj

unittest : $(LIB)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest1.obj $(SRC_STD_1)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest2.obj $(SRC_STD_RANGE)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest2a.obj $(SRC_STD_2a)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest3.obj $(SRC_STD_3)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest3a.obj $(SRC_STD_3a)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest3b.obj $(SRC_STD_DATETIME)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest4.obj $(SRC_STD_4) $(SRC_STD_DIGEST)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest5.obj $(SRC_STD_ALGO)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest5a.obj $(SRC_STD_FORMAT)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest5b.obj $(SRC_STD_MATH)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest6.obj $(SRC_STD_6) $(SRC_STD_CONTAINER)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest6a.obj $(SRC_STD_EXP_ALLOC)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest6b.obj $(SRC_STD_EXP_LOGGER)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest7.obj $(SRC_STD_7)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest7a.obj $(SRC_STD_7a)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest8a.obj $(SRC_STD_REGEX)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest8b.obj $(SRC_STD_NET)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest8c.obj $(SRC_STD_C) $(SRC_STD_WIN) $(SRC_STD_C_WIN)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest8d.obj $(SRC_STD_INTERNAL) $(SRC_STD_INTERNAL_DIGEST) $(SRC_STD_INTERNAL_MATH) $(SRC_STD_INTERNAL_WINDOWS)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest8e.obj $(SRC_ETC) $(SRC_ETC_C)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest8f.obj $(SRC_STD_EXP)
	$(DMD) $(UDFLAGS) -L/co  unittest.d $(UNITTEST_OBJS) \
		$(ZLIB) $(DRUNTIMELIB)
	.\unittest.exe

#unittest : unittest.exe
#	unittest
#
#unittest.exe : unittest.d $(LIB)
#	$(DMD) -conf= unittest -g
#	dmc unittest.obj -g

cov : $(SRC_TO_COMPILE) $(LIB)
#	$(DMD) -conf= -cov=ctfe -cov $(UDFLAGS) -ofcov.exe -main $(SRC_TO_COMPILE) $(LIB)
#	cov
	del *.lst
	$(DMD) -conf= -cov=ctfe -cov=83 $(UDFLAGS) -main -run std\stdio.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\string.d
	$(DMD) -conf= -cov=ctfe -cov=83 $(UDFLAGS) -main -run std\file.d
	$(DMD) -conf= -cov=ctfe -cov=86 $(UDFLAGS) -main -run std\range\package.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\array.d
	$(DMD) -conf= -cov=ctfe -cov=100 $(UDFLAGS) -main -run std\functional.d
	$(DMD) -conf= -cov=ctfe -cov=96 $(UDFLAGS) -main -run std\path.d
	$(DMD) -conf= -cov=ctfe -cov=41 $(UDFLAGS) -main -run std\outbuffer.d
	$(DMD) -conf= -cov=ctfe -cov=89 $(UDFLAGS) -main -run std\utf.d
	$(DMD) -conf= -cov=ctfe -cov=93 $(UDFLAGS) -main -run std\csv.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\complex.d
	$(DMD) -conf= -cov=ctfe -cov=70 $(UDFLAGS) -main -run std\numeric.d
	$(DMD) -conf= -cov=ctfe -cov=94 $(UDFLAGS) -main -run std\bigint.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\bitmanip.d
	$(DMD) -conf= -cov=ctfe -cov=82 $(UDFLAGS) -main -run std\typecons.d
	$(DMD) -conf= -cov=ctfe -cov=44 $(UDFLAGS) -main -run std\uni\package.d
	$(DMD) -conf= -cov=ctfe -cov=91 $(UDFLAGS) -main -run std\base64.d
	$(DMD) -conf= -cov=ctfe -cov=100 $(UDFLAGS) -main -run std\ascii.d
	$(DMD) -conf= -cov=ctfe -cov=0  $(UDFLAGS) -main -run std\demangle.d
	$(DMD) -conf= -cov=ctfe -cov=57 $(UDFLAGS) -main -run std\uri.d
	$(DMD) -conf= -cov=ctfe -cov=51 $(UDFLAGS) -main -run std\mmfile.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\getopt.d
	$(DMD) -conf= -cov=ctfe -cov=92 $(UDFLAGS) -main -run std\signals.d
	$(DMD) -conf= -cov=ctfe -cov=100 $(UDFLAGS) -main -run std\meta.d
	$(DMD) -conf= -cov=ctfe -cov=100 $(UDFLAGS) -main -run std\typetuple.d
	$(DMD) -conf= -cov=ctfe -cov=85 $(UDFLAGS) -main -run std\traits.d
	$(DMD) -conf= -cov=ctfe -cov=62 $(UDFLAGS) -main -run std\encoding.d
	$(DMD) -conf= -cov=ctfe -cov=61 $(UDFLAGS) -main -run std\xml.d
	$(DMD) -conf= -cov=ctfe -cov=79 $(UDFLAGS) -main -run std\random.d
	$(DMD) -conf= -cov=ctfe -cov=92 $(UDFLAGS) -main -run std\exception.d
	$(DMD) -conf= -cov=ctfe -cov=73 $(UDFLAGS) -main -run std\concurrency.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\datetime\date.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\datetime\interval.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\datetime\package.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\datetime\stopwatch.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\datetime\systime.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\datetime\timezone.d
	$(DMD) -conf= -cov=ctfe -cov=96 $(UDFLAGS) -main -run std\uuid.d
	$(DMD) -conf= -cov=ctfe -cov=100 $(UDFLAGS) -main -run std\digest\crc.d
	$(DMD) -conf= -cov=ctfe -cov=55 $(UDFLAGS) -main -run std\digest\sha.d
	$(DMD) -conf= -cov=ctfe -cov=100 $(UDFLAGS) -main -run std\digest\md.d
	$(DMD) -conf= -cov=ctfe -cov=100 $(UDFLAGS) -main -run std\digest\ripemd.d
	$(DMD) -conf= -cov=ctfe -cov=75 $(UDFLAGS) -main -run std\digest\digest.d
	$(DMD) -conf= -cov=ctfe -cov=100 $(UDFLAGS) -main -run std\digest\hmac.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\algorithm\package.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\algorithm\comparison.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\algorithm\iteration.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\algorithm\mutation.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\algorithm\searching.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\algorithm\setops.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\algorithm\sorting.d
	$(DMD) -conf= -cov=ctfe -cov=71 $(UDFLAGS) -main -run std\format\package.d
	$(DMD) -conf= -cov=ctfe -cov=71 $(UDFLAGS) -main -run std\math\package.d
	$(DMD) -conf= -cov=ctfe -cov=83 $(UDFLAGS) -main -run std\variant.d
	$(DMD) -conf= -cov=ctfe -cov=58 $(UDFLAGS) -main -run std\zlib.d
	$(DMD) -conf= -cov=ctfe -cov=53 $(UDFLAGS) -main -run std\socket.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\container\array.d
	$(DMD) -conf= -cov=ctfe -cov=68 $(UDFLAGS) -main -run std\container\binaryheap.d
	$(DMD) -conf= -cov=ctfe -cov=91 $(UDFLAGS) -main -run std\container\dlist.d
	$(DMD) -conf= -cov=ctfe -cov=93 $(UDFLAGS) -main -run std\container\rbtree.d
	$(DMD) -conf= -cov=ctfe -cov=92 $(UDFLAGS) -main -run std\container\slist.d
	$(DMD) -conf= -cov=ctfe -cov=100 $(UDFLAGS) -main -run std\container\util.d
	$(DMD) -conf= -cov=ctfe -cov=100 $(UDFLAGS) -main -run std\container\package.d
	$(DMD) -conf= -cov=ctfe -cov=90 $(UDFLAGS) -main -run std\conv.d
	$(DMD) -conf= -cov=ctfe -cov=0  $(UDFLAGS) -main -run std\zip.d
	$(DMD) -conf= -cov=ctfe -cov=77 $(UDFLAGS) -main -run std\regex\tests.d
	$(DMD) -conf= -cov=ctfe -cov=77 $(UDFLAGS) -main -run std\regex\tests2.d
	$(DMD) -conf= -cov=ctfe -cov=92 $(UDFLAGS) -main -run std\json.d
	$(DMD) -conf= -cov=ctfe -cov=87 $(UDFLAGS) -main -run std\parallelism.d
	$(DMD) -conf= -cov=ctfe -cov=50 $(UDFLAGS) -main -run std\mathspecial.d
	$(DMD) -conf= -cov=ctfe -cov=71 $(UDFLAGS) -main -run std\process.d
	$(DMD) -conf= -cov=ctfe -cov=70 $(UDFLAGS) -main -run std\net\isemail.d
	$(DMD) -conf= -cov=ctfe -cov=2  $(UDFLAGS) -main -run std\net\curl.d
	$(DMD) -conf= -cov=ctfe -cov=60 $(UDFLAGS) -main -run std\windows\registry.d
	$(DMD) -conf= -cov=ctfe -cov=0  $(UDFLAGS) -main -run std\internal\digest\sha_SSSE3.d
	$(DMD) -conf= -cov=ctfe -cov=50 $(UDFLAGS) -main -run std\internal\math\biguintcore.d
	$(DMD) -conf= -cov=ctfe -cov=75 $(UDFLAGS) -main -run std\internal\math\biguintnoasm.d
#	$(DMD) -conf= -cov=ctfe -cov $(UDFLAGS) -main -run std\internal\math\biguintx86.d
	$(DMD) -conf= -cov=ctfe -cov=94 $(UDFLAGS) -main -run std\internal\math\gammafunction.d
	$(DMD) -conf= -cov=ctfe -cov=92 $(UDFLAGS) -main -run std\internal\math\errorfunction.d
	$(DMD) -conf= -cov=ctfe -cov=31 $(UDFLAGS) -main -run std\internal\windows\advapi32.d
	$(DMD) -conf= -cov=ctfe -cov=58 $(UDFLAGS) -main -run etc\c\zlib.d
	$(DMD) -conf= -cov=ctfe -cov=95 $(UDFLAGS) -main -run std\sumtype.d

######################################################

$(ZLIB): $(SRC_ZLIB)
	cd etc\c\zlib
	$(MAKE) -f win32.mak zlib.lib CC=$(CC) LIB=$(AR)
	cd ..\..\..

######################################################

zip:
	del phobos.zip
	zip32 -r phobos.zip . -x .git\* -x \*.lib -x \*.obj

phobos.zip : zip

clean:
	cd etc\c\zlib
	$(MAKE) -f win32.mak clean
	cd ..\..\..
	del $(DOCS)
	del $(UNITTEST_OBJS) unittest.obj unittest.exe
	del $(LIB)
	del phobos.json

install: phobos.zip
	$(CP) phobos.lib phobos64.lib $(DIR)\windows\lib
	+rd/s/q $(DIR)\src\phobos
	unzip -o phobos.zip -d $(DIR)\src\phobos

auto-tester-build:
	echo "Windows builds have been disabled on auto-tester"

auto-tester-test:
	echo "Windows builds have been disabled on auto-tester"
