
// D Language Runtime Library
// Copyright (c) 2001 by Digital Mars
// All Rights Reserved
// www.digitalmars.com

// Do array resizing.

#include <stdio.h>
#include <string.h>
#include <assert.h>

#define __STDC__ 1
#include <gc.h>

#include "mars.h"

extern GC gc;

typedef struct Array
{
    unsigned length;
    void *data;
} Array;

extern "C"
{

/******************************
 * Resize dynamic arrays other than bit[].
 */

Array __ddecl __d_arraysetlength(unsigned newlength, unsigned sizeelem, Array *p)
{
    void *newdata;
    unsigned newsize;

    //printf("p = %p, sizeelem = %d, newlength = %d\n", p, sizeelem, newlength);

    assert(sizeelem);
    assert((p->data && p->length) || (!p->data && !p->length));
    if (newlength)
    {
	newsize = sizeelem * newlength;
	newdata = (void *)gc.malloc(newsize);
	if (!newdata)
	    _d_OutOfMemory();
	if (p->data)
	{   unsigned size;

	    size = p->length * sizeelem;
	    if (newsize < size)
		size = newsize;
	    else if (newsize > size)
		memset((char *)newdata + size, 0, newsize - size);
	    memcpy(newdata, p->data, size);
	}
	else
	    memset(newdata, 0, newsize);
    }
    else
    {
	newdata = NULL;
    }

    p->data = newdata;
    p->length = newlength;
    return *p;
}

/***************************
 * Resize bit[] arrays.
 */

Array __ddecl __d_arraysetlengthb(unsigned newlength, Array *p)
{
    void *newdata;
    unsigned newsize;

    //printf("p = %p, newlength = %d\n", p, newlength);

    assert((p->data && p->length) || (!p->data && !p->length));
    if (newlength)
    {
	newsize = (newlength + 31) >> 5;	// # of unsigned
	newdata = (void *)gc.malloc(newsize * 4);
	if (!newdata)
	    _d_OutOfMemory();
	if (p->data)
	{   unsigned size;

	    size = (p->length + 31) >> 5;	// # of unsigned
	    if (newsize < size)
		size = newsize;
	    memcpy(newdata, p->data, size * 4);
	}
    }
    else
    {
	newdata = NULL;
    }

    p->data = newdata;
    p->length = newlength;
    return *p;
}

}
