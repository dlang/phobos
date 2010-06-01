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
# OS can be posix, win32, win32remote, win32wine, or osx
OS = posix

# Configurable stuff that's rarely edited
DRUNTIME_PATH = ../druntime
ZIPFILE = phobos.zip
ROOT_OF_THEM_ALL = generated
ROOT = $(ROOT_OF_THEM_ALL)/$(OS)/$(BUILD)
# Documentation-related stuff
DOCSRC = ../docsrc
DOC_OUTPUT_DIR = ../web/2.0/phobos
STYLECSS_SRC = $(DOCSRC)/style.css
STYLECSS_TGT = $(DOC_OUTPUT_DIR)/../style.css
SRC_DOCUMENTABLES = phobos.d $(addsuffix .d,$(STD_MODULES))
STDDOC = $(DOCSRC)/std.ddoc
DDOCFLAGS=-version=ddoc -d -c -o- $(STDDOC)

# Variable defined in an OS-dependent manner (see below)
CC =
DMD =
CFLAGS =
DFLAGS = 

# BUILD can be debug or release, but is unset by default; recursive
# invocation will set it. See the debug and release targets below.
BUILD = 

# Fetch the makefile name, will use it in recursive calls
MAKEFILE:=$(lastword $(MAKEFILE_LIST))

# Set DRUNTIME name and full path
ifeq (,$(findstring win,$(OS)))
	DRUNTIME = $(DRUNTIME_PATH)/lib/libdruntime.a
else
	DRUNTIME = $(DRUNTIME_PATH)/lib/druntime.lib
endif

# Set CC and DMD
ifeq ($(OS),win32wine)
	CC = wine $(HOME)/dmc/bin/dmc.exe
	DMD = wine dmd.exe
else
	ifeq ($(OS),win32remote)
		DMD = ssh 206.125.170.138 "cd code/dmd/phobos && dmd"
		CC = ssh 206.125.170.138 "cd code/dmd/phobos && dmc"
	else
		DMD = dmd
		ifeq ($(OS),win32)
			CC = dmc
		else
			CC = cc
		endif
	endif
endif

# Set CFLAGS
ifeq ($(OS),posix)
	CFLAGS += -m32
	ifeq ($(BUILD),debug)
		CFLAGS += -g
	else
		CFLAGS += -O3
	endif
endif

# Set DFLAGS
DFLAGS := -I$(DRUNTIME_PATH)/import
ifeq ($(BUILD),debug)
	DFLAGS += -w -g -debug -d
else
	DFLAGS += -w -O -release -nofloat -d
endif

# Set DOTOBJ and DOTEXE
ifeq (,$(findstring win,$(OS)))
	DOTOBJ:=.o
	DOTEXE=
else
	DOTOBJ:=.obj
	DOTEXE=.exe
endif

# Set LINKOPTS
ifeq ($(OS),posix)
	LINKOPTS=-L-ldl -L-L$(ROOT)
else
	LINKOPTS=
endif

# Set LIB, the ultimate target
ifeq (,$(findstring win,$(OS)))
	LIB = $(ROOT)/libphobos2.a
else
	LIB = $(ROOT)/phobos.lib
endif

################################################################################
MAIN = $(ROOT)/emptymain.d

# Stuff in std/
STD_MODULES = $(addprefix std/, algorithm array atomics base64 bigint	\
        bitmanip boxer compiler complex contracts conv cpuid cstream	\
        ctype date datebase dateparse demangle encoding file format		\
        functional getopt intrinsic iterator json loader math md5		\
        metastrings mmfile numeric outbuffer path perf process random	\
        range regex regexp signals socket socketstream stdint stdio		\
        stdiobase stream string syserror system traits typecons			\
        typetuple uni uri utf variant xml zip zlib)

# Other D modules that aren't under std/
EXTRA_MODULES := $(addprefix std/c/, stdarg stdio) $(addprefix etc/c/,	\
        zlib) $(addprefix std/internal/math/, biguintcore biguintnoasm  \
        biguintx86 )

