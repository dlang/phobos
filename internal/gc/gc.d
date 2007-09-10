
/*
 *  Copyright (C) 2004-2005 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */


// Storage allocation

module std.gc;

//debug = PRINTF;

import std.c.stdarg;
import std.c.stdlib;
import std.c.string;
import gcx;
import std.outofmemory;
import gcstats;
import std.thread;

version=GCCLASS;

version (GCCLASS)
    alias GC gc_t;
else
    alias GC* gc_t;

gc_t _gc;

void addRoot(void *p)		      { _gc.addRoot(p); }
void removeRoot(void *p)	      { _gc.removeRoot(p); }
void addRange(void *pbot, void *ptop) { _gc.addRange(pbot, ptop); }
void removeRange(void *pbot)	      { _gc.removeRange(pbot); }
void fullCollect()		      { _gc.fullCollect(); }
void fullCollectNoStack()	      { _gc.fullCollectNoStack(); }
void genCollect()		      { _gc.genCollect(); }
void minimize()			      { _gc.minimize(); }
void disable()			      { _gc.disable(); }
void enable()			      { _gc.enable(); }
void getStats(out GCStats stats)      { _gc.getStats(stats); }

void* getGCHandle()
{
    return cast(void*)_gc;
}

void setGCHandle(void* p)
{
    void* oldp = getGCHandle();
    gc_t g = cast(gc_t)p;
    if (g.gcversion != gcx.GCVERSION)
	throw new Error("incompatible gc versions");

    // Add our static data to the new gc
    GC.scanStaticData(g);

    _gc = g;
//    return oldp;
}

void endGCHandle()
{
    GC.unscanStaticData(_gc);
}

