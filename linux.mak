# Makefile to build linux D runtime library libphobos.a.
# Targets:
#	make
#		Same as make unittest
#	make libphobos.a
#		Build libphobos.a
#	make clean
#		Delete unneeded files created by build process
#	make unittest
#		Build libphobos.a, build and run unit tests

LIB=libphobos2.a

CFLAGS=-O -m32
#CFLAGS=-g -m32

DFLAGS=-O -release
#DFLAGS=-unittest

CC=gcc
DOC=doc
#DMD=/dmd/bin/dmd
DMD=dmd

.c.o:
	$(CC) -c $(CFLAGS) $*.c

.cpp.o:
	g++ -c $(CFLAGS) $*.cpp

.d.o:
	$(DMD) -c $(DFLAGS) $*.d

.asm.o:
	$(CC) -c $*.asm

targets : unittest

test.o : test.d
	$(DMD) -c test -g

test : test.o $(LIB)
	$(CC) -o $@ test.o $(LIB) -lpthread -lm -g

unittest : unittest.o $(LIB)
	$(CC) -o $@ unittest.o $(LIB) -lpthread -lm -g

unittest.o : unittest.d
	$(DMD) -c unittest

STD_MODULES = array asserterror base64 bind bitarray boxer compiler \
	conv cover cpuid cstream ctype date dateparse demangle file format gc \
	hiddenfunc intrinsic loader math math2 md5 metastrings mmfile \
	moduleinit openrj outbuffer outofmemory path perf process random \
	regexp signals socket socketstream stdint stdio stream string \
	switcherr syserror system thread traits typetuple uni uri utf zip

STD_MODULES_NOTGENERATING_OBJ = stdarg

# zlib.d is an exception because it conflicts with zlib.c
#    and will be handled separately, although it's an std module

OBJS = Czlib.o Dcrc32.o Dzlib.o c_stdio.o complex.o critical.o errno.o \
     gcstats.o linux.o linuxsocket.o monitor.o stdarg.o \
     $(addprefix std_,$(addsuffix .o,$(STD_MODULES))) \
     $(addprefix internal_,$(addsuffix .o,$(INTERNAL_MODULES))) \
     $(addprefix typeinfo_,$(addsuffix .o,$(TYPEINFO_MODULES)))

ZLIB_OBJS = etc/c/zlib/adler32.o etc/c/zlib/compress.o \
	etc/c/zlib/crc32.o etc/c/zlib/gzio.o \
	etc/c/zlib/uncompr.o etc/c/zlib/deflate.o \
	etc/c/zlib/trees.o etc/c/zlib/zutil.o \
	etc/c/zlib/inflate.o etc/c/zlib/infback.o \
	etc/c/zlib/inftrees.o etc/c/zlib/inffast.o

GC_OBJS= internal/gc/gc.o internal/gc/gcold.o internal/gc/gcx.o \
	internal/gc/gcbits.o internal/gc/gclinux.o

SRC=	errno.c object.d unittest.d crc32.d gcstats.d

SRC_STD= $(addprefix std/,$(addsuffix .d,\
$(STD_MODULES) $(STD_MODULES_NOTGENERATING_OBJ)))

SRC_STD_C= std/c/fenv.d std/c/math.d std/c/process.d std/c/stdarg.d \
	std/c/stddef.d std/c/stdio.d std/c/stdlib.d std/c/string.d \
	std/c/time.d \
	#std/d/locale.d

TYPEINFO_MODULES=\
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

SRC_TI= $(addprefix std/typeinfo/,$(addsuffix .d,$(TYPEINFO_MODULES)))

INTERNAL_MODULES=aApply aApplyR aaA \
	adi alloca arraycast \
	arraycat cast cmath2 \
	deh2 \
	dmain2 invariant llmath \
	memset \
	obj object qsort \
	switch trace

SRC_INT=internal/complex.c internal/critical.c internal/deh.c internal/mars.h \
	internal/monitor.c internal/minit.asm \
	$(addprefix internal/,$(addsuffix .d,$(INTERNAL_MODULES)))

SRC_STD_WIN= std/windows/registry.d \
	std/windows/iunknown.d std/windows/charset.d

SRC_STD_C_WIN= std/c/windows/windows.d std/c/windows/com.d \
	std/c/windows/winsock.d std/c/windows/stat.d

SRC_STD_C_LINUX= std/c/linux/linux.d std/c/linux/linuxextern.d \
	std/c/linux/socket.d std/c/linux/pthread.d

SRC_ETC=  etc/gamma.d

SRC_ETC_C= etc/c/zlib.d

