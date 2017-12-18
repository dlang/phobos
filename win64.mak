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
#	make phobos32mscoff
#		Build phobos32mscoff.lib
#	make unittest32mscoff
#		Build phobos32mscoff.lib, build and run unit tests
#	make cov
#		Build for coverage tests, run coverage tests

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

## Location of druntime tree

DRUNTIME=..\druntime
DRUNTIMELIB=$(DRUNTIME)\lib\druntime$(MODEL).lib

## Flags for dmd D compiler

DFLAGS=-conf= -m$(MODEL) -O -release -w -de -dip25 -I$(DRUNTIME)\import
#DFLAGS=-m$(MODEL) -unittest -g
#DFLAGS=-m$(MODEL) -unittest -cov -g

## Flags for compiling unittests

UDFLAGS=-conf= -g -m$(MODEL) -O -w -dip25 -I$(DRUNTIME)\import -unittest

## C compiler, linker, librarian

CC="$(VCDIR)\bin\amd64\cl"
LD="$(VCDIR)\bin\amd64\link"
AR="$(VCDIR)\bin\amd64\lib"
MAKE=make

## D compiler

DMD_DIR=..\dmd
BUILD=release
OS=windows
DMD=$(DMD_DIR)\generated\$(OS)\$(BUILD)\$(MODEL)\dmd

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
	$(DMD) -conf= -c -m$(MODEL) test -g $(UDFLAGS)

test.exe : test.obj $(LIB)
	$(DMD) -conf= test.obj -m$(MODEL) -g -L/map

SRC_STD= \
	unittest.d \
	index.d
	std\stdio.d \
	std\string.d \
	std\format.d \
	std\file.d
	std\functional.d \
	std\path.d \
	std\outbuffer.d \
	std\utf.d
	std\complex.d \
	std\numeric.d \
	std\bigint.d
	std\base64.d \
	std\ascii.d \
	std\demangle.d \
	std\uri.d \
	std\mmfile.d \
	std\getopt.d
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
	std\typecons.d
	std\variant.d \
	std\zlib.d \
	std\socket.d \
	std\conv.d \
	std\zip.d \
	std\stdint.d \
	std\json.d \
	std\parallelism.d \
	std\mathspecial.d \
	std\process.d
	std\algorithm\package.d \
	std\algorithm\comparison.d \
	std\algorithm\iteration.d \
	std\algorithm\mutation.d
	std\algorithm\searching.d \
	std\algorithm\setops.d
	std\algorithm\sorting.d \
	std\algorithm\internal.d
	std\container\array.d \
	std\container\binaryheap.d \
	std\container\dlist.d \
	std\container\rbtree.d \
	std\container\slist.d \
	std\container\util.d \
	std\container\package.d
	std\datetime\date.d \
	std\datetime\interval.d \
	std\datetime\package.d \
	std\datetime\stopwatch.d \
	std\datetime\systime.d \
	std\datetime\timezone.d
	std\digest\crc.d \
	std\digest\sha.d \
	std\digest\md.d \
	std\digest\ripemd.d \
	std\digest\digest.d \
	std\digest\hmac.d \
	std\digest\murmurhash.d \
	std\digest\package.d
	std\net\isemail.d \
	std\net\curl.d
	std\range\package.d \
	std\range\primitives.d \
	std\range\interfaces.d
	std\regex\internal\ir.d \
	std\regex\package.d \
	std\regex\internal\parser.d \
	std\regex\internal\tests.d \
	std\regex\internal\tests2.d \
	std\regex\internal\backtracking.d \
	std\regex\internal\thompson.d \
	std\regex\internal\kickstart.d \
	std\regex\internal\generator.d
	std\windows\registry.d \
	std\windows\syserror.d \
	std\windows\charset.d
	std\internal\cstring.d \
	std\internal\unicode_tables.d \
	std\internal\unicode_comp.d \
	std\internal\unicode_decomp.d \
	std\internal\unicode_grapheme.d \
	std\internal\unicode_norm.d \
	std\internal\scopebuffer.d \
	std\internal\test\dummyrange.d \
	std\internal\test\range.d
	std\internal\digest\sha_SSSE3.d
	std\internal\math\biguintcore.d \
	std\internal\math\biguintnoasm.d \
	std\internal\math\biguintx86.d \
	std\internal\math\gammafunction.d \
	std\internal\math\errorfunction.d
	std\internal\windows\advapi32.d
	std\experimental\all.d std\experimental\checkedint.d std\experimental\typecons.d
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
	std\experimental\allocator\common.d \
	std\experimental\allocator\gc_allocator.d \
	std\experimental\allocator\mallocator.d \
	std\experimental\allocator\mmap_allocator.d \
	std\experimental\allocator\showcase.d \
	std\experimental\allocator\typed.d \
	std\experimental\allocator\package.d \
	std\experimental\logger\core.d \
	std\experimental\logger\filelogger.d \
	std\experimental\logger\multilogger.d \
	std\experimental\logger\nulllogger.d \
	std\experimental\logger\package.d

