/**
 * Part of the D programming language runtime library.
 */

/*
 *  Copyright (C) 2004-2007 by Digital Mars, www.digitalmars.com
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

public import std.c.stdarg;
public import std.c.stdlib;
public import std.c.string;
public import gcx;
public import std.outofmemory;
public import gcstats;
public import std.thread;

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
void hasPointers(void* p)	      { _gc.hasPointers(p); }
void hasNoPointers(void* p)	      { _gc.hasNoPointers(p); }
void setV1_0()			      { _gc.setV1_0(); }

void setTypeInfo(TypeInfo ti, void* p)
{
    if (ti.flags() & 1)
	hasNoPointers(p);
    else
	hasPointers(p);
}

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

    debug(PRINTF) printf("_d_newclass(ci = %p, %s)\n", ci, cast(char *)ci.name);
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
	if (ci.flags & 2)
	    _gc.hasNoPointers(p);
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

/******************************************
 * Allocate a new array of length elements.
 * ti is the type of the resulting array, or pointer to element.
 */

/* For when the array is initialized to 0 */
ulong _d_newarrayT(TypeInfo ti, size_t length)
{
    void *p;
    ulong result;
    auto size = ti.next.tsize();		// array element size

    debug(PRINTF) printf("_d_newT(length = %d, size = %d)\n", length, size);
    if (length == 0 || size == 0)
	result = 0;
    else
    {
	size *= length;
	p = _gc.malloc(size + 1);
	debug(PRINTF) printf(" p = %p\n", p);
	if (!(ti.next.flags() & 1))
	    _gc.hasNoPointers(p);
	memset(p, 0, size);
	result = cast(ulong)length + (cast(ulong)cast(uint)p << 32);
    }
    return result;
}

/* For when the array has a non-zero initializer.
 */
ulong _d_newarrayiT(TypeInfo ti, size_t length)
{
    ulong result;
    auto size = ti.next.tsize();		// array element size

    //debug(PRINTF) printf("_d_newarrayiT(length = %d, size = %d, isize = %d)\n", length, size, isize);
    if (length == 0 || size == 0)
	result = 0;
    else
    {
	auto initializer = ti.next.init();
	auto isize = initializer.length;
	auto q = initializer.ptr;
	size *= length;
	auto p = _gc.malloc(size + 1);
	debug(PRINTF) printf(" p = %p\n", p);
	if (!(ti.next.flags() & 1))
	    _gc.hasNoPointers(p);
	if (isize == 1)
	    memset(p, *cast(ubyte*)q, size);
	else if (isize == int.sizeof)
	{
	    int init = *cast(int*)q;
	    size /= int.sizeof;
	    for (size_t u = 0; u < size; u++)
	    {
		(cast(int*)p)[u] = init;
	    }
	}
	else
	{
	    for (size_t u = 0; u < size; u += isize)
	    {
		memcpy(p + u, q, isize);
	    }
	}
	va_end(q);
	result = cast(ulong)length + (cast(ulong)cast(uint)p << 32);
    }
    return result;
}

