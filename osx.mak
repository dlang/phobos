# Makefile to build linux D runtime library libphobos2.a and its unit test
# Targets:
#	all
#		Generate each build targets below except clean
#
#	release (default target)
#		-O -release
#               Symlink libphobos2.$(LIBEXT) in the top level directory
#
#	unittest/release
#		-O -release -unittest
#
#	debug
#		-g
#
#	headers
#		-O -release
#
#	unittest/debug
#		-g -unittest
#
#	html
#		Generate the ddocs for phobos
#
#	clean
#		Delete all files created by build process

ifdef WIN32
      OBJDIR = obj/win32
      OBJEXT = obj
      LIBEXT = lib
      EXEEXT = .exe
      CC = gcc
      DMD = dmd
      CFLAGS =
      DFLAGS =
      LDFLAGS =
else
      OBJDIR = obj/osx
      OBJEXT = o
      LIBEXT = a
      EXEEXT =
      CC = gcc
      DMD = dmd
      CFLAGS := -m32 $(CFLAGS)
      DFLAGS =
      LDFLAGS := $(LDFLAGS)
endif

ifeq (,$(MAKECMDGOALS))
    MAKECMDGOALS := release
endif
ifeq (unittest/release,$(MAKECMDGOALS))
    CFLAGS := $(CFLAGS) -O
    DFLAGS := $(DFLAGS) -O -release -unittest
    OBJDIR := $(OBJDIR)/unittest/release
endif
ifeq (unittest/debug,$(MAKECMDGOALS))
    CFLAGS := $(CFLAGS) -g
    DFLAGS := $(DFLAGS) -g -unittest
    OBJDIR : = $(OBJDIR)/unittest/debug
endif
ifeq (debug,$(MAKECMDGOALS))
    CFLAGS := $(CFLAGS) -g
    DFLAGS := $(DFLAGS) -g
    OBJDIR := $(OBJDIR)/debug
endif
ifeq (release,$(MAKECMDGOALS))
    CFLAGS := $(CFLAGS) -O
    DFLAGS := $(DFLAGS) -O -release
    OBJDIR := $(OBJDIR)/release
endif
ifeq (clean,$(MAKECMDGOALS))
    OBJDIR = none
endif
ifeq (html,$(MAKECMDGOALS))
    OBJDIR = none
endif
ifeq (all,$(MAKECMDGOALS))
    OBJDIR = none
endif
ifeq (headers,$(MAKECMDGOALS))
    DFLAGS := $(DFLAGS) -O -release
    OBJDIR = none
endif

ifndef OBJDIR
    $(error Cannot make $(MAKECMDGOALS). Please make either all,	\
debug, release, unittest/debug, unittest/release, clean, or html)
endif

ifneq (none,$(OBJDIR))
      DUMMY := $(shell mkdir -p $(OBJDIR) $(OBJDIR)/etc/c/zlib)
endif

LIB=$(OBJDIR)/libphobos2.$(LIBEXT)
DOC_OUTPUT_DIR=../web/phobos
DRUNTIME=../druntime/lib/libdruntime.a

.SUFFIXES: .d
$(OBJDIR)/%.$(OBJEXT) : %.c
	$(CC) -c $(CFLAGS) -o $@ $<

$(OBJDIR)/%.$(OBJEXT) : %.cpp
	g++ -c $(CFLAGS) -o $@ $<

$(OBJDIR)/%.$(OBJEXT) : %.d
	$(DMD) -I$(dir $<) -c $(DFLAGS) -of$@ $<

$(OBJDIR)/%.$(OBJEXT) : %.asm
	$(CC) -c -o $@ $<

debug release unittest/debug unittest/release : $(OBJDIR)/unittest$(EXEEXT)

all :
	$(MAKE) -f osx.mak release
	$(MAKE) -f osx.mak unittest/release
	$(MAKE) -f osx.mak debug
	$(MAKE) -f osx.mak unittest/debug
	$(MAKE) -f osx.mak html

$(OBJDIR)/unittest$(EXEEXT) : $(OBJDIR)/unittest.$(OBJEXT) \
                   $(OBJDIR)/all_std_modules_generated.$(OBJEXT) $(LIB)
