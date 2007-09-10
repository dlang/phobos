
/*
 *  Copyright (C) 2004 by Digital Mars, www.digitalmars.com
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

import std.c.stdlib;
import std.string;
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

ulong _d_new(uint length, uint size)
{
    void *p;
    ulong result;

    debug(PRINTF) printf("_d_new(length = %d, size = %d)\n", length, size);
    if (length == 0 || size == 0)
	result = 0;
    else
    {
	p = _gc.malloc(length * size);
	debug(PRINTF) printf(" p = %p\n", p);
	memset(p, 0, length * size);
	result = cast(ulong)length + (cast(ulong)cast(uint)p << 32);
    }
    return result;
}

ulong _d_newarrayi(uint length, uint size, ...)
{
    void *p;
    ulong result;

    debug(PRINTF) printf("_d_newarrayi(length = %d, size = %d)\n", length, size);
    if (length == 0 || size == 0)
	result = 0;
    else
    {   void* q = cast(void*)(&size + 1);	// pointer to initializer
	p = _gc.malloc(length * size);
	debug(PRINTF) printf(" p = %p\n", p);
	if (size == 1)
	    memset(p, *cast(ubyte*)q, length);
	else
	{
	    for (uint u = 0; u < length; u++)
	    {
		memcpy(p + u * size, q, size);
	    }
	}
	result = cast(ulong)length + (cast(ulong)cast(uint)p << 32);
    }
    return result;
}

ulong _d_newbitarray(uint length, bit value)
{
    void *p;
    ulong result;

    debug(PRINTF) printf("_d_newbitarray(length = %d, value = %d)\n", length, value);
    if (length == 0)
	result = 0;
    else
    {	uint size = (length + 7) >> 3;	// number of bytes
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
    uint length;
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
	    *pc = null;			// zero vptr
	}
    }
}

/+ ------------------------------------------------ +/


/******************************
 * Resize dynamic arrays other than bit[].
 */

extern (C)
byte[] _d_arraysetlength(uint newlength, uint sizeelem, Array *p)
{
    byte* newdata;
    uint newsize;

    debug(PRINTF)
    {
	printf("_d_arraysetlength(p = %p, sizeelem = %d, newlength = %d)\n", p, sizeelem, newlength);
	if (p)
	    printf("\tp.data = %p, p.length = %d\n", p.data, p.length);
    }

    assert(sizeelem);
    assert(!p.length || p.data);
    if (newlength)
    {
	newsize = sizeelem * newlength;
	if (p.length)
	{   uint size = p.length * sizeelem;

	    newdata = p.data;
	    if (newsize > size)
	    {
		uint cap = _gc.capacity(p.data);
		if (cap < newsize)
		{
		    newdata = cast(byte *)_gc.malloc(newsize);
		    newdata[0 .. size] = p.data[0 .. size];
		}
		newdata[size .. newsize] = 0;
	    }
	}
	else
	{
	    newdata = cast(byte *)_gc.calloc(newsize, 1);
	}
    }
    else
    {
	newdata = null;
    }

    p.data = newdata;
    p.length = newlength;
    return newdata[0 .. newlength];
}

/***************************
 * Resize bit[] arrays.
 */

extern (C)
bit[] _d_arraysetlengthb(uint newlength, Array *p)
{
    byte* newdata;
    uint newsize;

    debug (PRINTF)
	printf("p = %p, newlength = %d\n", p, newlength);

    assert(!p.length || p.data);
    if (newlength)
    {
	newsize = ((newlength + 31) >> 5) * 4;	// # bytes rounded up to uint
	if (p.length)
	{   uint size = ((p.length + 31) >> 5) * 4;

	    newdata = p.data;
	    if (newsize > size)
	    {
		uint cap = _gc.capacity(p.data);
		if (cap < newsize)
		{
		    newdata = cast(byte *)_gc.malloc(newsize);
		    newdata[0 .. size] = p.data[0 .. size];
		}
		newdata[size .. newsize] = 0;
	    }
	}
	else
	{
	    newdata = cast(byte *)_gc.calloc(newsize, 1);
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

/****************************************
 * Append y[] to array x[].
 * size is size of each array element.
 */

extern (C)
long _d_arrayappend(Array *px, byte[] y, uint size)
{

    uint cap = _gc.capacity(px.data);
    uint length = px.length;
    uint newlength = length + y.length;
    if (newlength * size > cap)
    {   byte* newdata;

	//newdata = cast(byte *)_gc.malloc(newlength * size);
	newdata = cast(byte *)_gc.malloc(newCapacity(newlength, size));
	memcpy(newdata, px.data, length * size);
	px.data = newdata;
    }
    px.length = newlength;
    memcpy(px.data + length * size, y, y.length * size);
    return *cast(long*)px;
}


uint newCapacity(uint newlength, uint size)
{
    version(none)
    {
	newcap = newlength * size;
    }
    else
    {
	/*
	 * Better version by davejf:
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
	uint newcap = newlength * size;
	uint newext = 0;

	if (newcap > 4096)
	{
	    //double mult2 = 1.0 + (size / log10(pow(newcap * 2.0,2.0)));

	    // Redo above line using only integer math

	    int log2plus1(uint c)
	    {   int i;

		    if (c == 0)
			i = -1;
		    else
			for (i = 1; c >>= 1; i++)
			    {   }
		    return i;
	    }

	    long mult = 100 + (1000L * size) / (6 * log2plus1(newcap));
	    // testing shows 1.02 for large arrays is about the point of diminishing return
	    if (mult < 102)
		mult = 102;
	    newext = cast(uint)((newcap * mult) / 100);
	    newext -= newext % size;
	    //printf("mult: %2.2f, mult2: %2.2f, alloc: %2.2f\n",mult/100.0,mult2,newext / cast(double)size);
	}
	newcap = newext > newcap ? newext : newcap;
    }
    return newcap;
}

extern (C)
byte[] _d_arrayappendc(inout byte[] x, in uint size, ...)
{
    uint cap = _gc.capacity(x);
    uint length = x.length;
    uint newlength = length + 1;
    if (newlength * size > cap)
    {   byte* newdata;

	//printf("_d_arrayappendc(%d, %d)\n", size, newlength);
	newdata = cast(byte *)_gc.malloc(newCapacity(newlength, size));
	memcpy(newdata, x, length * size);
	(cast(void **)(&x))[1] = newdata;
    }
    byte *argp = cast(byte *)(&size + 1);

    *cast(int *)&x = newlength;
    (cast(byte *)x)[length * size .. newlength * size] = argp[0 .. size];
    return x;

/+
    byte[] a;
    uint length;
    void *argp;

    //printf("size = %d\n", size);
    length = x.length + 1;
    a = new byte[length * size];
    memcpy(a, x, x.length * size);
    argp = &size + 1;
    //printf("*argp = %llx\n", *cast(long *)argp);
    memcpy(&a[x.length * size], argp, size);
    //printf("a[0] = %llx\n", *cast(long *)&a[0]);
    *cast(int *)&a = length;	// jam length
    //printf("a[0] = %llx\n", *cast(long *)&a[0]);
    x = a;
    return a;
+/
}


