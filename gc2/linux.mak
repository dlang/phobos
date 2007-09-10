
# makefile to build linux D garbage collector

DMD=../../dmd
#DMD=/dmd/bin/dmd
CFLAGS=-g
#DFLAGS=-unittest -g -release
DFLAGS=-release -O -inline -I..
#DFLAGS=-release -inline -O
CC=gcc

OBJS= gc.o gcx.o gcbits.o gclinux.o

SRC= gc.d gcx.d gcbits.d win32.d gclinux.d testgc.d win32.mak linux.mak

.c.o:
	$(CC) -c $(CFLAGS) $*

.d.o:
	$(DMD) -c $(DFLAGS) $*

targets : testgc dmgc.a

testgc : testgc.o $(OBJS) linux.mak ../phobos.a
	$(CC) -o $@ testgc.o $(OBJS) ../phobos.a -lpthread -lm -g -Xlinker -M

testgc.o : testgc.d
	$(DMD) -c $(DFLAGS) testgc.d

dmgc.a : $(OBJS) linux.mak
	ar -r $@ $(OBJS)

gc.o : gc.d
	$(DMD) -c $(DFLAGS) gc.d

gcx.o : gcx.d
	$(DMD) -c $(DFLAGS) gcx.d

gcbits.o : gcbits.d
	$(DMD) -c $(DFLAGS) gcbits.d

gclinux.o : gclinux.d
	$(DMD) -c $(DFLAGS) gclinux.d

zip : $(SRC)
	rm dmgc.zip
	zip dmgc $(SRC)

clean:
	rm $(OBJS) dmgc.a testgc