ulong _d_newarraymT(TypeInfo ti, int ndims, ...)
{
    ulong result;

    //debug(PRINTF)
	//printf("_d_newarraymT(ndims = %d)\n", ndims);
    if (ndims == 0)
	result = 0;
    else
    {	va_list q;
	va_start!(int)(q, ndims);

	void[] foo(TypeInfo ti, size_t* pdim, int ndims)
	{
	    size_t dim = *pdim;
	    void[] p;

	    //printf("foo(ti = %p, ti.next = %p, dim = %d, ndims = %d\n", ti, ti.next, dim, ndims);
	    if (ndims == 1)
	    {
		auto r = _d_newarrayT(ti, dim);
		p = *cast(void[]*)(&r);
	    }
	    else
	    {
		p = _gc.malloc(dim * (void[]).sizeof + 1)[0 .. dim];
		for (int i = 0; i < dim; i++)
		{
		    (cast(void[]*)p.ptr)[i] = foo(ti.next, pdim + 1, ndims - 1);
		}
	    }
	    return p;
	}

	size_t* pdim = cast(size_t *)q;
	result = cast(ulong)foo(ti, pdim, ndims);
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

ulong _d_newarraymiT(TypeInfo ti, int ndims, ...)
{
    ulong result;

    //debug(PRINTF)
	//printf("_d_newarraymi(size = %d, ndims = %d)\n", size, ndims);
    if (ndims == 0)
	result = 0;
    else
    {
	va_list q;
	va_start!(int)(q, ndims);

	void[] foo(TypeInfo ti, size_t* pdim, int ndims)
	{
	    size_t dim = *pdim;
	    void[] p;

	    if (ndims == 1)
	    {
		auto r = _d_newarrayiT(ti, dim);
		p = *cast(void[]*)(&r);
	    }
	    else
	    {
		p = _gc.malloc(dim * (void[]).sizeof + 1)[0 .. dim];
		for (int i = 0; i < dim; i++)
		{
		    (cast(void[]*)p.ptr)[i] = foo(ti.next, pdim + 1, ndims - 1);
		}
	    }
	    return p;
	}

	size_t* pdim = cast(size_t *)q;
	result = cast(ulong)foo(ti, pdim, ndims);
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
byte[] _d_arraysetlengthT(TypeInfo ti, size_t newlength, Array *p)
in
{
    assert(ti);
    assert(!p.length || p.data);
}
body
{
    byte* newdata;
    size_t sizeelem = ti.next.tsize();

    debug(PRINTF)
    {
	printf("_d_arraysetlengthT(p = %p, sizeelem = %d, newlength = %d)\n", p, sizeelem, newlength);
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
		    if (!(ti.next.flags() & 1))
			_gc.hasNoPointers(newdata);
		}
		newdata[size .. newsize] = 0;
	    }
	}
	else
	{
	    newdata = cast(byte *)_gc.calloc(newsize + 1, 1);
	    if (!(ti.next.flags() & 1))
		_gc.hasNoPointers(newdata);
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
byte[] _d_arraysetlengthiT(TypeInfo ti, size_t newlength, Array *p)
in
{
    assert(!p.length || p.data);
}
body
{
    byte* newdata;
    size_t sizeelem = ti.next.tsize();
    void[] initializer = ti.next.init();
    size_t initsize = initializer.length;

    assert(sizeelem);
    assert(initsize);
    assert(initsize <= sizeelem);
    assert((sizeelem / initsize) * initsize == sizeelem);

    debug(PRINTF)
    {
	printf("_d_arraysetlengthiT(p = %p, sizeelem = %d, newlength = %d, initsize = %d)\n", p, sizeelem, newlength, initsize);
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
	    if (!(ti.next.flags() & 1))
		_gc.hasNoPointers(newdata);
	}

	auto q = initializer.ptr;	// pointer to initializer

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

/****************************************
 * Append y[] to array x[].
 * size is size of each array element.
 */

extern (C)
long _d_arrayappendT(TypeInfo ti, Array *px, byte[] y)
{
    auto size = ti.next.tsize();		// array element size
    size_t cap = _gc.capacity(px.data);
    size_t length = px.length;
    size_t newlength = length + y.length;
    if (newlength * size > cap)
    {   byte* newdata;

	newdata = cast(byte *)_gc.malloc(newCapacity(newlength, size) + 1);
	if (!(ti.next.flags() & 1))
	    _gc.hasNoPointers(newdata);
	memcpy(newdata, px.data, length * size);
	px.data = newdata;
    }
    px.length = newlength;
    memcpy(px.data + length * size, y.ptr, y.length * size);
    return *cast(long*)px;
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
byte[] _d_arrayappendcT(TypeInfo ti, inout byte[] x, ...)
{
    auto size = ti.next.tsize();		// array element size
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
	if (!(ti.next.flags() & 1))
	    _gc.hasNoPointers(newdata);
	memcpy(newdata, x.ptr, length * size);
	(cast(void **)(&x))[1] = newdata;
    }
    byte *argp = cast(byte *)(&ti + 2);

    *cast(size_t *)&x = newlength;
    (cast(byte *)x)[length * size .. newlength * size] = argp[0 .. size];
    assert((cast(size_t)x.ptr & 15) == 0);
    assert(_gc.capacity(x.ptr) > x.length * size);
    return x;
}

extern (C)
byte[] _d_arraycatT(TypeInfo ti, byte[] x, byte[] y)
out (result)
{
    auto size = ti.next.tsize();		// array element size
    //printf("_d_arraycatT(%d,%p ~ %d,%p size = %d => %d,%p)\n", x.length, x.ptr, y.length, y.ptr, size, result.length, result.ptr);
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

    //printf("_d_arraycatT(%d,%p ~ %d,%p)\n", x.length, x.ptr, y.length, y.ptr);
    auto size = ti.next.tsize();		// array element size
    //printf("_d_arraycatT(%d,%p ~ %d,%p size = %d)\n", x.length, x.ptr, y.length, y.ptr, size);
    size_t xlen = x.length * size;
    size_t ylen = y.length * size;
    size_t len = xlen + ylen;
    if (!len)
	return null;

    byte* p = cast(byte*)_gc.malloc(len + 1);
    if (!(ti.next.flags() & 1))
	_gc.hasNoPointers(p);
    memcpy(p, x.ptr, xlen);
    memcpy(p + xlen, y.ptr, ylen);
    p[len] = 0;

    return p[0 .. x.length + y.length];
}


extern (C)
byte[] _d_arraycatnT(TypeInfo ti, uint n, ...)
{   byte[] a;
    size_t length;
    byte[]* p;
    uint i;
    byte[] b;
    auto size = ti.next.tsize();		// array element size

    p = cast(byte[]*)(&n + 1);

    for (i = 0; i < n; i++)
    {
	b = *p++;
	length += b.length;
    }
    if (!length)
	return null;

    a = new byte[length * size];
    if (!(ti.next.flags() & 1))
	_gc.hasNoPointers(a.ptr);
    p = cast(byte[]*)(&n + 1);

    uint j = 0;
    for (i = 0; i < n; i++)
    {
	b = *p++;
	if (b.length)
	{
	    memcpy(&a[j], b.ptr, b.length * size);
	    j += b.length * size;
	}
    }

    *cast(int *)&a = length;	// jam length
    //a.length = length;
    return a;
}

extern (C)
void* _d_arrayliteralT(TypeInfo ti, size_t length, ...)
{
    auto size = ti.next.tsize();		// array element size
    byte[] result;

    //printf("_d_arrayliteralT(size = %d, length = %d)\n", size, length);
    if (length == 0 || size == 0)
	result = null;
    else
    {
	result = new byte[length * size];
	if (!(ti.next.flags() & 1))
	    _gc.hasNoPointers(result.ptr);
	*cast(size_t *)&result = length;	// jam length

	va_list q;
	va_start!(size_t)(q, length);

	size_t stacksize = (size + int.sizeof - 1) & ~(int.sizeof - 1);

	if (stacksize == size)
	{
	    memcpy(result.ptr, q, length * size);
	}
	else
	{
	    for (size_t i = 0; i < length; i++)
	    {
		memcpy(result.ptr + i * size, q, size);
		q += stacksize;
	    }
	}

	va_end(q);
    }
    return result.ptr;
}

/**********************************
 * Support for array.dup property.
 */

struct Array2
{
    size_t length;
    void* ptr;
}

extern (C)
long _adDupT(TypeInfo ti, Array2 a)
    out (result)
    {
	auto szelem = ti.next.tsize();		// array element size
	assert(memcmp((*cast(Array2*)&result).ptr, a.ptr, a.length * szelem) == 0);
    }
    body
    {
	Array2 r;

	if (a.length)
	{
	    auto szelem = ti.next.tsize();		// array element size
	    auto size = a.length * szelem;
	    r.ptr = cast(void *) new void[size];
	    if (!(ti.next.flags() & 1))
		_gc.hasNoPointers(r.ptr);
	    r.length = a.length;
	    memcpy(r.ptr, a.ptr, size);
	}
	return *cast(long*)(&r);
    }

unittest
{
    int[] a;
    int[] b;
    int i;

    debug(adi) printf("array.dup.unittest\n");

    a = new int[3];
    a[0] = 1; a[1] = 2; a[2] = 3;
    b = a.dup;
    assert(b.length == 3);
    for (i = 0; i < 3; i++)
	assert(b[i] == i + 1);
}