extern (C)
{

void _d_monitorrelease(Object h);


void gc_init()
{
    version (GCCLASS)
    {	void* p;
	ClassInfo ci = GC.classinfo;

	p = std.c.stdlib.malloc(ci.init.length);
	(cast(byte*)p)[0 .. ci.init.length] = ci.init[];
	_gc = cast(GC)p;
    }
    else
    {
	_gc = cast(GC *) std.c.stdlib.calloc(1, GC.sizeof);
    }
    _gc.initialize();
    GC.scanStaticData(_gc);
    std.thread.Thread.thread_init();
}

void gc_term()
{
    _gc.fullCollectNoStack();
}

Object _d_newclass(ClassInfo ci)
{
    void *p;

    debug(PRINTF) printf("_d_newclass(ci = %p)\n", ci);
    if (ci.flags & 1)			// if COM object
    {
	p = cast(Object)std.c.stdlib.malloc(ci.init.length);
	if (!p)
	    _d_OutOfMemory();
    }
    else
    {
	p = _gc.malloc(ci.init.length);
	debug(PRINTF) printf(" p = %p\n", p);
	_gc.setFinalizer(p, &new_finalizer);
    }

    debug (PRINTF)
    {
	printf("p = %p\n", p);
	printf("ci = %p, ci.init = %p, len = %d\n", ci, ci.init, ci.init.length);
	printf("vptr = %p\n", *cast(void **)ci.init);
	printf("vtbl[0] = %p\n", (*cast(void ***)ci.init)[0]);
	printf("vtbl[1] = %p\n", (*cast(void ***)ci.init)[1]);
	printf("init[0] = %x\n", (cast(uint *)ci.init)[0]);
	printf("init[1] = %x\n", (cast(uint *)ci.init)[1]);
	printf("init[2] = %x\n", (cast(uint *)ci.init)[2]);
	printf("init[3] = %x\n", (cast(uint *)ci.init)[3]);
	printf("init[4] = %x\n", (cast(uint *)ci.init)[4]);
    }


    // Initialize it
    (cast(byte*)p)[0 .. ci.init.length] = ci.init[];

    //printf("initialization done\n");
    return cast(Object)p;
}

extern (D) alias void (*fp_t)(Object);		// generic function pointer

void _d_delinterface(void** p)
{
    if (*p)
    {
	Interface *pi = **cast(Interface ***)*p;
	Object o;

	o = cast(Object)(*p - pi.offset);
	_d_delclass(&o);
	*p = null;
    }
}

void _d_delclass(Object *p)
{
    if (*p)
    {
	debug (PRINTF) printf("_d_delclass(%p)\n", *p);
	version(0)
	{
	    ClassInfo **pc = cast(ClassInfo **)*p;
	    if (*pc)
	    {
		ClassInfo c = **pc;

		if (c.deallocator)
		{
		    _d_callfinalizer(*p);
		    fp_t fp = cast(fp_t)c.deallocator;
		    (*fp)(*p);			// call deallocator
		    *p = null;
		    return;
		}
	    }
	}
	_gc.free(*p);
	*p = null;
    }
}

ulong _d_new(size_t length, size_t size)
{
    void *p;
    ulong result;

    debug(PRINTF) printf("_d_new(length = %d, size = %d)\n", length, size);
    if (length == 0 || size == 0)
	result = 0;
    else
    {
	p = _gc.malloc(length * size + 1);
	debug(PRINTF) printf(" p = %p\n", p);
	memset(p, 0, length * size);
	result = cast(ulong)length + (cast(ulong)cast(uint)p << 32);
    }
    return result;
}

ulong _d_newarrayi(size_t length, size_t size, ...)
{
    void *p;
    ulong result;

    //debug(PRINTF) printf("_d_newarrayi(length = %d, size = %d)\n", length, size);
    if (length == 0 || size == 0)
	result = 0;
    else
    {
	//void* q = cast(void*)(&size + 1);	// pointer to initializer
	va_list q;
	va_start!(size_t)(q, size);		// q is pointer to ... initializer
	p = _gc.malloc(length * size + 1);
	debug(PRINTF) printf(" p = %p\n", p);
	if (size == 1)
	    memset(p, *cast(ubyte*)q, length);
	else if (size == int.sizeof)
	{
	    int init = *cast(int*)q;
	    for (uint u = 0; u < length; u++)
	    {
		(cast(int*)p)[u] = init;
	    }
	}
	else
	{
	    for (uint u = 0; u < length; u++)
	    {
		memcpy(p + u * size, q, size);
	    }
	}
	va_end(q);
	result = cast(ulong)length + (cast(ulong)cast(uint)p << 32);
    }
    return result;
}

ulong _d_newarrayii(size_t length, size_t size, size_t isize ...)
{
    void *p;
    ulong result;

    //debug(PRINTF) printf("_d_newarrayii(length = %d, size = %d, isize = %d)\n", length, size, isize);
    if (length == 0 || size == 0)
	result = 0;
    else
    {
	//void* q = cast(void*)(&size + 1);	// pointer to initializer
	va_list q;
	va_start!(size_t)(q, isize);		// q is pointer to ... initializer
	size *= length;
	p = _gc.malloc(size * isize + 1);
	debug(PRINTF) printf(" p = %p\n", p);
	if (isize == 1)
	    memset(p, *cast(ubyte*)q, size);
	else if (isize == int.sizeof)
	{
	    int init = *cast(int*)q;
	    for (uint u = 0; u < size; u++)
	    {
		(cast(int*)p)[u] = init;
	    }
	}
	else
	{
	    for (uint u = 0; u < size; u++)
	    {
		memcpy(p + u * isize, q, isize);
	    }
	}
	va_end(q);
	result = cast(ulong)length + (cast(ulong)cast(uint)p << 32);
    }
    return result;
}

ulong _d_newm(size_t size, int ndims, ...)
{
    ulong result;

    //debug(PRINTF)
	//printf("_d_newm(size = %d, ndims = %d)\n", size, ndims);
    if (size == 0 || ndims == 0)
	result = 0;
    else
    {	va_list q;
	va_start!(int)(q, ndims);

	void[] foo(size_t* pdim, int ndims)
	{
	    size_t dim = *pdim;
	    void[] p;

	    if (ndims == 1)
	    {	p = _gc.malloc(dim * size + 1)[0 .. dim];
		memset(p.ptr, 0, dim * size + 1);
	    }
	    else
	    {
		p = _gc.malloc(dim * (void[]).sizeof + 1)[0 .. dim];
		for (int i = 0; i < dim; i++)
		{
		    (cast(void[]*)p.ptr)[i] = foo(pdim + 1, ndims - 1);
		}
	    }
	    return p;
	}

	size_t* pdim = cast(size_t *)q;
	result = cast(ulong)foo(pdim, ndims);
	//printf("result = %llx\n", result);

	version (none)
	{
	    for (int i = 0; i < ndims; i++)
	    {
		printf("index %d: %d\n", i, va_arg!(int)(q));
	    }
	}
	va_end(q);
    }
    return result;
}

ulong _d_newarraymi(size_t size, int ndims, ...)
{
    ulong result;

    //debug(PRINTF)
	//printf("_d_newarraymi(size = %d, ndims = %d)\n", size, ndims);
    if (size == 0 || ndims == 0)
	result = 0;
    else
    {	void* pinit;		// pointer to initializer
	va_list q;
	va_start!(int)(q, ndims);

	void[] foo(size_t* pdim, int ndims)
	{
	    size_t dim = *pdim;
	    void[] p;

	    if (ndims == 1)
	    {	p = _gc.malloc(dim * size + 1)[0 .. dim];
		if (size == 1)
		    memset(p.ptr, *cast(ubyte*)pinit, dim);
		else
		{
		    for (size_t u = 0; u < dim; u++)
		    {
			memcpy(p.ptr + u * size, pinit, size);
		    }
		}
	    }
	    else
	    {
		p = _gc.malloc(dim * (void[]).sizeof + 1)[0 .. dim];
		for (int i = 0; i < dim; i++)
		{
		    (cast(void[]*)p.ptr)[i] = foo(pdim + 1, ndims - 1);
		}
	    }
	    return p;
	}

	size_t* pdim = cast(size_t *)q;
	pinit = pdim + ndims;
	result = cast(ulong)foo(pdim, ndims);
	//printf("result = %llx\n", result);

	version (none)
	{
	    for (int i = 0; i < ndims; i++)
	    {
		printf("index %d: %d\n", i, va_arg!(int)(q));
		printf("init = %d\n", va_arg!(int)(q));
	    }
	}
	va_end(q);
    }
    return result;
}

ulong _d_newbitarray(size_t length, bit value)
{
    void *p;
    ulong result;

    debug(PRINTF) printf("_d_newbitarray(length = %d, value = %d)\n", length, value);
    if (length == 0)
	result = 0;
    else
    {	size_t size = (length + 8) >> 3;	// number of bytes
	ubyte fill = value ? 0xFF : 0;

	p = _gc.malloc(size);
	debug(PRINTF) printf(" p = %p\n", p);
	memset(p, fill, size);
	result = cast(ulong)length + (cast(ulong)cast(uint)p << 32);
    }
    return result;
}

struct Array
{
    size_t length;
    byte *data;
};

// Perhaps we should get a a size argument like _d_new(), so we
// can zero out the array?

void _d_delarray(Array *p)
{
    if (p)
    {
	assert(!p.length || p.data);
	if (p.data)
	    _gc.free(p.data);
	p.data = null;
	p.length = 0;
    }
}


void _d_delmemory(void* *p)
{
    if (*p)
    {
	_gc.free(*p);
	*p = null;
    }
}


}

