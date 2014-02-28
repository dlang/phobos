# Makefile to build linux D runtime library libphobos2.a and its unit test
#
# make => makes release build of the library
#
# make clean => removes all targets built by the makefile
#
# make zip => creates a zip file of all the sources (not targets)
# referred to by the makefile, including the makefile
#
# make BUILD=debug => makes debug build of the library
#
# make unittest => builds all unittests (for release) and runs them
#
# make BUILD=debug unittest => builds all unittests (for debug) and runs them
#
# make html => makes html documentation
#
# make install => copies library to /usr/lib
#
# make unittest/std/somemodule.d => only builds and unittests std.somemodule
#

################################################################################
# Configurable stuff, usually from the command line
#
# OS can be linux, win32, win32wine, osx, or freebsd. The system will be
# determined by using uname

QUIET:=@

OS:=
uname_S:=$(shell uname -s)
ifeq (Darwin,$(uname_S))
    OS:=osx
endif
ifeq (Linux,$(uname_S))
    OS:=linux
endif
ifeq (FreeBSD,$(uname_S))
    OS:=freebsd
endif
ifeq (OpenBSD,$(uname_S))
    OS:=openbsd
endif
ifeq (Solaris,$(uname_S))
    OS:=solaris
endif
ifeq (SunOS,$(uname_S))
    OS:=solaris
endif
ifeq (,$(OS))
    $(error Unrecognized or unsupported OS for uname: $(uname_S))
endif

ifeq (,$(MODEL))
    uname_M:=$(shell uname -m)
    ifneq (,$(findstring $(uname_M),x86_64 amd64))
        MODEL:=64
    endif
    ifneq (,$(findstring $(uname_M),i386 i586 i686))
        MODEL:=32
    endif
    ifeq (,$(MODEL))
        $(error Cannot figure 32/64 model from uname -m: $(uname_M))
    endif
endif

# Default to a release built, override with BUILD=debug
BUILD=release

ifneq ($(BUILD),release)
    ifneq ($(BUILD),debug)
        $(error Unrecognized BUILD=$(BUILD), must be 'debug' or 'release')
    endif
endif

override PIC:=$(if $(PIC),-fPIC,)

# Configurable stuff that's rarely edited
INSTALL_DIR = ../install
DRUNTIME_PATH = ../druntime
ZIPFILE = phobos.zip
ROOT_OF_THEM_ALL = generated
ROOT = $(ROOT_OF_THEM_ALL)/$(OS)/$(BUILD)/$(MODEL)
# Documentation-related stuff
DOCSRC = ../dlang.org
WEBSITE_DIR = ../web
DOC_OUTPUT_DIR = $(WEBSITE_DIR)/phobos-prerelease
BIGDOC_OUTPUT_DIR = /tmp
SRC_DOCUMENTABLES = index.d $(addsuffix .d,$(STD_MODULES) $(STD_NET_MODULES) $(STD_DIGEST_MODULES) $(EXTRA_DOCUMENTABLES))
STDDOC = $(DOCSRC)/std.ddoc
BIGSTDDOC = $(DOCSRC)/std_consolidated.ddoc
# Set DDOC, the documentation generator
DDOC=$(DMD) -m$(MODEL) -w -c -o- -version=StdDdoc \
    -I$(DRUNTIME_PATH)/import $(DMDEXTRAFLAGS)

# Set DRUNTIME name and full path
ifeq (,$(findstring win,$(OS)))
	DRUNTIME = $(DRUNTIME_PATH)/lib/libdruntime-$(OS)$(MODEL).a
	DRUNTIMESO = $(DRUNTIME_PATH)/lib/libdruntime-$(OS)$(MODEL)so.a
else
	DRUNTIME = $(DRUNTIME_PATH)/lib/druntime.lib
endif

# Set CC and DMD
ifeq ($(OS),win32wine)
	CC = wine dmc.exe
	DMD = wine dmd.exe
	RUN = wine
