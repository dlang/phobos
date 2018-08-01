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
# Notes:
#	minit.obj requires Microsoft MASM386.EXE to build from minit.asm,
#	or just use the supplied minit.obj

## Memory model (32 or 64)
MODEL=32

## Flags for dmc C compiler

CFLAGS=-mn -6 -r
#CFLAGS=-g -mn -6 -r

## Location of druntime tree

DRUNTIME=../druntime
DRUNTIMELIB=$(DRUNTIME)/lib/druntime.lib

## C compiler

CC=dmc
AR=lib
MAKE=make

## D compiler

DMD_DIR=../dmd
BUILD=release
OS=windows
DMD=$(DMD_DIR)/generated/$(OS)/$(BUILD)/$(MODEL)/dmd

## Zlib library

ZLIB=etc\c\zlib\zlib.lib

LIB=phobos.lib

$(win.mak)

$(LIB) : $(SRC_TO_COMPILE) \
	$(ZLIB) $(DRUNTIMELIB) win32.mak win64.mak
	$(DMD) -lib -of$(LIB) -Xfphobos.json $(DFLAGS) $(SRC_TO_COMPILE) \
		$(ZLIB) $(DRUNTIMELIB)

unittest : $(LIB)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest1.obj $(SRC_STD_1)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest2.obj $(SRC_STD_RANGE)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest2a.obj $(SRC_STD_2a)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest3.obj $(SRC_STD_3)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest3a.obj $(SRC_STD_3a)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest3b.obj $(SRC_STD_DATETIME)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest4.obj $(SRC_STD_4) $(SRC_STD_DIGEST)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest5.obj $(SRC_STD_ALGO)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest6.obj $(SRC_STD_6) $(SRC_STD_CONTAINER)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest6a.obj $(SRC_STD_EXP_ALLOC)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest6b.obj $(SRC_STD_EXP_LOGGER)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest7.obj $(SRC_STD_7)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest8a.obj $(SRC_STD_REGEX)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest8b.obj $(SRC_STD_NET)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest8c.obj $(SRC_STD_C) $(SRC_STD_WIN) $(SRC_STD_C_WIN)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest8d.obj $(SRC_STD_INTERNAL) $(SRC_STD_INTERNAL_DIGEST) $(SRC_STD_INTERNAL_MATH) $(SRC_STD_INTERNAL_WINDOWS)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest8e.obj $(SRC_ETC) $(SRC_ETC_C)
	$(DMD) $(UDFLAGS) -L/co -c  -ofunittest8f.obj $(SRC_STD_EXP)
	$(DMD) $(UDFLAGS) -L/co  unittest.d $(UNITTEST_OBJS) \
		$(ZLIB) $(DRUNTIMELIB)
	.\unittest.exe