void new_finalizer(void *p, void *dummy)
{
    //printf("new_finalizer(p = %p)\n", p);
    _d_callfinalizer(p);
}

extern (C)
void _d_callfinalizer(void *p)
{
    //printf("_d_callfinalizer(p = %p)\n", p);
    if (p)	// not necessary if called from gc
    {
	ClassInfo **pc = cast(ClassInfo **)p;
	if (*pc)
	{
	    ClassInfo c = **pc;

	    try
	    {
		do
		{
		    if (c.destructor)
		    {
			fp_t fp = cast(fp_t)c.destructor;
			(*fp)(cast(Object)p);		// call destructor
		    }
		    c = c.base;
		} while (c);
		if ((cast(void**)p)[1])	// if monitor is not null
		    _d_monitorrelease(cast(Object)p);
	    }
	    finally
	    {
		*pc = null;			// zero vptr
	    }
	}
    }
}

/+ ------------------------------------------------ +/


/******************************
 * Resize dynamic arrays with 0 initializers.
 */

extern (C)
byte[] _d_arraysetlength(size_t newlength, size_t sizeelem, Array *p)
in
{
    assert(sizeelem);
    assert(!p.length || p.data);
}
body
{
    byte* newdata;

    debug(PRINTF)
    {
	printf("_d_arraysetlength(p = %p, sizeelem = %d, newlength = %d)\n", p, sizeelem, newlength);
	if (p)
	    printf("\tp.data = %p, p.length = %d\n", p.data, p.length);
    }

    if (newlength)
    {
	version (D_InlineAsm_X86)
	{
	    size_t newsize = void;

	    asm
	    {
		mov	EAX,newlength	;
		mul	EAX,sizeelem	;
		mov	newsize,EAX	;
		jc	Loverflow	;
	    }
	}
	else
	{
	    size_t newsize = sizeelem * newlength;

	    if (newsize / newlength != sizeelem)
		goto Loverflow;
	}
	//printf("newsize = %x, newlength = %x\n", newsize, newlength);

	if (p.data)
	{
	    newdata = p.data;
	    if (newlength > p.length)
	    {
		size_t size = p.length * sizeelem;
		size_t cap = _gc.capacity(p.data);

		if (cap <= newsize)
		{
		    newdata = cast(byte *)_gc.malloc(newsize + 1);
		    newdata[0 .. size] = p.data[0 .. size];
		}
		newdata[size .. newsize] = 0;
	    }
	}
	else
	{
	    newdata = cast(byte *)_gc.calloc(newsize + 1, 1);
	}
    }
    else
    {
	newdata = p.data;
    }

    p.data = newdata;
    p.length = newlength;
    return newdata[0 .. newlength];

Loverflow:
    _d_OutOfMemory();
}