# OS-specific D modules
EXTRA_MODULES_POSIX := $(addprefix std/c/linux/, linux socket)
EXTRA_MODULES_WIN32 := $(addprefix std/c/windows/, com stat windows		\
		winsock) $(addprefix std/windows/, charset iunknown syserror)
ifeq (,$(findstring win,$(OS)))
	EXTRA_MODULES+=$(EXTRA_MODULES_POSIX)
else
	EXTRA_MODULES+=$(EXTRA_MODULES_WIN32)
endif

# Aggregate all D modules relevant to this build
D_MODULES = crc32 $(STD_MODULES) $(EXTRA_MODULES)
# Add the .d suffix to the module names
D_FILES = $(addsuffix .d,$(D_MODULES))
# Aggregate all D modules over all OSs (this is for the zip file)
ALL_D_FILES = $(addsuffix .d,crc32 $(STD_MODULES) $(EXTRA_MODULES)	\
$(EXTRA_MODULES_POSIX) $(EXTRA_MODULES_WIN32))

# C files to be part of the build
C_MODULES = $(addprefix etc/c/zlib/, adler32 compress crc32 deflate	\
	gzio infback inffast inflate inftrees trees uncompr zutil)
C_FILES = $(addsuffix .c,$(C_MODULES))
# C files that are not compiled (right now only zlib-related)
C_EXTRAS = $(addprefix etc/c/zlib/, algorithm.txt ChangeLog crc32.h	\
deflate.h example.c inffast.h inffixed.h inflate.h inftrees.h		\
linux.mak minigzip.c osx.mak README trees.h win32.mak zconf.h		\
zconf.in.h zlib.3 zlib.h zutil.h)
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
release : 
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) BUILD=release
debug : 
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) BUILD=debug
unittest : 
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) BUILD=debug unittest
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) BUILD=release unittest
else
# This branch is normally taken in recursive builds. All we need to do
# is set the default build to $(BUILD) (which is either debug or
# release) and then let the unittest depend on that build's unittests.
$(BUILD) : $(LIB)
unittest : $(addprefix $(ROOT)/unittest/,$(D_MODULES))
endif

################################################################################

$(ROOT)/%$(DOTOBJ) : %.c
	@[ -d $(dir $@) ] || mkdir -p $(dir $@) || [ -d $(dir $@) ]
	$(CC) -c $(CFLAGS) $< -o$@

$(LIB) : $(OBJS) $(ALL_D) $(DRUNTIME)
	$(DMD) $(DFLAGS) -lib -of$@ $(DRUNTIME) $(D_FILES) $(OBJS)

$(ROOT)/unittest/%$(DOTEXE) : %.d $(LIB) $(ROOT)/emptymain.d
	@echo Testing $@
	@$(DMD) $(DFLAGS) -unittest $(LINKOPTS) -of$@ $(ROOT)/emptymain.d $<
# make the file very old so it builds and runs again if it fails
	@touch -t 197001230123 $@
# run unittest in its own directory
	@$@
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
	zip $(ZIPFILE) $(MAKEFILE) $(ALL_D_FILES) $(ALL_C_FILES)

install : release
	sudo cp $(LIB) /usr/lib/

$(DRUNTIME) :
	$(MAKE) -C $(DRUNTIME_PATH) -f posix.mak

###########################################################
# html documentation

$(DOC_OUTPUT_DIR)/%.html : %.d $(STDDOC)
	wine dmd $(DDOCFLAGS) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_%.html : std/%.d $(STDDOC)
	wine dmd $(DDOCFLAGS) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_c_%.html : std/c/%.d $(STDDOC)
	wine dmd $(DDOCFLAGS) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_c_linux_%.html : std/c/linux/%.d $(STDDOC)
	wine dmd $(DDOCFLAGS) -Df$@ $<

$(STYLECSS_TGT) : $(STYLECSS_SRC)
	cp $< $@

html : $(addprefix $(DOC_OUTPUT_DIR)/, $(subst /,_,$(subst .d,.html,	\
	$(SRC_DOCUMENTABLES)))) $(STYLECSS_TGT)
	@$(MAKE) -f $(DOCSRC)/linux.mak -C $(DOCSRC) --no-print-directory
