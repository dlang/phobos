
# makefile to build D garbage collector under win32

DMD=..\..\dmd
#DMD=\dmd\bin\dmd
CFLAGS=-g -mn -6 -r -Igc
#DFLAGS=-unittest -g -release
DFLAGS=-release -O -inline
#DFLAGS=-release -inline -O
CC=sc

.c.obj:
	$(CC) -c $(CFLAGS) $*

.cpp.obj:
	$(CC) -c $(CFLAGS) $*

.d.obj:
	$(DMD) -c $(DFLAGS) $*

.asm.obj:
	$(CC) -c $*

targets : testgc.exe dmgc.lib

testgc.exe : testgc.obj dmgc.lib
	$(DMD) testgc.obj dmgc.lib -g

testgc.obj : testgc.d

OBJS= gc.obj gcx.obj gcbits.obj win32.obj

SRC= gc.d gcx.d gcbits.d win32.d gclinux.d testgc.d win32.mak linux.mak

dmgc.lib : $(OBJS) makefile
	del dmgc.lib
	lib dmgc /c/noi +gc+gcx+gcbits+win32;

gc.obj : gc.d
gcx.obj : gcx.d
gcbits.obj : gcbits.d
win32.obj : win32.d

zip : $(SRC)
	del dmgc.zip
	zip32 dmgc $(SRC)

clean:
	del $(OBJS)
	del dmgc.lib
	del testgc.exe