/**
 * Resize arrays for non-zero initializers.
 * (obsolete, replaced by _d_arraysetlength3)
 */
extern (C)
byte[] _d_arraysetlength2(size_t newlength, size_t sizeelem, Array *p, ...)
in
{
    assert(sizeelem);
    assert(!p.length || p.data);
}
body
{
    byte* newdata;

    debug(PRINTF)
    {
	printf("_d_arraysetlength2(p = %p, sizeelem = %d, newlength = %d)\n", p, sizeelem, newlength);
	if (p)
	    printf("\tp.data = %p, p.length = %d\n", p.data, p.length);
    }

    if (newlength)
    {
	version (D_InlineAsm_X86)
	{
	    size_t newsize = void;

	    asm
	    {
		mov	EAX,newlength	;
		mul	EAX,sizeelem	;
		mov	newsize,EAX	;
		jc	Loverflow	;
	    }
	}
	else
	{
	    size_t newsize = sizeelem * newlength;

	    if (newsize / newlength != sizeelem)
		goto Loverflow;
	}
	//printf("newsize = %x, newlength = %x\n", newsize, newlength);

	size_t size = p.length * sizeelem;
	if (p.data)
	{
	    newdata = p.data;
	    if (newlength > p.length)
	    {
		size_t cap = _gc.capacity(p.data);

		if (cap <= newsize)
		{
		    newdata = cast(byte *)_gc.malloc(newsize + 1);
		    newdata[0 .. size] = p.data[0 .. size];
		}
	    }
	}
	else
	{
	    newdata = cast(byte *)_gc.malloc(newsize + 1);
	}

	va_list q;
	va_start!(Array *)(q, p);	// q is pointer to initializer

	if (newsize > size)
	{
	    if (sizeelem == 1)
	    {
		//printf("newdata = %p, size = %d, newsize = %d, *q = %d\n", newdata, size, newsize, *cast(byte*)q);
		newdata[size .. newsize] = *(cast(byte*)q);
	    }
	    else
	    {
		for (size_t u = size; u < newsize; u += sizeelem)
		{
		    memcpy(newdata + u, q, sizeelem);
		}
	    }
	}
    }
    else
    {
	newdata = p.data;
    }

    p.data = newdata;
    p.length = newlength;
    return newdata[0 .. newlength];

Loverflow:
    _d_OutOfMemory();
}

