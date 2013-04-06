# Makefile to build linux D runtime library libphobos2.a and its unit test
#
# make clean => removes all targets built by the makefile
#
# make zip => creates a zip file of all the sources (not targets)
# referred to by the makefile, including the makefile
#
# make release => makes release build of the library (this is also the
# default target)
#
# make debug => makes debug build of the library
#
# make unittest => builds all unittests (for both debug and release)
# and runs them
#
# make html => makes html documentation
#
# make install => copies library to /usr/lib

# Configurable stuff, usually from the command line
#
# OS can be linux, win32, win32remote, win32wine, osx, or freebsd. If left
# blank, the system will be determined by using uname

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

# For now, 32 bit is the default model
ifeq (,$(MODEL))
	MODEL:=32
endif

override PIC:=$(if $(PIC),-fPIC,)

# Configurable stuff that's rarely edited
DRUNTIME_PATH = ../druntime
ZIPFILE = phobos.zip
ROOT_OF_THEM_ALL = generated
ROOT = $(ROOT_OF_THEM_ALL)/$(OS)/$(BUILD)/$(MODEL)
# Documentation-related stuff
DOCSRC = ../d-programming-language.org
WEBSITE_DIR = ../web
DOC_OUTPUT_DIR = $(WEBSITE_DIR)/phobos-prerelease
BIGDOC_OUTPUT_DIR = /tmp
SRC_DOCUMENTABLES = index.d $(addsuffix .d,$(STD_MODULES) $(STD_NET_MODULES) $(STD_DIGEST_MODULES) $(EXTRA_DOCUMENTABLES))
STDDOC = $(DOCSRC)/std.ddoc
BIGSTDDOC = $(DOCSRC)/std_consolidated.ddoc
DDOCFLAGS=-m$(MODEL) -d -c -o- -version=StdDdoc -I$(DRUNTIME_PATH)/import $(DMDEXTRAFLAGS)

# BUILD can be debug or release, but is unset by default; recursive
# invocation will set it. See the debug and release targets below.
BUILD =

# Fetch the makefile name, will use it in recursive calls
MAKEFILE:=$(lastword $(MAKEFILE_LIST))

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
	DMD ?= wine dmd.exe
	RUN = wine
else
	ifeq ($(OS),win32remote)
		DMD ?= ssh 206.125.170.138 "cd code/dmd/phobos && dmd"
		CC = ssh 206.125.170.138 "cd code/dmd/phobos && dmc"
	else
		DMD ?= dmd
		ifeq ($(OS),win32)
			CC = dmc
		else
			CC = cc
		endif
	endif
	RUN =
endif

# Set CFLAGS
CFLAGS :=
ifneq (,$(filter cc% gcc% clang% icc% egcc%, $(CC)))
	CFLAGS += -m$(MODEL) $(PIC)
	ifeq ($(BUILD),debug)
		CFLAGS += -g
	else
		CFLAGS += -O3
	endif
endif

# Set DFLAGS
DFLAGS := -I$(DRUNTIME_PATH)/import $(DMDEXTRAFLAGS) -w -d -property -m$(MODEL) $(PIC)
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

# Set LINKOPTS
ifeq (,$(findstring win,$(OS)))
    ifeq (freebsd,$(OS))
        LINKOPTS=-L-L$(ROOT)
    else
        LINKOPTS=-L-ldl -L-L$(ROOT)
    endif
else
    LINKOPTS=-L/co $(LIB)
endif

# Set DDOC, the documentation generator
DDOC=$(DMD)

# Set LIB, the ultimate target
ifeq (,$(findstring win,$(OS)))
	LIB = $(ROOT)/libphobos2.a
	LIBSO = $(ROOT)/libphobos2so.so
else
	LIB = $(ROOT)/phobos.lib
endif

################################################################################
MAIN = $(ROOT)/emptymain.d

# Stuff in std/
STD_MODULES = $(addprefix std/, algorithm array ascii base64 bigint		\
        bitmanip compiler complex concurrency container conv		\
        cpuid cstream ctype csv datetime demangle encoding exception	\
        file format functional getopt json math mathspecial md5	\
        metastrings mmfile numeric outbuffer parallelism path perf		\
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
	processinit uni uni_tab)

# Aggregate all D modules relevant to this build
D_MODULES = crc32 $(STD_MODULES) $(EXTRA_MODULES) $(STD_NET_MODULES) $(STD_DIGEST_MODULES)
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

################################################################################
# Rules begin here
################################################################################

ifeq ($(BUILD),)
# No build was defined, so here we define release and debug
# targets. BUILD is not defined in user runs, only by recursive
# self-invocations. So the targets in this branch are accessible to
# end users.
ifeq (linux,$(OS))
release :
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) MODEL=$(MODEL) BUILD=release PIC=1 dll
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) MODEL=$(MODEL) BUILD=release
else
release :
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) MODEL=$(MODEL) BUILD=release
endif
debug :
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) MODEL=$(MODEL) BUILD=debug
unittest :
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) MODEL=$(MODEL) BUILD=debug unittest
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) MODEL=$(MODEL) BUILD=release unittest
else
# This branch is normally taken in recursive builds. All we need to do
# is set the default build to $(BUILD) (which is either debug or
# release) and then let the unittest depend on that build's unittests.
$(BUILD) : $(LIB)
unittest : $(addsuffix $(DOTEXE),$(addprefix $(ROOT)/unittest/,$(D_MODULES)))
endif

