
// D Language Runtime Library
// Copyright (c) 2001 by Digital Mars
// All Rights Reserved
// www.digitalmars.com

// Do array resizing.

import gc;

extern GC gc;

struct Array
{
    uint length;
    byte* data;
}


/******************************
 * Resize dynamic arrays other than bit[].
 */

Array __d_arraysetlength(uint newlength, uint sizeelem, Array *p)
{
    byte* newdata;
    uint newsize;

    //printf("p = %p, sizeelem = %d, newlength = %d\n", p, sizeelem, newlength);

    assert(sizeelem);
    assert((p.data && p.length) || (!p.data && !p.length));
    if (newlength)
    {
	newsize = sizeelem * newlength;
	newdata = (byte *)gc.malloc(newsize);
	if (p.data)
	{   uint size;

	    size = p.length * sizeelem;
	    if (newsize < size)
		size = newsize;
	    else if (newsize > size)
		newdata[size .. newsize] = 0;
	    newdata[0 .. size] = p.data[0 .. size];
	}
	else
	    newdata[0 .. newsize] = 0;
    }
    else
    {
	newdata = null;
    }

    p.data = newdata;
    p.length = newlength;
    return *p;
}

/***************************
 * Resize bit[] arrays.
 */

Array __d_arraysetlengthb(uint newlength, Array *p)
{
    byte* newdata;
    uint newsize;

    //printf("p = %p, newlength = %d\n", p, newlength);

    assert((p.data && p.length) || (!p.data && !p.length));
    if (newlength)
    {
	newsize = (newlength + 31) >> 5;	// # of uint
	newdata = (byte *)gc.malloc(newsize * 4);
	if (p.data)
	{   uint size;

	    size = (p.length + 31) >> 5;	// # of uint
	    if (newsize < size)
		size = newsize;
	    newdata[0 .. size * 4] = p.data[0 .. size * 4];
	}
    }
    else
    {
	newdata = NULL;
    }

    p.data = newdata;
    p.length = newlength;
    return *p;
}