/**
 * Resize arrays for non-zero initializers.
 *	p		pointer to array lvalue to be updated
 *	newlength	new .length property of array
 *	sizeelem	size of each element of array
 *	initsize	size of initializer
 *	...		initializer
 */
extern (C)
byte[] _d_arraysetlength3(size_t newlength, size_t sizeelem, Array *p,
	size_t initsize, ...)
in
{
    assert(sizeelem);
    assert(initsize);
    assert(initsize <= sizeelem);
    assert((sizeelem / initsize) * initsize == sizeelem);
    assert(!p.length || p.data);
}
body
{
    byte* newdata;

    debug(PRINTF)
    {
	printf("_d_arraysetlength3(p = %p, sizeelem = %d, newlength = %d, initsize = %d)\n", p, sizeelem, newlength, initsize);
	if (p)
	    printf("\tp.data = %p, p.length = %d\n", p.data, p.length);
    }

    if (newlength)
    {
	version (D_InlineAsm_X86)
	{
	    size_t newsize = void;

	    asm
	    {
		mov	EAX,newlength	;
		mul	EAX,sizeelem	;
		mov	newsize,EAX	;
		jc	Loverflow	;
	    }
	}
	else
	{
	    size_t newsize = sizeelem * newlength;

	    if (newsize / newlength != sizeelem)
		goto Loverflow;
	}
	//printf("newsize = %x, newlength = %x\n", newsize, newlength);

	size_t size = p.length * sizeelem;
	if (p.data)
	{
	    newdata = p.data;
	    if (newlength > p.length)
	    {
		size_t cap = _gc.capacity(p.data);

		if (cap <= newsize)
		{
		    newdata = cast(byte *)_gc.malloc(newsize + 1);
		    newdata[0 .. size] = p.data[0 .. size];
		}
	    }
	}
	else
	{
	    newdata = cast(byte *)_gc.malloc(newsize + 1);
	}

	va_list q;
	va_start!(size_t)(q, initsize);	// q is pointer to initializer

	if (newsize > size)
	{
	    if (initsize == 1)
	    {
		//printf("newdata = %p, size = %d, newsize = %d, *q = %d\n", newdata, size, newsize, *cast(byte*)q);
		newdata[size .. newsize] = *(cast(byte*)q);
	    }
	    else
	    {
		for (size_t u = size; u < newsize; u += initsize)
		{
		    memcpy(newdata + u, q, initsize);
		}
	    }
	}
    }
    else
    {
	newdata = p.data;
    }

    p.data = newdata;
    p.length = newlength;
    return newdata[0 .. newlength];

Loverflow:
    _d_OutOfMemory();
}

/***************************
 * Resize bit[] arrays.
 */

