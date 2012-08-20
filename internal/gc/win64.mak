
# makefile to build D garbage collector under win32

VCDIR="\Program Files (x86)\Microsoft Visual Studio 10.0\VC"

CC=$(VCDIR)\bin\amd64\cl
LD=$(VCDIR)\bin\amd64\link
LIB=$(VCDIR)\bin\amd64\lib
CP=cp

CFLAGS=/O2 /I$(VCDIR)\INCLUDE
#CFLAGS=/Zi /I$(VCDIR)\INCLUDE

#DMD=..\..\..\dmd
DMD=dmd

#DFLAGS=-m64 -unittest -g -release
#DFLAGS=-m64 -inline -O
DFLAGS=-m64 -release -inline -O
#DFLAGS=-m64 -g

.c.obj:
	$(CC) /c $(CFLAGS) $*.c

.cpp.obj:
	$(CC) /c $(CFLAGS) $*.cpp

.d.obj:
	$(DMD) -c $(DFLAGS) $*

.asm.obj:
	$(CC) -c $*

targets : testgc.exe dmgc64.lib

testgc.exe : testgc.obj dmgc64.lib
	$(DMD) testgc.obj dmgc64.lib -g

testgc.obj : testgc.d

OBJS= gc.obj gcold.obj gcx.obj gcbits.obj win32.obj

SRC= gc.d gcold.d gcx.d gcbits.d win32.d gclinux.d testgc.d win32.mak win64.mak linux.mak

#dmgc64.lib : $(OBJS) win32.mak
#       del dmgc64.lib
#       lib dmgc /c/noi +gc+gcold+gcx+gcbits+win32;

dmgc64.lib : gc.d gcold.obj gcx.d gcbits.d win32.d
	$(DMD) $(DFLAGS) -I..\.. -lib -ofdmgc64.lib gc.d gcold.obj gcx.d gcbits.d win32.d

gc.obj : gc.d
	$(DMD) -c $(DFLAGS) $*

gcold.obj : gcold.d
	$(DMD) -c $(DFLAGS) $*

gcx.obj : gcx.d gcbits.d
	$(DMD) -c $(DFLAGS) gcx gcbits

#gcbits.obj : gcbits.d

win32.obj : win32.d

zip : $(SRC)
	del dmgc.zip
	zip32 dmgc $(SRC)

clean:
	del $(OBJS)
	del dmgc64.lib
	del testgc.exe
