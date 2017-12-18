# Common parts shared between win32.mak and win64.mak

# Copy command

CP=cp

## Directory where dmd has been installed

DIR=\dmd2

# D compiler
DMD_DIR=..\dmd
BUILD=release
OS=windows
DMD=$(DMD_DIR)\generated\$(OS)\$(BUILD)\$(MODEL)\dmd

# Make

MAKE=make

################################################################################
# Flags
################################################################################

# Flags for dmd D compiler
DFLAGS=-conf= -m$(MODEL) -O -release -w -de -dip25 -I$(DRUNTIME)\import

# Flags for compiling unittests

UDFLAGS=-conf= -unittest -g -m$(MODEL) -O -w -dip25 -I$(DRUNTIME)\import

################################################################################
# Libraries
################################################################################

DRUNTIME=..\druntime
DRUNTIMELIB=$(DRUNTIME)\lib\druntime$(LIBEXT).lib

ZLIB=etc\c\zlib\zlib$(LIBEXT).lib

LIB=phobos$(LIBEXT).lib

################################################################################
# Source files
################################################################################

SRC= \
	unittest.d \
	index.d

# The separation is a workaround for bug 4904 (optlink bug 3372).
SRC_STD_1= \
	std\stdio.d \
	std\string.d \
	std\format.d \
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

SRC_STD_3a= \
	std\math.d

SRC_STD_3b= \
	std\uni.d \
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
	std\process.d

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
	$(SRC_STD_7)

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
	std\regex\internal\backtracking.d \
	std\regex\internal\thompson.d \
	std\regex\internal\kickstart.d \
	std\regex\internal\generator.d

SRC_STD_C= \
	std\c\process.d \
	std\c\stdlib.d \
	std\c\time.d \
	std\c\stdio.d \
	std\c\math.d \
	std\c\stdarg.d \
	std\c\stddef.d \
	std\c\fenv.d \
	std\c\string.d \
	std\c\locale.d \
	std\c\wcharh.d

SRC_STD_WIN= \
	std\windows\registry.d \
	std\windows\iunknown.d \
	std\windows\syserror.d \
	std\windows\charset.d

SRC_STD_C_WIN= \
	std\c\windows\windows.d \
	std\c\windows\com.d \
	std\c\windows\winsock.d \
	std\c\windows\stat.d

SRC_STD_C_LINUX= \
	std\c\linux\linux.d \
	std\c\linux\socket.d \
	std\c\linux\pthread.d \
	std\c\linux\termios.d \
	std\c\linux\tipc.d

SRC_STD_C_OSX= \
	std\c\osx\socket.d

SRC_STD_C_FREEBSD= \
	std\c\freebsd\socket.d

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
	std\experimental\checkedint.d std\experimental\typecons.d

SRC_STD_EXP_ALLOC_BB= \
	std\experimental\allocator\building_blocks\affix_allocator.d \
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

UNITTEST_OBJS= \
		unittest1.obj \
		unittest2.obj \
		unittest2a.obj \
		unittest3.obj \
		unittest3a.obj \
		unittest3b.obj \
		unittest3c.obj \
		unittest3d.obj \
		unittest4.obj \
		unittest5a.obj \
		unittest5b.obj \
		unittest5c.obj \
		unittest6a.obj \
		unittest6c.obj \
		unittest6e.obj \
		unittest6g.obj \
		unittest6h.obj \
		unittest6i.obj \
		unittest7.obj \
		unittest8a.obj \
		unittest8b.obj \
		unittest8c.obj \
		unittest8d.obj \
		unittest8e.obj \
		unittest8f.obj \
		unittest9.obj
