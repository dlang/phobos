# Makefile to build linux D runtime library libphobos2.a and its unit test
# Targets:
#	<default> | release
#		-release -O
#	unittest
#		-unittest -release -O
#	debug
#		-g
#	unittest-debug
#		-unittest -g
#
#	clean
#		Delete all files created by build process

VPATH=..

LIB=libphobos2.a

DOC_OUTPUT_DIR=doc

CFLAGS=-m32
DFLAGS=-I..
ifneq (,$(findstring debug,$(MAKECMDGOALS)))
CFLAGS:=$(CFLAGS) -g
DFLAGS:=$(DFLAGS) -g
else
CFLAGS:=$(CFLAGS) -O
DFLAGS:=$(DFLAGS) -release -O
endif

ifneq (,$(findstring unittest,$(MAKECMDGOALS)))
DFLAGS:=$(DFLAGS) -unittest
endif

CC=gcc
#DMD=/dmd/bin/dmd
DMD=dmd

.SUFFIXES: .d
.c.o:
	$(CC) -c $(CFLAGS) -o $@ $<

.cpp.o:
	g++ -c $(CFLAGS) -o $@ $<

.d.o:
	$(DMD) -c $(DFLAGS) -of$@ $<

.asm.o:
	$(CC) -c -o $@ $<

debug release unittest-debug : unittest

unittest : unittest.o $(LIB)
	$(CC) -o $@ $^ -lpthread -lm -g

unittest.o : unittest.d
	$(DMD) -c $(DFLAGS) $<

INTERNAL_MODULES = aApply aApplyR aaA adi alloca arraycast arraycat cast cmath2 \
	deh2 dmain2 invariant llmath memset obj object qsort switch trace
INTERNAL_CMODULES = complex critical monitor
INTERNAL_CMODULES_NOTBUILT = deh
INTERNAL_EXTRAFILES = internal/mars.h internal/minit.asm

INTERNAL_GC_MODULES = gc gcold gcx gcbits gclinux
INTERNAL_GC_EXTRAFILES = \
	internal/gc/gcstub.d \
	internal/gc/win32.d \
	internal/gc/testgc.d \
	internal/gc/win32.mak \
	internal/gc/linux.mak

STD_MODULES = array asserterror base64 bind bitarray boxer compiler \
	conv cover cpuid cstream ctype date dateparse demangle file format gc \
	getopt hiddenfunc intrinsic loader math math2 md5 metastrings mmfile \
	moduleinit openrj outbuffer outofmemory path perf process random \
	regexp signals socket socketstream stdint stdio stream string \
	switcherr syserror system thread traits typetuple uni uri utf variant \
	zip zlib
STD_MODULES_NOTBUILT = stdarg

STD_C_MODULES = stdarg stdio
STD_C_MODULES_NOTBUILT = fenv math process stddef stdlib string time locale

STD_C_LINUX_MODULES = linux socket
STD_C_LINUX_MODULES_NOTBUILT = linuxextern pthread

STD_C_WINDOWS_MODULES_NOTBUILT = windows com winsock stat

STD_WINDOWS_MODULES_NOTBUILT = registry iunknown charset

ZLIB_CMODULES = adler32 compress crc32 gzio uncompr deflate \
	trees zutil inflate infback inftrees inffast

TYPEINFO_MODULES = \
	ti_wchar ti_uint \
	ti_short ti_ushort \
	ti_byte ti_ubyte \
	ti_long ti_ulong \
	ti_ptr \
	ti_float ti_double \
	ti_real ti_delegate \
	ti_creal ti_ireal \
	ti_cfloat ti_ifloat \
	ti_cdouble ti_idouble \
	ti_dchar \
	ti_Ashort \
	ti_Ag \
	ti_AC ti_C \
	ti_int ti_char \
	ti_Aint \
	ti_Along \
	ti_Afloat ti_Adouble \
	ti_Areal \
	ti_Acfloat ti_Acdouble \
	ti_Acreal \
	ti_void

ETC_MODULES_NOTBUILT = gamma

ETC_C_MODULES = zlib

SRC = errno.c object.d unittest.d crc32.d gcstats.d

SRC_ZLIB = \
	etc/c/zlib/ChangeLog \
	etc/c/zlib/README \
	etc/c/zlib/adler32.c \
	etc/c/zlib/algorithm.txt \
	etc/c/zlib/compress.c \
	etc/c/zlib/crc32.c \
	etc/c/zlib/crc32.h \
	etc/c/zlib/deflate.c \
	etc/c/zlib/deflate.h \
	etc/c/zlib/example.c \
	etc/c/zlib/gzio.c \
	etc/c/zlib/infback.c \
	etc/c/zlib/inffast.c \
	etc/c/zlib/inffast.h \
	etc/c/zlib/inffixed.h \
	etc/c/zlib/inflate.c \
	etc/c/zlib/inflate.h \
	etc/c/zlib/inftrees.c \
	etc/c/zlib/inftrees.h \
	etc/c/zlib/linux.mak \
	etc/c/zlib/minigzip.c \
	etc/c/zlib/trees.c \
	etc/c/zlib/trees.h \
	etc/c/zlib/uncompr.c \
	etc/c/zlib/win32.mak \
	etc/c/zlib/zconf.h \
	etc/c/zlib/zconf.in.h \
	etc/c/zlib/zlib.3 \
	etc/c/zlib/zlib.h \
	etc/c/zlib/zutil.c \
	etc/c/zlib/zutil.h