else
	DMD = ../dmd/src/dmd
	ifeq ($(OS),win32)
		CC = dmc
	else
		CC = cc
	endif
	RUN =
endif

# Set CFLAGS
CFLAGS=
ifneq (,$(filter cc% gcc% clang% icc% egcc%, $(CC)))
	CFLAGS += -m$(MODEL) -fPIC
	ifeq ($(BUILD),debug)
		CFLAGS += -g
	else
		CFLAGS += -O3
	endif
endif

# Set DFLAGS
DFLAGS=-I$(DRUNTIME_PATH)/import $(DMDEXTRAFLAGS) -w -m$(MODEL) $(PIC)
ifeq ($(BUILD),debug)
	DFLAGS += -g -debug
else
	DFLAGS += -O -release
endif

# Set DOTOBJ and DOTEXE
ifeq (,$(findstring win,$(OS)))
	DOTOBJ:=.o
	DOTEXE:=
	PATHSEP:=/
else
	DOTOBJ:=.obj
	DOTEXE:=.exe
	PATHSEP:=$(shell echo "\\")
endif

LINKDL:=$(if $(findstring $(OS),linux),-L-ldl,)

# Set VERSION, where the file is that contains the version string
VERSION=../dmd/VERSION

# Set LIB, the ultimate target
ifeq (,$(findstring win,$(OS)))
	LIB:=$(ROOT)/libphobos2.a
	# 2.064.2 => libphobos2.so.0.64.2
	# 2.065 => libphobos2.so.0.65.0
	# MAJOR version is 0 for now, which means the ABI is still unstable
	MAJOR:=0
	MINOR:=$(shell awk -F. '{ print int($$2) }' $(VERSION))
	PATCH:=$(shell awk -F. '{ print int($$3) }' $(VERSION))
	# SONAME doesn't use patch level (ABI compatible)
	SONAME:=libphobos2.so.$(MAJOR).$(MINOR)
	LIBSO:=$(ROOT)/$(SONAME).$(PATCH)
else
	LIB:=$(ROOT)/phobos.lib
endif

LIBCURL_STUB:=$(if $(findstring $(OS),linux),$(ROOT)/libcurl_stub.so,)
LINKCURL:=$(if $(LIBCURL_STUB),-L$(LIBCURL_STUB),-L-lcurl)

################################################################################
MAIN = $(ROOT)/emptymain.d

# Stuff in std/
STD_MODULES = $(addprefix std/, algorithm array ascii base64 bigint \
        bitmanip compiler complex concurrency container conv		\
        cstream csv datetime demangle encoding exception	\
        file format functional getopt json math mathspecial	\
        metastrings mmfile numeric outbuffer parallelism path		\
        process random range regex signals socket socketstream	\
        stdint stdio stdiobase stream string syserror system traits		\
        typecons typetuple uni uri utf uuid variant xml zip zlib)

STD_NET_MODULES = $(addprefix std/net/, isemail curl)

STD_DIGEST_MODULES = $(addprefix std/digest/, digest crc md ripemd sha)

# OS-specific D modules
EXTRA_MODULES_LINUX := $(addprefix std/c/linux/, linux socket)
EXTRA_MODULES_OSX := $(addprefix std/c/osx/, socket)
EXTRA_MODULES_FREEBSD := $(addprefix std/c/freebsd/, socket)
EXTRA_MODULES_WIN32 := $(addprefix std/c/windows/, com stat windows		\
		winsock) $(addprefix std/windows/, charset iunknown syserror)
ifeq (,$(findstring win,$(OS)))
	EXTRA_DOCUMENTABLES:=$(EXTRA_MODULES_LINUX)
else
	EXTRA_DOCUMENTABLES:=$(EXTRA_MODULES_WIN32)
endif

