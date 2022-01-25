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

DRUNTIME=../druntime
DRUNTIMELIB=$(DRUNTIME)/lib/druntime$(MODEL).lib

## Flags for dmd D compiler

DFLAGS=-conf= -m$(MODEL) -O -release -w -de -preview=dip1000 -preview=dtorfields -preview=fieldwise -I$(DRUNTIME)\import
#DFLAGS=-m$(MODEL) -unittest -g
#DFLAGS=-m$(MODEL) -unittest -cov -g

## Flags for compiling unittests

UDFLAGS=-conf= -g -m$(MODEL) -O -w -preview=dip1000 -preview=fieldwise -I$(DRUNTIME)\import -unittest -version=StdUnittest -version=CoreUnittest

## C compiler, linker, librarian

CC=$(VCDIR)\bin\amd64\cl
LD=$(VCDIR)\bin\amd64\link
AR=$(VCDIR)\bin\amd64\lib
MAKE=make

## D compiler

DMD_DIR=../dmd
BUILD=release
OS=windows
DMD=$(DMD_DIR)/generated/$(OS)/$(BUILD)/$(MODEL)/dmd

## Zlib library

ZLIB=etc\c\zlib\zlib$(MODEL).lib

.c.obj:
	"$(CC)" -c $(CFLAGS) $*.c

.cpp.obj:
	"$(CC)" -c $(CFLAGS) $*.cpp

.d.obj:
	"$(DMD)" -c $(DFLAGS) $*

.asm.obj:
	"$(CC)" -c $*

LIB=phobos$(MODEL).lib

targets : $(LIB)

test : test.exe

test.obj : test.d
	"$(DMD)" -conf= -c -m$(MODEL) test -g $(UDFLAGS)

test.exe : test.obj $(LIB)
	"$(DMD)" -conf= test.obj -m$(MODEL) -g -L/map

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
	std\bigint.d

SRC_STD_3b= \
	std\base64.d \
	std\ascii.d \
	std\demangle.d \
	std\uri.d \
	std\mmfile.d \
	std\getopt.d

SRC_STD_3c= \
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

SRC_STD_3d= \
	std\bitmanip.d \
	std\typecons.d

SRC_STD_4= \
	std\uuid.d

SRC_STD_6a=std\variant.d
SRC_STD_6c=std\zlib.d
SRC_STD_6e=std\socket.d
SRC_STD_6h=std\conv.d
SRC_STD_6i=std\zip.d

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
	$(SRC_STD_3b) \
	$(SRC_STD_3c) \
	$(SRC_STD_3d) \
	$(SRC_STD_4) \
	$(SRC_STD_6a) \
	$(SRC_STD_6c) \
	$(SRC_STD_6e) \
	$(SRC_STD_6h) \
	$(SRC_STD_6i) \
	$(SRC_STD_7) \
	$(SRC_STD_7a)

SRC_STD_ALGO_1= \
	std\algorithm\package.d \
	std\algorithm\comparison.d \
	std\algorithm\iteration.d \
	std\algorithm\mutation.d

SRC_STD_ALGO_2= \
	std\algorithm\searching.d \
	std\algorithm\setops.d

SRC_STD_ALGO_3= \
	std\algorithm\sorting.d \
	std\algorithm\internal.d

SRC_STD_ALGO= \
	$(SRC_STD_ALGO_1) \
	$(SRC_STD_ALGO_2) \
	$(SRC_STD_ALGO_3)

SRC_STD_FORMAT= \
    std\format\package.d \
    std\format\read.d \
    std\format\spec.d \
    std\format\write.d \
    std\format\internal\floats.d \
    std\format\internal\read.d \
    std\format\internal\write.d

SRC_STD_MATH = \
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

SRC_STD_UNI = std\uni\package.d

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
	$(SRC_STD_UNI) \
	$(SRC_STD_EXP) \
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
	"$(DMD)" -lib -of$(LIB) -Xfphobos.json $(DFLAGS) $(SRC_TO_COMPILE) \
		$(ZLIB) $(DRUNTIMELIB)

UNITTEST_OBJS= \
		unittest1.obj \
		unittest2.obj \
		unittest2a.obj \
		unittest3.obj \
		unittest3b.obj \
		unittest3c.obj \
		unittest3d.obj \
		unittest4.obj \
		unittest5a.obj \
		unittest5b.obj \
		unittest5c.obj \
		unittest5d.obj \
		unittest5e.obj \
		unittest6a.obj \
		unittest6c.obj \
		unittest6e.obj \
		unittest6g.obj \
		unittest6h.obj \
		unittest6i.obj \
		unittest7.obj \
		unittest7a.obj \
		unittest8a.obj \
		unittest8b.obj \
		unittest8c.obj \
		unittest8d.obj \
		unittest8e.obj \
		unittest8f.obj \
		unittest9.obj