SRC_DOCUMENTABLES = \
	phobos.d \
	$(addprefix std/,$(addsuffix .d,$(STD_MODULES) $(STD_MODULES_NOTBUILT))) \
	$(addprefix std/c/,$(addsuffix .d,$(STD_C_MODULES) $(STD_C_MODULES_NOTBUILT))) \
	$(addprefix std/c/linux/,$(addsuffix .d,$(STD_C_LINUX_MODULES) $(STD_C_LINUX_MODULES_NOTBUILT)))


SRC_RELEASEZIP = \
	linux.mak linux-2.mak win32.mak phoboslicense.txt \
	$(SRC) $(SRC_ZLIB) \
	\
	$(INTERNAL_EXTRAFILES) \
	$(INTERNAL_GC_EXTRAFILES) \
	$(addprefix internal/,$(addsuffix .c,$(INTERNAL_CMODULES_NOTBUILT))) \
	$(addprefix internal/,$(addsuffix .c,$(INTERNAL_CMODULES))) \
	$(addprefix internal/,$(addsuffix .d,$(INTERNAL_MODULES))) \
	$(addprefix internal/gc/,$(addsuffix .d,$(INTERNAL_GC_MODULES))) \
	$(addprefix std/,$(addsuffix .d,$(STD_MODULES) $(STD_MODULES_NOTBUILT))) \
	$(addprefix std/c/,$(addsuffix .d,$(STD_C_MODULES) $(STD_C_MODULES_NOTBUILT))) \
	$(addprefix std/c/linux/,$(addsuffix .d,$(STD_C_LINUX_MODULES) $(STD_C_LINUX_MODULES_NOTBUILT))) \
	$(addprefix std/c/windows/,$(addsuffix .d,$(STD_C_WINDOWS_MODULES_NOTBUILT))) \
	$(addprefix std/typeinfo/,$(addsuffix .d,$(TYPEINFO_MODULES))) \
	$(addprefix std/windows/,$(addsuffix .d,$(STD_WINDOWS_MODULES_NOTBUILT))) \
	$(addprefix etc/,$(addsuffix .d,$(ETC_MODULES_NOTBUILT))) \
	$(addprefix etc/c/,$(addsuffix .d,$(ETC_C_MODULES)))

OBJS = crc32.o errno.o gcstats.o \
	$(addprefix std/,$(addsuffix .o,$(STD_MODULES))) \
	$(addprefix std/c/,$(addsuffix .o,$(STD_C_MODULES))) \
	$(addprefix std/c/linux/,$(addsuffix .o,$(STD_C_LINUX_MODULES))) \
	$(addprefix std/typeinfo/,$(addsuffix .o,$(TYPEINFO_MODULES))) \
	$(addprefix internal/,$(addsuffix .o,$(INTERNAL_MODULES))) \
	$(addprefix internal/,$(addsuffix .o,$(INTERNAL_CMODULES))) \
	$(addprefix internal/gc/,$(addsuffix .o,$(INTERNAL_GC_MODULES))) \
	$(addprefix etc/c/,$(addsuffix .o,$(ETC_C_MODULES))) \
	$(addprefix etc/c/zlib/,$(addsuffix .o,$(ZLIB_CMODULES)))

$(LIB) : $(OBJS) linux.mak
	rm -f $(LIB)
	ar -r $@ $(OBJS)

###########################################################
# Dox

$(DOC_OUTPUT_DIR)/%.html : %.d std.ddoc
	$(DMD) -c -o- $(DFLAGS) -Df$@ std.ddoc $<

$(DOC_OUTPUT_DIR)/std_%.html : std/%.d std.ddoc
	$(DMD) -c -o- $(DFLAGS) -Df$@ std.ddoc $<

$(DOC_OUTPUT_DIR)/std_c_%.html : std/c/%.d std.ddoc
	$(DMD) -c -o- $(DFLAGS) -Df$@ std.ddoc $<

$(DOC_OUTPUT_DIR)/std_c_linux_%.html : std/c/linux/%.d std.ddoc
	$(DMD) -c -o- $(DFLAGS) -Df$@ std.ddoc $<

html : $(addprefix $(DOC_OUTPUT_DIR)/,$(subst /,_,$(subst .d,.html,$(SRC_DOCUMENTABLES))))

###########################################################

internal/gc/%.o : internal/gc/%.d
	$(DMD) -c $(DFLAGS) -I../internal/gc -of$@ $<

DUMMY := $(shell mkdir --parents etc/c/zlib)

etc/c/zlib/%.o : etc/c/zlib/%.c
	$(CC) -c $(CFLAGS) -o $@ $<

##########################################################

zip : $(SRC_RELEASEZIP)
	$(RM) phobos.zip
	zip phobos $(SRC_RELEASEZIP)

clean:
	$(RM) $(LIB) unittest unittest.o
	$(RM) -r *.o
	$(RM) -r $(DOC_OUTPUT_DIR)

