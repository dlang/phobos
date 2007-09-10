!IF !DEFINED(NULL)
!IF DEFINED(OS) && "$(OS)" == "Windows_NT"
NULL=
!ELSE
NULL="NUL"
!ENDIF
!ENDIF

CC=cl

DCHAR=-DUNICODE
#DCHAR=

CPPFLAGS= $(CPPFLAGS) $(DCHAR) /W4 /GR /Gy /TP /Fd$(OUTDIR)\dmgcvc.pdb
LFLAGS=/DEBUG /DEBUGTYPE:CV /PDBTYPE:CON
LIBFLAGS=

# Debug settings
!IF !DEFINED(BUILD_CONFIG) || "$(BUILD_CONFIG)" == "DEBUG" || "$(BUILD_CONFIG)" == "debug"
OUTDIR=Debug
DEFAULTLIBFLAG= /MDd
CPPFLAGS= $(CPPFLAGS) $(DEFAULTLIBFLAG) /D_DEBUG /DDEBUG /ZI

!ELSE

# Release settings
DEFAULTLIBFLAG= /MD
CPPFLAGS= $(CPPFLAGS) $(DEFAULTLIBFLAG) /Zi /Ox
OUTDIR=Release
LFLAGS=$(LFLAGS) /OPT:REF /OPT:ICF,2

!ENDIF

!IF "$(GENERATE_COD_FILES)" == "1"
CPPFLAGS=$(CPPFLAGS) /FAcs /Fa$*.cod
!ENDIF

.c{$(OUTDIR)}.obj:
	$(CC) -c $(CPPFLAGS) /Fo$@ $<

targets : $(OUTDIR) \
    $(OUTDIR)\dmgcvc.lib \
    $(OUTDIR)\testgc.exe
    

$(OUTDIR):
 -@IF NOT EXIST "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

OBJS1= $(OUTDIR)\gc.obj $(OUTDIR)\bits.obj $(OUTDIR)\win32.obj
OBJS2=
OBJS3=
OBJS4=
OBJS5=

OBJS= $(OBJS1) $(OBJS2) $(OBJS3) $(OBJS4) $(OBJS5)

SRC1= gc.h gc.c bits.h bits.c os.h win32.c linux.c
SRC2=
SRC3=
SRC4=
SRC5= linux.mak win32.mak
SRC6= msvc.mak

$(OUTDIR)\dmgcvc.lib : $(OBJS) msvc.mak $(OUTDIR)\_libcmd.rsp
	lib /out:$@ @$(OUTDIR)\_libcmd.rsp
	-del $(OUTDIR)\_libcmd.rsp

$(OUTDIR)\_libcmd.rsp : msvc.mak
	echo $(OBJS1) >  $(OUTDIR)\_libcmd.rsp
#	echo $(OBJS2) >> $(OUTDIR)\_libcmd.rsp
#	echo $(OBJS3) >> $(OUTDIR)\_libcmd.rsp
#	echo $(OBJS4) >> $(OUTDIR)\_libcmd.rsp
#	echo $(OBJS5) >> $(OUTDIR)\_libcmd.rsp

$(OUTDIR)\bits.obj: bits.h bits.c
$(OUTDIR)\gc.obj: os.h bits.h gc.h gc.c
$(OUTDIR)\win32.obj: os.h win32.c
$(OUTDIR)\testgc.obj: gc.h testgc.c

$(OUTDIR)\testgc.exe : msvc.mak $(OUTDIR)\dmgcvc.lib $(OUTDIR)\testgc.obj
	$(CC) $(DEFAULTLIBFLAG) $(OUTDIR)\testgc.obj /link $(OUTDIR)\dmgcvc.lib /out:$@

test : $(OUTDIR)\testgc.exe
	testgc

clean:
    @echo Cleaning $(BUILD_CONFIG)
    -@IF EXIST "$(OUTDIR)/$(NULL)" delnode /q "$(OUTDIR)"

zip : $(SRC1) $(SRC2) $(SRC3) $(SRC4) $(SRC5) $(SRC6)
	zip32 -u dmgc $(SRC1)
	zip32 -u dmgc $(SRC2)
	zip32 -u dmgc $(SRC3)
	zip32 -u dmgc $(SRC4)
	zip32 -u dmgc $(SRC5)
	zip32 -u dmgc $(SRC6)

