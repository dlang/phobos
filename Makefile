# Makefile to build linux D runtime library libphobos2.a and its unit test

DOCDIR = ../web/phobos
DOC_OUTPUT_DIR = ../web/phobos
DRUNTIMEDIR = ../druntime/lib
PRODUCTIONLIBDIR = $(dir $(shell which dmd))/../lib
OBJDIR = obj
DOCSRC = ../docsrc
STDDOC = $(DOCSRC)/std.ddoc
STYLECSS_SRC = $(DOCSRC)/style.css
STYLECSS_TGT = $(DOC_OUTPUT_DIR)/../style.css

################################################################################

CC_win32 = wine /home/andrei/d/dm/bin/dmc.exe
DMD_win32 = wine /home/andrei/dmd/windows/bin/dmd.exe
OBJSUFFIX_win32 = .obj
LIBSUFFIX_win32 = .lib
EXESUFFIX_win32 = .exe
CFLAGS_win32_debug = 
CFLAGS_win32_release = 
LIBDRUNTIME_win32 = 

CC_posix = cc
DMD_posix = dmd
OBJDIR_posix = obj/posix
OBJSUFFIX_posix = .o
LIBSUFFIX_posix = .a
EXESUFFIX_posix =
LIBDRUNTIME_posix = $(DRUNTIMEDIR)/libdruntime.a

CFLAGS_posix_debug = -m32 -g
CFLAGS_posix_release = -m32 -O3
DFLAGS_debug = -w -g -debug
DFLAGS_release = -w -O -release -inline

################################################################################

STD_MODULES = $(addprefix std/, algorithm array atomics base64 bigint	\
        bitarray bitmanip boxer compiler complex contracts conv cpuid	\
        cstream ctype date datebase dateparse demangle encoding file	\
        format functional getopt intrinsic iterator loader math md5		\
        metastrings mmfile numeric openrj outbuffer path perf process	\
        random range regex regexp signals socket socketstream stdint	\
        stdio stdiobase stream string syserror system traits typecons	\
        typetuple uni uri utf variant xml zip zlib)
EXTRA_MODULES = $(addprefix std/c/, stdarg stdio) $(addprefix etc/c/,	\
zlib) etc/algorithm etc/random
EXTRA_MODULES_posix = $(addprefix std/c/linux/, linux socket)
EXTRA_MODULES_win32 = $(addprefix std/c/windows/, com stat windows winsock) \
	$(addprefix std/windows/, charset iunknown syserror)
C_MODULES = $(addprefix etc/c/zlib/, adler32 compress crc32 gzio	\
	uncompr deflate trees zutil inflate infback inftrees inffast)

SRC_DOCUMENTABLES = phobos.d $(addsuffix .d,$(STD_MODULES))

define LINKOPTS_win32
endef
define LINKOPTS_posix
-defaultlib=phobos2tmp_$1 -debuglib=phobos2tmp_$1 -L-ldl
endef

define REL2ABS_win32
'z:$(subst /,\,$(realpath .)/$1)'
endef
define REL2ABS_posix
$1
endef

define ABS2ABS_win32
'z:$(subst /,\,$1)'
endef
define ABS2ABS_posix
$1
endef

define RUN_win32
wine $1
endef
define RUN_posix
$1
endef

################################################################################
define GENERATE
# $1 is OS, $2 is the build

OBJS_$1_$2 = $$(addsuffix $$(OBJSUFFIX_$1), $$(addprefix	\
$$(OBJDIR)/$1/$2/, $$(basename $$(C_MODULES))))
LIB_$1_$2 = $$(OBJDIR)/$1/$2/libphobos2$$(LIBSUFFIX_$1)
SRC2LIB_$1 = $$(addsuffix .d,crc32 $(STD_MODULES) $(EXTRA_MODULES)	\
$(EXTRA_MODULES_$1))

$$(OBJDIR)/$1/$2/%$$(OBJSUFFIX_$1) : %.c $$(OBJDIR)/$1/$2/.directory
	@mkdir --parents $$(dir $$@)
	$(CC_$1) -c $(CFLAGS_$1_$2) -o$$@ $$<