unittest : $(LIB)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest1.obj $(SRC_STD_1)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest2.obj $(SRC_STD_RANGE)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest2a.obj $(SRC_STD_2a)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest3.obj $(SRC_STD_3)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest3b.obj $(SRC_STD_3b)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest3c.obj $(SRC_STD_3c)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest3d.obj $(SRC_STD_3d) $(SRC_STD_DATETIME)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest4.obj $(SRC_STD_4) $(SRC_STD_DIGEST)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest5a.obj $(SRC_STD_ALGO_1)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest5b.obj $(SRC_STD_ALGO_2)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest5c.obj $(SRC_STD_ALGO_3)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest5d.obj $(SRC_STD_FORMAT)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest5e.obj $(SRC_STD_MATH)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest6a.obj $(SRC_STD_6a)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest6c.obj $(SRC_STD_6c)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest6e.obj $(SRC_STD_6e)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest6g.obj $(SRC_STD_CONTAINER)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest6h.obj $(SRC_STD_6h)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest6i.obj $(SRC_STD_6i)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest7.obj $(SRC_STD_7) $(SRC_STD_EXP_LOGGER)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest7a.obj $(SRC_STD_7a)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest8a.obj $(SRC_STD_REGEX)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest8b.obj $(SRC_STD_NET)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest8c.obj $(SRC_STD_C) $(SRC_STD_WIN) $(SRC_STD_C_WIN)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest8d.obj $(SRC_STD_INTERNAL) $(SRC_STD_INTERNAL_DIGEST) $(SRC_STD_INTERNAL_MATH) $(SRC_STD_INTERNAL_WINDOWS)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest8e.obj $(SRC_ETC) $(SRC_ETC_C)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest8f.obj $(SRC_STD_EXP)
	"$(DMD)" $(UDFLAGS) -c  -ofunittest9.obj $(SRC_STD_EXP_ALLOC)
	"$(DMD)" $(UDFLAGS) unittest.d $(UNITTEST_OBJS) \
	    $(ZLIB) $(DRUNTIMELIB)
	.\unittest.exe

#unittest : unittest.exe
#	unittest
#
#unittest.exe : unittest.d $(LIB)
#	$(DMD) -conf= unittest -g
#	dmc unittest.obj -g

cov : $(SRC_TO_COMPILE) $(LIB)
	"$(DMD)" -conf= -m$(MODEL) -cov $(UDFLAGS) -ofcov.exe unittest.d $(SRC_TO_COMPILE) $(LIB)
	cov

################### Win32 COFF support #########################

# default to 32-bit compiler relative to the location of the 64-bit compiler,
# link and lib are architecture agnostic
CC32=$(CC)\..\..\cl

# build phobos32mscoff.lib
phobos32mscoff:
	"$(MAKE)" -f win64.mak "DMD=$(DMD)" "MAKE=$(MAKE)" MODEL=32mscoff "CC=$(CC32)" "AR=$(AR)" "VCDIR=$(VCDIR)" "SDKDIR=$(SDKDIR)"

# run unittests for 32-bit COFF version
unittest32mscoff:
	"$(MAKE)" -f win64.mak "DMD=$(DMD)" "MAKE=$(MAKE)" MODEL=32mscoff "CC=$(CC32)" "AR=$(AR)" "VCDIR=$(VCDIR)" "SDKDIR=$(SDKDIR)" unittest

######################################################

$(ZLIB): $(SRC_ZLIB)
	cd etc\c\zlib
	"$(MAKE)" -f win64.mak MODEL=$(MODEL) zlib$(MODEL).lib "CC=$(CC)" "LIB=$(AR)" "VCDIR=$(VCDIR)"
	cd ..\..\..

######################################################

zip:
	del phobos.zip
	zip32 -r phobos.zip . -x .git\* -x \*.lib -x \*.obj

phobos.zip : zip

clean:
	cd etc\c\zlib
	"$(MAKE)" -f win64.mak MODEL=$(MODEL) clean
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

JOBS=$(NUMBER_OF_PROCESSORS)
GMAKE=gmake

auto-tester-test:
	echo "Windows builds have been disabled on auto-tester"
	#"$(GMAKE)" -j$(JOBS) -f posix.mak unittest BUILD=release DMD="$(DMD)" OS=win$(MODEL) \
	#CUSTOM_DRUNTIME=1 PIC=0 MODEL=$(MODEL) DRUNTIME=$(DRUNTIMELIB) CC=$(CC)
