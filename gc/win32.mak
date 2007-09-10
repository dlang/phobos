

# Build library with Digital Mars C++
# Copyright (c) 2000-2001 by Digital Mars
# written by Walter Bright
# www.digitalmars.com

#DCHAR=-DUNICODE
DCHAR=

#CFLAGS=-g -cpp $(DCHAR)
CFLAGS=-o -gl -cpp -6 $(DCHAR)
CC=sc

.c.obj:
	$(CC) -c $(CFLAGS) $*

targets : dmgc.lib testgc.exe

OBJS= gc.obj bits.obj win32.obj

SRC1= gc.h gc.c bits.h bits.c os.h win32.c linux.c win32.mak msvc.mak
SRC2=
SRC3=
SRC4=
SRC5=

dmgc.lib : $(OBJS) win32.mak
	del dmgc.lib
	lib dmgc /c/noi +gc+bits+win32;

bits.obj: bits.h bits.c
gc.obj: os.h bits.h gc.h gc.c
win32.obj: os.h win32.c

testgc.obj: gc.h testgc.c

testgc.exe : win32.mak dmgc.lib testgc.obj
	$(CC) -o testgc $(CFLAGS) testgc.obj dmgc.lib

clean :
	del $(OBJS)

zip : $(SRC1)
	zip32 -u dmgc $(SRC1)
#	zip32 -u dmgc $(SRC2)
#	zip32 -u dmgc $(SRC3)
#	zip32 -u dmgc $(SRC4)
#	zip32 -u dmgc $(SRC5)


