
// Copyright (C) 2001-2002 by Digital Mars
// All Rights Reserved
// Written by Walter Bright
// www.digitalmars.com

// GC tester program

import c.stdio;
import c.stdlib;
import string;

import gcstats;
import gc;
import gcx;
import random;

void printStats(GC *gc)
{
    GCStats stats;

    //gc.getStats(stats);
    printf("poolsize = x%x, usedsize = x%x, freelistsize = x%x, freeblocks = %d, pageblocks = %d\n",
	stats.poolsize, stats.usedsize, stats.freelistsize, stats.freeblocks, stats.pageblocks);
}

uint PERMUTE(uint key)
{
    return key + 1;
}

void fill(void *p, uint key, uint size)
{
    uint i;
    byte *q = (byte *)p;

    for (i = 0; i < size; i++)
    {
	key = PERMUTE(key);
	q[i] = (byte)key;
    }
}

void verify(void *p, uint key, uint size)
{
    uint i;
    byte *q = (byte *)p;

    for (i = 0; i < size; i++)
    {
	key = PERMUTE(key);
	assert(q[i] == (byte)key);
    }
}

long desregs()
{
    return strlen("foo");
}

/* ---------------------------- */

void smoke()
{
    GC *gc;

    printf("--------------------------smoke()\n");

    gc = newGC();
    deleteGC(gc);

    gc = newGC();
    gc.init();
    deleteGC(gc);

    gc = newGC();
    gc.init();
    char *p = (char *)gc.malloc(10);
    assert(p);
    strcpy(p, "Hello!");
//    char *p2 = gc.strdup(p);
//    printf("p2 = %x, '%s'\n", p2, p2);
//    int result = strcmp(p, p2);
//    assert(result == 0);
//    gc.strdup(p);

    printf("p  = %x\n", p);
    p = null;
    gc.fullCollect();
    printStats(gc);

    deleteGC(gc);
}

/* ---------------------------- */

void finalizer(void *p, void *dummy)
{
}

void smoke2()
{
    GC *gc;
    int *p;
    int i;

    const int SMOKE2_SIZE = 100;
    int *foo[SMOKE2_SIZE];

    printf("--------------------------smoke2()\n");

    gc = newGC();
    gc.init();

    for (i = 0; i < SMOKE2_SIZE; i++)
    {
	p = (int *)gc.calloc(i + 1, 500);
	p[0] = i * 3;
	foo[i] = p;
	gc.setFinalizer((void *)p, &finalizer);
    }

    for (i = 0; i < SMOKE2_SIZE; i += 2)
    {
	p = foo[i];
	if (p[0] != i * 3)
	{
	    printf("p = %x, i = %d, p[0] = %d\n", p, i, p[0]);
	    //c.stdio.fflush(stdout);
	}
	assert(p[0] == i * 3);
	gc.free(p);
    }

    p = null;
    foo[] = null;

    gc.fullCollect();
    printStats(gc);

    deleteGC(gc);
}

/* ---------------------------- */

void smoke3()
{
    GC *gc;
    int *p;
    int i;

    printf("--------------------------smoke3()\n");

    gc = newGC();
    gc.init();

//    for (i = 0; i < 1000000; i++)
    for (i = 0; i < 1000; i++)
    {
	uint size = rand() % 2048;
	p = (int *)gc.malloc(size);
	memset(p, i, size);

	size = rand() % 2048;
	p = (int *)gc.realloc(p, size);
	memset(p, i + 1, size);
    }

    p = null;
    desregs();
    gc.fullCollect();
    printStats(gc);

    deleteGC(gc);
}

/* ---------------------------- */

void smoke4()
{
    GC *gc;
    int *p;
    int i;

    printf("--------------------------smoke4()\n");

    gc = newGC();
    gc.init();

    for (i = 0; i < 80000; i++)
    {
	uint size = i;
	p = (int *)gc.malloc(size);
	memset(p, i, size);

	size = rand() % 2048;
	gc.check(p);
	p = (int *)gc.realloc(p, size);
	memset(p, i + 1, size);
    }

    p = null;
    desregs();
    gc.fullCollect();
    printStats(gc);

    deleteGC(gc);
}

/* ---------------------------- */

void smoke5(GC *gc)
{
    byte *p;
    int i;
    int j;
    const int SMOKE5_SIZE = 1000;
    byte *array[SMOKE5_SIZE];
    uint offset[SMOKE5_SIZE];

    printf("--------------------------smoke5()\n");
    //printf("gc = %p\n", gc);
    //printf("gc = %p, gcx = %p, self = %x\n", gc, gc.gcx, gc.gcx.self);

    for (j = 0; j < 20; j++)
    {
	for (i = 0; i < 2000 /*4000*/; i++)
	{
	    uint size = (rand() % 2048) + 1;
	    uint index = rand() % SMOKE5_SIZE;

	    //printf("index = %d, size = %d\n", index, size);
	    p = array[index] - offset[index];
	    p = (byte *)gc.realloc(p, size);
	    if (array[index])
	    {	uint s;

		//printf("\tverify = %d\n", p[0]);
		s = offset[index];
		if (size < s)
		    s = size;
		verify(p, index, s);
	    }
	    array[index] = p;
	    fill(p, index, size);
	    offset[index] = rand() % size;
	    array[index] += offset[index];

	    //printf("p[0] = %d\n", p[0]);
	}
	gc.fullCollect();
    }

    p = null;
    array[] = null;
    gc.fullCollect();
    printStats(gc);
}

/* ---------------------------- */

/* ---------------------------- */

int main(int argc, char *argv[])
{
    GC *gc;

    printf("GC test start\n");

    gc = newGC();
printf("gc = %p\n", gc);
    gc.init();

    smoke();
    smoke2();
    smoke3();
    smoke4();
printf("gc = %p\n", gc);
    smoke5(gc);

    deleteGC(gc);

    printf("GC test success\n");
    return EXIT_SUCCESS;
}

GC *newGC()
{
    return (GC *)c.stdlib.calloc(1, GC.size);
}

void deleteGC(GC *gc)
{
    gc.Dtor();
    c.stdlib.free(gc);
}