ifdef WIN32
	cp $(LIB) ../../lib/phobos.lib
	$(DMD) $(DFLAGS) unittest.d minit.obj
	mv unittest.exe $@
	wine $@
else
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ -lpthread -lm -g -ldl
endif
ifeq (release,$(MAKECMDGOALS))
	ln -sf `pwd`/$(OBJDIR)/libphobos2.$(LIBEXT) ../../lib
endif

$(OBJDIR)/unittest.$(OBJEXT) : unittest.d all_std_modules_generated.d

all_std_modules_generated.d : $(MAKEFILE_LIST)
	for m in $(STD_MODULES); do echo public import std.$$m\;; done > $@

STD_MODULES = algorithm array atomics base64 bigint bind bitarray       \
        bitmanip boxer compiler complex contracts conv cpuid		\
        cstream ctype date dateparse demangle encoding file format	\
        functional  getopt intrinsic iterator loader math	        \
        md5 metastrings mmfile numeric openrj outbuffer	                \
        path perf process random regexp signals socket	                \
        socketstream stdint stdio stream string syserror	        \
        system traits typecons typetuple uni uri utf                    \
        variant xml zip zlib
STD_MODULES_NOTBUILT = stdarg __fileinit

STD_C_MODULES = stdarg stdio
STD_C_MODULES_NOTBUILT = fenv math process stddef stdlib string time locale \
	wcharh

STD_C_LINUX_MODULES = linux socket pthread
STD_C_LINUX_MODULES_NOTBUILT = linuxextern termios
STD_C_OSX_MODULES = socket

STD_C_WINDOWS_MODULES_NOTBUILT = windows com winsock stat

STD_WINDOWS_MODULES_NOTBUILT = registry iunknown charset

ZLIB_CMODULES = adler32 compress crc32 gzio uncompr deflate trees	\
	zutil inflate infback inftrees inffast

TYPEINFO_MODULES = ti_wchar ti_uint ti_short ti_ushort ti_byte		\
	ti_ubyte ti_long ti_ulong ti_ptr ti_float ti_double ti_real	\
	ti_delegate ti_creal ti_ireal ti_cfloat ti_ifloat ti_cdouble	\
	ti_idouble ti_dchar ti_Ashort ti_Ag ti_AC ti_C ti_int ti_char	\
	ti_Aint ti_Along ti_Afloat ti_Adouble ti_Areal ti_Acfloat	\
	ti_Acdouble ti_Acreal ti_void

ETC_MODULES_NOTBUILT =

ETC_C_MODULES = zlib

SRC = object.d unittest.d crc32.d

SRC_ZLIB = ChangeLog README adler32.c algorithm.txt compress.c crc32.c	\
	crc32.h deflate.c deflate.h example.c gzio.c infback.c		\
	inffast.c inffast.h inffixed.h inflate.c inflate.h inftrees.c	\
	inftrees.h linux.mak osx.mak minigzip.c trees.c trees.h uncompr.c	\
	win32.mak zconf.h zconf.in.h zlib.3 zlib.h zutil.c zutil.h
SRC_ZLIB := $(addprefix etc/c/zlib/,$(SRC_ZLIB))

SRC_DOCUMENTABLES = phobos.d $(addprefix std/, $(addsuffix .d,		\
	$(STD_MODULES) $(STD_MODULES_NOTBUILT))) $(addprefix std/c/,	\
	$(addsuffix .d, $(STD_C_MODULES) $(STD_C_MODULES_NOTBUILT)))	\
	$(addprefix std/c/linux/,$(addsuffix .d,			\
	$(STD_C_LINUX_MODULES) $(STD_C_LINUX_MODULES_NOTBUILT)))        \
	$(STD_C_OSX_MODULES)

