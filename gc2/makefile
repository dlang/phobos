
DMD=..\..\dmd
#DMD=\dmd\bin\dmd
CFLAGS=-g -mn -6 -r -Igc
DFLAGS=-unittest -g -release
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

SRC= gc.d gcx.d gcbits.d win32.d testgc.d

dmgc.lib : $(OBJS) makefile
	del dmgc.lib
	lib dmgc /c/noi +gc+gcx+gcbits+win32;

gc.obj : gc.d
gcx.obj : gcx.d
gcbits.obj : gcbits.d
win32.obj : win32.d

zip : makefile $(SRC)
	zip32 -u dmgc makefile $(SRC)

clean:
	del $(OBJS)
	del dmgc.lib
	del testgc.exe