version (none)
{
extern (C)
bit[] _d_arraysetlengthb(size_t newlength, Array *p)
{
    byte* newdata;
    size_t newsize;

    debug (PRINTF)
	printf("p = %p, newlength = %d\n", p, newlength);

    assert(!p.length || p.data);
    if (newlength)
    {
	newsize = ((newlength + 31) >> 5) * 4;	// # bytes rounded up to uint
	if (p.length)
	{   size_t size = ((p.length + 31) >> 5) * 4;

	    newdata = p.data;
	    if (newsize > size)
	    {
		size_t cap = _gc.capacity(p.data);
		if (cap <= newsize)
		{
		    newdata = cast(byte *)_gc.malloc(newsize + 1);
		    newdata[0 .. size] = p.data[0 .. size];
		}
		newdata[size .. newsize] = 0;
	    }
	}
	else
	{
	    newdata = cast(byte *)_gc.calloc(newsize + 1, 1);
	}
    }
    else
    {
	newdata = null;
    }

    p.data = newdata;
    p.length = newlength;
    return (cast(bit *)newdata)[0 .. newlength];
}
}

/****************************************
 * Append y[] to array x[].
 * size is size of each array element.
 */

extern (C)
long _d_arrayappend(Array *px, byte[] y, size_t size)
{

    size_t cap = _gc.capacity(px.data);
    size_t length = px.length;
    size_t newlength = length + y.length;
    if (newlength * size > cap)
    {   byte* newdata;

	newdata = cast(byte *)_gc.malloc(newCapacity(newlength, size) + 1);
	memcpy(newdata, px.data, length * size);
	px.data = newdata;
    }
    px.length = newlength;
    memcpy(px.data + length * size, y.ptr, y.length * size);
    return *cast(long*)px;
}

version (none)
{
extern (C)
long _d_arrayappendb(Array *px, bit[] y)
{

    size_t cap = _gc.capacity(px.data);
    size_t length = px.length;
    size_t newlength = length + y.length;
    size_t newsize = (newlength + 7) / 8;
    if (newsize > cap)
    {	void* newdata;

	//newdata = _gc.malloc(newlength * size);
	newdata = _gc.malloc(newCapacity(newsize, 1) + 1);
	memcpy(newdata, px.data, (length + 7) / 8);
	px.data = cast(byte*)newdata;
    }
    px.length = newlength;
    if ((length & 7) == 0)
	// byte aligned, straightforward copy
	memcpy(px.data + length / 8, y, (y.length + 7) / 8);
    else
    {	bit* x = cast(bit*)px.data;

	for (size_t u = 0; u < y.length; u++)
	{
	    x[length + u] = y[u];
	}
    }
    return *cast(long*)px;
}
}

size_t newCapacity(size_t newlength, size_t size)
{
    version(none)
    {
	size_t newcap = newlength * size;
    }
    else
    {
	/*
	 * Better version by Dave Fladebo:
	 * This uses an inverse logorithmic algorithm to pre-allocate a bit more
	 * space for larger arrays.
	 * - Arrays smaller than 4096 bytes are left as-is, so for the most
	 * common cases, memory allocation is 1 to 1. The small overhead added
	 * doesn't effect small array perf. (it's virutally the same as
	 * current).
	 * - Larger arrays have some space pre-allocated.
	 * - As the arrays grow, the relative pre-allocated space shrinks.
	 * - The logorithmic algorithm allocates relatively more space for
	 * mid-size arrays, making it very fast for medium arrays (for
	 * mid-to-large arrays, this turns out to be quite a bit faster than the
	 * equivalent realloc() code in C, on Linux at least. Small arrays are
	 * just as fast as GCC).
	 * - Perhaps most importantly, overall memory usage and stress on the GC
	 * is decreased significantly for demanding environments.
	 */
	size_t newcap = newlength * size;
	size_t newext = 0;

	if (newcap > 4096)
	{
	    //double mult2 = 1.0 + (size / log10(pow(newcap * 2.0,2.0)));

	    // Redo above line using only integer math

	    static int log2plus1(size_t c)
	    {   int i;

		if (c == 0)
		    i = -1;
		else
		    for (i = 1; c >>= 1; i++)
			{   }
		return i;
	    }

	    /* The following setting for mult sets how much bigger
	     * the new size will be over what is actually needed.
	     * 100 means the same size, more means proportionally more.
	     * More means faster but more memory consumption.
	     */
	    //long mult = 100 + (1000L * size) / (6 * log2plus1(newcap));
	    long mult = 100 + (1000L * size) / log2plus1(newcap);

	    // testing shows 1.02 for large arrays is about the point of diminishing return
	    if (mult < 102)
		mult = 102;
	    newext = cast(size_t)((newcap * mult) / 100);
	    newext -= newext % size;
	    //printf("mult: %2.2f, mult2: %2.2f, alloc: %2.2f\n",mult/100.0,mult2,newext / cast(double)size);
	}
	newcap = newext > newcap ? newext : newcap;
	//printf("newcap = %d, newlength = %d, size = %d\n", newcap, newlength, size);
    }
    return newcap;
}

