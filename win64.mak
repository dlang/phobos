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

## Visual C directories
VCDIR=\Program Files (x86)\Microsoft Visual Studio 10.0\VC
SDKDIR=\Program Files (x86)\Microsoft SDKs\Windows\v7.0A

## Flags for VC compiler

#CFLAGS=/Zi /nologo /I"$(VCDIR)\INCLUDE" /I"$(SDKDIR)\Include"
CFLAGS=/O2 /nologo /I"$(VCDIR)\INCLUDE" /I"$(SDKDIR)\Include"

## Location of druntime tree

DRUNTIME=../druntime
DRUNTIMELIB=$(DRUNTIME)/lib/druntime$(MODEL).lib

## C compiler, linker, librarian

CC="$(VCDIR)\bin\amd64\cl"
LD="$(VCDIR)\bin\amd64\link"
AR="$(VCDIR)\bin\amd64\lib"
MAKE=make

## D compiler

DMD_DIR=../dmd
BUILD=release
OS=windows
DMD="$(DMD_DIR)/generated/$(OS)/$(BUILD)/$(MODEL)/dmd"

## Zlib library

ZLIB=etc\c\zlib\zlib$(MODEL).lib

LIB=phobos$(MODEL).lib

$(win.mak)

$(LIB) : $(SRC_TO_COMPILE) \
	$(ZLIB) $(DRUNTIMELIB) win32.mak win64.mak
	$(DMD) -lib -of$(LIB) -Xfphobos.json $(DFLAGS) $(SRC_TO_COMPILE) \
		$(ZLIB) $(DRUNTIMELIB)

unittest : $(LIB)
	$(DMD) $(UDFLAGS) -c  -ofunittest1.obj $(SRC_STD_1)
	$(DMD) $(UDFLAGS) -c  -ofunittest2.obj $(SRC_STD_RANGE)
	$(DMD) $(UDFLAGS) -c  -ofunittest2a.obj $(SRC_STD_2a)
	$(DMD) $(UDFLAGS) -c  -ofunittest3.obj $(SRC_STD_3)
	$(DMD) $(UDFLAGS) -c  -ofunittest3a.obj $(SRC_STD_3a)
	$(DMD) $(UDFLAGS) -c  -ofunittest3b.obj $(SRC_STD_DATETIME)
	$(DMD) $(UDFLAGS) -c  -ofunittest4.obj $(SRC_STD_4) $(SRC_STD_DIGEST)
	$(DMD) $(UDFLAGS) -c  -ofunittest5.obj $(SRC_STD_ALGO)
	$(DMD) $(UDFLAGS) -c  -ofunittest6.obj $(SRC_STD_6) $(SRC_STD_CONTAINER)
	$(DMD) $(UDFLAGS) -c  -ofunittest6a.obj $(SRC_STD_EXP_ALLOC)
	$(DMD) $(UDFLAGS) -c  -ofunittest6b.obj $(SRC_STD_EXP_LOGGER)
	$(DMD) $(UDFLAGS) -c  -ofunittest7.obj $(SRC_STD_7)
	$(DMD) $(UDFLAGS) -c  -ofunittest8a.obj $(SRC_STD_REGEX)
	$(DMD) $(UDFLAGS) -c  -ofunittest8b.obj $(SRC_STD_NET)
	$(DMD) $(UDFLAGS) -c  -ofunittest8c.obj $(SRC_STD_C) $(SRC_STD_WIN) $(SRC_STD_C_WIN)
	$(DMD) $(UDFLAGS) -c  -ofunittest8d.obj $(SRC_STD_INTERNAL) $(SRC_STD_INTERNAL_DIGEST) $(SRC_STD_INTERNAL_MATH) $(SRC_STD_INTERNAL_WINDOWS)
	$(DMD) $(UDFLAGS) -c  -ofunittest8e.obj $(SRC_ETC) $(SRC_ETC_C)
	$(DMD) $(UDFLAGS) -c  -ofunittest8f.obj $(SRC_STD_EXP)
	$(DMD) $(UDFLAGS)  unittest.d $(UNITTEST_OBJS) \
		$(ZLIB) $(DRUNTIMELIB)
	.\unittest.exe

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