# Other D modules that aren't under std/
EXTRA_DOCUMENTABLES += $(addprefix etc/c/,curl sqlite3 zlib) $(addprefix	\
std/c/, fenv locale math process stdarg stddef stdio stdlib string	\
time wcharh)
EXTRA_MODULES += $(EXTRA_DOCUMENTABLES) $(addprefix			\
	std/internal/digest/, sha_SSSE3 ) $(addprefix \
	std/internal/math/, biguintcore biguintnoasm biguintx86	\
	gammafunction errorfunction) $(addprefix std/internal/, \
	processinit uni uni_tab unicode_tables \
	unicode_comp unicode_decomp unicode_grapheme unicode_norm)

# Aggregate all D modules relevant to this build
D_MODULES = $(STD_MODULES) $(EXTRA_MODULES) $(STD_NET_MODULES) \
    $(STD_DIGEST_MODULES)
# Add the .d suffix to the module names
D_FILES = $(addsuffix .d,$(D_MODULES))
# Aggregate all D modules over all OSs (this is for the zip file)
ALL_D_FILES = $(addsuffix .d, $(D_MODULES) \
$(EXTRA_MODULES_LINUX) $(EXTRA_MODULES_OSX) $(EXTRA_MODULES_FREEBSD) $(EXTRA_MODULES_WIN32)) \
	std/internal/windows/advapi32.d \
	std/windows/registry.d std/c/linux/pthread.d std/c/linux/termios.d \
	std/c/linux/tipc.d std/net/isemail.d std/net/curl.d

# C files to be part of the build
C_MODULES = $(addprefix etc/c/zlib/, adler32 compress crc32 deflate	\
	gzclose gzlib gzread gzwrite infback inffast inflate inftrees trees uncompr zutil)
C_FILES = $(addsuffix .c,$(C_MODULES))
# C files that are not compiled (right now only zlib-related)
C_EXTRAS = $(addprefix etc/c/zlib/, algorithm.txt ChangeLog crc32.h	\
deflate.h example.c inffast.h inffixed.h inflate.h inftrees.h		\
linux.mak minigzip.c osx.mak README trees.h win32.mak zconf.h		\
win64.mak \
gzguts.h zlib.3 zlib.h zutil.h)
# Aggregate all C files over all OSs (this is for the zip file)
ALL_C_FILES = $(C_FILES) $(C_EXTRAS)

OBJS = $(addsuffix $(DOTOBJ),$(addprefix $(ROOT)/,$(C_MODULES)))

MAKEFILE = $(firstword $(MAKEFILE_LIST))

################################################################################
# Rules begin here
################################################################################

# Main target (builds the dll on linux, too)
ifeq (linux,$(OS))
all : $(BUILD) $(BUILD)_pic
$(BUILD)_pic :
	$(MAKE) -f $(MAKEFILE) OS=$(OS) MODEL=$(MODEL) BUILD=$(BUILD) PIC=1 dll
else
all : $(BUILD)
endif

install :
	$(MAKE) -f $(MAKEFILE) OS=$(OS) MODEL=$(MODEL) BUILD=release INSTALL_DIR=$(INSTALL_DIR) \
		DMD=$(DMD) install2

$(BUILD) : $(LIB)
unittest : $(addsuffix .d,$(addprefix unittest/,$(D_MODULES)))

depend: $(addprefix $(ROOT)/unittest/,$(addsuffix .deps,$(D_MODULES)))

-include $(addprefix $(ROOT)/unittest/,$(addsuffix .deps,$(D_MODULES)))

################################################################################
# Patterns begin here
################################################################################

$(ROOT)/%$(DOTOBJ) : %.c
	@[ -d $(dir $@) ] || mkdir -p $(dir $@) || [ -d $(dir $@) ]
	$(CC) -c $(CFLAGS) $< -o$@

$(LIB) : $(OBJS) $(ALL_D_FILES) druntime_libs
	$(DMD) $(DFLAGS) -lib -of$@ $(DRUNTIME) $(D_FILES) $(OBJS)

dll : $(ROOT)/libphobos2.so

