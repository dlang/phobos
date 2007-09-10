//
// Copyright (C) 2001-2002 by Digital Mars
// All Rights Reserved
// Written by Walter Bright
// www.digitalmars.com


// Storage allocation

//debug = PRINTF;

import c.stdlib;
import string;
import gcx;
import outofmemory;
import gcstats;

GC* _gc;

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


extern (C)
{

void gc_init()
{
    _gc = (GC *) c.stdlib.calloc(1, GC.size);
    _gc.init();
    //_gc.setStackBottom(_atopsp);
    _gc.scanStaticData();
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
	p = (Object)c.stdlib.malloc(ci.init.length);
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
	printf("vptr = %p\n", *(void **)ci.init);
	printf("vtbl[0] = %p\n", (*(void ***)ci.init)[0]);
	printf("vtbl[1] = %p\n", (*(void ***)ci.init)[1]);
	printf("init[0] = %x\n", ((uint *)ci.init)[0]);
	printf("init[1] = %x\n", ((uint *)ci.init)[1]);
	printf("init[2] = %x\n", ((uint *)ci.init)[2]);
	printf("init[3] = %x\n", ((uint *)ci.init)[3]);
	printf("init[4] = %x\n", ((uint *)ci.init)[4]);
    }


    // Initialize it
    ((byte*)p)[0 .. ci.init.length] = ci.init[];

    //printf("initialization done\n");
    return (Object)p;
}

extern (D) alias void (*fp_t)(Object);		// generic function pointer

void _d_delclass(Object *p)
{
    if (*p)
    {
	version(0)
	{
	    ClassInfo **pc = (ClassInfo **)*p;
	    if (*pc)
	    {
		ClassInfo c = **pc;

		if (c.deallocator)
		{
		    if (c.destructor)
		    {
			fp_t fp = (fp_t)c.destructor;
			(*fp)(*p);		// call destructor
		    }
		    fp_t fp = (fp_t)c.deallocator;
		    (*fp)(*p);			// call deallocator
		    *pc = null;			// zero vptr
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
	result = (ulong)length + ((ulong)(uint)p << 32);
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
	ClassInfo **pc = (ClassInfo **)p;
	if (*pc)
	{
	    ClassInfo c = **pc;

	    do
	    {
		if (c.destructor)
		{
		    fp_t fp = (fp_t)c.destructor;
		    (*fp)((Object)p);		// call destructor
		}
		c = c.base;
	    } while (c);
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
		    newdata = (byte *)_gc.malloc(newsize);
		    newdata[0 .. size] = p.data[0 .. size];
		}
		newdata[size .. newsize] = 0;
	    }
	}
	else
	{
	    newdata = (byte *)_gc.calloc(newsize, 1);
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
		    newdata = (byte *)_gc.malloc(newsize);
		    newdata[0 .. size] = p.data[0 .. size];
		}
		newdata[size .. newsize] = 0;
	    }
	}
	else
	{
	    newdata = (byte *)_gc.calloc(newsize, 1);
	}
    }
    else
    {
	newdata = null;
    }

    p.data = newdata;
    p.length = newlength;
    return ((bit *)newdata)[0 .. newlength];
}

/****************************************
 * Append y[] to array x[].
 * size is size of each array element.
 */

extern (C)
Array _d_arrayappend(Array *px, byte[] y, uint size)
{

    uint cap = _gc.capacity(px.data);
    uint length = px.length;
    uint newlength = length + y.length;
    if (newlength * size > cap)
    {   byte* newdata;

	newdata = (byte *)_gc.malloc(newlength * size);
	memcpy(newdata, px.data, length * size);
	px.data = newdata;
    }
    px.length = newlength;
    px.data[length * size .. newlength * size] = y[];
    return *px;
}


extern (C)
byte[] _d_arrayappendc(inout byte[] x, in uint size, ...)
{
    uint cap = _gc.capacity(x);
    uint length = x.length;
    uint newlength = length + 1;
    if (newlength * size > cap)
    {   byte* newdata;

	newdata = (byte *)_gc.malloc(newlength * size);
	memcpy(newdata, x, length * size);
	((void **)(&x))[1] = newdata;
    }
    byte *argp = (byte *)(&size + 1);

    *(int *)&x = newlength;
    ((byte *)x)[length * size .. newlength * size] = argp[0 .. size];
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
    //printf("*argp = %llx\n", *(long *)argp);
    memcpy(&a[x.length * size], argp, size);
    //printf("a[0] = %llx\n", *(long *)&a[0]);
    *(int *)&a = length;	// jam length
    //printf("a[0] = %llx\n", *(long *)&a[0]);
    x = a;
    return a;
+/
}


