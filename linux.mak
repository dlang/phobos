# Makefile to build linux D runtime library libphobos2.a and its unit test

DOC_OUTPUT_DIR = ../web/2.0/phobos
DRUNTIMEDIR = ../druntime
PRODUCTIONLIBDIR = $(dir $(shell which dmd))../lib
OBJDIR = obj
DOCSRC = ../docsrc
STDDOC = $(DOCSRC)/std.ddoc
STYLECSS_SRC = $(DOCSRC)/style.css
STYLECSS_TGT = $(DOC_OUTPUT_DIR)/../style.css

OS = wine posix win32remote
BUILDS = debug release

################################################################################

# Wine options
CC_wine = dmc.exe
DMD_wine = dmd.exe
OBJSUFFIX_wine = .obj
LIB_wine = phobos.lib
EXESUFFIX_wine = .exe
CFLAGS_wine_debug = $(CFLAGS)
CFLAGS_wine_release = $(CFLAGS)
LIBDRUNTIME_wine = 

# Win32 remote options
CC_win32remote = dmc.exe
DMD_win32remote = dmd.exe
OBJSUFFIX_win32remote = .obj
LIB_win32remote = phobos.lib
EXESUFFIX_win32remote = .exe
CFLAGS_win32remote_debug = $(CFLAGS)
CFLAGS_win32remote_release = $(CFLAGS)
LIBDRUNTIME_win32remote = 

# These options only pertain to Andrei's settings for accessing the
# server donated by Adam Ruppe
SERVER_win32remote = 206.125.170.138
SERVERDIR_win32remote = code/dmd/phobos
HOMEMAP_win32remote = /ssh/winmachine/home/andrei

# Posix options
CC_posix = $(CC)
DMD_posix = dmd
OBJSUFFIX_posix = .o
LIB_posix = libphobos2.a
EXESUFFIX_posix =
LIBDRUNTIME_posix = $(DRUNTIMEDIR)/libdruntime.a
CFLAGS_posix_debug = -m32 -g $(CFLAGS)
CFLAGS_posix_release = -m32 -O3 $(CFLAGS)

# D flags for all OSs, but customized by build
DFLAGS_debug = -w -g -debug -d $(DFLAGS)
DFLAGS_release = -w -O -release -nofloat -d $(DFLAGS)

# D flags for documentation generation
DDOCFLAGS=-version=ddoc -d -c -o- $(STDDOC)

################################################################################

STD_MODULES = $(addprefix std/, algorithm array atomics base64 bigint	\
        bitmanip boxer concurrency compiler complex contracts conv      \
        cpuid cstream ctype date datebase dateparse demangle encoding   \
        file format	functional getopt intrinsic iterator json loader    \
        math md5 metastrings mmfile numeric outbuffer path perf process \
        random range regex regexp signals socket socketstream stdint    \
        stdio stdiobase stream string syserror system traits typecons	\
        typetuple uni uri utf variant xml zip zlib)
EXTRA_MODULES = $(addprefix std/c/, stdarg stdio) $(addprefix etc/c/,	\
zlib)
EXTRA_MODULES_posix = $(addprefix std/c/linux/, linux socket)
EXTRA_MODULES_wine = $(addprefix std/c/windows/, com stat windows winsock) \
	$(addprefix std/windows/, charset iunknown syserror)
EXTRA_MODULES_win32remote = $(EXTRA_MODULES_wine)
C_MODULES = $(addprefix etc/c/zlib/, adler32 compress crc32 gzio	\
	uncompr deflate trees zutil inflate infback inftrees inffast)

SRC_DOCUMENTABLES = phobos.d $(addsuffix .d,$(STD_MODULES))

define LINKOPTS_wine
endef
define LINKOPTS_win32remote
endef
define LINKOPTS_posix
-L-ldl -L-Lobj/posix/$1/
endef

define REL2ABS_wine
'z:$(subst /,\,$(abspath $1))'
endef
define REL2ABS_win32remote
'z:$(subst /,\,$(abspath $1))'
endef
define REL2ABS_posix
$(abspath $1)
endef

define REL2REL_wine
'$(subst /,\,$1)'
endef
define REL2REL_win32remote
'$(subst /,\\,$1)'
endef
define REL2REL_posix
$1
endef

define RUN_wine
wine $1
endef
define RUN_win32remote
ssh $(SERVER_win32remote) "cd $(SERVERDIR_win32remote) && $1"
endef
define RUN_posix
$1
endef

################################################################################
define GENERATE
# $1 is OS, $2 is the build

ROOT$1$2 = $$(OBJDIR)/$1/$2
OBJS_$1_$2 = $$(addsuffix $$(OBJSUFFIX_$1), $$(addprefix	\
$$(OBJDIR)/$1/$2/, $$(basename $$(C_MODULES))))
LIB_$1_$2 = $$(OBJDIR)/$1/$2/$$(LIB_$1)
SRC2LIB_$1 = $$(addsuffix .d,crc32 $(STD_MODULES) $(EXTRA_MODULES)	\
$(EXTRA_MODULES_$1))
CC$1$2 = $$(call RUN_$1,$(CC_$1))
DMD$1$2 = $$(call RUN_$1,$(DMD_$1))