$(ROOT)/libphobos2.so: $(ROOT)/$(SONAME)
	ln -sf $(notdir $(LIBSO)) $@

$(ROOT)/$(SONAME): $(LIBSO)
	ln -sf $(notdir $(LIBSO)) $@

$(LIBSO): $(OBJS) $(ALL_D_FILES) druntime_libs $(LIBCURL_STUB)
	$(DMD) $(DFLAGS) -shared -debuglib= -defaultlib= -of$@ -L-soname=$(SONAME) $(DRUNTIMESO) $(LINKDL) $(LINKCURL) $(D_FILES) $(OBJS)

# stub library with soname of the real libcurl.so (Bugzilla 10710)
$(LIBCURL_STUB):
	@echo "void curl_global_init() {}" > $(ROOT)/libcurl_stub.c
	$(CC) -shared $(CFLAGS) $(ROOT)/libcurl_stub.c -o $@ -Wl,-soname=libcurl.so.4

ifeq (osx,$(OS))
# Build fat library that combines the 32 bit and the 64 bit libraries
libphobos2.a: $(ROOT_OF_THEM_ALL)/osx/release/libphobos2.a
$(ROOT_OF_THEM_ALL)/osx/release/libphobos2.a:
	$(MAKE) -f $(MAKEFILE) OS=$(OS) MODEL=32 BUILD=release
	$(MAKE) -f $(MAKEFILE) OS=$(OS) MODEL=64 BUILD=release
	lipo $(ROOT_OF_THEM_ALL)/osx/release/32/libphobos2.a \
	    $(ROOT_OF_THEM_ALL)/osx/release/64/libphobos2.a \
	    -create -output $@
endif

$(addprefix $(ROOT)/unittest/,$(DISABLED_TESTS)) :
	@echo Testing $@ - disabled

UT_D_OBJS:=$(addprefix $(ROOT)/unittest/,$(addsuffix .o,$(D_MODULES)))
$(UT_D_OBJS): $(ROOT)/unittest/%.o: %.d
	@mkdir -p $(dir $@)
	$(DMD) $(DFLAGS) -unittest -c -of$@ -deps=$(@:.o=.deps.tmp) $<
	@echo $@: `sed 's|.*(\(.*\)).*|\1|' $(@:.o=.deps.tmp) | sort | uniq` \
	   >$(@:.o=.deps)
	@rm $(@:.o=.deps.tmp)
#	$(DMD) $(DFLAGS) -unittest -c -of$@ $*.d

ifneq (linux,$(OS))

$(ROOT)/unittest/test_runner: $(DRUNTIME_PATH)/src/test_runner.d $(UT_D_OBJS) $(OBJS) druntime_libs
	$(DMD) $(DFLAGS) -unittest -of$@ $(DRUNTIME_PATH)/src/test_runner.d $(UT_D_OBJS) $(OBJS) $(DRUNTIME) $(LINKCURL) -defaultlib= -debuglib=

else

UT_LIBSO:=$(ROOT)/unittest/libphobos2-ut.so

$(UT_LIBSO): override PIC:=-fPIC
$(UT_LIBSO): $(UT_D_OBJS) $(OBJS) druntime_libs $(LIBCURL_STUB)
	$(DMD) $(DFLAGS) -shared -unittest -of$@ $(UT_D_OBJS) $(OBJS) $(DRUNTIMESO) $(LINKDL) $(LINKCURL) -defaultlib= -debuglib=

$(ROOT)/unittest/test_runner: $(DRUNTIME_PATH)/src/test_runner.d $(UT_LIBSO)
	$(DMD) $(DFLAGS) -of$@ $< -L$(UT_LIBSO) -defaultlib= -debuglib=

endif

# macro that returns the module name given the src path
moduleName=$(subst /,.,$(1))

unittest/%.d : $(ROOT)/unittest/test_runner
	$(QUIET)$(RUN) $< $(call moduleName,$*)

# Disable implicit rule
%$(DOTEXE) : %$(DOTOBJ)

