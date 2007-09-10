# ##############################################################################
# File:         makefile.win32
#
# Purpose:      Digital Mars C/C++ 8.38+ makefile for the recls library (std.recls)
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

CC				=	dmc

RECLS_LIBDIR			= .

STLSOFT_RECLS_PATCH_INCLUDE	= $(RECLS_INCLUDE)

STLSOFT_INCLUDE			= ..\stlsoft

CCFLAGS	= -wx -o
CCDEFS	= -DNDEBUG

CCARGS	= $(CCFLAGS) $(CCDEFS) -c -I. -I$(STLSOFT_INCLUDE) -Ic:\dm\stlport\stlport

################################################################################
# Objects

OBJS_C	    =   \
	.\recls_api.obj			\
	.\recls_fileinfo.obj		\
	.\recls_internal.obj		\
	.\recls_util.obj		\
	.\recls_api_win32.obj		\
	.\recls_fileinfo_win32.obj	\
	.\recls_util_win32.obj


################################################################################
# Suffix rules

.c.obj:
	$(CC) $(CCARGS) -o$@ $?

.cpp.obj:
	$(CC) $(CCARGS) -o$@ $?

################################################################################
# Targets

target:	$(RECLS_LIBDIR)\recls.lib

clean:
	@echo Cleaning other file types
	@if exist $(RECLS_LIBDIR)\recls.lib del $(RECLS_LIBDIR)\recls.lib
	@del $(OBJS_C) 2>NUL
	@if exist *.map del *.map

# executables

$(RECLS_LIBDIR)\recls.lib:	$(OBJS_C)
	lib -c $@ $(OBJS_C)

################################################################################