SRC_ETC=
	etc\c\zlib.d \
	etc\c\curl.d \
	etc\c\sqlite3.d \
	etc\c\odbc\sql.d \
	etc\c\odbc\sqlext.d \
	etc\c\odbc\sqltypes.d \
	etc\c\odbc\sqlucode.d

SRC_TO_COMPILE= \
	$(SRC_STD) \
	$(SRC_ETC) \

SRC=$(SRC_TO_COMPILE)

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

$(LIB) : $(SRC_TO_COMPILE) \
	$(ZLIB) $(DRUNTIMELIB) win32.mak win64.mak
	$(DMD) -lib -of$(LIB) -Xfphobos.json $(DFLAGS) $(SRC_TO_COMPILE) \
		$(ZLIB) $(DRUNTIMELIB)

unittest : $(LIB)
	$(DMD) $(UDFLAGS) -L/OPT:NOICF -unittest -ofunittest.exe $(SRC) $(ZLIB) $(DRUNTIMELIB)
	.\unittest.exe

#unittest : unittest.exe
#	unittest
#
#unittest.exe : unittest.d $(LIB)
#	$(DMD) -conf= unittest -g
#	dmc unittest.obj -g

cov : $(SRC_TO_COMPILE) $(LIB)
	$(DMD) -conf= -m$(MODEL) -cov $(UDFLAGS) -ofcov.exe unittest.d $(SRC_TO_COMPILE) $(LIB)
	cov

################### Win32 COFF support #########################

# default to 32-bit compiler relative to the location of the 64-bit compiler,
# link and lib are architecture agnostic
CC32=$(CC)\..\..\cl

# build phobos32mscoff.lib
phobos32mscoff:
	$(MAKE) -f win64.mak "DMD=$(DMD)" "MAKE=$(MAKE)" MODEL=32mscoff "CC=\$(CC32)"\"" "AR=\$(AR)"\"" "VCDIR=$(VCDIR)" "SDKDIR=$(SDKDIR)"

# run unittests for 32-bit COFF version
unittest32mscoff:
	$(MAKE) -f win64.mak "DMD=$(DMD)" "MAKE=$(MAKE)" MODEL=32mscoff "CC=\$(CC32)"\"" "AR=\$(AR)"\"" "VCDIR=$(VCDIR)" "SDKDIR=$(SDKDIR)" unittest

######################################################

$(ZLIB): $(SRC_ZLIB)
	cd etc\c\zlib
	$(MAKE) -f win64.mak MODEL=$(MODEL) zlib$(MODEL).lib "CC=\$(CC)"\"" "LIB=\$(AR)"\"" "VCDIR=$(VCDIR)"
	cd ..\..\..

######################################################

zip:
	del phobos.zip
	zip32 -r phobos.zip . -x .git\* -x \*.lib -x \*.obj

phobos.zip : zip

clean:
	cd etc\c\zlib
	$(MAKE) -f win64.mak MODEL=$(MODEL) clean
	cd ..\..\..
	del $(DOCS)
	del $(UNITTEST_OBJS) unittest.obj unittest.exe
	del $(LIB)
	del phobos.json

install: phobos.zip
	$(CP) phobos.lib phobos64.lib $(DIR)\windows\lib
	+rd/s/q $(DIR)\src\phobos
	unzip -o phobos.zip -d $(DIR)\src\phobos

auto-tester-build: targets

auto-tester-test: unittest