SRC_ZLIB= etc/c/zlib\trees.h \
	etc/c/zlib\inffixed.h \
	etc/c/zlib\inffast.h \
	etc/c/zlib\crc32.h \
	etc/c/zlib\algorithm.txt \
	etc/c/zlib\uncompr.c \
	etc/c/zlib\compress.c \
	etc/c/zlib\deflate.h \
	etc/c/zlib\inftrees.h \
	etc/c/zlib\infback.c \
	etc/c/zlib\zutil.c \
	etc/c/zlib\crc32.c \
	etc/c/zlib\inflate.h \
	etc/c/zlib\example.c \
	etc/c/zlib\inffast.c \
	etc/c/zlib\trees.c \
	etc/c/zlib\inflate.c \
	etc/c/zlib\gzio.c \
	etc/c/zlib\zconf.h \
	etc/c/zlib\zconf.in.h \
	etc/c/zlib\minigzip.c \
	etc/c/zlib\deflate.c \
	etc/c/zlib\inftrees.c \
	etc/c/zlib\zutil.h \
	etc/c/zlib\zlib.3 \
	etc/c/zlib\zlib.h \
	etc/c/zlib\adler32.c \
	etc/c/zlib\ChangeLog \
	etc/c/zlib\README \
	etc/c/zlib\win32.mak \
	etc/c/zlib\linux.mak

SRC_GC= internal/gc/gc.d \
	internal/gc/gcold.d \
	internal/gc/gcx.d \
	internal/gc/gcstub.d \
	internal/gc/gcbits.d \
	internal/gc/win32.d \
	internal/gc/gclinux.d \
	internal/gc/testgc.d \
	internal/gc/win32.mak \
	internal/gc/linux.mak

ALLSRCS = $(SRC) $(SRC_STD) $(SRC_STD_C) $(SRC_TI) $(SRC_INT) $(SRC_STD_WIN) \
	$(SRC_STD_C_WIN) $(SRC_STD_C_LINUX) $(SRC_ETC) $(SRC_ETC_C) \
	$(SRC_ZLIB) $(SRC_GC)

#$(LIB) : $(OBJS) internal/gc/dmgc.a linux.mak
$(LIB) : $(OBJS) internal/gc/dmgc.a $(ZLIB_OBJS) linux.mak
	rm -f $(LIB)
	ar -r $@ $(OBJS) $(ZLIB_OBJS) $(GC_OBJS)


###########################################################
# Dox

LINUX_DOCUMENTABLES = phobos.d $(SRC_STD) $(SRC_STD_C) $(SRC_STD_C_LINUX)

define d2html
$(DOC)/$(subst /,_,$(subst .d,.html,$(1)))
endef

define html_dep
HTML_FILES += $(call d2html,$(1))
$(call d2html,$(1)) : $(1) std.ddoc
	$(DMD) -c -o- $(DFLAGS) -Df$$@ std.ddoc $$<

endef

$(foreach file,$(LINUX_DOCUMENTABLES),$(eval $(call html_dep,$(file))))

html : $(HTML_FILES)

###########################################################

internal/gc/dmgc.a:
#	cd internal/gc
#	make -f linux.mak dmgc.a
#	cd ../..
	$(MAKE) -C ./internal/gc -f linux.mak dmgc.a

$(ZLIB_OBJS):
#	cd etc/c/zlib
#	make -f linux.mak
#	cd ../../..
	$(MAKE) -C ./etc/c/zlib -f linux.mak

###

Dcrc32.o : crc32.d
	$(DMD) -c $(DFLAGS) crc32.d -ofDcrc32.o

errno.o : errno.c

gcstats.o : gcstats.d
	$(DMD) -c $(DFLAGS) gcstats.d

### internal

internal_%.o : internal/%.d
	$(DMD) -c $(DFLAGS) -of$@ $<

complex.o : internal/complex.c
	$(CC) -c $(CFLAGS) internal/complex.c

critical.o : internal/critical.c
	$(CC) -c $(CFLAGS) internal/critical.c

#deh.o : internal/mars.h internal/deh.cA
#	$(CC) -c $(CFLAGS) internal/deh.c

#minit.o : internal/minit.asm
#	$(CC) -c internal/minit.asm

monitor.o : internal/mars.h internal/monitor.c
	$(CC) -c $(CFLAGS) internal/monitor.c

### std

std_%.o : std/%.d
	$(DMD) -c $(DFLAGS) -of$@ $<

# Exception
Dzlib.o : std/zlib.d
	$(DMD) -c $(DFLAGS) $< -of$@

### std/c

stdarg.o : std/c/stdarg.d
	$(DMD) -c $(DFLAGS) std/c/stdarg.d

c_stdio.o : std/c/stdio.d
	$(DMD) -c $(DFLAGS) std/c/stdio.d -ofc_stdio.o

### std/c/linux

linux.o : std/c/linux/linux.d
	$(DMD) -c $(DFLAGS) std/c/linux/linux.d

linuxsocket.o : std/c/linux/socket.d
	$(DMD) -c $(DFLAGS) std/c/linux/socket.d -oflinuxsocket.o

### etc

### etc/c

Czlib.o : etc/c/zlib.d
	$(DMD) -c $(DFLAGS) etc/c/zlib.d -ofCzlib.o

### std/typeinfo

typeinfo_%.o : std/typeinfo/%.d
	$(DMD) -c $(DFLAGS) -of$@ $<

##########################################################

zip : $(ALLSRCS) linux.mak win32.mak phoboslicense.txt
	$(RM) phobos.zip
	zip phobos $(ALLSRCS) linux.mak win32.mak phoboslicense.txt

clean:
	$(RM) $(LIB) $(OBJS) $(HTML_FILES) unittest unittest.o 
	$(RM) -r $(DOC)