cov : $(SRC_TO_COMPILE) $(LIB)
#	$(DMD) -conf= -cov $(UDFLAGS) -ofcov.exe -main $(SRC_TO_COMPILE) $(LIB)
#	cov
	del *.lst
	$(DMD) -conf= -cov=83 $(UDFLAGS) -main -run std\stdio.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\string.d
	$(DMD) -conf= -cov=71 $(UDFLAGS) -main -run std\format.d
	$(DMD) -conf= -cov=83 $(UDFLAGS) -main -run std\file.d
	$(DMD) -conf= -cov=86 $(UDFLAGS) -main -run std\range\package.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\array.d
	$(DMD) -conf= -cov=100 $(UDFLAGS) -main -run std\functional.d
	$(DMD) -conf= -cov=96 $(UDFLAGS) -main -run std\path.d
	$(DMD) -conf= -cov=41 $(UDFLAGS) -main -run std\outbuffer.d
	$(DMD) -conf= -cov=89 $(UDFLAGS) -main -run std\utf.d
	$(DMD) -conf= -cov=93 $(UDFLAGS) -main -run std\csv.d
	$(DMD) -conf= -cov=91 $(UDFLAGS) -main -run std\math.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\complex.d
	$(DMD) -conf= -cov=70 $(UDFLAGS) -main -run std\numeric.d
	$(DMD) -conf= -cov=94 $(UDFLAGS) -main -run std\bigint.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\bitmanip.d
	$(DMD) -conf= -cov=82 $(UDFLAGS) -main -run std\typecons.d
	$(DMD) -conf= -cov=44 $(UDFLAGS) -main -run std\uni.d
	$(DMD) -conf= -cov=91 $(UDFLAGS) -main -run std\base64.d
	$(DMD) -conf= -cov=100 $(UDFLAGS) -main -run std\ascii.d
	$(DMD) -conf= -cov=0  $(UDFLAGS) -main -run std\demangle.d
	$(DMD) -conf= -cov=57 $(UDFLAGS) -main -run std\uri.d
	$(DMD) -conf= -cov=51 $(UDFLAGS) -main -run std\mmfile.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\getopt.d
	$(DMD) -conf= -cov=92 $(UDFLAGS) -main -run std\signals.d
	$(DMD) -conf= -cov=100 $(UDFLAGS) -main -run std\meta.d
	$(DMD) -conf= -cov=100 $(UDFLAGS) -main -run std\typetuple.d
	$(DMD) -conf= -cov=85 $(UDFLAGS) -main -run std\traits.d
	$(DMD) -conf= -cov=62 $(UDFLAGS) -main -run std\encoding.d
	$(DMD) -conf= -cov=61 $(UDFLAGS) -main -run std\xml.d
	$(DMD) -conf= -cov=79 $(UDFLAGS) -main -run std\random.d
	$(DMD) -conf= -cov=92 $(UDFLAGS) -main -run std\exception.d
	$(DMD) -conf= -cov=73 $(UDFLAGS) -main -run std\concurrency.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\datetime\date.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\datetime\interval.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\datetime\package.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\datetime\stopwatch.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\datetime\systime.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\datetime\timezone.d
	$(DMD) -conf= -cov=96 $(UDFLAGS) -main -run std\uuid.d
	$(DMD) -conf= -cov=100 $(UDFLAGS) -main -run std\digest\crc.d
	$(DMD) -conf= -cov=55 $(UDFLAGS) -main -run std\digest\sha.d
	$(DMD) -conf= -cov=100 $(UDFLAGS) -main -run std\digest\md.d
	$(DMD) -conf= -cov=100 $(UDFLAGS) -main -run std\digest\ripemd.d
	$(DMD) -conf= -cov=75 $(UDFLAGS) -main -run std\digest\digest.d
	$(DMD) -conf= -cov=100 $(UDFLAGS) -main -run std\digest\hmac.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\algorithm\package.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\algorithm\comparison.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\algorithm\iteration.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\algorithm\mutation.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\algorithm\searching.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\algorithm\setops.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\algorithm\sorting.d
	$(DMD) -conf= -cov=83 $(UDFLAGS) -main -run std\variant.d
	$(DMD) -conf= -cov=58 $(UDFLAGS) -main -run std\zlib.d
	$(DMD) -conf= -cov=53 $(UDFLAGS) -main -run std\socket.d
	$(DMD) -conf= -cov=95 $(UDFLAGS) -main -run std\container\array.d
	$(DMD) -conf= -cov=68 $(UDFLAGS) -main -run std\container\binaryheap.d
	$(DMD) -conf= -cov=91 $(UDFLAGS) -main -run std\container\dlist.d
	$(DMD) -conf= -cov=93 $(UDFLAGS) -main -run std\container\rbtree.d
	$(DMD) -conf= -cov=92 $(UDFLAGS) -main -run std\container\slist.d
	$(DMD) -conf= -cov=100 $(UDFLAGS) -main -run std\container\util.d
	$(DMD) -conf= -cov=100 $(UDFLAGS) -main -run std\container\package.d
	$(DMD) -conf= -cov=90 $(UDFLAGS) -main -run std\conv.d
	$(DMD) -conf= -cov=0  $(UDFLAGS) -main -run std\zip.d
	$(DMD) -conf= -cov=77 $(UDFLAGS) -main -run std\regex\tests.d
	$(DMD) -conf= -cov=77 $(UDFLAGS) -main -run std\regex\tests2.d
	$(DMD) -conf= -cov=92 $(UDFLAGS) -main -run std\json.d
	$(DMD) -conf= -cov=87 $(UDFLAGS) -main -run std\parallelism.d
	$(DMD) -conf= -cov=50 $(UDFLAGS) -main -run std\mathspecial.d
	$(DMD) -conf= -cov=71 $(UDFLAGS) -main -run std\process.d
	$(DMD) -conf= -cov=70 $(UDFLAGS) -main -run std\net\isemail.d
	$(DMD) -conf= -cov=2  $(UDFLAGS) -main -run std\net\curl.d
	$(DMD) -conf= -cov=60 $(UDFLAGS) -main -run std\windows\registry.d
	$(DMD) -conf= -cov=0  $(UDFLAGS) -main -run std\internal\digest\sha_SSSE3.d
	$(DMD) -conf= -cov=50 $(UDFLAGS) -main -run std\internal\math\biguintcore.d
	$(DMD) -conf= -cov=75 $(UDFLAGS) -main -run std\internal\math\biguintnoasm.d
#	$(DMD) -conf= -cov $(UDFLAGS) -main -run std\internal\math\biguintx86.d
	$(DMD) -conf= -cov=94 $(UDFLAGS) -main -run std\internal\math\gammafunction.d
	$(DMD) -conf= -cov=92 $(UDFLAGS) -main -run std\internal\math\errorfunction.d
	$(DMD) -conf= -cov=31 $(UDFLAGS) -main -run std\internal\windows\advapi32.d
	$(DMD) -conf= -cov=58 $(UDFLAGS) -main -run etc\c\zlib.d

######################################################

$(ZLIB): $(SRC_ZLIB)
	cd etc\c\zlib
	$(MAKE) -f win$(MODEL).mak zlib.lib CC=$(CC) LIB=$(AR)
	cd ..\..\..