SRC_RELEASEZIP = linux.mak win32.mak osx.mak phoboslicense.txt $(SRC)	\
	$(SRC_ZLIB) $(addprefix std/, $(addsuffix .d, $(STD_MODULES)    \
	$(STD_MODULES_NOTBUILT))) $(addprefix std/c/, $(addsuffix .d,	\
	$(STD_C_MODULES) $(STD_C_MODULES_NOTBUILT))) $(addprefix	\
	std/c/linux/, $(addsuffix .d, $(STD_C_LINUX_MODULES)		\
	$(STD_C_LINUX_MODULES_NOTBUILT))) $(addprefix	                \
	std/c/osx/, $(addsuffix .d, $(STD_C_OSX_MODULES)))		\
	$(addprefix std/c/windows/, $(addsuffix .d,                     \
	$(STD_C_WINDOWS_MODULES_NOTBUILT))) $(addprefix std/windows/,   \
	$(addsuffix .d, $(STD_WINDOWS_MODULES_NOTBUILT)))               \
	$(addprefix etc/, $(addsuffix .d, $(ETC_MODULES_NOTBUILT)))     \
	$(addprefix etc/c/, $(addsuffix .d, $(ETC_C_MODULES)))

OBJS = $(addprefix etc/c/zlib/, $(ZLIB_CMODULES))

OBJS := $(addsuffix .$(OBJEXT),$(addprefix $(OBJDIR)/,$(OBJS)))

SRC2LIB = crc32 $(addprefix std/, $(STD_MODULES)) $(addprefix std/c/,   \
$(STD_C_MODULES)) $(addprefix std/c/osx/, $(STD_C_OSX_MODULES))	\
$(addprefix etc/c/, $(ETC_C_MODULES))

SRC2LIB := $(addsuffix .d,$(SRC2LIB))

$(LIB) : $(SRC2LIB) $(OBJS) $(DRUNTIME) $(MAKEFILE_LIST)
	@echo $(DMD) $(DFLAGS) -lib -of$@ "[...tons of files...]"
	$(DMD) $(DFLAGS) -lib -of$@ $(SRC2LIB) $(OBJS) $(DRUNTIME)

###########################################################
# Dox

STDDOC = ../docsrc/std.ddoc

$(DOC_OUTPUT_DIR)/%.html : %.d $(STDDOC)
	$(DMD) -c -o- $(DFLAGS) -Df$@ $(STDDOC) $<

$(DOC_OUTPUT_DIR)/std_%.html : std/%.d $(STDDOC)
	$(DMD) -c -o- $(DFLAGS) -Df$@ $(STDDOC) $<

$(DOC_OUTPUT_DIR)/std_c_%.html : std/c/%.d $(STDDOC)
	$(DMD) -c -o- $(DFLAGS) -Df$@ $(STDDOC) $<

$(DOC_OUTPUT_DIR)/std_c_linux_%.html : std/c/linux/%.d $(STDDOC)
	$(DMD) -c -o- $(DFLAGS) -Df$@ $(STDDOC) $<

html : $(addprefix $(DOC_OUTPUT_DIR)/,$(subst /,_,$(subst .d,.html,$(SRC_DOCUMENTABLES))))

##########################################################

zip : $(SRC_RELEASEZIP)
	$(RM) phobos.zip
	zip phobos $(SRC_RELEASEZIP)

clean:
	$(RM) libphobos2.$(LIBEXT) all_std_modules_generated.d
	$(RM) -r $(DOC_OUTPUT_DIR) obj


HEADERDIR = include
HEADERS = $(addprefix std/,$(addsuffix .d,$(STD_MODULES))) \
	$(addprefix std/,$(addsuffix .d,$(STD_MODULES_NOTBUILT))) \
	$(addprefix std/c/,$(addsuffix .d,$(STD_C_MODULES))) \
	$(addprefix std/c/,$(addsuffix .d,$(STD_C_MODULES_NOTBUILT))) \
	$(addprefix std/c/linux/,$(addsuffix .d,$(STD_C_LINUX_MODULES))) \
	$(addprefix std/c/linux/,$(addsuffix .d,$(STD_C_LINUX_MODULES_NOTBUILT))) \
	$(addprefix std/c/osx/,$(addsuffix .d,$(STD_C_OSX_MODULES)))

HEADERS := $(addprefix $(HEADERDIR)/,$(HEADERS))

$(HEADERDIR)/%.d : %.d
	$(DMD) -I$(dir $<) -o- -c -H $(DFLAGS) -Hf$@ $<

headers: $(HEADERS)
