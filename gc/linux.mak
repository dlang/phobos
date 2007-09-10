##
## Linux makefile for dscript "dmgc"
##
## Copyright (C) 2001 Digital Mars
## All Rights Reserved
##

CC= g++

CHILICOM_DIR= ../../chilicom_sdk

CHILI_FLAGS= \
	-D_XOPEN_SOURCE=500 -D_XOPEN_SOURCE_EXTENDED=1 -D_BSD_SOURCE=1 \
	-D_POSIX_C_SOURCE=199903 -D_POSIX_PTHREAD_SEMANTICS=1 \
	-DEVENTLOG_ASSERTIONS -D_WIN32

#OPT=-g
OPT=-O2 -w

FLAGS= -DUNICODE $(CHILI_FLAGS) -I$(CHILICOM_DIR)/include -L$(CHILICOM_DIR)/lib/linux2_debug

CFLAGS= \
    $(OPT) -fPIC -Wall -Wno-non-virtual-dtor \
    -D_GNU_SOURCE -D_THREAD_SAFE -D_REENTRANT=1 \
    $(FLAGS)

OBJS= gc.o bits.o linux.o

default: dmgc.a testgc

tests: testgc

dmgc.a : $(OBJS)
	ar -r $@ $(OBJS) 

testgc : dmgc.a testgc.o
	$(CC) -o $@ $(CFLAGS) testgc.o dmgc.a $(LIBS)

bits.o: bits.h bits.c
gc.o: os.h bits.h gc.h gc.c
linux.o: os.h linux.c

clean:
	-rm -f *.a 
	-rm -f *.o
	-rm -f testgc

.cpp.o :
	$(CC) -c $(CFLAGS) $<

.c.o :
	$(CC) -c $(CFLAGS) $<