################################################################################

$(ROOT)/%$(DOTOBJ) : %.c
	@[ -d $(dir $@) ] || mkdir -p $(dir $@) || [ -d $(dir $@) ]
	$(CC) -c $(CFLAGS) $< -o$@

$(LIB) : $(OBJS) $(ALL_D_FILES) $(DRUNTIME)
	$(DMD) $(DFLAGS) -lib -of$@ $(DRUNTIME) $(D_FILES) $(OBJS)

dll : $(LIBSO)

$(LIBSO): $(OBJS)
	$(DMD) $(DFLAGS) -shared -debuglib= -defaultlib= -of$@ $(DRUNTIMESO) $(D_FILES) $(OBJS)

ifeq (osx,$(OS))
# Build fat library that combines the 32 bit and the 64 bit libraries
libphobos2.a : generated/osx/release/32/libphobos2.a generated/osx/release/64/libphobos2.a
	lipo generated/osx/release/32/libphobos2.a generated/osx/release/64/libphobos2.a -create -output generated/osx/release/libphobos2.a
endif

$(addprefix $(ROOT)/unittest/,$(DISABLED_TESTS)) :
	@echo Testing $@ - disabled

$(ROOT)/unittest/%$(DOTEXE) : %.d $(LIB) $(ROOT)/emptymain.d
	@echo Testing $@
	$(QUIET)$(DMD) $(DFLAGS) -unittest $(LINKOPTS) $(subst /,$(PATHSEP),"-of$@") \
	 	$(ROOT)/emptymain.d $<
# make the file very old so it builds and runs again if it fails
	@touch -t 197001230123 $@
# run unittest in its own directory
	$(QUIET)$(RUN) $@
# succeeded, render the file new again
	@touch $@

# Disable implicit rule
%$(DOTEXE) : %$(DOTOBJ)

$(ROOT)/emptymain.d : $(ROOT)/.directory
	@echo 'void main(){}' >$@

$(ROOT)/.directory :
	mkdir -p $(ROOT) || exists $(ROOT)
	touch $@

clean :
	rm -rf $(ROOT_OF_THEM_ALL) $(ZIPFILE) $(DOC_OUTPUT_DIR)

zip :
	zip $(ZIPFILE) $(MAKEFILE) $(ALL_D_FILES) $(ALL_C_FILES) win32.mak win64.mak

install : release
	sudo cp $(LIB) /usr/lib/

$(DRUNTIME) :
	$(MAKE) -C $(DRUNTIME_PATH) -f posix.mak MODEL=$(MODEL)

###########################################################
# html documentation

HTMLS=$(addprefix $(DOC_OUTPUT_DIR)/, $(subst /,_,$(subst .d,.html,	\
	$(SRC_DOCUMENTABLES))))
BIGHTMLS=$(addprefix $(BIGDOC_OUTPUT_DIR)/, $(subst /,_,$(subst	\
	.d,.html, $(SRC_DOCUMENTABLES))))

$(DOC_OUTPUT_DIR)/. :
	mkdir -p $@

$(DOC_OUTPUT_DIR)/std_%.html : std/%.d $(STDDOC)
	$(DDOC) $(DDOCFLAGS)  $(STDDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_c_%.html : std/c/%.d $(STDDOC)
	$(DDOC) $(DDOCFLAGS)  $(STDDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_c_linux_%.html : std/c/linux/%.d $(STDDOC)
	$(DDOC) $(DDOCFLAGS)  $(STDDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_c_windows_%.html : std/c/windows/%.d $(STDDOC)
	$(DDOC) $(DDOCFLAGS) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_net_%.html : std/net/%.d $(STDDOC)
	$(DDOC) $(DDOCFLAGS)  $(STDDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_digest_%.html : std/digest/%.d $(STDDOC)
	$(DDOC) $(DDOCFLAGS)  $(STDDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/etc_c_%.html : etc/c/%.d $(STDDOC)
	$(DDOC) $(DDOCFLAGS)  $(STDDOC) -Df$@ $<

$(DOC_OUTPUT_DIR)/%.html : %.d $(STDDOC)
	$(DDOC) $(DDOCFLAGS)  $(STDDOC) -Df$@ $<

html : $(DOC_OUTPUT_DIR)/. $(HTMLS) $(STYLECSS_TGT)

rsync-prerelease : html
	rsync -avz $(DOC_OUTPUT_DIR)/ d-programming@digitalmars.com:data/phobos-prerelease/
	rsync -avz $(WEBSITE_DIR)/ d-programming@digitalmars.com:data/phobos-prerelase/

html_consolidated :
	$(DDOC) $(DDOCFLAGS) -Df$(DOCSRC)/std_consolidated_header.html $(DOCSRC)/std_consolidated_header.dd
	$(DDOC) $(DDOCFLAGS) -Df$(DOCSRC)/std_consolidated_footer.html $(DOCSRC)/std_consolidated_footer.dd
	$(MAKE) DOC_OUTPUT_DIR=$(BIGDOC_OUTPUT_DIR) STDDOC=$(BIGSTDDOC) html -j 8
	cat $(DOCSRC)/std_consolidated_header.html $(BIGHTMLS)	\
	$(DOCSRC)/std_consolidated_footer.html > $(DOC_OUTPUT_DIR)/std_consolidated.html