$$(ROOT$1$2)/%$$(OBJSUFFIX_$1) : %.c $$(ROOT$1$2)/.directory	
	@[ -d $$(dir $$@) ] || mkdir -p $$(dir $$@) || [ -d $$(dir $$@) ]
	$$(CC$1$2) -c $(CFLAGS_$1_$2) -o$$@ $$<

$$(ROOT$1$2)/emptymain.d : $$(ROOT$1$2)/.directory
	@echo 'void main(){}' >$$@

$$(ROOT$1$2)/unittest/std/%$$(EXESUFFIX_$1) : std/%.d $$(LIB_$1_$2) $$(ROOT$1$2)/emptymain.d
	@echo Testing $$@
	@$$(DMD$1$2) $(DFLAGS_$2) -unittest \
		$$(call LINKOPTS_$1,$2) \
		-of$$(call REL2REL_$1,$$@) \
		$$(ROOT$1$2)/emptymain.d \
		$$(foreach F,$$<,$$F)
# make the file very old so it builds and runs again if it fails
	@touch -t 197001230123 $$@
# run unittest in its own directory
#cd $$(dir $$@) && $$(call RUN_$1,./`basename $$@`)
	@$$(call RUN_$1,$$@)
# succeeded, render the file new again
	@touch $$@

# $(PRODUCTIONLIBDIR)/tmp_$2$$(LIB_$1) : $$(LIB_$1_$2)
# 	ln -sf $$(realpath $$<) $$@

$1/$2 : $$(LIB_$1_$2)
$$(LIB_$1_$2) : $$(SRC2LIB_$1) $$(OBJS_$1_$2)					\
$(LIBDRUNTIME_$1)
#	@echo $$(DMD$1$2) $(DFLAGS_$2) -lib -of$$@ "[...tons of files...]"
	$$(DMD$1$2) $(DFLAGS_$2) -lib -of$$@ $$^

$$(ROOT$1$2)/.directory :
	mkdir -p $$(OBJDIR) || exists $$(OBJDIR)
	if [ "$(SERVER_$1)" != "" ]; then \
		$$(call RUN_$1,mkdir) -p $$(OBJDIR)/$1 && \
		ln -sf $(HOMEMAP_$1)/$(SERVERDIR_$1)/$$(OBJDIR)/$1 obj/ ; \
	fi
	mkdir -p $$@ || [ -d $$@ ]

$1/$2/unittest : $1/$2 $$(addsuffix $$(EXESUFFIX_$1),$$(addprefix $$(OBJDIR)/$1/$2/unittest/,$(STD_MODULES)))

endef

################################################################################
# Default OS is posix, default build is release
default : posix/release

# Define targets windows posix etc.
$(foreach S,$(OS), $(eval $S : $(foreach B,$(BUILDS), $S/$B/unittest)))

# Define targets debug release
$(foreach B,$(BUILDS), $(eval $B : $(foreach S,$(OS), $S/$B/unittest)))

# The unittest target builds unittests for all OSs
unittest : $(foreach S,$(OS), $S)

# # Production replaces the produc
# production : posix/release
# 	ln -sf $(realpath $(OBJDIR)/posix/release/$(LIB_posix)) \
# 		$(PRODUCTIONLIBDIR)/$(LIB_posix)

all : $(BUILDS) html
clean :
	rm -rf $(foreach S,$(OS),$(OBJDIR)/$S/* $(OBJDIR)/$S/)
	rm -rf $(OBJDIR) $(DOC_OUTPUT_DIR)

# This generates the entire thingy
$(eval $(foreach B,$(BUILDS), $(foreach S,$(OS), $(call	\
	GENERATE,$S,$B))))

###########################################################
# Dox

$(DOC_OUTPUT_DIR)/%.html : %.d $(STDDOC)
	$(call RUN_wine,$(DMD_wine)) $(DDOCFLAGS) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_%.html : std/%.d $(STDDOC)
	$(call RUN_wine,$(DMD_wine)) $(DDOCFLAGS) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_c_%.html : std/c/%.d $(STDDOC)
	$(call RUN_wine,$(DMD_wine)) $(DDOCFLAGS) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_c_linux_%.html : std/c/linux/%.d $(STDDOC)
	$(call RUN_wine,$(DMD_wine)) $(DDOCFLAGS) -Df$@ $<

$(STYLECSS_TGT) : $(STYLECSS_SRC)
	cp $< $@

html : $(addprefix $(DOC_OUTPUT_DIR)/, $(subst /,_,$(subst .d,.html,	\
	$(SRC_DOCUMENTABLES)))) $(STYLECSS_TGT)
	@$(MAKE) -f $(DOCSRC)/linux.mak -C $(DOCSRC) --no-print-directory

##########################################################