$$(OBJDIR)/$1/$2/unittest/std/% : std/%.d				\
	$(PRODUCTIONLIBDIR)/libphobos2tmp_$2$(LIBSUFFIX_$1)
	@echo 'void main(){}' >/tmp/emptymain.d
	@echo Testing $$@
	@$(DMD_$1) $(DFLAGS_$2) -unittest \
		$$(call LINKOPTS_$1,$2) \
		-of$$(call REL2ABS_$1,$$@) $$(call ABS2ABS_$1,/tmp/emptymain.d) \
		$$(foreach F,$$<,$$(call REL2ABS_$1,$$F)) \
		$(PRODUCTIONLIBDIR)/libphobos2tmp_$2$(LIBSUFFIX_$1)
# make the file very old so it builds and runs again if it fails
	@touch $$@ -t 197001230123
# run unittest
	@$$(call RUN_$1,$$@)
# succeeded, render the file new again
	@touch $$@

$(PRODUCTIONLIBDIR)/libphobos2tmp_$2$$(LIBSUFFIX_$1) : $$(LIB_$1_$2)
	ln -sf $$(realpath $$<) $$@

PRODUCTIONLIB_$1 = $(PRODUCTIONLIBDIR)/libphobos2$(LIBSUFFIX_$1)
ifeq ($2,release)
$1/$2 : $$(PRODUCTIONLIB_$1)
$$(PRODUCTIONLIB_$1) : $$(LIB_$1_$2)
	ln -sf $$(realpath $$<) $$@
else
$1/$2 : $$(LIB_$1_$2)
endif

$$(LIB_$1_$2) : $$(SRC2LIB_$1) $$(OBJS_$1_$2)					\
$(LIBDRUNTIME_$1)
	@echo $(DMD_$1) $(DFLAGS_$2) -lib -of$$@ "[...tons of files...]"
	@$(DMD_$1) $(DFLAGS_$2) -lib -of$$@ $$^

$$(OBJDIR)/$1/$2/.directory :
	mkdir --parents $$@

$1/$2/unittest : $1/$2 $$(addprefix $$(OBJDIR)/$1/$2/unittest/,$(STD_MODULES))

endef

################################################################################
# Default OS is posix, default build is release
default : posix/release
debug : posix/debug
release : posix/release
unittest : posix/release/unittest

posix : posix/debug/unittest posix/release/unittest 
win32 : win32/debug/unittest win32/release/unittest 

all : $(foreach B,debug release, $(foreach S,posix win32, $S/$B))
clean :
	rm -rf $(OBJDIR) $(DOC_OUTPUT_DIR)

$(eval $(foreach B,debug release, $(foreach S,posix win32, $(call	\
	GENERATE,$S,$B))))

###########################################################
# Dox

$(DOC_OUTPUT_DIR)/%.html : %.d $(STDDOC)
	$(DMD_posix) -c -o- -Df$@ $(STDDOC) $<

$(DOC_OUTPUT_DIR)/std_%.html : std/%.d $(STDDOC)
	$(DMD_posix) -c -o- -Df$@ $(STDDOC) $<

$(DOC_OUTPUT_DIR)/std_c_%.html : std/c/%.d $(STDDOC)
	$(DMD_posix) -c -o- -Df$@ $(STDDOC) $<

$(DOC_OUTPUT_DIR)/std_c_linux_%.html : std/c/linux/%.d $(STDDOC)
	$(DMD_posix) -c -o- -Df$@ $(STDDOC) $<

$(STYLECSS_TGT) : $(STYLECSS_SRC)
	cp $< $@

html : $(addprefix $(DOC_OUTPUT_DIR)/, $(subst /,_,$(subst .d,.html,	\
	$(SRC_DOCUMENTABLES)))) $(STYLECSS_TGT)
	$(MAKE) -f $(DOCSRC)/linux.mak -C $(DOCSRC) --no-print-directory

##########################################################