%/.directory :
	mkdir -p $* || exists $*
	touch $@

clean :
	rm -rf $(ROOT_OF_THEM_ALL) $(ZIPFILE) $(DOC_OUTPUT_DIR)

zip :
	zip $(ZIPFILE) $(MAKEFILE) $(ALL_D_FILES) $(ALL_C_FILES) win32.mak win64.mak

install2 : release
	mkdir -p $(INSTALL_DIR)/lib
	cp $(LIB) $(INSTALL_DIR)/lib/
ifneq (,$(findstring $(OS),linux))
	cp -P $(LIBSO) $(ROOT)/$(SONAME) $(ROOT)/libphobos2.so $(INSTALL_DIR)/lib/
endif
	mkdir -p $(INSTALL_DIR)/import/etc
	mkdir -p $(INSTALL_DIR)/import/std
	cp -r std/* $(INSTALL_DIR)/import/std/
	cp -r etc/* $(INSTALL_DIR)/import/etc/
	cp LICENSE_1_0.txt $(INSTALL_DIR)/phobos-LICENSE.txt

# Target druntime_libs produces $(DRUNTIME) and $(DRUNTIMESO). See
# http://stackoverflow.com/q/7081284 on why this setup makes sense.
.PHONY: druntime_libs
druntime_libs:
	$(MAKE) -C $(DRUNTIME_PATH) -f posix.mak MODEL=$(MODEL) DMD=$(DMD) OS=$(OS)

###########################################################
# html documentation

HTMLS=$(addprefix $(DOC_OUTPUT_DIR)/, $(subst /,_,$(subst .d,.html,	\
	$(SRC_DOCUMENTABLES))))
BIGHTMLS=$(addprefix $(BIGDOC_OUTPUT_DIR)/, $(subst /,_,$(subst	\
	.d,.html, $(SRC_DOCUMENTABLES))))

$(DOC_OUTPUT_DIR)/. :
	mkdir -p $@

$(DOC_OUTPUT_DIR)/std_%.html : std/%.d $(STDDOC)
	$(DDOC) project.ddoc $(STDDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_c_%.html : std/c/%.d $(STDDOC)
	$(DDOC) project.ddoc $(STDDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_c_linux_%.html : std/c/linux/%.d $(STDDOC)
	$(DDOC) project.ddoc $(STDDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_c_windows_%.html : std/c/windows/%.d $(STDDOC)
	$(DDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_net_%.html : std/net/%.d $(STDDOC)
	$(DDOC) project.ddoc $(STDDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_digest_%.html : std/digest/%.d $(STDDOC)
	$(DDOC) project.ddoc $(STDDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/etc_c_%.html : etc/c/%.d $(STDDOC)
	$(DDOC) project.ddoc $(STDDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/%.html : %.d $(STDDOC)
	$(DDOC) project.ddoc $(STDDOC) -Df$@ $<

html : $(DOC_OUTPUT_DIR)/. $(HTMLS) $(STYLECSS_TGT)

rsync-prerelease : html
	rsync -avz $(DOC_OUTPUT_DIR)/ d-programming@digitalmars.com:data/phobos-prerelease/
	rsync -avz $(WEBSITE_DIR)/ d-programming@digitalmars.com:data/phobos-prerelase/

html_consolidated :
	$(DDOC) -Df$(DOCSRC)/std_consolidated_header.html $(DOCSRC)/std_consolidated_header.dd
	$(DDOC) -Df$(DOCSRC)/std_consolidated_footer.html $(DOCSRC)/std_consolidated_footer.dd
	$(MAKE) DOC_OUTPUT_DIR=$(BIGDOC_OUTPUT_DIR) STDDOC=$(BIGSTDDOC) html -j 8
	cat $(DOCSRC)/std_consolidated_header.html $(BIGHTMLS)	\
	$(DOCSRC)/std_consolidated_footer.html > $(DOC_OUTPUT_DIR)/std_consolidated.html

#############################