extern (C)
byte[] _d_arrayappendc(inout byte[] x, in size_t size, ...)
{
    size_t cap = _gc.capacity(x.ptr);
    size_t length = x.length;
    size_t newlength = length + 1;

    assert(cap == 0 || length * size <= cap);

    //printf("_d_arrayappendc(size = %d, ptr = %p, length = %d, cap = %d)\n", size, x.ptr, x.length, cap);

    if (newlength * size >= cap)
    {   byte* newdata;

	//printf("_d_arrayappendc(size = %d, newlength = %d, cap = %d)\n", size, newlength, cap);
	cap = newCapacity(newlength, size);
	assert(cap >= newlength * size);
	newdata = cast(byte *)_gc.malloc(cap + 1);
	memcpy(newdata, x.ptr, length * size);
	(cast(void **)(&x))[1] = newdata;
    }
    byte *argp = cast(byte *)(&size + 1);

    *cast(size_t *)&x = newlength;
    (cast(byte *)x)[length * size .. newlength * size] = argp[0 .. size];
    assert((cast(size_t)x.ptr & 15) == 0);
    assert(_gc.capacity(x.ptr) > x.length * size);
    return x;
}

extern (C)
byte[] _d_arraycat(byte[] x, byte[] y, size_t size)
out (result)
{
    //printf("_d_arraycat(%d,%p ~ %d,%p size = %d => %d,%p)\n", x.length, x.ptr, y.length, y.ptr, size, result.length, result.ptr);
    assert(result.length == x.length + y.length);
    for (size_t i = 0; i < x.length * size; i++)
	assert((cast(byte*)result)[i] == (cast(byte*)x)[i]);
    for (size_t i = 0; i < y.length * size; i++)
	assert((cast(byte*)result)[x.length * size + i] == (cast(byte*)y)[i]);

    size_t cap = _gc.capacity(result.ptr);
    assert(!cap || cap > result.length * size);
}
body
{
    version (none)
    {
	/* Cannot use this optimization because:
	 *  char[] a, b;
	 *  char c = 'a';
	 *	b = a ~ c;
	 *	c = 'b';
	 * will change the contents of b.
	 */
	if (!y.length)
	    return x;
	if (!x.length)
	    return y;
    }

    size_t xlen = x.length * size;
    size_t ylen = y.length * size;
    size_t len = xlen + ylen;
    if (!len)
	return null;

    byte* p = cast(byte*)_gc.malloc(len + 1);
    memcpy(p, x.ptr, xlen);
    memcpy(p + xlen, y.ptr, ylen);
    p[len] = 0;

    return p[0 .. x.length + y.length];
}


version (none)
{
extern (C)
bit[] _d_arrayappendcb(inout bit[] x, bit b)
{
    if (x.length & 7)
    {
	*cast(size_t *)&x = x.length + 1;
    }
    else
    {
	x.length = x.length + 1;
    }
    x[x.length - 1] = b;
    return x;
}
}
