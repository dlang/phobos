# ##############################################################################
# File:         makefile.unix
#
# Purpose:      GCC 3.2+ makefile for the recls library (std.recls)
#
# Created:      24th November 2003
# Updated:      24th November 2003
#
# Copyright:    Synesis Software Pty Ltd, (c) 2003. All rights reserved.
#
# Home:         www.synesis.com.au/software
#
# ##############################################################################

# ##############################################################################
# Macros

CC				=	g++
LD				=	g++
AR				=	ar

RECLS_INCLUDE			=	.
RECLS_LIBDIR			=   .
RECLS_SRCDIR			=   .

STLSOFT_RECLS_PATCH_INCLUDE	=	#$(RECLS_INCLUDE)

STLSOFT_INCLUDE		=	../stlsoft

F_WARN_ALL	=	-Wall
F_WARN_AS_ERR	=	#
F_OPT_SPEED	=	-O4
F_TARG_PENTIUM	=	-mcpu=i686
F_NOLOGO	=	


CCFLAGS	= $(F_WARN_ALL) $(F_WARN_AS_ERR) $(F_OPT_SPEED) $(F_TARG_PENTIUM) $(F_NOLOGO)
CCDEFS	= -DNDEBUG -DUNIX -D_M_IX86

CCARGS	= $(CCFLAGS) $(CCDEFS) -c -I. -I$(STLSOFT_INCLUDE)

################################################################################
# Objects

OBJS_C	    =   \
	./recls_api.o		\
	./recls_fileinfo.o	\
	./recls_internal.o	\
	./recls_util.o		\
	./recls_api_unix.o	\
	./recls_fileinfo_unix.o	\
	./recls_util_unix.o


################################################################################
# Suffix rules

.c.o:
	$(CC) $(CCARGS) -o$@ $?

.cpp.o:
	$(CC) $(CCARGS) -o$@ $?

################################################################################
# Targets

target:	$(RECLS_LIBDIR)/librecls.a

clean:
	@echo Cleaning targets
	@rm -f $(RECLS_LIBDIR)/librecls.a
	@rm -f $(OBJS_C)
	@rm -f *.map

# executables

$(RECLS_LIBDIR)/librecls.a:	$(OBJS_C)
	$(AR) -r $@ $(OBJS_C)

################################################################################
